export {}

// ── PROPERTY / PARCEL TYPES ─────────────────────────────────────────────────────
// Consumer-report property intelligence. Central dataset: parcels_staging
// (10.7M+ FL parcels). The card is driven mostly by get_site_intelligence(), which
// already returns address, owner, just value, land_sqft, flood zone + elevation.
// parcels_staging is only queried to place the pin (geometry) and to get the
// (co_no, parcel_id) key that the RPC is keyed on.

// Result of the bbox query over parcels_staging — just enough to drop a pin and
// key the intelligence RPC. parcels_staging has no centroid lat/lng column (only
// geom / geom_wkt), so this comes from a PostGIS RPC — see parcels_in_view in
// PROPOSED_site_intelligence_batch.sql.
export interface PropertyMapPin {
  id: string        // synthetic React key: `${coNo}:${parcelId}`
  parcelId: string  // parcels_staging.parcel_id (text) — RPC arg #2
  coNo: number      // parcels_staging.co_no (numeric, FL county number) — RPC arg #1
  lat: number       // centroid latitude  (ST_Y(ST_Centroid(geom)))
  lng: number       // centroid longitude (ST_X(ST_Centroid(geom)))
}

// ── SITE INTELLIGENCE ───────────────────────────────────────────────────────────
// Exact return of get_site_intelligence(p_co_no numeric, p_parcel_id text).
// (Confirmed by maintainer; not documented in the repo — CLAUDE.md to be updated.)
export interface SiteIntelligence {
  parcelId: string           // parcel_id
  countyName: string | null  // county_name
  ownerName: string | null   // owner_name
  situsAddress: string | null // phy_addr1
  city: string | null        // phy_city
  landSqft: number | null    // land_sqft  (acreage = land_sqft / 43560)
  buildingSqft: number | null // building_sqft
  justValue: number | null   // just_value
  landUseCode: string | null // land_use_code (DOR use code — may need a label lookup)
  nearbyMaxAadt: number | null    // nearby_max_aadt (traffic_aadt)
  nearbyRoadDesc: string | null   // nearby_road_desc
  censusBlockGroup: string | null // census_block_group
  areaPopulation: number | null   // area_population
  areaMedianIncome: number | null // area_median_income
  areaHousingUnits: number | null // area_housing_units
  elevationM: number | null       // elevation_m (METERS — convert for ft display)
  nearestWaterM: number | null    // nearest_water_m
  floodZoneAvailable: boolean | null // flood_zone_available
  floodZone: string | null           // flood_zone (e.g. 'AE','VE','X') — conversion hero
  inFloodHazardArea: boolean | null  // in_flood_hazard_area
  gisAcres: number | null            // gis_acres — ST_Area(geom) in acres (NOT the assessor's figure)
}

// ── CARD DATA ────────────────────────────────────────────────────────────────────
// What the rolodex renders — pin geometry + SiteIntelligence, flattened.
export interface PropertyCardData {
  id: string
  parcelId: string
  coNo: number             // county number — needed to call get_nearby_amenities
  situsAddress: string
  city: string
  landUse: string
  justValue: number
  acreage: number          // assessor acreage (land_sqft / 43560) — labeled "Assessor"
  gisAcres: number | null  // GIS-calculated (ST_Area) — labeled "Site Size (GIS-Calculated)"; shown alongside, never merged
  yearBuilt: number | null

  // Conversion hook shown near the top of the card front.
  // ⚠️ TODO(murphy): "PIR" still undefined in the repo. Assuming Property Intelligence
  // Report teaser (e.g. report unlock price "$29 report"). Free string until confirmed.
  pirPriceTeaser: string | null

  // From get_site_intelligence().
  floodZone: string | null
  elevationFt: number | null   // derived from elevation_m

  // Back-of-card only (privacy/framing).
  ownerName: string

  lat: number
  lng: number
}
