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

export type ChipCategory = {
  category: string
  label: string
  /** Records across BOTH registers. Construction rows are listings; electrical rows are licences. */
  records: number
  construction: number
  electrical: number
  /** PINS — construction listings holding lat and lng. A DIFFERENT POPULATION from `records`. */
  pins: number
  /** pins as a percentage of records. */
  pinShare: number
  /**
   * Whether the map can REPRESENT this trade (pins >= 50% of records), not whether a pin exists.
   * False for Electrical (1 plottable of 15,877) and Alarm System (0 of 2,092): the electrical
   * board's file has no coordinates. Those trades are reachable by search, never by the map.
   */
  mapCapable: boolean
}

// The homepage trade chips, from trade_chip_map where is_chip — the view holds the threshold, the
// plottable-share floor, and the exclusion of grouping not_a_trade, by rule rather than by omission.
// A register loaded without regenerating this file fails prebuild instead of quietly dropping a trade,
// which is how Electrical (15,876), Alarm System (2,092) and Specialty (3,770) went missing before.
//
// NEVER LABEL THE MAP WITH `records`. Use `pins`. They differ by ~15% on every construction trade
// and by everything on the two electrical ones.
export const CHIP_CATEGORIES: readonly ChipCategory[] = [
  { category: "general_contractor", label: "General Contractor", records: 43171, construction: 43171, electrical: 0, pins: 36877, pinShare: 85.4, mapCapable: true },
  { category: "building_contractor", label: "Building Contractor", records: 17414, construction: 17414, electrical: 0, pins: 15032, pinShare: 86.3, mapCapable: true },
  { category: "electrical", label: "Electrical", records: 15877, construction: 1, electrical: 15876, pins: 1, pinShare: 0, mapCapable: false },
  { category: "hvac", label: "HVAC", records: 13789, construction: 13789, electrical: 0, pins: 11987, pinShare: 86.9, mapCapable: true },
  { category: "roofing", label: "Roofing", records: 10498, construction: 10498, electrical: 0, pins: 9085, pinShare: 86.5, mapCapable: true },
  { category: "plumbing", label: "Plumbing", records: 8923, construction: 8923, electrical: 0, pins: 7735, pinShare: 86.7, mapCapable: true },
  { category: "residential_contractor", label: "Residential Contractor", records: 7775, construction: 7775, electrical: 0, pins: 6747, pinShare: 86.8, mapCapable: true },
  { category: "pool_spa", label: "Pool & Spa", records: 4690, construction: 4690, electrical: 0, pins: 4086, pinShare: 87.1, mapCapable: true },
  { category: "specialty", label: "Specialty Contractor", records: 3770, construction: 3770, electrical: 0, pins: 3348, pinShare: 88.8, mapCapable: true },
  { category: "underground_utility", label: "Underground Utility", records: 2663, construction: 2663, electrical: 0, pins: 2222, pinShare: 83.4, mapCapable: true },
  { category: "alarm_system", label: "Alarm System", records: 2092, construction: 0, electrical: 2092, pins: 0, pinShare: 0, mapCapable: false },
  { category: "solar", label: "Solar", records: 442, construction: 442, electrical: 0, pins: 400, pinShare: 90.5, mapCapable: true },
] as const
