import { NextRequest, NextResponse } from 'next/server'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWZxb3J3bWdheWlxbWJ0emNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjMxNjIzOCwiZXhwIjoyMDk3ODkyMjM4fQ.L23cjzASjDbuFQ1zeQt30CThOSX_aRwyWpbl7QLeO-E'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const { slug, ref, action, trade_category, city, state } = body

    if (!slug) return NextResponse.json({ ok: false }, { status: 400 })

    await fetch(`https://${SB_HOST}/rest/v1/scan_events`, {
      method: 'POST',
      headers: {
        'apikey': SB_KEY,
        'Authorization': 'Bearer ' + SB_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({
        slug,
        ref: ref ?? 'direct',
        action: action ?? 'page_view',
        trade_category: trade_category ?? null,
        city: city ?? null,
        state: state ?? null,
        ua: req.headers.get('user-agent') ?? null,
        ip: req.headers.get('x-forwarded-for') ?? null,
      }),
    })

    return NextResponse.json({ ok: true })
  } catch {
    return NextResponse.json({ ok: false }, { status: 400 })
  }
}