import { NextRequest, NextResponse } from 'next/server'
import { addressSocket } from '@/lib/sockets/address'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'

// Address autocomplete endpoint. Searches our OWN parcel roll (never a vendor list)
// so every suggestion has a report behind it. When we don't hold the address we say
// so honestly — "assessed through 2025, new construction may not appear yet" — and
// log the miss with what the user typed, so the gap (typo vs format vs genuinely
// missing) is measured rather than guessed.

const MISS_MESSAGE =
  "We don't hold this address. Our roll is assessed through 2025 — recently platted or " +
  'newly built homes may not appear yet, and some addresses are recorded under a different ' +
  'city name than the post office uses. Try the street number and name alone, or a nearby address.'

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
      { status: 429, headers: { 'Retry-After': String(Math.ceil((resetAt - Date.now()) / 1000)) } }
    )
  }

  const q = (req.nextUrl.searchParams.get('q') ?? '').trim()
  if (q.length < 3) {
    return NextResponse.json({ held: false, results: [], tooShort: true })
  }

  try {
    const r = await addressSocket.search(q, 8)

    // Log misses server-side (reliable, not spoofable by a client omitting the call).
    if (!r.held) {
      await addressSocket.logMiss(r.query, r.normalized, r.results.length, 'no_results')
    }

    return NextResponse.json(
      {
        held: r.held,
        results: r.results,
        message: r.held ? null : MISS_MESSAGE,
      },
      {
        headers: {
          'X-RateLimit-Remaining': String(remaining),
          // short cache: autocomplete keystrokes repeat, but the roll is stable
          'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
        },
      }
    )
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/address-search]', detail)
    return NextResponse.json({ error: 'Search error', detail }, { status: 500 })
  }
}
