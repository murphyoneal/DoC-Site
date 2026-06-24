/**
 * GET /api/contractors
 * Bounding box query — returns map pins only (no full records).
 *
 * Query params:
 *   north, south, east, west  — float bounding box coordinates (required)
 *   category                  — doc_category filter (optional)
 *   emergency                 — "true" to filter emergency_available (optional)
 *
 * Security:
 *   - Rate limited: 30 req/min per IP
 *   - Bounding box validated (max 2 degree span each axis)
 *   - Max 50 records returned
 *   - Supabase anon key NEVER used — service key server-side only
 */

import { NextRequest, NextResponse } from 'next/server'
import { contractorSocket } from '@/lib/sockets/contractors'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'
import type { BoundingBox } from '@/types/contractor'

const MAX_SPAN_DEGREES = 2.0  // ~220km — prevents near-full-state queries

function getClientIp(req: NextRequest): string {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  )
}

export async function GET(req: NextRequest) {
  // Rate limiting
  const ip = getClientIp(req)
  pruneRateLimitStore()
  const { allowed, remaining, resetAt } = checkRateLimit(ip)

  if (!allowed) {
    return NextResponse.json(
      { error: 'Rate limit exceeded. Please slow down.' },
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

  const { searchParams } = req.nextUrl

  // Accept both parameter formats:
  //   north/south/east/west      — canonical (ContractorMap)
  //   neLat/neLng/swLat/swLng   — alternate format
  const north = parseFloat(searchParams.get('north') ?? searchParams.get('neLat') ?? '')
  const south = parseFloat(searchParams.get('south') ?? searchParams.get('swLat') ?? '')
  const east  = parseFloat(searchParams.get('east')  ?? searchParams.get('neLng') ?? '')
  const west  = parseFloat(searchParams.get('west')  ?? searchParams.get('swLng') ?? '')

  if ([north, south, east, west].some(isNaN)) {
    return NextResponse.json(
      { error: 'Missing or invalid bounding box parameters: north, south, east, west required' },
      { status: 400 }
    )
  }

  // Validate coordinate ranges
  if (north < -90 || north > 90 || south < -90 || south > 90) {
    return NextResponse.json({ error: 'Latitude out of range' }, { status: 400 })
  }
  if (east < -180 || east > 180 || west < -180 || west > 180) {
    return NextResponse.json({ error: 'Longitude out of range' }, { status: 400 })
  }
  if (north <= south) {
    return NextResponse.json({ error: 'north must be greater than south' }, { status: 400 })
  }

  // Enforce max span — anti-scraping
  const latSpan = north - south
  const lngSpan = Math.abs(east - west)
  if (latSpan > MAX_SPAN_DEGREES || lngSpan > MAX_SPAN_DEGREES) {
    return NextResponse.json(
      { error: `Bounding box too large. Maximum span is ${MAX_SPAN_DEGREES} degrees per axis.` },
      { status: 400 }
    )
  }

  const bounds: BoundingBox = { north, south, east, west }
  const category  = searchParams.get('category') ?? undefined
  const emergency = searchParams.get('emergency') === 'true'

  try {
    const contractors = await contractorSocket.forMap(bounds, { category, emergency })

    return NextResponse.json(
      { contractors, count: contractors.length },
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
    console.error('[/api/contractors]', err)
    return NextResponse.json({ error: 'Database error' }, { status: 500 })
  }
}