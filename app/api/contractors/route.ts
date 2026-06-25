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