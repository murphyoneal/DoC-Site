import { NextRequest, NextResponse } from 'next/server'
import { getCounties, getCountiesByIds } from '@/lib/registration'

// Counties (and parishes, boroughs, independent cities) for one state - or, with ?ids=, the named
// counties themselves - from geo_reference, seeded from the Census 2020 FIPS list (migration 141b).
export async function GET(req: NextRequest) {
  const ids = req.nextUrl.searchParams.get('ids')
  if (ids) return NextResponse.json(await getCountiesByIds(ids.split(',').slice(0, 60)))
  const state = req.nextUrl.searchParams.get('state') ?? ''
  const counties = await getCounties(state)
  return NextResponse.json(counties, { headers: { 'Cache-Control': 'public, max-age=86400' } })
}
