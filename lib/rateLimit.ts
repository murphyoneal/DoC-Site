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

/** The caller's IP as VERCEL's edge reports it. Only headers Vercel sets are trusted: the domains are
 *  not proxied through Cloudflare, so a cf-connecting-ip header would come from the client itself and
 *  could forge the logged IP or dodge a rate limit. The limiter is per-instance and in-memory: a speed
 *  bump against one script in a loop, not a control against a distributed one. */
export function clientIp(req: { headers: Headers }): string {
  return (
    req.headers.get('x-vercel-forwarded-for')?.split(',')[0]?.trim() ||
    req.headers.get('x-real-ip')?.trim() ||
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    'unknown'
  )
}

/**
 * 210f (ruling 975): the PERSISTED limit for write routes. The Map above is per serverless instance, so it limits one
 * warm instance and nothing else; this counts in the database (rate_limit_take, per-key lock). If the database cannot
 * be reached it falls back to the in-memory check - a guard that fails closed on its own outage becomes the outage
 * (CLAUDE.md invariant 4) - and says so in the log.
 */
export async function takeLimit(key: string, max: number, windowMs: number): Promise<boolean> {
  const sk = process.env.SUPABASE_SECRET_KEY ?? ''
  try {
    const r = await fetch('https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1/rpc/rate_limit_take', {
      method: 'POST', cache: 'no-store',
      headers: { apikey: sk, Authorization: 'Bearer ' + sk, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_key: key.slice(0, 300), p_max: max, p_window_seconds: Math.max(1, Math.round(windowMs / 1000)) }),
    })
    if (!r.ok) throw new Error(`HTTP ${r.status}`)
    const j = await r.json()
    return j?.allowed === true
  } catch (e) {
    console.error('[rateLimit] persisted limit unavailable, using the per-instance one:', e instanceof Error ? e.message : String(e))
    return checkRateLimit(key, max, windowMs).allowed
  }
}
