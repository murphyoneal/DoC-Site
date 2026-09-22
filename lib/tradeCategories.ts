// GENERATED FILE — DO NOT EDIT.
// Source of truth: the trade_display_category table.
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
