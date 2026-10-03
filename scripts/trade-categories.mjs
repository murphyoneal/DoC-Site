#!/usr/bin/env node
/**
 * Generate (or verify) lib/tradeCategories.ts from trade_display_category and trade_chip_map.
 *
 *   node scripts/trade-categories.mjs            # regenerate the file
 *   node scripts/trade-categories.mjs --check    # fail if the file is stale
 *
 * WHY THIS EXISTS. CATEGORY_LABELS was three hand-maintained copies and drifted twice:
 * qualifier_business was absent from one (407 rows would render a raw slug) and WRONG in another,
 * labelling those same 407 business registrations "General Contractor" - live on the homepage map,
 * asserting an unlimited licence scope. Generating the file removes the drift class instead of
 * detecting it: the database is the only place the vocabulary is written down.
 *
 * WHY IT NOW GENERATES THE CHIP LIST TOO (ruling 944/947). lib/trade-categories.ts carried a
 * hand-written CHIP_KEYS of nine, each with a count in a comment dated 2026-09-26, and a comment
 * explaining that there is "deliberately no Electrical chip" because the construction licence file
 * does not cover electricians. That was true when written. Migrations 176a/189a/201b then loaded the
 * Electrical Contractors' Licensing Board and made it false, and the comment stayed. 15,876
 * electrical and 2,092 alarm-system licences were searchable and unchipped - and so were 3,770
 * specialty contractors nobody had noticed were missing. CHIP_KEYS was the same defect as
 * CATEGORY_LABELS, one level up, and Electrical was the drift it was always going to produce.
 *
 * The threshold and the not_a_trade exclusion live in the trade_chip_map VIEW, not here, so this
 * script stays a renderer and the rule stays in one place.
 *
 * The --check mode runs in prebuild. A category added in SQL without regenerating fails the build
 * rather than rendering a slug to a user. A register loaded in SQL without regenerating now fails
 * the build rather than silently omitting a trade.
 *
 * FAILURE POLICY: if the database cannot be reached, --check FAILS. It does not pass quietly. A
 * check that skips itself when it cannot run is not a check - that is the vacuous-predicate shape,
 * and it has already cost this project a wrong conclusion once.
 */
import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const HERE = dirname(fileURLToPath(import.meta.url))
const OUT = resolve(HERE, '..', 'lib', 'tradeCategories.ts')
const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''

async function sbGet(path, what) {
  if (!KEY) {
    throw new Error(
      'SUPABASE_SECRET_KEY is not set. Refusing to pass a check that cannot run — ' +
      'set it, or run the generator locally and commit the result.',
    )
  }
  const res = await fetch(`https://${SB_HOST}/rest/v1/${path}`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  })
  if (!res.ok) {
    throw new Error(`${what} fetch failed: HTTP ${res.status} ${await res.text()}`)
  }
  const rows = await res.json()
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error(`${what} returned no rows — empty is not done`)
  }
  return rows
}

function fetchCategories() {
  return sbGet(
    'trade_display_category?select=category,label,grouping,note&order=grouping,category',
    'trade_display_category',
  )
}

// The chips, from the view that counts BOTH registers against a declared threshold. is_chip already
// excludes grouping not_a_trade, so education_provider cannot become a chip by crossing the threshold.
//
// NO COUNTS ARE EMITTED, and that is a correction (ruling 959). The first version of this generator
// baked records_total and plottable_records into the file as DATA, to avoid the stale-comment defect
// that CHIP_KEYS had. It traded one failure for a worse one: a count changes on every register load,
// the --check is an equality test, so every routine data load broke the build until someone
// regenerated. 209a proved it within a day - fixing 10,125 miscategorised rows moved General
// Contractor by exactly that much and made main unbuildable.
//
// What belongs in a generated file is what SHOULD stop a build when it changes: which trades exist,
// what they are called, and whether the map can represent them. A trade appearing or disappearing is
// a semantic change. 43,171 becoming 33,046 is Tuesday.
//
// And a count left in the file but excluded from the check would be the stale comment again wearing a
// data costume - a number nothing verifies. So it is not emitted at all. Any surface that wants a
// count reads trade_chip_map at runtime, where it is never stale.
function fetchChips() {
  return sbGet(
    'trade_chip_map?select=category,label,map_capable' +
      '&is_chip=is.true&order=records_total.desc,category',
    'trade_chip_map',
  )
}

function render(rows, chips) {
  const GROUP_TITLE = {
    licence_scope: 'licence scope, per s.489.105 — these describe what may legally be built',
    trade: 'trades',
    not_a_trade: 'not a trade and not a scope',
  }
  const order = ['licence_scope', 'trade', 'not_a_trade']
  let body = ''
  for (const g of order) {
    const inGroup = rows.filter((r) => r.grouping === g)
    if (!inGroup.length) continue
    body += `  // ${GROUP_TITLE[g] ?? g}\n`
    for (const r of inGroup) {
      body += `  ${r.category}: ${JSON.stringify(r.label)},\n`
    }
  }

  // 209a/ruling 957: the scope list is rendered from the table, so a new scope cannot be missed by the page guard.
  let scopeBody = ''
  for (const r of rows.filter((r) => r.grouping === 'licence_scope')) scopeBody += `  ${JSON.stringify(r.category)},
`

  let chipBody = ''
  for (const c of chips) {
    chipBody +=
      `  { category: ${JSON.stringify(c.category)}, label: ${JSON.stringify(c.label)},` +
      ` mapCapable: ${c.map_capable} },\n`
  }

  return `// GENERATED FILE — DO NOT EDIT.
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
${body}}

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
${scopeBody}] as const

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
${chipBody}] as const
`
}

const check = process.argv.includes('--check')
try {
  const [rows, chips] = await Promise.all([fetchCategories(), fetchChips()])
  const next = render(rows, chips)
  const current = (() => {
    try {
      return readFileSync(OUT, 'utf8')
    } catch {
      return null
    }
  })()

  if (!check) {
    writeFileSync(OUT, next, 'utf8')
    console.log(
      `wrote lib/tradeCategories.ts — ${rows.length} categories, ${chips.length} chips.`,
    )
  } else if (current === null) {
    console.error('FAIL: lib/tradeCategories.ts does not exist. Run npm run categories:generate.')
    process.exitCode = 1
  } else if (current.replace(/\r\n/g, '\n') !== next.replace(/\r\n/g, '\n')) {
    console.error(
      'FAIL: lib/tradeCategories.ts is STALE — it disagrees with trade_display_category or\n' +
      '      trade_chip_map. Run: npm run categories:generate, and commit the result.',
    )
    process.exitCode = 1
  } else {
    console.log(
      `trade categories OK — ${rows.length} categories, ${chips.length} chips, ` +
      'generated file matches the tables.',
    )
  }
} catch (err) {
  console.error(`FAIL: ${err.message}`)
  process.exitCode = 1
}

// exitCode rather than process.exit(): exit() races the open fetch handle and crashes libuv on
// Windows with a misleading 127 instead of a clean 1. The build still failed, but on the wrong
// signal — and a wrong exit code is the kind of thing that gets special-cased in CI later.
