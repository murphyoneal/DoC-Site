import { NextRequest, NextResponse } from 'next/server'
import { getCounties } from '@/lib/registration'

// Counties (and parishes, boroughs, independent cities) for one state, for the self-registration
// form's county list. From geo_reference, seeded from the Census 2020 FIPS list (migration 141b).
export async function GET(req: NextRequest) {
  const state = req.nextUrl.searchParams.get('state') ?? ''
  const counties = await getCounties(state)
  return NextResponse.json(counties, { headers: { 'Cache-Control': 'public, max-age=86400' } })
}
