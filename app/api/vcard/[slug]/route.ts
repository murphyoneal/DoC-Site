import { NextRequest, NextResponse } from 'next/server'
import { contractorSocket } from '@/lib/sockets/contractors'
import { SITE_URL } from '@/lib/site'
import { resolveBusinessSlug } from '@/lib/business'

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug: rawSlug } = await params

  if (!/^[a-z0-9-]+$/.test(rawSlug)) {
    return NextResponse.json({ error: 'Invalid slug' }, { status: 400 })
  }

  // A saved contact must carry the business's slug, never a retired one.
  const business = await resolveBusinessSlug(rawSlug)
  const slug = business?.slug ?? rawSlug

  const c = await contractorSocket.forProfile(slug)
  if (!c) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 })
  }

  // Canonical host only — NEXT_PUBLIC_APP_URL resolved to do-c-site.vercel.app in production,
  // and a saved contact card keeps whatever URL it was given.
  const baseUrl = SITE_URL

  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${c.display_name}`,
    c.phone ? `TEL;TYPE=WORK,VOICE:${c.phone}` : null,
    c.city && c.state
      ? `ADR;TYPE=WORK:;;;${c.city};${c.state};${c.zip_code ?? ''};US` // no street — see the profile page
      : null,
    c.trade_label ? `TITLE:${c.trade_label}` : null,
    `URL:${baseUrl}/c/${slug}`,
    `NOTE:Licensed contractor. Licence ${c.license_number ?? 'N/A'} — ${c.license_status ?? 'unknown'}. Verify at ${baseUrl}/c/${slug}`,
    'END:VCARD',
  ].filter(Boolean).join('\r\n')

  return new NextResponse(lines, {
    status: 200,
    headers: {
      'Content-Type': 'text/vcard; charset=utf-8',
      'Content-Disposition': `attachment; filename="${slug}.vcf"`,
      'Cache-Control': 'no-cache',
    },
  })
}