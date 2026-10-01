import { NextRequest, NextResponse } from 'next/server'
import { contractorSocket } from '@/lib/sockets/contractors'
import { CONTRACTOR_URL } from '@/lib/site'
import { resolveBusinessSlug } from '@/lib/business'
import { getPublicBusinessProfile } from '@/lib/business-profile'
import { vcardLicenceNote } from '@/lib/vcard-note.mjs'

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

  // Contact lines only from what a CLAIMED business chose to publish (712), never the DBPR copy.
  const own = c.claimed ? await getPublicBusinessProfile(slug) : null

  // Canonical host only — NEXT_PUBLIC_APP_URL resolved to do-c-site.vercel.app in production,
  // and a saved contact card keeps whatever URL it was given.
  const baseUrl = CONTRACTOR_URL

  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${c.display_name}`,
    own?.phone ? `TEL;TYPE=WORK,VOICE:${own.phone}` : null,
    own?.email ? `EMAIL;TYPE=WORK:${own.email}` : null,
    own?.website ? `URL;TYPE=WORK:${own.website}` : null,
    c.city && c.state
      ? `ADR;TYPE=WORK:;;;${c.city};${c.state};${c.zip_code ?? ''};US` // no street — see the profile page
      : null,
    c.trade_label ? `TITLE:${c.trade_label}` : null,
    `URL:${baseUrl}/c/${slug}`,
    `NOTE:${vcardLicenceNote(c as Parameters<typeof vcardLicenceNote>[0], `${baseUrl}/c/${slug}`)}`,
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