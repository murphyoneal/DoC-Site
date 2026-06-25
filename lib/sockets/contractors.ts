import { getSupabaseAdmin } from '@/lib/supabase/server'
import type { BoundingBox, Contractor, ContractorMapPin } from '@/types/contractor'

export const contractorSocket = {

  forMap: async (
    bounds: BoundingBox,
    _filters: { category?: string; emergency?: boolean } = {},
    limit = 50
  ): Promise<ContractorMapPin[]> => {
    const { data, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id,slug,display_name,trade_label,doc_category,city,state,lat,lng,tier,verified,emergency_available,license_status')
      .eq('active', true)
      .gte('lat', bounds.south)
      .lte('lat', bounds.north)
      .gte('lng', bounds.west)
      .lte('lng', bounds.east)
      .limit(limit)

    if (error) throw error
    return (data ?? []) as ContractorMapPin[]
  },

  forProfile: async (slug: string): Promise<Contractor | null> => {
    const { data, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('*')
      .eq('slug', slug)
      .eq('active', true)
      .single()
    if (error) return null
    return data as Contractor
  },

  forVolusia: async (limit = 20): Promise<Contractor[]> => {
    const { data, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label')
      .eq('in_volusia', true)
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },

  countInVolusia: async (): Promise<number> => {
    const { count, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id', { count: 'exact', head: true })
      .eq('in_volusia', true)
      .eq('active', true)
    if (error) return 0
    return count ?? 0
  },

  forCounty: async (countyCode: string, state: string, limit = 20): Promise<Contractor[]> => {
    const { data, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label')
      .eq('state', state.toUpperCase())
      .eq('county_code', countyCode)
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },

  forState: async (state: string, limit = 20): Promise<Contractor[]> => {
    const { data, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label')
      .eq('state', state.toUpperCase())
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },

  countInBounds: async (bounds: BoundingBox): Promise<number> => {
    const { count, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id', { count: 'exact', head: true })
      .eq('active', true)
      .gte('lat', bounds.south)
      .lte('lat', bounds.north)
      .gte('lng', bounds.west)
      .lte('lng', bounds.east)
    if (error) return 0
    return count ?? 0
  },

  forCity: async (city: string, state: string, limit = 20): Promise<Contractor[]> => {
    const { data, error } = await getSupabaseAdmin()
      .from('contractors')
      .select('id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label')
      .eq('state', state.toUpperCase())
      .ilike('city', `%${city}%`)
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(limit)
    if (error) throw error
    return (data ?? []) as Contractor[]
  },
}