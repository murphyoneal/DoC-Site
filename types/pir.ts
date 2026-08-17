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
  // RULING 218 b1: dataQualityScore REMOVED, not renamed. It was a 13-band ordinal
  // (20/35/40/45/50/55/65/70/75/80/85/90/100 over 313,578 rows) rendered as "55/100"
  // and captioned "the county appraiser's own completeness score" — a denominator it
  // never had, attributed to an authority that did not produce it. Do not re-add.
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
  // The flat justValue/assessedValue/landValue/improvementValue were REMOVED — they duplicated the value
  // facts below (a bare number stripped of its roll-year/authority). Those four dollar figures live ONLY in
  // valuesFacts now. Do not re-add: a flat number without its per-field as_of misleads when Volusia reads a
  // 2026 CAMA roll and Marion a 2025 NAL roll. Guarded by payload-carries-no-superseded-fabrication-keys.
  assessedYear: number | null
  rollYear?: number | string | null
  // The value facts: just_value / assessed_value / land_value / special_feature_value / improvement_value —
  // EVERY dollar figure now lives here (specialFeatureValue joined the index; the flat key was removed). Each
  // carries its own value, per-field roll year (as_of) and tier; improvement_value carries a derivation naming
  // its inputs (just − land − special) on the computed branch. The page renders FROM these, so a figure is
  // never shown without its provenance and mixed rolls are surfaced, not reconciled.
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
// get_parcel_sinkhole_facts — documented FGS subsidence incidents near the parcel (area context, never a
// per-parcel risk score). field_status 'present' | 'not_established' (a coverage gap about OUR data).
export interface PirSinkholeFacts {
  field_status: 'present' | 'not_established'
  county?: string
  nearest?: { distance_ft: number | null; event_date: string | null; verified: string | null; depth: string | null } | null
  incidents_within_1mi?: number
  incidents_within_quarter_mi?: number
  verified_within_1mi?: number
  note?: string
  coverage_note?: string | null
}

export interface PirLand {
  // elevationM/elevationFt intentionally REMOVED from the payload — a bare elevation figure with no
  // vertical datum was the recurring fabrication surface. Elevation is represented ONLY by the withheld
  // groundElevation fact (PirReport.groundElevation). Do not re-add these keys.
  // Item 112: coverage tells "no habitat nearby in a county we hold" apart from "we hold no habitat
  // data for this county". gopher tortoise overlay is Volusia-only, so off-Volusia is 'not_available'.
  // Without this the Protected-species line rendered "None mapped nearby" for every non-Volusia parcel.
  gopherTortoiseCoverage?: 'covered' | 'not_available'
  gopherTortoiseInside?: boolean; gopherTortoiseNearestM?: number
}
// Item 112: the county school-assignment layer is Volusia-only. 'assigned' = zoned schools returned;
// 'none_on_file' = covered county, no assignment recorded; 'not_available' = we hold no assignment data
// for this county. A `schools: []` must NOT read as "no assigned schools" off-Volusia.
export interface PirSchoolsCoverage { field_status: 'assigned' | 'none_on_file' | 'not_available'; who_can_answer?: string }

export interface PirWaterFeature { name: string | null; ftype: string | null; distanceM: number; bearingDegrees: number }
export interface PirBoatRamp { name: string | null; waterbody: string | null; distanceM: number; bearingDegrees: number }
// RULING 203 item 5. boatRamps stays an ARRAY (the report page calls .map on it), so
// the coverage state travels beside it rather than replacing it — additive, never a
// shape change. An empty boatRamps[] is ambiguous on its own and must NOT be read as
// "no ramp near this parcel": read boatRampsCoverage.
//   not_available     no marine layer is held for the county — says nothing either way
//   none_within_range layer held, genuinely no ramp within search_radius_m — a real negative
//   present           ramps returned
export interface PirBoatRampsCoverage {
  field_status: 'present' | 'none_within_range' | 'not_available'
  search_radius_m?: number
  coverage_note?: string | null
  who_can_answer?: string | null
}

export interface PirWater {
  nearestWaterM: number | null
  features: PirWaterFeature[]
  boatRamps: PirBoatRamp[]
  boatRampsCoverage?: PirBoatRampsCoverage | null
}

// Flood now comes from get_parcel_flood_zone() (coverage-aware NFHL), merged with areaRepetitiveLoss.
// not_available / parcel_not_resolved are COVERAGE GAPS — never render as "not in a flood zone".
export interface PirFloodZoneEntry {
  // in_sfha is NULLABLE: Zone D means FEMA performed NO analysis. null is UNDETERMINED,
  // never a clearance, and must not render like false. Ruling 251.
  zone: string; subtype: string | null; in_sfha: boolean | null
  base_flood_elevation_ft: number | null; pct_of_parcel: number | null
}
// RULING 266 — shareCheck is THREE STATES and only tenancy in common can produce true/false.
// value null means NOT COMPUTED, with the reason saying why: no_share_column (the county
// publishes none), not_applicable_tenancy (an entirety/joint/trust/life estate records each
// holder at the full share BY DESIGN), mixed_tenancy, or tenancy_not_recorded.
// A null must render as NOTHING — not a dash, not "unknown".
export interface PirShareCheck {
  subject?: unknown
  predicate?: 'shares_sum_to_unity'
  value: boolean | null
  field_status: 'present' | 'not_computed'
  reason?: 'sums_to_unity' | 'under_allocated' | 'over_allocated' | 'no_share_column'
         | 'not_applicable_tenancy' | 'mixed_tenancy' | 'tenancy_not_recorded' | 'no_share_recorded'
  note?: string
}

export interface PirFlood {
  field?: string
  field_status: 'present' | 'undetermined' | 'none_intersecting' | 'not_available' | 'parcel_not_resolved'
  zones?: PirFloodZoneEntry[] | null
  in_sfha?: boolean | null
  undetermined_zone_count?: number | null
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
  // null when the county recorded a PLACEHOLDER issue date rather than a real one
  // (Pinellas carries 661 such rows: 1800/1899/1900 — registered as
  // pcpao-permit-date-sentinel-years). The permit still evidences that a permit
  // EXISTS; it cannot support any claim about WHEN, and must never be compared
  // against a structure year to derive a permit gap. date_note says so verbatim.
  date: string | null
  date_note?: string | null
  permit_number: string | null
  issuing_authority: string | null
  work_description: string | null
  work_type?: string | null
  sub_type?: string | null
  // Pinellas only: the county's own permit type CODE, carried verbatim. We hold NO
  // crosswalk for these, so permit_type_note states the meaning is UNDEFINED. Do not
  // infer one — work_description is the authoritative text.
  permit_type_code?: string | null
  permit_type_note?: string | null
  contractor: string | null
  // Pinellas only: that register carries no contractor column at all, so absence is a
  // gap in the source and never evidence of unlicensed work.
  contractor_note?: string | null
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

// RULING 199. Four distinct states — collapsing them is the defect this replaced,
// where every non-Volusia county returned not_established over 1.65M loaded Pinellas
// permit rows. Registers are held for Volusia and Pinellas only.
//   present         register held, parcel keyed, permits found
//   none_recorded   register held, parcel keyed, register lists none FOR THIS PARCEL
//   not_established register held, but this parcel could not be keyed into it (our gap)
//   not_available   NO permit register is held for this county — says nothing about
//                   the parcel. A county with no permit register is not a parcel with
//                   no permits.
export interface PirPermitFacts {
  field_status: 'present' | 'none_recorded' | 'not_established' | 'not_available'
  count: number
  permits: PirPermitFact[]
  closeout_not_recorded_count: number
  coverage_note: string | null
  who_can_answer?: string | null
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

// PirZoning (zoneCode/pudName/futureLandUse*) REMOVED with the legacy `zoning` payload key — it was a
// Volusia-only duplicate of zoningFacts. Zoning + future land use live on PirZoningFacts only.

// Item 112: economic overlays are resolved by get_parcel_econzone_facts with an EXPLICIT
// coverage state, so the report distinguishes four genuinely different things:
//   present            parcel is inside a mapped zone (inside === true)
//   none_intersecting  county IS covered, parcel just isn't in a zone — a REAL negative (inside === false, distanceM to nearest)
//   not_available      we don't hold that overlay for this county — a COVERAGE GAP (routes to §7 via who_can_answer)
//   not_established    parcel geometry could not be resolved
// A null overlay must NEVER be read as "not in a zone" — that was the pre-112 false negative.
export type PirCoverageStatus = 'present' | 'none_intersecting' | 'not_available' | 'not_established'
export interface PirEconOverlay {
  field_status: PirCoverageStatus
  inside?: boolean | null
  distanceM?: number
  name?: string | null
  tract?: string | null
  zone?: string | null
  who_can_answer?: string
  coverage_note?: string
  note?: string
}
export interface PirEconomic {
  opportunityZone: PirEconOverlay | null
  hubZone: PirEconOverlay | null
  cra: PirEconOverlay | null
  enterpriseZone: PirEconOverlay | null
  // Brownfield is NO LONGER an econ overlay — it is a statewide FINDING (get_parcel_brownfield_facts):
  // inside a designated area (containment) + nearby sites (proximity) + honest absence. Rendered via
  // renderBrownfieldBlock, not overlayLine. Shape is the resolver's jsonb; field_status gates it.
  brownfield: Record<string, unknown> | null
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
  schoolsCoverage?: PirSchoolsCoverage | null
  permitFacts?: PirPermitFacts | null
  transactionFacts?: PirTransactionFacts | null
  land: PirLand
  sinkholeFacts?: PirSinkholeFacts | null
  water: PirWater
  // `flood` and `marineImprovements` REMOVED from the payload — superseded by floodBlock / marineBlock.
  // They were live fabrication surfaces for payload consumers (the payload is the security boundary, not
  // the render). areaRepetitiveLoss migrated onto floodBlock. Do not re-add.
  taxDeedStatus: PirTaxDeedStatus
  censusFacts?: PirCensusFacts | null
  ownerFacts?: PirOwnerFacts | null
  // NOTE: the legacy `zoning` key (volusia_zoning/FLU-backed, Volusia-only) was REMOVED — it was a duplicate
  // representation sitting beside statewide zoningFacts, the same hazard class as land.elevationFt beside
  // groundElevation. Zoning + future land use are answered ONLY by zoningFacts now. Do not re-add.
  zoningFacts?: PirZoningFacts | null
  economic: PirEconomic
  disclosures?: PirDisclosure[] | null
  marineBlock?: PirMarineBlock | null
  floodBlock?: PirFloodBlock | null
  groundElevation?: Record<string, unknown> | null
  contaminationFacilities?: Record<string, unknown> | null
  // Recorded land-use restrictions (get_parcel_restrictions): GWCA well-drilling bar (Ch. 62-524),
  // institutional controls, regulated on-parcel wells. An ARRAY of restriction findings; [] = checked,
  // none in the layers we hold (the render turns that into the honest historic-use absence statement).
  landRestrictions?: Record<string, unknown>[] | null
  // NWI wetland finding (get_parcel_wetland): containment, Deepwater + Lake (open water) EXCLUDED by category.
  // wetland_types drives the finding; a mapped NWI hit is a regional inventory, not a jurisdictional
  // delineation (the delineation gap renders in §7). identityFrame carries the frame; both read via cast.
  wetland?: Record<string, unknown> | null
  // Construction-defect repose window (get_parcel_repose_window): computed from act_yr_blt + FL s.95.11(3)(b)
  // 7-year repose. States ONLY whether the statutory window has/hasn't closed — never that a claim exists.
  // Builder from the original NEW-construction permit (Volusia), name AS RECORDED, related-by-name.
  reposeWindow?: Record<string, unknown> | null
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
