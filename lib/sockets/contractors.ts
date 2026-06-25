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
  forMap: async (bounds: BoundingBox, _filters: { category?: string; emergency?: boolean } = {}, limit = 50): Promise<ContractorMapPin[]> => {
    const params = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,lat,lng,tier,verified,emergency_available,license_status',
      'active=eq.true',
      'lat=gte.' + bounds.south,
      'lat=lte.' + bounds.north,
      'lng=gte.' + bounds.west,
      'lng=lte.' + bounds.east,
      'limit=' + limit,
    ].join('&')
    const data = await query(params)
    return data as ContractorMapPin[]
  },

  forProfile: async (slug: string): Promise<Contractor | null> => {
    const params = 'select=*&slug=eq.' + slug + '&active=eq.true&limit=1'
    const data = await query(params)
    return data[0] as Contractor ?? null
  },

  forVolusia: async (limit = 20): Promise<Contractor[]> => {
    const params =