import type { PirReport, PirMapGeoJson, PirParcelCloseup } from '@/types/pir'

// Raw https → Supabase PostgREST RPC, same pattern as lib/sockets/parcels.ts.
// Both functions return a single jsonb document, so PostgREST hands back the
// object directly (no row wrapper).
const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY!
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

function httpPost(path: string, body: unknown): Promise<any> {
  return new Promise(function (resolve, reject) {
    const https = require('https')
    const payload = JSON.stringify(body)
    const req = https.request({
      hostname: SB_HOST, path: path, method: 'POST',
      headers: Object.assign({}, SB_HEADERS, {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      }),
    }, function (res: any) {
      let d = ''
      res.on('data', function (c: any) { d += c })
      res.on('end', function () { try { resolve(JSON.parse(d)) } catch (e) { resolve(null) } })
    })
    req.on('error', reject)
    req.write(payload)
    req.end()
  })
}

export const pirSocket = {
  // Full report document for a single parcel. (co_no, parcel_id) keyed, exactly
  // like get_site_intelligence / get_nearby_amenities.
  forParcel: async function (coNo: number, parcelId: string): Promise<PirReport | null> {
    const res = await httpPost('/rest/v1/rpc/get_pir_report', {
      p_co_no: coNo, p_parcel_id: parcelId,
    })
    // PostgREST returns the jsonb object; guard against error payloads.
    if (!res || typeof res !== 'object' || Array.isArray(res) || !res.meta) return null
    return res as PirReport
  },

  // Real-geometry map layers (parcel boundary + flood + zoning), clipped to a
  // real radius circle. Heavier payload — fetched lazily by the map component.
  mapGeoJson: async function (coNo: number, parcelId: string, radiusM = 8047): Promise<PirMapGeoJson | null> {
    const res = await httpPost('/rest/v1/rpc/get_pir_map_geojson', {
      p_co_no: coNo, p_parcel_id: parcelId, p_radius_m: radiusM,
    })
    if (!res || typeof res !== 'object' || !res.center) return null
    return res as PirMapGeoJson
  },

  // Close-up parcel boundary view: subject parcel + neighbours within a small
  // radius. Real parcels_staging geometry. Fetched lazily by the map component.
  parcelCloseup: async function (coNo: number, parcelId: string, radiusM = 46): Promise<PirParcelCloseup | null> {
    const res = await httpPost('/rest/v1/rpc/get_pir_parcel_closeup', {
      p_co_no: coNo, p_parcel_id: parcelId, p_radius_m: radiusM,
    })
    if (!res || typeof res !== 'object' || !res.center) return null
    return res as PirParcelCloseup
  },
}
