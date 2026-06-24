/**
 * Contractor socket — server-side query helpers.
 * All queries use supabaseAdmin (service key).
 * NEVER call from client components.
 */
import { supabaseAdmin } from '@/lib/supabase/server'
import type { BoundingBox, Contractor, ContractorMapPin } from '@/types/contractor'

export const contractorSocket = {
  /** Bounding-box query for map pins — returns only fields needed for markers */
  forMap: async (
    bounds: BoundingBox,
    filters: { category?: string; emergency?: boolean } = {},
    limit = 50
  ): Promise<ContractorMapPin[]> => {
    let query = supabaseAdmin
      .from('contractors')
      .select(
        'id,slug,display_name,trade_label,doc_category,city,state,lat,lng,tier,verified,emergency_available,license_status'
      )
      .eq('active', true)
      .gte('lat', bounds.south)
      .lte('lat', bounds.north)
      .gte('lng', bounds.west)
      .lte('lng', bounds.east)
      .eq('geocoded', true)
      .limit(limit)

    if (filters.category) {
      query = query.eq('doc_category', filters.category)
    }
    if (filters.emergency) {
      query = query.eq('emergency_available', true)
    }

    const { data, error } = await query
    if (error) throw error
    return (data ?? []) as ContractorMapPin[]
  },

  /** Full profile record for /c/[slug] page */
  forProfile: async (slug: string): Promise<Contractor | null> => {
    const { data, error } = await supabaseAdmin
      .from('contractors')
      .select('*')
      .eq('slug', slug)
      .eq('active', true)
      .single()
    if (error) return null
    return data as Contractor
  },

  /** Contractors for Volusia County — uses in_volusia boolean (county_code = '74' numeric DBPR) */
  forVolusia: async (limit = 20): Promise<Contractor[]> => {
    const { data, error } = await supabaseAdmin
      .from('contractors')
      .select(
        'id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label'
      )
      .eq('in_volusia', true)
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },

  /** Generic county query by county_code string — for future counties */
  forCounty: async (
    countyCode: string,
    state: string,
    limit = 20
  ): Promise<Contractor[]> => {
    const { data, error } = await supabaseAdmin
      .from('contractors')
      .select(
        'id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label'
      )
      .eq('state', state.toUpperCase())
      .eq('county_code', countyCode)
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },

  /** Contractors for a state market page — verified first */
  forState: async (state: string, limit = 20): Promise<Contractor[]> => {
    const { data, error } = await supabaseAdmin
      .from('contractors')
      .select(
        'id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label'
      )
      .eq('state', state.toUpperCase())
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },

  /** Count Volusia contractors — uses in_volusia boolean */
  countInVolusia: async (): Promise<number> => {
    const { count, error } = await supabaseAdmin
      .from('contractors')
      .select('id', { count: 'exact', head: true })
      .eq('in_volusia', true)
      .eq('active', true)
    if (error) return 0
    return count ?? 0
  },

  /** Count contractors in a bounding box — for market stats */
  countInBounds: async (bounds: BoundingBox): Promise<number> => {
    const { count, error } = await supabaseAdmin
      .from('contractors')
      .select('id', { count: 'exact', head: true })
      .eq('active', true)
      .eq('geocoded', true)
      .gte('lat', bounds.south)
      .lte('lat', bounds.north)
      .gte('lng', bounds.west)
      .lte('lng', bounds.east)
    if (error) return 0
    return count ?? 0
  },

  /** Lookup by city name — for Spruce Creek community page */
  forCity: async (city: string, state: string, limit = 20): Promise<Contractor[]> => {
    const { data, error } = await supabaseAdmin
      .from('contractors')
      .select(
        'id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label'
      )
      .eq('state', state.toUpperCase())
      .ilike('city', `%${city}%`)
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },
}
