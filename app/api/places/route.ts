import { NextRequest, NextResponse } from 'next/server'
import { getPlaces } from '@/lib/registration'

// Census 2020 places (incorporated places and census-designated places) in one county, for the
// self-registration form's city dropdown (work order 705). A place that spans counties is listed
// under each of them.
export async function GET(req: NextRequest) {
  const county = req.nextUrl.searchParams.get('county') ?? ''
  const places = await getPlaces(county)
  return NextResponse.json(places, { headers: { 'Cache-Control': 'public, max-age=86400' } })
}
