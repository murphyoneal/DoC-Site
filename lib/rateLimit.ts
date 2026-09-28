/**
 * In-memory rate limiter for /api/ routes.
 * For production, swap the store with Upstash Redis.
 * Window: 60 seconds. Max: 30 requests per IP.
 */

interface RateLimitEntry {
  count: number
  resetAt: number
}

const store = new Map<string, RateLimitEntry>()
const WINDOW_MS = 60_000
const MAX_REQUESTS = 30

/** Returns true if the IP is allowed, false if rate-limited */
export function checkRateLimit(ip: string, max: number = MAX_REQUESTS, windowMs: number = WINDOW_MS): {
  allowed: boolean
  remaining: number
  resetAt: number
} {
  const now = Date.now()
  const entry = store.get(ip)

  if (!entry || entry.resetAt < now) {
    // New window
    const resetAt = now + windowMs
    store.set(ip, { count: 1, resetAt })
    return { allowed: true, remaining: max - 1, resetAt }
  }

  if (entry.count >= max) {
    return { allowed: false, remaining: 0, resetAt: entry.resetAt }
  }

  entry.count++
  return { allowed: true, remaining: max - entry.count, resetAt: entry.resetAt }
}

/** Prune old entries (call periodically to prevent memory leak) */
export function pruneRateLimitStore(): void {
  const now = Date.now()
  for (const [key, entry] of store.entries()) {
    if (entry.resetAt < now) store.delete(key)
  }
}

/** The caller's IP as the edge reports it. Per-instance and in-memory: a speed bump against one
 *  script in a loop, not a control against a distributed one. */
export function clientIp(req: { headers: Headers }): string {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  )
}
