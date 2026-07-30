// lib/fact-render.test.mjs
// Proves the deterministic path renders all states correctly BEFORE the happy path is wired everywhere.
//   node lib/fact-render.test.mjs
// Fixtures A/B/C are REAL get_parcel_marine_fact output (parcels 2001178 / 2001160). NULL and UNVERIFIED
// are constructed: no marine improvement in the data has a null area (the county records footprint for
// every one), and the only corroborator source seeded so far (permits) is 'partial', so the 'unverified'
// branch is exercised with a synthetic corroborator — the render LOGIC is what's under test.

import assert from 'node:assert';
import { renderFact, NULL_STRINGS } from './fact-render.mjs';

let ran = 0; const failures = [];
function test(name, fn) { ran++; try { fn(); console.log(`  ok   ${name}`); }
  catch (e) { failures.push(name); console.log(`  FAIL ${name} — ${e.message}`); } }
const noConfidenceScore = (o) => !/["']?(confidence|score|certainty)["']?\s*[:=]/i.test(JSON.stringify(o));

// ── REAL records (captured from get_parcel_marine_fact) ──────────────────────────
const REC_A = { predicate: 'area_sqft', value: 2856, field_status: 'present',
  source: 'volusia_cama_misc.AREA', source_tier: 'county_assessor_record', as_of: '2026 tax roll',
  corroborators: [], contradictors: [], open_questions: [],
  note: 'as_of dates the claim (the 2026 roll), not the structure (built 1998).' };

const REC_B = { predicate: 'built_year', value: 1998, field_status: 'present',
  source: 'volusia_cama_misc.YRBLT', source_tier: 'county_assessor_record', as_of: '2026 tax roll',
  corroborators: [
    { source: 'volusia_cama_permits[19970827008]', value: 'SINGLE FAMILY-DETACH · $0 · 09/03/97 00:00:00', independence_status: 'partial', qualifier_note: 'built_year only: appraiser may consult the permit…' },
    { source: 'volusia_cama_permits[19971014061]', value: 'LAKE GEORGE FISHING PIER · $107000 · 11/19/97 00:00:00', independence_status: 'partial', qualifier_note: 'built_year only: appraiser may consult the permit…' },
    { source: 'volusia_cama_permits[19980707072]', value: 'MECHANICAL MISC · $0 · 07/07/98 00:00:00', independence_status: 'partial', qualifier_note: 'built_year only: appraiser may consult the permit…' },
  ], contradictors: [], open_questions: [],
  note: 'as_of dates the claim (the 2026 roll), not the structure (built 1998).' };

const REC_C = { predicate: 'built_year', value: 2011, field_status: 'present',
  source: 'volusia_cama_misc.YRBLT', source_tier: 'county_assessor_record', as_of: '2026 tax roll',
  corroborators: [], contradictors: [],
  open_questions: [{ question: 'Assessed dock, boat built 2011, but no county building permit corroborates that year (no permits on this parcel at all).',
    why_it_matters: '…', who_can_answer: 'The seller and the Volusia building department; FDEP for marine/environmental work.' }],
  note: 'as_of dates the claim (the 2026 roll), not the structure (built 2011).' };

// ── CONSTRUCTED (see header) ─────────────────────────────────────────────────────
const REC_NULL = { predicate: 'area_sqft', value: null, field_status: 'not_recorded',
  source: 'volusia_cama_misc.AREA', source_tier: 'county_assessor_record', as_of: '2026 tax roll',
  corroborators: [], contradictors: [], open_questions: [] };

const REC_UNVERIFIED = { predicate: 'built_year', value: 1998, field_status: 'present',
  source: 'volusia_cama_misc.YRBLT', source_tier: 'county_assessor_record', as_of: '2026 tax roll',
  corroborators: [{ source: 'some_source_with_no_lineage_edge[x]', value: 'a claim whose independence was never established', independence_status: 'unverified' }],
  contradictors: [], open_questions: [] };

// ── HAPPY ────────────────────────────────────────────────────────────────────────
test('happy: area renders the value + provenance, single source, no confidence score', () => {
  const v = renderFact(REC_A);
  assert.equal(v.label, '2,856 sq ft');
  assert.equal(v.hasValue, true);
  assert.equal(v.provenance.source_count, 1);
  assert.equal(v.provenance.tier, 'county_assessor_record');
  assert.equal(v.corroboration.length, 0);            // honest single-source; no manufactured corroboration
  assert.ok(noConfidenceScore(v), 'must not emit a confidence/score');
});

// ── NULL — the line that kills the ±0.96 ft fabrication ──────────────────────────
test('null: absent value renders the FIXED string, no source line, no narration', () => {
  const v = renderFact(REC_NULL);
  assert.equal(v.label, NULL_STRINGS.area_sqft);      // 'Footprint not recorded by the county'
  assert.equal(v.hasValue, false);
  assert.equal(v.provenance, null);                   // no source line for an absent value
  assert.equal(v.corroboration.length, 0);
});

// ── PARTIAL — 'partially independent', never bare 'independent' ───────────────────
test('partial: permit corroborators render "partially independent", never "independent"', () => {
  const v = renderFact(REC_B);
  assert.equal(v.provenance.source_count, 4);         // 1 + 3 permits
  assert.equal(v.corroboration.length, 3);
  for (const c of v.corroboration) {
    assert.equal(c.independence, 'partially independent');
    assert.notEqual(c.independence, 'independent');   // the whole point of the qualifier
    assert.ok(c.caveat, 'partial must carry its caveat');
  }
});

// ── UNVERIFIED — renders "not established", NEVER "independent" ───────────────────
test('unverified: an unasserted corroborator renders "not established", never "independent"', () => {
  const v = renderFact(REC_UNVERIFIED);
  assert.equal(v.corroboration[0].independence, 'not established');
  assert.notEqual(v.corroboration[0].independence, 'independent');
});

// ── OPEN QUESTION — the 6,097 rendered as value, not a missing corroborator ───────
test('open question: no-permit dock surfaces the question, empty corroboration', () => {
  const v = renderFact(REC_C);
  assert.equal(v.corroboration.length, 0);
  assert.equal(v.openQuestions.length, 1);
  assert.ok(/no county building permit/i.test(v.openQuestions[0]));
});

// ── GLOBAL — no rendered record anywhere emits a confidence score ────────────────
test('no confidence score on ANY rendered record', () => {
  for (const rec of [REC_A, REC_B, REC_C, REC_NULL, REC_UNVERIFIED])
    assert.ok(noConfidenceScore(renderFact(rec)), 'a confidence/score leaked into a render');
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} fact-render controls; null + unverified render safe, no confidence score.` : `FAIL — ${failures.length}/${ran}`}`);
process.exit(failures.length === 0 ? 0 : 1);
