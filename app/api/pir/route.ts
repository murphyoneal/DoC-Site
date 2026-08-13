import { NextRequest, NextResponse } from 'next/server'
import { pirSocket } from '@/lib/sockets/pir'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'

// Full PIR document for one parcel (co_no + parcel_id). One assembler RPC.
function getIp(req: NextRequest): string {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  )
}

export async function GET(req: NextRequest) {
  const ip = getIp(req)
  pruneRateLimitStore()
  const { allowed, remaining, resetAt } = checkRateLimit(ip)
  if (!allowed) {
    return NextResponse.json({ error: 'Rate limit exceeded.' }, {
      status: 429,
      headers: {
        'X-RateLimit-Limit': '30', 'X-RateLimit-Remaining': '0',
        'X-RateLimit-Reset': String(Math.ceil(resetAt / 1000)),
        'Retry-After': String(Math.ceil((resetAt - Date.now()) / 1000)),
      },
    })
  }

  const sp = req.nextUrl.searchParams
  const coNo = parseFloat(sp.get('co_no') ?? '')
  const parcelId = sp.get('parcel_id') ?? ''
  if (isNaN(coNo) || !parcelId) {
    return NextResponse.json({ error: 'co_no and parcel_id are required' }, { status: 400 })
  }

  try {
    const report = await pirSocket.forParcel(coNo, parcelId)
    if (!report) return NextResponse.json({ error: 'Report not found for that parcel' }, { status: 404 })
    return NextResponse.json(report, {
      headers: {
        'X-RateLimit-Limit': '30',
        'X-RateLimit-Remaining': String(remaining),
        'X-RateLimit-Reset': String(Math.ceil(resetAt / 1000)),
        'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=600',
      },
    })
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/pir]', detail)
    return NextResponse.json({ error: 'Database error', detail }, { status: 500 })
  }
}
