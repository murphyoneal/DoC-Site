import { NextRequest, NextResponse } from 'next/server'
import { pirSocket } from '@/lib/sockets/pir'
import { checkRateLimit, pruneRateLimitStore, clientIp } from '@/lib/rateLimit'

// Real-geometry map layers for the PIR (parcel boundary + flood + zoning),
// clipped to a real radius circle. Consumed by PropertyReportMap (client).
// Only headers Vercel's edge sets are trusted (lib/rateLimit clientIp): the domains are not proxied
// through Cloudflare, so a cf-connecting-ip header would be the caller's own choice.
const getIp = (req: NextRequest): string => clientIp(req)

export async function GET(req: NextRequest) {
  const ip = getIp(req)
  pruneRateLimitStore()
  const { allowed, remaining, resetAt } = checkRateLimit(ip)
  if (!allowed) {
    return NextResponse.json({ error: 'Rate limit exceeded.' }, {
      status: 429,
      headers: { 'X-RateLimit-Limit': '30', 'X-RateLimit-Remaining': '0', 'Retry-After': String(Math.ceil((resetAt - Date.now()) / 1000)) },
    })
  }

  const sp = req.nextUrl.searchParams
  const coNo = parseFloat(sp.get('co_no') ?? '')
  const parcelId = sp.get('parcel_id') ?? ''
  const radius = parseFloat(sp.get('radius') ?? '8047')
  if (isNaN(coNo) || !parcelId) {
    return NextResponse.json({ error: 'co_no and parcel_id are required' }, { status: 400 })
  }

  try {
    const geo = await pirSocket.mapGeoJson(coNo, parcelId, isNaN(radius) ? 8047 : radius)
    if (!geo) return NextResponse.json({ error: 'No geometry for that parcel' }, { status: 404 })
    return NextResponse.json(geo, {
      headers: {
        'X-RateLimit-Remaining': String(remaining),
        'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
      },
    })
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/pir/map]', detail)
    return NextResponse.json({ error: 'Database error', detail }, { status: 500 })
  }
}
