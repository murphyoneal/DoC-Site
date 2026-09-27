// Self-registration (work order 699, ruling 701). A self-registered business is the business's own
// DECLARATION and lives in registered_business / registered_credential - never in contractors, which
// is a copy of the Florida DBPR file. Every read and write goes through a service_role SECURITY
// DEFINER function; the browser never reaches the tables.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY ?? ''
export const SB_HEADERS = { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' }
export const SB_REST = `https://${SB_HOST}/rest/v1`

import type { Geo } from './geo-display'
export type { Geo } from './geo-display'
export { countyDisplay } from './geo-display'

// The three check states (ruling 648/651). register_not_held says nothing about the business.
export type CheckState = 'register_held_matched' | 'register_held_no_match' | 'register_not_held'

export type PublicCredential = {
  kind: 'licence' | 'certification' | 'insurance'
  number: string | null
  issuing_state: string | null
  trade: string | null
  issuer: string | null
  expires_on: string | null
  declared_at: string
  check_state: CheckState
  check_note: string | null
  checked_at: string
  matched_slug: string | null
}

export type RegisteredPage = {
  slug: string
  business_name: string
  state: string
  state_abbr: string
  county: string | null
  county_level: string | null
  city: string | null
  trades: string[] | null
  other_services: string | null
  public_phone: string | null
  website: string | null
  registered_on: string
  approved_on: string | null
  credentials: PublicCredential[]
}

export async function getStates(): Promise<Geo[]> {
  try {
    const r = await fetch(`${SB_REST}/geo_reference?country_iso=eq.US&admin_level=eq.1&select=geo_id,name,admin1_abbr,level_type&order=name`,
      { headers: SB_HEADERS, next: { revalidate: 86400 } })
    return r.ok ? await r.json() : []
  } catch { return [] }
}

export async function getCounties(state: string): Promise<Geo[]> {
  if (!/^US-\d{2}$/.test(state)) return []
  try {
    const r = await fetch(`${SB_REST}/geo_reference?parent_geo_id=eq.${state}&admin_level=eq.2&select=geo_id,name,admin1_abbr,level_type&order=name`,
      { headers: SB_HEADERS, next: { revalidate: 86400 } })
    return r.ok ? await r.json() : []
  } catch { return [] }
}

export async function getRegisteredPage(slug: string): Promise<RegisteredPage | null> {
  try {
    const r = await fetch(`${SB_REST}/rpc/registered_business_page`, {
      method: 'POST', headers: SB_HEADERS, body: JSON.stringify({ p_slug: slug }), next: { revalidate: 300 },
    })
    return r.ok ? await r.json() : null
  } catch { return null }
}
