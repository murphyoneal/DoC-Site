import type { PirReport, PirMapGeoJson, PirParcelCloseup } from '@/types/pir'

// RULING 197: transport moved to lib/sockets/postgrest.ts, which throws on an error
// body instead of resolving it as data. Each RPC below returns a single jsonb
// document, so PostgREST hands back the object directly (no row wrapper).
import { pgPost } from './postgrest'

const httpPost = pgPost

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

  // RULING 169 + 197. The SCRUBBED document, for render surfaces that are not
  // pir_write_snapshot — currently the Roz/B2B assistant. get_pir_report itself
  // still carries grantor/grantee on every conveyance (the scrub lives in the
  // snapshot writer), so a narrator reading the raw report would speak deed party
  // names with no manifest. The scrub is applied SERVER-SIDE and its manifest is
  // returned at meta.scrubManifest, so the removal is evidenced, not just done.
  // Do not reimplement the scrub here — that is the divergence ruling 197 closes.
  forParcelScrubbed: async function (coNo: number, parcelId: string): Promise<PirReport | null> {
    const res = await httpPost('/rest/v1/rpc/get_pir_report_scrubbed', {
      p_co_no: coNo, p_parcel_id: parcelId,
    })
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
