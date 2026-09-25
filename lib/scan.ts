// Server-side scan logging (work order 653 (b)).
//
// Page views are recorded by the /c/[slug] request itself, not by the browser after it loads.
// Client-side logging missed every visitor without JavaScript (a curl check wrote zero rows) and
// can never see a visitor who is redirected before the page renders — which the planned QR
// destination redirect (645) depends on. Click events stay client-side in /api/scan.
//
// Callers read request headers BEFORE after() (a Server Component cannot read them inside it)
// and schedule this with after(), so logging never delays or breaks the page.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''

export type RequestMeta = { ua: string | null; ip: string | null; prefetch: boolean }

// A prefetch is the router fetching a page the visitor has not opened. Never a view.
export function requestMeta(h: Headers): RequestMeta {
  const purpose = (h.get('purpose') ?? h.get('sec-purpose') ?? '').toLowerCase()
  return {
    ua: h.get('user-agent'),
    ip: h.get('x-forwarded-for'),
    prefetch: h.has('next-router-prefetch') || purpose.includes('prefetch'),
  }
}

export async function logScanServer(e: {
  slug: string
  ref: string | null
  action: 'page_view' | 'slug_redirect' | 'scan_landing'
  tradeCategory?: string | null
  city?: string | null
  state?: string | null
  meta: RequestMeta
}): Promise<void> {
  if (e.meta.prefetch) return
  try {
    const res = await fetch(`https://${SB_HOST}/rest/v1/scan_events`, {
      method: 'POST',
      headers: {
        'apikey': SB_KEY,
        'Authorization': 'Bearer ' + SB_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal',
      },
      body: JSON.stringify({
        slug: e.slug,
        ref: e.ref ?? 'direct',
        action: e.action,
        trade_category: e.tradeCategory ?? null,
        city: e.city ?? null,
        state: e.state ?? null,
        ua: e.meta.ua,
        ip: e.meta.ip,
        logged_by: 'server',
      }),
      cache: 'no-store',
    })
    if (!res.ok) console.error('[scan] server log returned', res.status, await res.text())
  } catch (err) {
    console.error('[scan] server log failed', err)
  }
}

// ?ref may arrive as an array; the first value is the one a printed code carries.
export function firstParam(v: string | string[] | undefined): string | null {
  return Array.isArray(v) ? (v[0] ?? null) : (v ?? null)
}
