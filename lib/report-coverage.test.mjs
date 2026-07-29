// lib/report-coverage.test.mjs
// Render smoke test for the coverage-aware report blocks — the check that would have caught the
// unseen marine states (and the fabricated wind dial's shape). Plain node, no site/keys/env:
//   node lib/report-coverage.test.mjs
// Fixtures mirror the live get_parcel_marine_improvements / get_parcel_tax_deed_status shapes.

import assert from 'node:assert';
import { marineView, taxDeedView, hasForbiddenCoverageGapPhrase } from './report-coverage.mjs';

let ran = 0; const failures = [];
function test(name, fn) { ran++; try { fn(); console.log(`  ok   ${name}`); }
  catch (e) { failures.push(name); console.log(`  FAIL ${name} — ${e.message}`); } }

const text = (v) => [v.note, v.body].filter(Boolean).join(' ');

// ── Fixtures (trimmed from live payloads) ────────────────────────────────────
const marineWithDock = { field_status: 'present', material_caveat: 'Material is not recorded…',
  waterfront_basis: 'The county has assessed a marine improvement.', service_life_basis: 'Derived from the county schedule.',
  items: [{ description: 'DOCK, BOAT', size: '845 sq ft', grade: 'C', year_built: '2018', age_years: 8,
            depreciated_value: '19484', replacement_cost_new: '26330', pct_depreciated: 26, at_or_past_assessed_service_life: false }] };
const marineNone = { field_status: 'none_recorded', items: [], waterfront_indicator: false,
  coverage_caveat: 'A zero here means the appraiser recorded none, NOT that no structure exists.' };
const marineNotAvail = { field_status: 'not_available', items: null, waterfront_indicator: null,
  coverage_caveat: 'CAMA misc not held for this county. COVERAGE GAP … no dock, seawall, lift or slip. Volusia only.' };

const taxDeedPresent = { field_status: 'present', as_of: '2026-07-03', opening_bid_usd: 1504.56,
  certificate_number: '8028-19', date_available_to_public: '2025-07-11', meaning: 'Held by the county…',
  staleness_warning: 'The register changes as parcels are purchased or redeemed.', not_legal_advice: 'Not legal advice.' };
const taxDeedNotOnList = { field_status: 'not_on_list', as_of: '2026-07-03',
  coverage_caveat: 'Does not appear on the register; NOT a statement that taxes are current.' };
const taxDeedNotAvail = { field_status: 'not_available', on_lands_available_list: null,
  coverage_caveat: 'Register not held for this county. COVERAGE GAP … free of tax-deed exposure. Volusia only.' };

// ── The load-bearing rule: coverage gap must never read as a negative finding ─
test('negative control — the forbidden-phrase detector actually fires', () => {
  assert.ok(hasForbiddenCoverageGapPhrase('absence does not mean no dock'), 'must catch "no dock"');
  assert.ok(hasForbiddenCoverageGapPhrase('None on record'), 'must catch "none"');
  assert.ok(!hasForbiddenCoverageGapPhrase('its absence is not evidence either way'), 'clean text must pass');
});

test('marine not_available → coverage gap, never "no dock"/"none"', () => {
  const v = marineView(marineNotAvail);
  assert.equal(v.mode, 'coverage_gap');
  assert.ok(/coverage gap/i.test(text(v)), 'must state it is a coverage gap');
  assert.ok(!hasForbiddenCoverageGapPhrase(text(v)),
    `coverage-gap copy leaked a finding phrase: "${text(v)}"`);
});

test('tax-deed not_available → coverage gap, never "no tax exposure"/"none"', () => {
  const v = taxDeedView(taxDeedNotAvail);
  assert.equal(v.mode, 'coverage_gap');
  assert.ok(/coverage gap/i.test(text(v)));
  assert.ok(!hasForbiddenCoverageGapPhrase(text(v)),
    `coverage-gap copy leaked a finding phrase: "${text(v)}"`);
});

test('coverage gap and "recorded none" are DISTINCT modes (the whole point)', () => {
  assert.equal(marineView(marineNotAvail).mode, 'coverage_gap');
  assert.equal(marineView(marineNone).mode, 'none_recorded');  // Volusia, real "none recorded"
  assert.notEqual(marineView(marineNotAvail).mode, marineView(marineNone).mode);
});

test('marine present renders its items', () => {
  const v = marineView(marineWithDock);
  assert.equal(v.mode, 'present');
  assert.equal(v.items.length, 1);
  assert.equal(v.items[0].description, 'DOCK, BOAT');
});

test('tax-deed present & not_on_list MUST carry as_of (staleness is load-bearing)', () => {
  assert.equal(taxDeedView(taxDeedPresent).asOf, '2026-07-03');
  assert.ok(taxDeedView(taxDeedNotOnList).body.includes('2026-07-03'), 'not_on_list must show the snapshot date');
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} render controls, coverage gap never reads as a finding.` : `FAIL — ${failures.length}/${ran}`}`);
process.exit(failures.length === 0 ? 0 : 1);
