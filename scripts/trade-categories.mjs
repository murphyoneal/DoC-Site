#!/usr/bin/env node
/**
 * Generate (or verify) lib/tradeCategories.ts from trade_display_category.
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
 * The --check mode runs in prebuild. A category added in SQL without regenerating fails the build
 * rather than rendering a slug to a user.
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

async function fetchCategories() {
  if (!KEY) {
    throw new Error(
      'SUPABASE_SECRET_KEY is not set. Refusing to pass a check that cannot run — ' +
      'set it, or run the generator locally and commit the result.',
    )
  }
  const url =
    `https://${SB_HOST}/rest/v1/trade_display_category` +
    `?select=category,label,grouping,note&order=grouping,category`
  const res = await fetch(url, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  })
  if (!res.ok) {
    throw new Error(`trade_display_category fetch failed: HTTP ${res.status} ${await res.text()}`)
  }
  const rows = await res.json()
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error('trade_display_category returned no rows — empty is not done')
  }
  return rows
}

function render(rows) {
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
  return `// GENERATED FILE — DO NOT EDIT.
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
${body}}

/** Display label for a doc_category, falling back to the licence's own trade label. */
export function categoryLabel(
  docCategory: string | null | undefined,
  tradeLabel?: string | null,
): string {
  if (docCategory && CATEGORY_LABELS[docCategory]) return CATEGORY_LABELS[docCategory]
  return tradeLabel ?? 'Contractor'
}
`
}

const check = process.argv.includes('--check')
try {
  const rows = await fetchCategories()
  const next = render(rows)
  const current = (() => {
    try {
      return readFileSync(OUT, 'utf8')
    } catch {
      return null
    }
  })()

  if (!check) {
    writeFileSync(OUT, next, 'utf8')
    console.log(`wrote lib/tradeCategories.ts — ${rows.length} categories.`)
  } else if (current === null) {
    console.error('FAIL: lib/tradeCategories.ts does not exist. Run npm run categories:generate.')
    process.exitCode = 1
  } else if (current.replace(/\r\n/g, '\n') !== next.replace(/\r\n/g, '\n')) {
    console.error(
      'FAIL: lib/tradeCategories.ts is STALE — it disagrees with trade_display_category.\n' +
      '      Run: npm run categories:generate, and commit the result.',
    )
    process.exitCode = 1
  } else {
    console.log(`trade categories OK — ${rows.length} categories, generated file matches the table.`)
  }
} catch (err) {
  console.error(`FAIL: ${err.message}`)
  process.exitCode = 1
}

// exitCode rather than process.exit(): exit() races the open fetch handle and crashes libuv on
// Windows with a misleading 127 instead of a clean 1. The build still failed, but on the wrong
// signal — and a wrong exit code is the kind of thing that gets special-cased in CI later.
