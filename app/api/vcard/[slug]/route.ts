import { NextRequest, NextResponse } from 'next/server'
import { contractorSocket } from '@/lib/sockets/contractors'

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params

  if (!/^[a-z0-9-]+$/.test(slug)) {
    return NextResponse.json({ error: 'Invalid slug' }, { status: 400 })
  }

  const c = await contractorSocket.forProfile(slug)
  if (!c) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 })
  }

  const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? 'https://departmentofconstruction.com'

  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${c.display_name}`,
    c.phone ? `TEL;TYPE=WORK,VOICE:${c.phone}` : null,
    c.city && c.state
      ? `ADR;TYPE=WORK:;;${c.address_line_1 ?? ''};${c.city};${c.state};${c.zip_code ?? ''};US`
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