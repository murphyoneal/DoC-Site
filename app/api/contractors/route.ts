import { NextRequest, NextResponse } from 'next/server'
import { contractorSocket } from '@/lib/sockets/contractors'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'
import type { BoundingBox } from '@/types/contractor'

const MAX_SPAN = 2.0

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
      { status: 429, headers: { 'X-RateLimit-Limit': '30', 'X-RateLimit-Remaining': '0', 'X-RateLimit-Reset': String(Math.ceil(resetAt / 1000)), 'Retry-After': String(Math.ceil((resetAt - Date.now()) / 1000)) } }
    )
  }

  const sp = req.nextUrl.searchParams
  const north = parseFloat(sp.get('north') ?? sp.get('neLat') ?? '')
  const south = parseFloat(sp.get('south') ?? sp.get('swLat') ?? '')
  const east  = parseFloat(sp.get('east')  ?? sp.get('neLng') ?? '')
  const west  = parseFloat(sp.get('west')  ?? sp.get('swLng') ?? '')

  if ([north, south, east, west].some(isNaN)) {
    return NextResponse.json({ error: 'Missing or invalid bounding box: north, south, east, west required' }, { status: 400 })
  }

  if (north <= south) {
    return NextResponse.json({ error: 'north must be greater than south' }, { status: 400 })
  }

  if ((north - south) > MAX_SPAN || Math.abs(east - west) > MAX_SPAN) {
    return NextResponse.json({ error: 'Bounding box too large. Maximum span is 2 degrees per axis.' }, { status: 400 })
  }

  const bounds: BoundingBox = { north: north, south: south, east: east, west: west }
  const category = sp.get('category') ?? undefined
  const emergency = sp.get('emergency') === 'true'

  try {
    const contractors = await contractorSocket.forMap(bounds, { category: category, emergency: emergency })
    return NextResponse.json(
      { contractors: contractors, count: contractors.length },
      { headers: { 'X-RateLimit-Limit': '30', 'X-RateLimit-Remaining': String(remaining), 'X-RateLimit-Reset': String(Math.ceil(resetAt / 1000)), 'Cache-Control': 'public, s-maxage=30, stale-while-revalidate=60' } }
    )
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/contractors]', detail)
    return