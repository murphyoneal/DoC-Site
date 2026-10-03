// GENERATED FILE — DO NOT EDIT.
// Source of truth: the trade_display_category and trade_chip_map tables.
// Regenerate with: npm run categories:generate
//
// Hand-editing this file recreates exactly the defect it replaced. CATEGORY_LABELS was three
// hand-maintained copies and drifted twice — qualifier_business absent from one (407 rows would
// have rendered the raw slug) and labelled "General Contractor" in another, asserting an
// unlimited licence scope on 407 business registrations, live on the homepage map.
//
// Keys are contractors.doc_category values. An unmapped value is NOT inert: it falls through to
// trade_label on the profile and renders the raw slug on the map. Only general_contractor may
// read "General Contractor" — see s.489.105.
export const CATEGORY_LABELS: Record<string, string> = {
  // licence scope, per s.489.105 — these describe what may legally be built
  building_contractor: "Building Contractor",
  general_contractor: "General Contractor",
  pollutant_storage: "Pollutant Storage",
  residential_contractor: "Residential Contractor",
  tank_testing: "Precision Tank Testing",
  underground_utility: "Underground Utility",
  // trades
  alarm_system: "Alarm System",
  drywall: "Drywall",
  electrical: "Electrical",
  fencing: "Fencing",
  fire_protection: "Fire Protection",
  flooring: "Flooring",
  general_engineering: "General Engineering",
  hvac: "HVAC",
  insulation: "Insulation",
  landscaping: "Landscaping",
  masonry: "Masonry",
  painting: "Painting",
  plumbing: "Plumbing",
  pool_spa: "Pool & Spa",
  pressure_washing: "Pressure Washing",
  roofing: "Roofing",
  sheet_metal: "Sheet Metal",
  solar: "Solar",
  specialty: "Specialty Contractor",
  windows_doors: "Windows & Doors",
  // not a trade and not a scope
  education_provider: "Continuing Education Provider",
  qualifier_business: "Business Registration",
}

/** Display label for a doc_category, falling back to the licence's own trade label. */
export function categoryLabel(
  docCategory: string | null | undefined,
  tradeLabel?: string | null,
): string {
  if (docCategory && CATEGORY_LABELS[docCategory]) return CATEGORY_LABELS[docCategory]
  return tradeLabel ?? 'Contractor'
}

// Licence SCOPES (trade_display_category grouping licence_scope). Under s.489.105 these state what a licence
// legally permits - "General Contractor" is unlimited as to type of work. Ruling 957: 10,125 business
// registrations (QB, no licence of their own) rendered "General Contractor" because a page preferred the
// category over the record's own trade label. A scope is rendered only where the row's own licence grants it.
export const LICENCE_SCOPE_CATEGORIES: readonly string[] = [
  "building_contractor",
  "general_contractor",
  "pollutant_storage",
  "residential_contractor",
  "tank_testing",
  "underground_utility",
] as const

/**
 * The trade line for a register row: the category label, EXCEPT that a licence scope is never shown for a row whose
 * category is a business registration or which holds no licence number - then the record's own trade label is used.
 */
export function rowTradeLabel(row: {
  doc_category?: string | null
  trade_label?: string | null
  license_number?: string | null
}): string {
  const cat = row.doc_category ?? null
  if (cat && LICENCE_SCOPE_CATEGORIES.includes(cat) && !row.license_number) return row.trade_label ?? 'Contractor'
  return categoryLabel(cat, row.trade_label)
}

export type ChipCategory = {
  category: string
  label: string
  /**
   * Whether the map can REPRESENT this trade — pins are at least half its records — not whether a
   * pin exists. False for Electrical (one plottable listing out of ~16,000) and Alarm System (none):
   * the electrical board's file carries no coordinates. Those trades are reachable by search only.
   */
  mapCapable: boolean
}

// The homepage trade chips, from trade_chip_map where is_chip. The view holds the record threshold,
// the plottable-share floor and the exclusion of grouping not_a_trade, by rule rather than by
// omission. A register loaded without regenerating this file fails prebuild instead of quietly
// dropping a trade — which is how Electrical, Alarm System and Specialty went missing before.
//
// NO COUNTS LIVE HERE. They change on every register load and would break the build each time; a
// count kept here but unchecked would just be the stale comment again. Read trade_chip_map at runtime
// for records_total (register rows) or plottable_records (map pins) — and never label a map with the
// first, because ~15% of construction listings have no coordinates.
export const CHIP_CATEGORIES: readonly ChipCategory[] = [
  { category: "general_contractor", label: "General Contractor", mapCapable: true },
  { category: "building_contractor", label: "Building Contractor", mapCapable: true },
  { category: "electrical", label: "Electrical", mapCapable: false },
  { category: "hvac", label: "HVAC", mapCapable: true },
  { category: "roofing", label: "Roofing", mapCapable: true },
  { category: "plumbing", label: "Plumbing", mapCapable: true },
  { category: "residential_contractor", label: "Residential Contractor", mapCapable: true },
  { category: "pool_spa", label: "Pool & Spa", mapCapable: true },
  { category: "specialty", label: "Specialty Contractor", mapCapable: true },
  { category: "underground_utility", label: "Underground Utility", mapCapable: true },
  { category: "alarm_system", label: "Alarm System", mapCapable: false },
  { category: "solar", label: "Solar", mapCapable: true },
] as const
