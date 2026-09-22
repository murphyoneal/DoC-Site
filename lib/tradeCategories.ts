// The ONE display map for contractors.doc_category.
//
// This existed as three hand-maintained copies — app/c/[slug]/page.tsx,
// app/c/[slug]/scan/page.tsx and app/components/ContractorMap.tsx — and they had
// drifted, twice over:
//
//   * qualifier_business was absent from the profile copy entirely, so 407 served
//     rows would have rendered the raw slug.
//   * the map copy labelled qualifier_business 'General Contractor' — a business
//     registration displayed as an unlimited-scope licence, which is the same
//     overstatement that s.489.105 work had just removed everywhere else. It
//     survived in the third copy because nothing compared them.
//
// Three copies of one vocabulary is the same shape as two columns storing one
// fact; it just fails in the display layer instead of the data layer. One map,
// imported.
//
// The KEYS are contractors.doc_category values. Those are set from
// trade_code_registry.display_category for every code whose licence determines
// the trade, and left alone for QB, which carries a per-business category the
// code cannot supply. So a new key appears here only when the registry gains a
// new display_category — and an unmapped value is NOT inert: it falls through to
// trade_label on the profile and renders the raw slug on the map.
//
// The labels must not overstate the licence. Under s.489.105 a Certified General
// Contractor is unlimited as to type of work; a Building Contractor is limited to
// three storeys; a Residential Contractor to one-, two- and three-family homes.
// Only general_contractor may read "General Contractor".
export const CATEGORY_LABELS: Record<string, string> = {
  // licence scope, per s.489.105
  general_contractor: 'General Contractor',
  building_contractor: 'Building Contractor',
  residential_contractor: 'Residential Contractor',
  underground_utility: 'Underground Utility',
  pollutant_storage: 'Pollutant Storage',
  tank_testing: 'Precision Tank Testing',
  // trades
  roofing: 'Roofing',
  plumbing: 'Plumbing',
  hvac: 'HVAC',
  electrical: 'Electrical',
  pool_spa: 'Pool & Spa',
  specialty: 'Specialty Contractor',
  sheet_metal: 'Sheet Metal',
  solar: 'Solar',
  painting: 'Painting',
  flooring: 'Flooring',
  masonry: 'Masonry',
  landscaping: 'Landscaping',
  windows_doors: 'Windows & Doors',
  insulation: 'Insulation',
  drywall: 'Drywall',
  fencing: 'Fencing',
  fire_protection: 'Fire Protection',
  general_engineering: 'General Engineering',
  pressure_washing: 'Pressure Washing',
  // not a trade at all
  qualifier_business: 'Business Registration',
  education_provider: 'Continuing Education Provider',
}

/** Display label for a doc_category, falling back to the licence's own trade label. */
export function categoryLabel(
  docCategory: string | null | undefined,
  tradeLabel?: string | null,
): string {
  if (docCategory && CATEGORY_LABELS[docCategory]) return CATEGORY_LABELS[docCategory]
  return tradeLabel ?? 'Contractor'
}
