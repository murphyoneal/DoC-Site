export {}

// ── PROPERTY INTELLIGENCE REPORT (PIR) ──────────────────────────────────────────
// Exact shape of get_pir_report(p_co_no numeric, p_parcel_id text) → jsonb.
// One assembler, one document. Every field here is populated ONLY from data
// confirmed real for the parcel; anything the DB doesn't have arrives as null or
// an empty array and the report renders an honest "not on file" state — it never
// fabricates. See PROPOSED_get_pir_report.sql.

export interface PirMeta {
  coNo: number
  parcelId: string
  stateParcelId: string | null
  countyName: string | null
  lat: number | null
  lng: number | null
  generatedAt: string
  dataQualityScore: number | null
  source: string | null
}

export interface PirProperty {
  address: string | null
  city: string | null
  zip: string | null
  jurisdiction: string | null
  incorporation: string | null
  ownerName: string | null
  ownerOccupied: boolean | null   // homestead exemption ⇒ owner-occupied
  ownerMailAddr: string | null
  ownerMailCity: string | null
  subdivision: string | null
  neighborhood: string | null
  legal: string | null
  propertyType: string | null
  landUseCode: string | null
  yearBuilt: number | null
  effectiveYearBuilt: number | null
  stories: number | null
  bedrooms: number | null
  bathrooms: number | null
  numBuildings: number | null
  residentialUnits: number | null
  livingSqft: number | null
  totalSqft: number | null
  livingAreaSource?: string | null // e.g. "county CAMA residential record (SFLA)"; null when unsourced
  gisAcres: number | null
  section: string | null
  township: string | null
  range: string | null
}

export interface PirValues {
  justValue: number | null
  assessedValue: number | null
  assessedYear: number | null
  landValue: number | null
  specialFeatureValue: number | null
  improvementValue: number | null
}

export interface PirTax {
  homesteadExempt: boolean | null
  homesteadExemption1: number | null
  homesteadExemption2: number | null
  taxableValueCounty: number | null
  taxableValueSchool: number | null
  taxAuthorityCode: string | null
}

// One badge-compass per amenity type (individual badges, per spec — never a
// shared map). Absence of a badge is itself informative.
export interface PirAmenity {
  amenityType: string
  displayName: string
  iconName: string | null
  category: string | null
  name: string | null
  distanceM: number
  bearingDegrees: number
}

// Assigned school zones (elementary / middle / high) — one badge each. Name is
// the parcel's zoned school; distance/bearing come from the school's point.
export interface PirSchool {
  level: string
  name: string
  distanceM: number | null
  bearingDegrees: number | null
}

export interface PirPermit {
  permitNumber: string | null
  permitDate: string | null
  completionDate: string | null
  occCertDate: string | null
  status: string | null            // honest: null ⇒ "status not on file"
  permitType: string | null
  workDescription: string | null
  contractorName: string | null
  jobValue: number | null
  tradeCategory: string | null
}

export interface PirTransaction {
  recordingDate: string | null
  saleDate: string | null
  salePrice: number | null
  instrumentType: string | null
  grantor: string | null
  grantee: string | null
  qualifiedSale: boolean | null
  docStampAmount: number | null
  book: string | null
  page: string | null
}

// count MUST equal items.length — the report never states a summary count that
// disagrees with the itemised list.
export interface PirCountedList<T> { count: number; items: T[] }

// PirAir removed 2026-07-29: every property_environmental (v_env) air field was a single
// value across all 313,578 rows (fabricated). Stripped from get_pir_report — see anchor §9.

export interface PirWind {
  prevailingDirection?: string; avgSpeedMph?: number; maxGustMph?: number
  designSpeedMph?: number; windSpeedZone?: string
}

// radon / sinkhole / water / lead / algae removed 2026-07-29 (fabricated v_env constants).
// Only elevation (v_si) and the gopher-tortoise overlay (real spatial) remain.
export interface PirLand {
  elevationM?: number; elevationFt?: number
  gopherTortoiseInside?: boolean; gopherTortoiseNearestM?: number
}

export interface PirWaterFeature { name: string | null; ftype: string | null; distanceM: number; bearingDegrees: number }
export interface PirBoatRamp { name: string | null; waterbody: string | null; distanceM: number; bearingDegrees: number }
export interface PirWater {
  nearestWaterM: number | null
  features: PirWaterFeature[]
  boatRamps: PirBoatRamp[]
}

export interface PirFlood {
  zone: string | null
  available: boolean | null
  inHazardArea: boolean | null
  countyZone: string | null
  stormSurgeZone: string | null
  floodEvents10yr: number | null
  areaRepetitiveLoss: { properties: number | null; totalLosses: number | null } | null
}

export interface PirClimate {
  precipAnnualIn?: number; precipMax24hrIn?: number
  tempAnnualF?: number; tempMaxRecordF?: number; tempMinRecordF?: number; humidityPct?: number
  solarKwhM2Day?: number; solarPeakHours?: number; solarPotentialKwhYr?: number
  lightningDensity?: number; hurricaneDirectHits?: number; lastHurricaneCategory?: number
  tornadoEvents10yr?: number; hailEvents10yr?: number
  wildfireRiskClass?: string; extremeHeatDaysAnnual?: number
}

export interface PirCensus {
  blockGroup: string | null
  population: number | null
  medianHouseholdIncome: number | null
  housingUnits: number | null
}

export interface PirZoning {
  zoneCode?: string; pudName?: string
  futureLandUseCode?: string; futureLandUseName?: string
}

// inside === false with a distanceM ⇒ "nearest, not adjacent" context.
// A whole overlay being null ⇒ none within range at all.
export interface PirEconOverlay { inside: boolean; distanceM: number; name?: string; tract?: string; zone?: string }
export interface PirEconomic {
  opportunityZone: PirEconOverlay | null
  hubZone: PirEconOverlay | null
  cra: PirEconOverlay | null
  enterpriseZone: PirEconOverlay | null
  brownfield: PirEconOverlay | null
}

export interface PirReport {
  meta: PirMeta
  property: PirProperty
  values: PirValues
  tax: PirTax
  amenities: PirAmenity[]
  schools: PirSchool[]
  permits: PirCountedList<PirPermit>
  transactions: PirCountedList<PirTransaction>
  wind: PirWind
  land: PirLand
  water: PirWater
  flood: PirFlood
  climate: PirClimate
  census: PirCensus
  zoning: PirZoning
  economic: PirEconomic
  climateSources: Record<string, string> | null
  salesAgent?: PirSalesAgent[] | null
}

// A self-reported sales-agent claim (item 50/59). Firsthand agent knowledge corroborated to a
// recorded sale — NOT the county record's own fact, NOT an MLS listing. Render with that framing.
export interface PirSalesAgent {
  value: string | null            // agent / business name
  license_number?: string | null
  claimed_role?: string | null
  as_of?: string | null           // when the claim was made
  sale_date?: string | null
  sale_price?: number | null
  sale_instrument?: string | null
  sale_instr_no?: string | null
  reporting_rule?: string | null
}

// ── MAP GEOJSON ─────────────────────────────────────────────────────────────────
// get_pir_map_geojson(co_no, parcel_id, radius_m) → jsonb. Real geometry, clipped
// to a real radius circle, dissolved by category to keep the payload small.
export interface GeoJsonFeatureCollection {
  type: 'FeatureCollection'
  features: Array<{ type: 'Feature'; properties: Record<string, unknown>; geometry: unknown }>
}

export interface PirMapGeoJson {
  center: { lat: number; lng: number }
  radiusM: number
  parcel: unknown                    // GeoJSON geometry (parcel boundary)
  flood: GeoJsonFeatureCollection    // features carry properties.zone
  zoning: GeoJsonFeatureCollection   // features carry properties.category
}

// get_pir_parcel_closeup(co_no, parcel_id, radius) — tight boundary view:
// the subject parcel + neighbouring parcels within ~radius metres.
export interface PirParcelCloseup {
  center: { lat: number; lng: number }
  radiusM: number
  subject: unknown                   // GeoJSON geometry (subject parcel boundary)
  neighbors: GeoJsonFeatureCollection
}
