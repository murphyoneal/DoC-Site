/**
 * GET /api/qr/[slug]
 * Returns a QR code PNG for a contractor profile URL.
 *
 * Query params:
 *   size  — pixel size (default 256, max 512 for screen / 1200 for claimed hi-res)
 *   ref   — tracking ref appended to URL (e.g. ?ref=print)
 *
 * Screen-res (≤512) is public.
 * Hi-res (>512) requires claimed=true — placeholder for Phase 2 auth gate.
 */

import { NextRequest, NextResponse } from 'next/server'
import QRCode from 'qrcode'
import { contractorSocket } from '@/lib/sockets/contractors'

const SCREEN_MAX = 512
const PRINT_MAX  = 1200

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params
  const { searchParams } = req.nextUrl

  const requestedSize = parseInt(searchParams.get('size') ?? '256', 10)
  const ref = searchParams.get('ref') ?? ''

  // Validate slug format
  if (!/^[a-z0-9-]+$/.test(slug)) {
    return NextResponse.json({ error: 'Invalid slug' }, { status: 400 })
  }

  // Look up contractor to verify it exists
  const contractor = await contractorSocket.forProfile(slug)
  if (!contractor) {
    return NextResponse.json({ error: 'Contractor not found' }, { status: 404 })
  }

  // Hi-res gate — placeholder for Phase 2 (claimed + auth)
  const isClaimed = contractor.claimed === true
  const maxSize = isClaimed ? PRINT_MAX : SCREEN_MAX
  const size = Math.min(Math.max(requestedSize, 64), maxSize)

  if (requestedSize > SCREEN_MAX && !isClaimed) {
    return NextResponse.json(
      { error: 'Hi-resolution QR requires a claimed profile. Claim your profile to unlock print-ready downloads.' },
      { status: 403 }
    )
  }

  // Build target URL
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'https://departmentofconstruction.com'
  const targetUrl = ref
    ? `${baseUrl}/c/${slug}?ref=${encodeURIComponent(ref)}`
    : `${baseUrl}/c/${slug}`

  try {
    const qrBuffer = await QRCode.toBuffer(targetUrl, {
      type: 'png',
      width: size,
      margin: 2,
      color: {
        dark:  '#1B2A4A',  // navy — matches brand
        light: '#FAF7F2',  // cream
      },
      errorCorrectionLevel: 'M',
    })

    return new NextResponse(new Uint8Array(qrBuffer), {
      status: 200,
      headers: {
        'Content-Type': 'image/png',
        'Content-Disposition': `inline; filename="doc-qr-${slug}.png"`,
        'Cache-Control': 'public, max-age=86400, stale-while-revalidate=604800',
      },
    })
  } catch (err) {
    console.error('[/api/qr]', err)
    return NextResponse.json({ error: 'QR generation failed' }, { status: 500 })
  }
}
