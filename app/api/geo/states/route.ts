import { NextResponse } from 'next/server'
import { getStates } from '@/lib/registration'

// The 50 states and DC, for forms that choose a county by state.
export async function GET() {
  return NextResponse.json(await getStates(), { headers: { 'Cache-Control': 'public, max-age=86400' } })
}
