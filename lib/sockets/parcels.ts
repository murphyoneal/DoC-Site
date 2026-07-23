import type { BoundingBox } from '@/types/contractor'
import type { PropertyMapPin, SiteIntelligence, PropertyCardData } from '@/types/property'

// Mirrors lib/sockets/contractors.ts: raw https → Supabase PostgREST with the
// service key. parcels_staging supplies geometry + the (co_no, parcel_id) key;
// get_site_intelligence(p_co_no, p_parcel_id) supplies everything else.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY!
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

function httpPost(path: string, body: unknown): Promise<any> {
  return new Promise(function(resolve, reject) {
    const https = require('https')
    const payload = JSON.stringify(body)
    const req = https.request({
      hostname: SB_HOST, path: path, method: 'POST',
      headers: Object.assign({}, SB_HEADERS, {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      }),
    }, function(res: any) {
      let d = ''
      res.on('data', function(c: any) { d += c })
      res.on('end', function() { try { resolve(JSON.parse(d)) } catch(e) { resolve(null) } })
    })
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

// get_site_intelligence() raw row → SiteIntelligence
function mapIntel(r: any): SiteIntelligence {
  const num = (v: any) => (v == null ? null : Number(v))
  return {
    parcelId:           String(r?.parcel_id ?? ''),
    countyName:         r?.county_name ?? null,
    ownerName:          r?.owner_name ?? null,
    situsAddress:       r?.phy_addr1 ?? null,
    city:               r?.phy_city ?? null,
    landSqft:           num(r?.land_sqft),
    buildingSqft:       num(r?.building_sqft),
    justValue:          num(r?.just_value),
    landUseCode:        r?.land_use_code ?? null,
    nearbyMaxAadt:      num(r?.nearby_max_aadt),
    nearbyRoadDesc:     r?.nearby_road_desc ?? null,
    censusBlockGroup:   r?.census_block_group ?? null,
    areaPopulation:     num(r?.area_population),
    areaMedianIncome:   num(r?.area_median_income),
    areaHousingUnits:   num(r?.area_housing_units),
    elevationM:         num(r?.elevation_m),
    nearestWaterM:      num(r?.nearest_water_m),
    floodZoneAvailable: r?.flood_zone_available ?? null,
    floodZone:          r?.flood_zone ?? null,
    inFloodHazardArea:  r?.in_flood_hazard_area ?? null,
    gisAcres:           num(r?.gis_acres),
  }
}

const M_TO_FT = 3.28084

function compose(pin: PropertyMapPin, s: SiteIntelligence | null): PropertyCardData {
  return {
    id: pin.id,
    parcelId: pin.parcelId,
    coNo: pin.coNo,
    situsAddress: s?.situsAddress ?? '',
    city: s?.city ?? '',
    landUse: s?.landUseCode ?? '',          // TODO(murphy): code→label lookup for DOR use codes
    justValue: s?.justValue ?? 0,
    acreage: s?.landSqft ? s.landSqft / 43560 : 0, // assessor acreage (land_sqft → acres)
    gisAcres: s?.gisAcres ?? null,          // GIS-calculated, shown alongside assessor
    yearBuilt: null,                        // TODO(murphy): no source — RPC/parcels_staging don't return year built
    pirPriceTeaser: null,                   // TODO(murphy): populate once "PIR" is defined
    floodZone: s?.floodZone ?? null,
    elevationFt: s?.elevationM != null ? Math.round(s.elevationM * M_TO_FT * 10) / 10 : null,
    ownerName: s?.ownerName ?? '',
    lat: pin.lat,
    lng: pin.lng,
  }
}

export const parcelSocket = {

  // Parcels in view → pins. parcels_staging has no lat/lng column (geom only), so
  // this goes through a PostGIS RPC that returns the centroid.
  // ⚠️ TODO(murphy): parcels_in_view() is part of PROPOSED_site_intelligence_batch.sql
  // (not yet applied). Confirm the geom SRID there before running.
  forMap: async function(bounds: BoundingBox, limit: number = 25): Promise<PropertyMapPin[]> {
    const res = await httpPost('/rest/v1/rpc/parcels_in_view', {
      p_west: bounds.west, p_south: bounds.south, p_east: bounds.east, p_north: bounds.north, p_limit: limit,
    })
    const rows = Array.isArray(res) ? res : []
    return rows.map(function(r: any): PropertyMapPin {
      return {
        id: r.co_no + ':' + r.parcel_id,
        parcelId: String(r.parcel_id),
        coNo: Number(r.co_no),
        lat: Number(r.lat),
        lng: Number(r.lng),
      }
    })
  },

  // Single-parcel spatial join. Signature confirmed: (p_co_no numeric, p_parcel_id text).
  siteIntelligence: async function(pin: PropertyMapPin): Promise<SiteIntelligence | null> {
    return parcelSocket.siteIntelligenceFor(pin.coNo, pin.parcelId)
  },

  // Same, keyed directly by (coNo, parcelId) — used by the B2B assistant.
  siteIntelligenceFor: async function(coNo: number, parcelId: string): Promise<SiteIntelligence | null> {
    const res = await httpPost('/rest/v1/rpc/get_site_intelligence', {
      p_co_no: coNo,
      p_parcel_id: parcelId,
    })
    const r = Array.isArray(res) ? res[0] : res
    return r ? mapIntel(r) : null
  },

  // Batched variant — one round trip for the whole viewport. Ready to switch on once
  // get_site_intelligence_batch() from PROPOSED_site_intelligence_batch.sql is applied.
  siteIntelligenceBatch: async function(pins: PropertyMapPin[]): Promise<Map<string, SiteIntelligence>> {
    const res = await httpPost('/rest/v1/rpc/get_site_intelligence_batch', {
      p_keys: pins.map(function(p) { return { co_no: p.coNo, parcel_id: p.parcelId } }),
    })
    const rows = Array.isArray(res) ? res : []
    const byKey = new Map<string, SiteIntelligence>()
    rows.forEach(function(r: any) {
      // batch RPC echoes co_no so rows map back unambiguously
      byKey.set(r.co_no + ':' + String(r.parcel_id), mapIntel(r))
    })
    return byKey
  },

  // Composed cards for the rolodex. One bbox query + one batched intelligence
  // call (get_site_intelligence_batch) — a pan costs two round trips, not N+1.
  forMapWithIntel: async function(bounds: BoundingBox, limit: number = 25): Promise<PropertyCardData[]> {
    const pins = await parcelSocket.forMap(bounds, limit)
    if (pins.length === 0) return []
    const byKey = await parcelSocket.siteIntelligenceBatch(pins)
    return pins.map(function(p) { return compose(p, byKey.get(p.id) ?? null) })
  },

}
