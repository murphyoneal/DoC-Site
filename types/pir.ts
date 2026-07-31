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

// One value fact from get_parcel_values_facts (_value_fact output): the winning coalesce branch's
// figure with its OWN provenance. corroborators are always [] — CAMA and NAL share DOR lineage, so
// one is never an independent witness of the other. as_of is per-field (the winning branch's roll).
export interface PirValueFact {
  predicate: string
  value: number | null
  field_status: 'present' | 'not_recorded'
  source?: string
  source_tier?: 'county_assessor_record' | 'government_derived' | string
  as_of?: string | null
  corroborators: unknown[]
  contradictors: unknown[]
}

export interface PirValues {
  justValue: number | null
  assessedValue: number | null
  assessedYear: number | null
  landValue: number | null
  specialFeatureValue: number | null
  improvementValue: number | null
  // Fact-index records backing the four dollar figures above (justValue/assessedValue/landValue/
  // improvementValue). The page renders FROM these — value, per-field roll year, and tier badge — so a
  // figure is never shown without its provenance and mixed rolls are surfaced, not reconciled.
  valuesFacts?: Record<string, PirValueFact> | null
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

// PirWind removed 2026-07-29: every property_hazard_risk (v_haz) wind field was a single value
// statewide, incl. the FBC design wind speed (130 / zone II everywhere) — fabricated (anchor §9).

// radon / sinkhole / water / lead / algae removed 2026-07-29 (fabricated v_env constants).
// Only elevation (v_si) and the gopher-tortoise overlay (real spatial) remain.
export interface PirLand {
  // elevationM/elevationFt intentionally REMOVED from the payload — a bare elevation figure with no
  // vertical datum was the recurring fabrication surface. Elevation is represented ONLY by the withheld
  // groundElevation fact (PirReport.groundElevation). Do not re-add these keys.
  gopherTortoiseInside?: boolean; gopherTortoiseNearestM?: number
}

export interface PirWaterFeature { name: string | null; ftype: string | null; distanceM: number; bearingDegrees: number }
export interface PirBoatRamp { name: string | null; waterbody: string | null; distanceM: number; bearingDegrees: number }
export interface PirWater {
  nearestWaterM: number | null
  features: PirWaterFeature[]
  boatRamps: PirBoatRamp[]
}

// Flood now comes from get_parcel_flood_zone() (coverage-aware NFHL), merged with areaRepetitiveLoss.
// not_available / parcel_not_resolved are COVERAGE GAPS — never render as "not in a flood zone".
export interface PirFloodZoneEntry {
  zone: string; subtype: string | null; in_sfha: boolean
  base_flood_elevation_ft: number | null; pct_of_parcel: number | null
}
export interface PirFlood {
  field?: string
  field_status: 'present' | 'none_intersecting' | 'not_available' | 'parcel_not_resolved'
  zones?: PirFloodZoneEntry[] | null
  in_sfha?: boolean | null
  base_flood_elevation_ft?: number | null
  vertical_datum?: string | null
  layer_used?: string
  coverage_caveat?: string; county_layer_status?: string
  source?: string; authority?: string; relation?: string; resolution_level?: string
  areaRepetitiveLoss: { field_status?: string; properties?: number | null; totalLosses?: number | null; note?: string; coverage_caveat?: string } | null
}

// Marine improvements (volusia_cama_misc — Tyler iasWorld other-improvements): dock/seawall/
// boat house/lift/slip. Coverage-aware — see PirMarineImprovements.field_status. Material is not
// recorded by the county, so remaining life is never asserted (only age + county depreciation).
export interface PirMarineItem {
  code: string; description: string
  size: string | null; grade: string | null; dimensions_ft: string | null
  material: string; year_built: string | null; age_years: number | null
  pct_depreciated: number | null; depreciated_value: string | null; replacement_cost_new: string | null
  assessed_service_life_years: number | null; at_or_past_assessed_service_life: boolean
}
// Tax-deed status (lands_available_for_taxes_<county>): county-held parcels that went unsold at
// tax-deed auction. Same three coverage states as marine. as_of is load-bearing — a stale listing
// acted on is worse than none — and not_available (on_lands_available_list null) is a coverage gap,
// never "no tax exposure".
export interface PirTaxDeedStatus {
  field: string; source: string; authority: string; relation?: string
  field_status: 'present' | 'not_on_list' | 'not_available'
  as_of?: string | null
  on_lands_available_list: boolean | null
  opening_bid_usd?: number | null
  certificate_number?: string | null
  date_original_sale?: string | null
  date_available_to_public?: string | null
  meaning?: string; staleness_warning?: string; not_legal_advice?: string
  coverage_caveat?: string; resolution_level?: string
}

export interface PirMarineImprovements {
  field: string; source: string; authority: string; relation?: string
  // 'present' → items populated; 'none_recorded' → Volusia, county recorded none (indicator false);
  // 'not_available' → coverage gap, items null, indicator NULL (never render as "no dock").
  field_status: 'present' | 'none_recorded' | 'not_available'
  items: PirMarineItem[] | null
  item_count?: number
  waterfront_indicator: boolean | null
  waterfront_basis: string | null
  coverage_caveat: string; material_caveat?: string; service_life_basis?: string
  resolution_level?: string; seawall_age_disclosure?: boolean
}

// PirClimate removed 2026-07-29: every property_hazard_risk (v_haz) climate field was a single
// value statewide (fabricated). Stripped from get_pir_report — see anchor §9.

export interface PirCensus {
  blockGroup: string | null
  population: number | null
  medianHouseholdIncome: number | null
  housingUnits: number | null
}

// A census fact whose SUBJECT is the block group, never the parcel. tier is federal_statistical (a
// 5-year sample estimate). note carries the un-carried-MOE statement; vintage_note the how-we-know.
// corroborators always [] (a single federal statistical source).
export interface PirCensusFact {
  subject: { type?: string; geoid?: string; contains_parcel?: string }
  predicate: string
  value: number | null
  field_status: 'present' | 'not_recorded'
  source?: string
  source_tier?: 'federal_statistical' | string
  as_of?: string
  note?: string
  vintage_note?: string | null
  corroborators: unknown[]
  contradictors: unknown[]
}

// get_parcel_census_facts output. field_status 'present' | 'not_established' (a coverage gap about OUR
// data). The geography is NAMED; the parcel's contained_within relationship is its own stated fact.
export interface PirCensusFacts {
  field_status: 'present' | 'not_established'
  geography: { type?: string; geoid?: string; name?: string; contains_parcel?: string } | null
  containment?: {
    subject?: unknown; predicate?: string; value?: string; field_status?: string
    source?: string; source_tier?: string; as_of?: string; derivation?: unknown
    corroborators?: unknown[]; contradictors?: unknown[]
  } | null
  facts: Record<string, PirCensusFact>
  coverage_note: string | null
}

// One owner-of-record fact. Subject is anchored on (parcel, ownseq) — NEVER the name (a reported value,
// not a join key). pct_own is AS RECORDED and must never be summed or normalized (tenancy by the entirety
// records each owner at 100%). corroborators always [] by default (CAMA/NAL share DOR lineage).
export interface PirOwnerFact {
  subject: { parcel?: string; ownseq?: string }
  predicate: 'owner_of_record'
  value: string | null
  name_detail?: string | null
  pct_own?: number | null
  ownership_type?: string | null
  ownership_type2?: string | null
  field_status: 'present'
  source?: string
  source_tier?: 'county_assessor_record' | 'government_derived' | string
  as_of?: string
  corroborators: unknown[]
  contradictors: unknown[]
}

// get_parcel_owner_facts output. Multi-valued: one fact per owner, plus a parcel-level owner_count fact.
// field_status 'present' | 'not_established' (a coverage gap about OUR data). Precedence Clerk deed >
// county CAMA (live file) > DOR NAL (1-January snapshot, can lag ~19 months).
export interface PirOwnerFacts {
  field_status: 'present' | 'not_established'
  owner_count: {
    subject?: unknown; predicate: 'owner_count'; value: number | null
    field_status: 'present' | 'not_recorded'
    source?: string; source_tier?: string; as_of?: string; note?: string
  }
  owners: PirOwnerFact[]
  tenancy?: { form: string | null; note: string | null } | null
  coverage_note: string | null
}

// One recorded conveyance. TWO qualification facts travel with it: sale_qualification (the county's, on
// county_assessor_record) and market_signal (OURS, on analysis_inference — never borrows county authority).
// price_role gates the money: 'sale_price' only for a qualified market sale; 'consideration' otherwise.
export interface PirConveyance {
  subject?: { parcel?: string; instrument?: string; date?: string }
  date: string | null
  instrument_type: string | null
  book?: string | null; page?: string | null; instrument_number?: string | null
  grantor?: string | null; grantee?: string | null
  sale_type?: string | null
  // money on the key that names it: sale_price only for a qualified market sale, consideration otherwise
  sale_price: number | null
  consideration: number | null
  multi_parcel?: boolean; parcels_on_instrument?: number | null
  legal_xref?: boolean
  price_role: 'sale_price' | 'consideration'
  nominal?: boolean; nominal_reason?: string | null
  sale_qualification: { predicate: 'sale_qualification'; value: string | null; field_status: string
    source?: string; source_tier?: string; as_of?: string; corroborators: unknown[]; contradictors: unknown[] }
  market_signal: { predicate: 'market_signal'; value: 'market' | 'non_market'; field_status: string
    source?: string; source_tier?: 'analysis_inference' | string; derivation?: unknown; note?: string | null
    corroborators: unknown[]; contradictors: unknown[] }
  legal_cross_reference?: { note: string; independence: string } | null
}

// get_parcel_transaction_facts output. field_status 'present' | 'not_established' (coverage gap about OUR
// data). last_market_sale is the most recent conveyance we classify as a market sale (null if none).
export interface PirTransactionFacts {
  field_status: 'present' | 'not_established'
  count: number
  conveyances: PirConveyance[]
  last_market_sale: PirConveyance | null
  last_market_sale_price?: number | null
  last_market_sale_date?: string | null
  coverage_note: string | null
}

// One permit fact. Subject is the permit (attaches_by_key to the parcel). closeout is a disclosure: a
// dated completion => finaled; otherwise 'not_recorded' with an affirmative disclosure line. declared_value
// is DECLARED, not cost. contractor_licence is checked as of the permit date against DBPR (independent).
export interface PirPermitFact {
  subject?: { permit_number?: string; date?: string; issuing_authority?: string | null }
  predicate: 'permit'
  relation_to_parcel: 'attaches_by_key'
  date: string | null
  permit_number: string | null
  issuing_authority: string | null
  work_description: string | null
  work_type?: string | null
  sub_type?: string | null
  contractor: string | null
  source?: string; source_tier?: string
  declared_value: number | null
  declared_value_note?: string
  closeout: {
    predicate: 'permit_closeout'; value: 'finaled' | null; field_status: 'present' | 'not_recorded'
    finaled_date: string | null; source?: string; source_tier?: string; disclosure: string | null
  }
  contractor_licence?: {
    predicate?: 'contractor_licence_at_permit_date'; matched: boolean
    license_number?: string | null; business_name?: string | null
    active_at_permit_date?: boolean | null; checked_as_of?: string
    source?: string; source_tier?: string; independence?: string
    finding?: string | null; corroboration?: string | null; note?: string
  } | null
}

export interface PirPermitFacts {
  field_status: 'present' | 'not_established'
  count: number
  permits: PirPermitFact[]
  closeout_not_recorded_count: number
  coverage_note: string | null
}

// One zoning/FLU fact — the jurisdiction's OWN code + description, never normalized into a national
// taxonomy. definition_note carries the half-a-fact caveat when no description is held; note carries the
// municipal-governs message. Two of these travel per parcel (zoning + future_land_use), never merged.
export interface PirZoningFact {
  subject?: unknown
  predicate: 'zoning' | 'future_land_use'
  value: string | null
  description?: string | null
  // 'municipal_not_held' = the county disclaims jurisdiction (a "999"/"INCORPORATED" sentinel); the value
  // is null and coverage_note names the governing municipality. Never render the sentinel as a code.
  field_status: 'present' | 'municipal_not_held'
  incorporated_in?: string | null
  coverage_note?: string | null
  jurisdiction?: string | null
  jurisdiction_level?: 'county' | 'municipal' | string
  source?: string
  source_tier?: string
  definition_url?: string | null
  definition_note?: string | null
  note?: string | null
}
export interface PirZoningFacts {
  field_status: 'present' | 'not_established'
  zoning: PirZoningFact | null
  future_land_use: PirZoningFact | null
  relationship?: { note: string } | null
  coverage_note: string | null
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

// A source/disclose defect surfaced onto the report (from get_parcel_disclosures). A stated limit of
// the county's public record — a finding with weight, NOT a coverage gap and NOT a disclaimer.
export interface PirDisclosure {
  defect_id: string
  kind: 'source_limit'
  disclosure: string
}

// The fact-index marine block (get_parcel_marine_block_by_parcel). Every figure is a sourced fact;
// built-year is cross-examined against building permits. open_questions is the block-level roll-up.
export interface PirMarineBlock {
  parcel: string
  field_status: 'present' | 'none_recorded' | 'not_available'
  coverage_note?: string
  open_questions: { count: number; total_improvements: number; headline: string | null; items: Array<{ question: string }> }
  improvements: Array<{ improvement: string; built: number; facts: Record<string, unknown> }>
  material_disclosure?: { defect_id: string; kind: string; disclosure: string } | null
}

// The fact-index flood block (get_parcel_flood_block). THE fact is the SFHA determination; a coverage
// gap renders "not established" (about our data), never "not in a flood zone". FEMA is singular authority.
export interface PirFloodBlock {
  parcel: string
  field_status: string
  determination: { predicate: 'in_sfha'; value: boolean | null; field_status: string; source: string; source_tier: string; determination_note?: string; corroborators: unknown[]; contradictors: unknown[] }
  base_flood_elevation: Record<string, unknown>
  elevation_above_bfe: Record<string, unknown>
  zones: unknown[]
  vertical_datum: string | null
  coverage_caveat?: string | null
  // county-context FEMA NFIP repetitive-loss totals, merged onto floodBlock (migrated off the removed
  // standalone `flood` key). Area context, not a per-parcel claim.
  areaRepetitiveLoss?: { field_status?: string; properties?: number | null; totalLosses?: number | null; note?: string; coverage_caveat?: string } | null
}

export interface PirReport {
  meta: PirMeta
  property: PirProperty
  values: PirValues
  tax: PirTax
  amenities: PirAmenity[]
  schools: PirSchool[]
  permitFacts?: PirPermitFacts | null
  transactionFacts?: PirTransactionFacts | null
  land: PirLand
  water: PirWater
  // `flood` and `marineImprovements` REMOVED from the payload — superseded by floodBlock / marineBlock.
  // They were live fabrication surfaces for payload consumers (the payload is the security boundary, not
  // the render). areaRepetitiveLoss migrated onto floodBlock. Do not re-add.
  taxDeedStatus: PirTaxDeedStatus
  censusFacts?: PirCensusFacts | null
  ownerFacts?: PirOwnerFacts | null
  zoning: PirZoning
  zoningFacts?: PirZoningFacts | null
  economic: PirEconomic
  disclosures?: PirDisclosure[] | null
  marineBlock?: PirMarineBlock | null
  floodBlock?: PirFloodBlock | null
  groundElevation?: Record<string, unknown> | null
  contaminationFacilities?: Record<string, unknown> | null
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
