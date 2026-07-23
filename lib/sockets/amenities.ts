import type { NearbyAmenity } from '@/types/amenity'

// Raw https → Supabase PostgREST RPC, same pattern as lib/sockets/parcels.ts.
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

export const amenitySocket = {
  // Nearest amenity per covered type. The DB function is coverage-aware, so the
  // returned list already excludes types with no data for this county.
  forParcel: async function(coNo: number, parcelId: string): Promise<NearbyAmenity[]> {
    const res = await httpPost('/rest/v1/rpc/get_nearby_amenities', {
      p_co_no: coNo,
      p_parcel_id: parcelId,
    })
    const rows = Array.isArray(res) ? res : []
    return rows.map(function(r: any): NearbyAmenity {
      return {
        amenityType: String(r.amenity_type),
        displayName: String(r.display_name),
        iconName: r.icon_name ?? null,
        category: r.category ?? null,
        sortOrder: Number(r.sort_order ?? 100),
        name: r.name ?? null,
        distanceM: Number(r.distance_m),
        bearingDegrees: Number(r.bearing_degrees),
      }
    })
  },
}
