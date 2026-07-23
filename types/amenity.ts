export {}

// Result of get_nearby_amenities(p_co_no, p_parcel_id). One row per amenity type
// that ACTUALLY has data for the parcel's county (coverage-aware by construction —
// the DB function only emits covered types). Drives the "Nearby Amenities Compass".
export interface NearbyAmenity {
  amenityType: string       // 'hydrant' | 'bus_stop' | 'sunrail' | 'library' | 'hospital' | ...
  displayName: string       // 'Fire Hydrant'
  iconName: string | null   // registry icon key: 'droplet','bus','train','book','hospital','flame','school','shield'
  category: string | null   // 'safety' | 'transit' | 'civic' | 'health'
  sortOrder: number
  name: string | null       // nearest feature's label (may be null, e.g. hydrants)
  distanceM: number         // metres to nearest feature (from parcel centroid)
  bearingDegrees: number    // compass bearing 0=N, 90=E … (arrow rotation)
}
