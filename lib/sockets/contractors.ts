import type { BoundingBox, Contractor, ContractorMapPin } from '@/types/contractor'

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL!
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY!

async function query(params: string): Promise<any[]> {
  const url = SUPABASE_URL + '/rest/v1/contractors?' + params
  const res = await fetch(url, {
    headers: {
      'apikey': SUPABASE_KEY,
      'Authorization': 'Bearer ' + SUPABASE_KEY,
      'Content-Type': 'application/json',
      'x-supabase-bypass-rls': 'true',
    },
    cache: 'no-store',
  })
  if (!res.ok) {
    const text = await res.text()
    throw new Error('Supabase REST error: ' + res.status + ' ' + text)
  }
  return res.json()
}

export const contractorSocket = {

 forMap: async (bounds: BoundingBox, filters: { category?: string; emergency?: boolean } = {}, limit = 50): Promise<ContractorMapPin[]> => {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,lat,lng,tier,verified,emergency_available,license_status',
      'active=eq.true',
      'lat=gte.' + bounds.south,
      'lat=lte.' + bounds.north,
      'lng=gte.' + bounds.west,
      'lng=lte.' + bounds.east,
      'limit=' + limit,
    ]
    if (filters.category) parts.push('doc_category=eq.' + filters.category)
    if (filters.emergency) parts.push('emergency_available=eq.true')
    const data = await query(parts.join('&'))
    return data as ContractorMapPin[]
  },
  forProfile: async (slug: string): Promise<Contractor | null> => {
    const params = 'select=*&slug=eq.' + slug + '&active=eq.true&limit=1'
    const data = await query(params)
    return data[0] as Contractor ?? null
  },

  forVolusia: async (limit = 20): Promise<Contractor[]> => {
    const params = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'in_volusia=eq.true',
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ].join('&')
    const data = await query(params)
    return data as Contractor[]
  },

  countInVolusia: async (): Promise<number> => {
    const url = SUPABASE_URL + '/rest/v1/contractors?in_volusia=eq.true&active=eq.true&select=id'
    const res = await fetch(url, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': 'Bearer ' + SUPABASE_KEY,
        'Prefer': 'count=exact',
      },
      cache: 'no-store',
    })
    if (!res.ok) return 0
    const countHeader = res.headers.get('content-range')
    if (!countHeader) return 0
    const parts = countHeader.split('/')
    return parts[1] ? parseInt(parts[1], 10) : 0
  },

  forCounty: async (countyCode: string, state: string, limit = 20): Promise<Contractor[]> => {
    const params = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'state=eq.' + state.toUpperCase(),
      'county_code=eq.' + countyCode,
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ].join('&')
    const data = await query(params)
    return data as Contractor[]
  },

  forState: async (state: string, limit = 20): Promise<Contractor[]> => {
    const params = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'state=eq.' + state.toUpperCase(),
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ].join('&')
    const data = await query(params)
    return data as Contractor[]
  },

  countInBounds: async (bounds: BoundingBox): Promise<number> => {
    const url = SUPABASE_URL + '/rest/v1/contractors?' + [
      'active=eq.true',
      'lat=gte.' + bounds.south,
      'lat=lte.' + bounds.north,
      'lng=gte.' + bounds.west,
      'lng=lte.' + bounds.east,
      'select=id',
    ].join('&')
    const res = await fetch(url, {
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': 'Bearer ' + SUPABASE_KEY,
        'Prefer': 'count=exact',
      },
      cache: 'no-store',
    })
    if (!res.ok) return 0
    const countHeader = res.headers.get('content-range')
    if (!countHeader) return 0
    const parts = countHeader.split('/')
    return parts[1] ? parseInt(parts[1], 10) : 0
  },

  forCity: async (city: string, state: string, limit = 20): Promise<Contractor[]> => {
    const params = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'state=eq.' + state.toUpperCase(),
      'city=ilike.*' + city + '*',
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ].join('&')
    const data = await query(params)
    return data as Contractor[]
  },
}