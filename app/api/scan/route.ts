import { NextRequest, NextResponse } from 'next/server'

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const {
      slug,
      ref,
      action,
      trade_category,
      city,
      state,
    } = body

    console.log('[scan]', {
      slug,
      ref: ref ?? 'direct',
      action: action ?? 'page_view',
      trade_category: trade_category ?? null,
      city: city ?? null,
      state: state ?? null,
      timestamp: new Date().toISOString(),
      ua: req.headers.get('user-agent') ?? null,
      ip: req.headers.get('x-forwarded-for') ?? null,
    })

    return NextResponse.json({ ok: true })
  } catch {
    return NextResponse.json({ ok: false }, { status: 400 })
  }
}