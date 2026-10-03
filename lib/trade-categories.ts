import { CHIP_CATEGORIES } from './tradeCategories'

// The homepage trade chips. Values are contractors.doc_category values; the list, the labels and the
// map/search split all come from the GENERATED CHIP_CATEGORIES, rendered from the trade_chip_map view.
// Nothing here is hand-maintained, and that is the whole point of the file.
//
// WHAT WAS HERE BEFORE (rulings 944, 947). CHIP_KEYS was nine hand-written keys, each with a count in a
// comment dated 2026-09-26, plus a sentence explaining that the construction licence file does not cover
// electricians so there was "deliberately no Electrical chip". True when written; migrations 176a, 189a
// and 201b loaded the Electrical Contractors' Licensing Board and made it false, and the sentence stayed.
// Generating the list also turned up a third gap nobody had noticed: specialty contractors.
//
// TWO LISTS, NOT ONE (ruling 951). These chips drive a MAP, and the electrical board's file has no
// coordinates — 26 columns, not one of them lat or lng. An Electrical chip wired to the map would draw
// ONE pin in all of Florida and Alarm System would draw NONE.
//
// NO COUNTS (ruling 959). The first generated version baked record and pin counts in as data, to avoid
// the stale-comment defect. That was an over-correction: counts move on every register load, the
// generator's check is an equality test, so routine data loads broke the build. Fixing 10,125
// miscategorised business registrations proved it inside a day. Counts now live only in trade_chip_map
// and are read at runtime. What the file carries is what should stop a build when it changes: which
// trades exist, what they are called, and whether the map can represent them.
export const TRADE_CATEGORIES = CHIP_CATEGORIES.map(({ category, label }) => ({
  value: category,
  label,
}))

// Chips that can FILTER THE MAP: pins are at least half the trade's records.
// If a count is shown beside one of these, read it from trade_chip_map.plottable_records — the PIN
// count — never records_total. About 15% of construction listings carry no coordinates.
export const MAP_TRADE_CATEGORIES = CHIP_CATEGORIES.filter(c => c.mapCapable)

// Chips the map cannot represent — Electrical and Alarm System, from the electrical board's file.
// They are NOT hidden: hiding them would reproduce the exact gap this work existed to close, with the
// register holding licences the homepage never mentions. They open the two-board register search for
// that trade instead of filtering the map, and the UI must make that visibly a different action rather
// than a filter that silently returns nothing.
export const SEARCH_ONLY_TRADE_CATEGORIES = CHIP_CATEGORIES.filter(c => !c.mapCapable)
