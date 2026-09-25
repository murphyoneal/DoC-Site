// The register's subject is a BUSINESS; a contractors row is one licence record of it
// (migration 128a). Every /c/{slug} consumer resolves through here so a retired slug — the
// second licence row of a business, e.g. red-stag-contracting-inc-jacksonville-fl-2 — lands
// permanently on the business's slug. Printed QR codes encode retired slugs too; they must
// keep resolving, which is why retired slugs are redirected and never deleted.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''

// A failed lookup returns null and the caller falls through to its per-licence page: a retired
// slug then renders its own licence record instead of redirecting. Degraded, never a 500.
async function rpc(fn: string, args: Record<string, unknown>, revalidate: number) {
  try {
    const res = await fetch(`https://${SB_HOST}/rest/v1/rpc/${fn}`, {
      method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify(args),
      next: { revalidate },
    })
    if (!res.ok) {
      console.error(`[business] ${fn} returned`, res.status, await res.text())
      return null
    }
    return await res.json()
  } catch (e) {
    console.error(`[business] ${fn} failed`, e)
    return null
  }
}

export type BusinessSlug = { slug: string; business_id: string; redirect: boolean }

// null = the slug is not in the business register (or the lookup failed). Callers then fall
// through to their existing per-licence lookup, which 404s exactly as before.
export async function resolveBusinessSlug(slug: string): Promise<BusinessSlug | null> {
  return (await rpc('resolve_business_slug', { p_slug: slug }, 300)) as BusinessSlug | null
}

export type BusinessLicence = {
  license_number: string | null
  trade_code: string
  trade_label: string | null
  license_status: string | null
  expiry_date: string | null
  holder_name: string | null
  link_basis: 'member' | 'qualifier'
}

export async function getBusinessLicences(slug: string): Promise<BusinessLicence[]> {
  return ((await rpc('get_business_licences', { p_slug: slug }, 300)) ?? []) as BusinessLicence[]
}

export type RelatedBusinesses = {
  field_status: 'present' | 'none_recorded'
  county_name: string | null
  items: { slug: string; name: string; trade_label: string | null; city: string | null; claimed: boolean }[]
}

// Same trade, same county; claimed first then alphabetical — never a ranking (migration 133a).
export async function getRelatedBusinesses(slug: string): Promise<RelatedBusinesses | null> {
  return (await rpc('get_related_businesses', { p_slug: slug, p_limit: 6 }, 3600)) as RelatedBusinesses | null
}

// Rebuilds a query string for a redirect, so ?ref=download on a printed code survives the hop
// and the scan is still attributed.
export function withQuery(path: string, searchParams: Record<string, string | string[] | undefined>) {
  const q = new URLSearchParams()
  for (const [k, v] of Object.entries(searchParams)) {
    if (typeof v === 'string') q.append(k, v)
    else if (Array.isArray(v)) v.forEach(x => q.append(k, x))
  }
  const s = q.toString()
  return s ? `${path}?${s}` : path
}
