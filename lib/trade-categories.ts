import { CHIP_CATEGORIES } from './tradeCategories'

// The homepage trade chips. Values are contractors.doc_category values; the list, the labels and the
// counts all come from the GENERATED CHIP_CATEGORIES, rendered from the trade_chip_map view. Nothing
// here is hand-maintained, and that is the whole point of the file.
//
// WHAT WAS HERE BEFORE (rulings 944, 947). CHIP_KEYS was nine hand-written keys, each with a count in
// a comment dated 2026-09-26, plus this sentence:
//
//     "The construction licence file does not cover electricians (a separate board), so there is
//      deliberately no Electrical chip."
//
// True when written. Migrations 176a, 189a and 201b then loaded the Electrical Contractors' Licensing
// Board, the two-board search began returning electricians, and the sentence became the only thing in
// the codebase still asserting they were not covered. Generating the list also turned up a third gap
// nobody had noticed: 3,770 specialty contractors, never chipped at all.
//
// TWO LISTS, NOT ONE (ruling 951). The first generated list was wrong for its consumer and CC caught
// it: these chips drive a MAP, and the electrical board's file has no coordinates — 26 columns, not
// one of them lat or lng. An Electrical chip wired to the map would draw ONE pin in all of Florida
// (a single construction listing miscategorised electrical) and Alarm System would draw NONE. That is
// the empty-map failure the old Emergency chip was removed for.
//
// Checking it found the wider version: EVERY trade overstates the map. About 15% of construction
// listings carry no coordinates, so roofing is 10,498 records but 9,085 pins. `records` and `pins` are
// different populations and the generated type keeps them apart on purpose.
export const TRADE_CATEGORIES = CHIP_CATEGORIES.map(({ category, label }) => ({
  value: category,
  label,
}))

// Chips that can FILTER THE MAP: pins are at least half the trade's records. Ten of twelve.
// Label these with `pins`, never `records`.
export const MAP_TRADE_CATEGORIES = CHIP_CATEGORIES.filter(c => c.mapCapable)

// Chips the map cannot represent — Electrical (15,877 records, 1 pin) and Alarm System (2,092
// records, 0 pins). They are NOT hidden: hiding them would reproduce the exact gap this work was
// done to close, with the register holding 17,968 licences the homepage never mentions. They open the
// two-board register search for that trade instead of filtering the map, and the UI must make that
// visibly a different action rather than a filter that silently returns nothing.
export const SEARCH_ONLY_TRADE_CATEGORIES = CHIP_CATEGORIES.filter(c => !c.mapCapable)

// Full rows, for anywhere that wants a count. Kept separate from TRADE_CATEGORIES so a renderer
// cannot print a count without having asked for one.
//
// UNITS, because nothing here counts the same thing twice: `records` are register rows — construction
// rows are LISTINGS (114,000 rows carry 103,478 distinct licence numbers), electrical rows are
// LICENCES. `pins` are construction listings holding coordinates. A map labelled with `records`
// promises more than it draws.
export const TRADE_CATEGORY_RECORDS = CHIP_CATEGORIES
