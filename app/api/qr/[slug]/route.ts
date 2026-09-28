/**
 * GET /api/qr/[slug]
 * Returns a QR code PNG for a contractor profile URL.
 *
 * Query params:
 *   size  — pixel size (default 256, max 512 for screen / 1200 for claimed hi-res)
 *   ref   — tracking ref appended to URL (e.g. ?ref=print)
 *
 * Screen-res (≤512) is public.
 * Print-res (>512) is EARNED (work order 730): only the signed-in owner of an approved claim gets it,
 * from the editor after completing their profile. The code always encodes /c/{slug}; never their URL.
 */

import { NextRequest, NextResponse } from 'next/server'
import QRCode from 'qrcode'
import { contractorSocket } from '@/lib/sockets/contractors'
import { CONTRACTOR_URL } from '@/lib/site'
import { resolveBusinessSlug } from '@/lib/business'
import { getSessionUser } from '@/lib/supabase/ssr-server'

const SCREEN_MAX = 512
const PRINT_MAX  = 1200

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug: rawSlug } = await params
  const { searchParams } = req.nextUrl

  const requestedSize = parseInt(searchParams.get('size') ?? '256', 10)
  const ref = searchParams.get('ref') ?? ''

  // Validate slug format
  if (!/^[a-z0-9-]+$/.test(rawSlug)) {
    return NextResponse.json({ error: 'Invalid slug' }, { status: 400 })
  }

  // A retired slug encodes the business's slug, so a new code never points at a retired one.
  const business = await resolveBusinessSlug(rawSlug)
  const slug = business?.slug ?? rawSlug

  // Look up contractor to verify it exists
  const contractor = await contractorSocket.forProfile(slug)
  if (!contractor) {
    return NextResponse.json({ error: 'Contractor not found' }, { status: 404 })
  }

  // Print-res gate: the signed-in owner of an approved claim on this business, nobody else.
  let isOwner = false
  if (requestedSize > SCREEN_MAX) {
    const user = await getSessionUser()
    if (user?.email) {
      const key = process.env.SUPABASE_SECRET_KEY ?? ''
      const r = await fetch('https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1/rpc/claim_state_for_business', {
        method: 'POST', cache: 'no-store',
        headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_slug: slug, p_email: user.email }),
      }).catch(() => null)
      const j = r?.ok ? await r.json() : null
      isOwner = j?.state === 'approved' && j?.mine === true
    }
    if (!isOwner) {
      return NextResponse.json(
        { error: 'The print-ready QR code is available to the business owner once they have claimed and completed their profile.' },
        { status: 403 }
      )
    }
  }
  const size = Math.min(Math.max(requestedSize, 64), isOwner ? PRINT_MAX : SCREEN_MAX)

  // Build target URL. Always the canonical host, never NEXT_PUBLIC_APP_URL: in production that
  // resolved to do-c-site.vercel.app, so every code issued encoded the Vercel host. A printed
  // code is permanent — it must name the domain the redirects live on.
  const baseUrl = CONTRACTOR_URL
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
