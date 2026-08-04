import { getSupabaseAdmin } from '@/lib/supabase/server'

// Address autocomplete over our OWN parcel roll (parcels_staging.phy_addr1 +
// phy_city), served through SECURITY DEFINER RPCs (the table is not REST-granted).
// Anything returned is guaranteed to have a parcel — and therefore a report —
// behind it, which is the whole reason we don't buy a national address list.

export type AddressHit = {
  co_no: number
  parcel_id: string
  phy_addr1: string
  phy_city: string | null
  label: string
  score: number
}

export type AddressSearchResult = {
  query: string
  normalized: string
  results: AddressHit[]
  held: boolean
}

export const addressSocket = {
  async search(q: string, limit = 8): Promise<AddressSearchResult> {
    const sb = getSupabaseAdmin()
    const { data, error } = await sb.rpc('search_parcel_address', { p_q: q, p_limit: limit })
    if (error || !data || typeof data !== 'object') {
      console.error('[addressSocket] search_parcel_address failed:', error?.message ?? 'no data')
      return { query: q, normalized: '', results: [], held: false }
    }
    return data as AddressSearchResult
  },

  // Log an unresolved address with exactly what the user typed. Fire-and-forget:
  // a logging failure must never break the search response.
  async logMiss(q: string, normalized: string, count: number, kind = 'no_results'): Promise<void> {
    try {
      const sb = getSupabaseAdmin()
      await sb.rpc('log_address_miss', { p_q: q, p_normalized: normalized, p_count: count, p_kind: kind })
    } catch (e) {
      console.error('[addressSocket] log_address_miss failed:', e instanceof Error ? e.message : String(e))
    }
  },
}
