import { CATEGORY_LABELS } from './tradeCategories'

// The homepage map's trade chips. KEYS ARE contractors.doc_category VALUES, and the labels come from
// the generated CATEGORY_LABELS, so a chip cannot drift from the data again. The old hand list
// keyed "pool" (the data says pool_spa), offered Concrete (0 businesses) and six trades holding 1
// or 2 each, and had no chip for building or residential contractors (17,415 and 7,776).
//
// Only categories with a useful number of businesses get a chip (counts from contractors_public,
// 2026-09-26). The construction licence file does not cover electricians (a separate board), so
// there is deliberately no Electrical chip. Emergency is not a chip: no business has stated it.
const CHIP_KEYS = [
  'general_contractor',     // 43,173
  'building_contractor',    // 17,415
  'residential_contractor', //  7,776
  'hvac',                   // 13,790
  'roofing',                // 10,498
  'plumbing',               //  8,923
  'pool_spa',               //  4,691
  'underground_utility',    //  2,663
  'solar',                  //    442
] as const

export const TRADE_CATEGORIES = CHIP_KEYS.map(value => ({ value, label: CATEGORY_LABELS[value] ?? value }))
