import { NextRequest, NextResponse } from 'next/server'
import { parcelSocket } from '@/lib/sockets/parcels'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'
import type { BoundingBox } from '@/types/contractor'

// Mirrors app/api/contractors/route.ts. Bounding-box query over parcels_staging,
// composed with get_site_intelligence() flood/elevation. Kept behind the same
// rate limit + span cap. Per PRE_BUILD_SPEC this is the Phase-2 /api/properties
// endpoint.
//
// Tighter span cap than contractors: parcels are ~10.7M rows and each result
// currently triggers a spatial-join RPC, so we keep the viewport small.
const MAX_SPAN = 0.5

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
    return NextResponse.json(
      { error: 'Rate limit exceeded.' },
      {
        status: 429,
        headers: {
          'X-RateLimit-Limit': '30',
          'X-RateLimit-Remaining': '0',
          'X-RateLimit-Reset': String(Math.ceil(resetAt / 1000)),
          'Retry-After': String(Math.ceil((resetAt - Date.now()) / 1000)),
        },
      }
    )
  }

  const sp = req.nextUrl.searchParams
  const north = parseFloat(sp.get('north') ?? sp.get('neLat') ?? '')
  const south = parseFloat(sp.get('south') ?? sp.get('swLat') ?? '')
  const east  = parseFloat(sp.get('east')  ?? sp.get('neLng') ?? '')
  const west  = parseFloat(sp.get('west')  ?? sp.get('swLng') ?? '')

  if ([north, south, east, west].some(isNaN)) {
    return NextResponse.json(
      { error: 'Missing or invalid bounding box: north, south, east, west required' },
      { status: 400 }
    )
  }
  if (north <= south) {
    return NextResponse.json({ error: 'north must be greater than south' }, { status: 400 })
  }
  if ((north - south) > MAX_SPAN || Math.abs(east - west) > MAX_SPAN) {
    return NextResponse.json(
      { error: 'Bounding box too large. Maximum span is 0.5 degrees per axis.' },
      { status: 400 }
    )
  }

  const bounds: BoundingBox = { north, south, east, west }

  try {
    const properties = await parcelSocket.forMapWithIntel(bounds)
    return NextResponse.json(
      { properties, count: properties.length },
      {
        headers: {
          'X-RateLimit-Limit': '30',
          'X-RateLimit-Remaining': String(remaining),
          'X-RateLimit-Reset': String(Math.ceil(resetAt / 1000)),
          'Cache-Control': 'public, s-maxage=30, stale-while-revalidate=60',
        },
      }
    )
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/properties]', detail)
    return NextResponse.json({ error: 'Database error', detail }, { status: 500 })
  }
}
