import type { BoundingBox, Contractor, ContractorMapPin } from '@/types/contractor'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY!
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

  forMap: async function(bounds: BoundingBox, filters: { category?: string } = {}, limit: number = 50): Promise<ContractorMapPin[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,zip_code,lat,lng,tier,license_status',
      'active=eq.true',
      'lat=gte.' + bounds.south,
      'lat=lte.' + bounds.north,
      'lng=gte.' + bounds.west,
      'lng=lte.' + bounds.east,
      'limit=' + limit,
    ]
    // Audit 971 B3: this value came straight from the query string into a PostgREST URL called with the SECRET key, so
    // '&limit=500' or '&order=...' rode along (the 50-row cap was bypassed live). Only a known category key is accepted,
    // and it is encoded anyway.
    if (filters.category) {
      if (!Object.prototype.hasOwnProperty.call(CATEGORY_LABELS, filters.category)) return []
      parts.push('doc_category=eq.' + encodeURIComponent(filters.category))
    }
    const data = await httpGet('/rest/v1/contractors_public?' + parts.join('&'))
    return data as ContractorMapPin[]
  },

  forProfile: async function(slug: string): Promise<Contractor | null> {
    const data = await httpGet('/rest/v1/contractors_public?select=*&slug=eq.' + encodeURIComponent(slug) + '&active=eq.true&limit=1')
    return data[0] as Contractor ?? null
  },

  forVolusia: async function(limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,tier,profile_tier_label',
      'in_volusia=eq.true',
      'active=eq.true',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors_public?' + parts.join('&'))
    return data as Contractor[]
  },

  countInVolusia: async function(): Promise<number> {
    return new Promise(function(resolve) {
      const https = require('https')
      const req = https.get({
        hostname: SB_HOST,
        path: '/rest/v1/contractors_public?in_volusia=eq.true&active=eq.true&select=id',
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

  // Jurisdiction, not address (Murphy 2026-10-03): which register a licence belongs to is source_state. contractors.state
  // is the MAILING address - since 212a restored it, a Florida licensee who mails from Georgia has state GA and would
  // silently drop out of "Florida contractors".
  forCounty: async function(countyCode: string, state: string, limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,tier,profile_tier_label',
      'source_state=eq.' + encodeURIComponent(state.toUpperCase()),
      'county_code=eq.' + encodeURIComponent(String(countyCode)),
      'active=eq.true',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors_public?' + parts.join('&'))
    return data as Contractor[]
  },

  forState: async function(state: string, limit: number = 20): Promise<Contractor[]> {
    const parts = [
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,tier,profile_tier_label',
      'source_state=eq.' + encodeURIComponent(state.toUpperCase()),  // jurisdiction, not mailing address
      'active=eq.true',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors_public?' + parts.join('&'))
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
        path: '/rest/v1/contractors_public?' + parts.join('&'),
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
      'select=id,slug,display_name,trade_label,doc_category,city,state,license_status,tier,profile_tier_label',
      'state=eq.' + encodeURIComponent(state.toUpperCase()),
      'city=ilike.*' + encodeURIComponent(city) + '*',  // an address query: the address state above is right here
      'active=eq.true',
      'limit=' + limit,
    ]
    const data = await httpGet('/rest/v1/contractors_public?' + parts.join('&'))
    return data as Contractor[]
  },

}