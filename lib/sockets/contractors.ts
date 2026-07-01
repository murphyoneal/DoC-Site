import type { BoundingBox, Contractor, ContractorMapPin } from '@/types/contractor'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = 'sb_secret_POUAGzaloJwoWGjWL7DVcQ_b2-NIQ-z'
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

function httpGet(path: string): Promise<any[]> {
  return new Promise(function(resolve, reject) {
    const https = require('https')
    https.get({ hostname: SB_HOST, path: path, headers: SB_HEADERS }, function(res: any) {
      let d = ''
      res.on('data', function(c: any) { d += c })
      res.on('end', function() { try { resolve(JSON.parse(d)) } catch(e) { resolve([]) } })
    }).on('error', reject)
  })
}

export const contractorSocket = {

  forMap: async function(bounds: BoundingBox, filters: { category?: string; emergency?: boolean } = {}, limit: number = 50): Promise<ContractorMapPin[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,address_line_1,city,state,zip_code,lat,lng,tier,verified,emergency_available,license_status',
      'active=eq.true',
      'lat=gte.' + bounds.south,
      'lat=lte.' + bounds.north,
      'lng=gte.' + bounds.west,
      'lng=lte.' + bounds.east,
      'limit=' + limit,
    ]
    if (filters.category) { parts.push('doc_category=eq.' + filters.category) }
    if (filters.emergency) { parts.push('emergency_available=eq.true') }
    const data = await httpGet('/rest/v1/contractors?' + parts.join('&'))
    return data as ContractorMapPin[]
  },

  forProfile: async function(slug: string): Promise<Contractor | null> {
    const data = await httpGet('/rest/v1/contractors?select=*&slug=eq.' + slug + '&active=eq.true&limit=1')
    return data[0] as Contractor ?? null
  },

  forVolusia: async function(limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'in_volusia=eq.true',
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors?' + parts.join('&'))
    return data as Contractor[]
  },

  countInVolusia: async function(): Promise<number> {
    return new Promise(function(resolve) {
      const https = require('https')
      const req = https.get({
        hostname: SB_HOST,
        path: '/rest/v1/contractors?in_volusia=eq.true&active=eq.true&select=id',
        headers: Object.assign({}, SB_HEADERS, { 'Prefer': 'count=exact' })
      }, function(res: any) {
        const h = res.headers['content-range']
        res.on('data', function() {})
        res.on('end', function() {
          if (!h) { resolve(0); return }
          const parts = h.split('/')
          resolve(parts[1] ? parseInt(parts[1], 10) : 0)
        })
      })
      req.on('error', function() { resolve(0) })
    })
  },

  forCounty: async function(countyCode: string, state: string, limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'state=eq.' + state.toUpperCase(),
      'county_code=eq.' + countyCode,
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors?' + parts.join('&'))
    return data as Contractor[]
  },

  forState: async function(state: string, limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'state=eq.' + state.toUpperCase(),
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors?' + parts.join('&'))
    return data as Contractor[]
  },

  countInBounds: async function(bounds: BoundingBox): Promise<number> {
    return new Promise(function(resolve) {
      const https = require('https')
      const parts = [
        'active=eq.true',
        'lat=gte.' + bounds.south,
        'lat=lte.' + bounds.north,
        'lng=gte.' + bounds.west,
        'lng=lte.' + bounds.east,
        'select=id',
      ]
      const req = https.get({
        hostname: SB_HOST,
        path: '/rest/v1/contractors?' + parts.join('&'),
        headers: Object.assign({}, SB_HEADERS, { 'Prefer': 'count=exact' })
      }, function(res: any) {
        const h = res.headers['content-range']
        res.on('data', function() {})
        res.on('end', function() {
          if (!h) { resolve(0); return }
          const p = h.split('/')
          resolve(p[1] ? parseInt(p[1], 10) : 0)
        })
      })
      req.on('error', function() { resolve(0) })
    })
  },

  forCity: async function(city: string, state: string, limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,verified,tier,profile_tier_label',
      'state=eq.' + state.toUpperCase(),
      'city=ilike.*' + city + '*',
      'active=eq.true',
      'order=verified.desc',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors?' + parts.join('&'))
    return data as Contractor[]
  },

}
