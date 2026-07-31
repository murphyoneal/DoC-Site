// lib/fact-render.test.mjs
// Proves the deterministic path renders all states correctly BEFORE the happy path is wired everywhere.
//   node lib/fact-render.test.mjs
// Fixtures A/B/C are REAL get_parcel_marine_fact output (parcels 2001178 / 2001160). NULL and UNVERIFIED
// are constructed: no marine improvement in the data has a null area (the county records footprint for
// every one), and the only corroborator source seeded so far (permits) is 'partial', so the 'unverified'
// branch is exercised with a synthetic corroborator — the render LOGIC is what's under test.

import assert from 'node:assert';
import { renderFact, renderMarineBlock, renderValuesBlock, renderCensusBlock, NULL_STRINGS } from './fact-render.mjs';

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

// ── Derived / our-inference / block (the four things to hold) ────────────────────
test('derived value declares itself — pct_depreciated on "derived" tier, carries its method', () => {
  const v = renderFact({ predicate: 'pct_depreciated', value: 54, field_status: 'present', source: '(derived)', source_tier: 'derived',
    derivation: { method: '1 - RCNLD/RCN', inputs: ['RCN','RCNLD'], our_inference: false }, corroborators: [], contradictors: [], open_questions: [] });
  assert.equal(v.label, '54% depreciated');
  assert.equal(v.provenance.tier, 'derived');
  assert.ok(v.provenance.derivation, 'a derived value must carry its derivation');
  assert.equal(v.provenance.is_our_inference, false);      // arithmetic on county figures, not OUR inference
});

test('our inference never borrows county authority — service_life on analysis_inference tier', () => {
  const v = renderFact({ predicate: 'service_life_vs_age', value: 13, field_status: 'present', source: 'dop_analysis', source_tier: 'analysis_inference',
    derivation: { our_inference: true, assessed_service_life_years: 30, age_years: 17 }, corroborators: [], contradictors: [], open_questions: [] });
  assert.equal(v.label, '13 yr of assessed service life remaining');
  assert.equal(v.provenance.is_our_inference, true);
  assert.notEqual(v.provenance.tier, 'county_assessor_record');
});

test('not_derived renders the fixed string (service life for boat house / lift)', () => {
  const v = renderFact({ predicate: 'service_life_vs_age', value: null, field_status: 'not_derived', source: 'dop_analysis', source_tier: 'analysis_inference',
    derivation: { our_inference: true }, corroborators: [], contradictors: [], open_questions: [] });
  assert.equal(v.hasValue, false);
  assert.equal(v.label, 'Service life not derived for this improvement type');
});

test('block: 1212 S Riverside surfaces 4 improvements, >=1 open question, DEF-023 material', () => {
  const block = { parcel: '74/6473111', improvements: [
    { improvement: 'boat house', built: 2009, facts: { built_year: { predicate: 'built_year', value: 2009, field_status: 'present',
        source: 'volusia_cama_misc.YRBLT', source_tier: 'county_assessor_record', corroborators: [], contradictors: [],
        open_questions: [{ question: 'no county permit within a year', why_it_matters: 'x', who_can_answer: 'y' }] } } },
    { improvement: 'boat lift', built: 2009, facts: {} },
    { improvement: 'dock, boat', built: 2009, facts: {} },
    { improvement: 'sea wall (bulkheads)', built: 2010, facts: {} },
  ], material_disclosure: { kind: 'source_limit', defect_id: 'DEF-023', disclosure: 'The county does not record what this structure is made of.' } };
  const r = renderMarineBlock(block);
  assert.equal(r.improvements.length, 4);
  assert.ok(r.improvements.some((i) => i.openQuestions.length >= 1), 'at least one open question');
  assert.ok(r.material && r.material.kind === 'source_limit' && r.material.text.length > 0, 'material caveat carried from DEF-023');
});

test('value_withheld: the number is NEVER rendered — only the asymmetry (the 5th-fabrication fix)', () => {
  const v = renderFact({ predicate: 'ground_elevation', value: null, field_status: 'value_withheld',
    source: 'parcel_elevations', source_tier: 'government_derived', vertical_datum: 'not recorded',
    note: 'Ground elevation is on record, but its vertical datum is not — so it cannot be placed relative to a base flood elevation.' });
  assert.equal(v.hasValue, false);
  assert.ok(/vertical datum is not/i.test(v.label), 'must render the asymmetry statement');
  assert.ok(!/\d/.test(v.label), 'must NOT render any number');   // no foot-level figure
  assert.equal(v.provenance, null);
});

// ── VALUES BLOCK — real _value_fact output (captured from get_parcel_values_facts) ────────────────
// Volusia 744403020120 (1212 S Riverside): every field CAMA 2026. Marion 21068-001-01: NAL 2025,
// improvement is just-land-special ($90,948,950 — the $45.6M special-feature subtraction the
// assert-equality check caught). corroborators:[] on every field BY DESIGN (CAMA/NAL share DOR lineage).
const vf = (predicate, value, source, tier, as_of, status = 'present') =>
  ({ predicate, value, field_status: status, source, source_tier: tier, as_of, corroborators: [], contradictors: [] });

const VF_VOLUSIA = {
  just_value:        vf('just_value',        2094505, 'volusia_cama_parcel', 'county_assessor_record', '2026 roll (CAMA — live county file)'),
  assessed_value:    vf('assessed_value',    1969218, 'volusia_cama_parcel', 'county_assessor_record', '2026 roll (CAMA — live county file)'),
  land_value:        vf('land_value',         915000, 'volusia_cama_parcel', 'county_assessor_record', '2026 roll (CAMA — live county file)'),
  improvement_value: vf('improvement_value', 1179505, 'volusia_cama_parcel', 'county_assessor_record', '2026 roll (CAMA — live county file)'),
};
const VF_MARION = {
  just_value:        vf('just_value',        137869293, 'marion_nal_dor_source', 'government_derived', '2025 roll (NAL — DOR annual snapshot)'),
  land_value:        vf('land_value',          1287794, 'marion_nal_dor_source', 'government_derived', '2025 roll (NAL — DOR annual snapshot)'),
  improvement_value: vf('improvement_value',  90948950, 'marion_nal_dor_source', 'government_derived', '2025 roll (NAL — DOR annual snapshot)'),
  assessed_value:    vf('assessed_value',    null, 'marion_nal_dor_source', 'government_derived', null, 'not_recorded'),
};
// A real asymmetry: CAMA carries a 2026 just value, but the land value falls through to the 2025 NAL roll.
const VF_MIXED = {
  just_value:        vf('just_value',        2094505, 'volusia_cama_parcel',   'county_assessor_record', '2026 roll (CAMA — live county file)'),
  land_value:        vf('land_value',         800000, 'volusia_nal_dor_source','government_derived',      '2025 roll (NAL — DOR annual snapshot)'),
};

test('values: CAMA figures render as dollars with county tier, no confidence score', () => {
  const b = renderValuesBlock(VF_VOLUSIA);
  const just = b.fields.find((f) => f.key === 'justValue');
  assert.equal(just.rendered.label, '$2,094,505');
  assert.equal(just.rendered.provenance.tier, 'county_assessor_record');
  assert.equal(just.rendered.corroboration.length, 0);   // CAMA/NAL same lineage — never manufactured corroboration
  assert.equal(b.rollSpan.mixed, false);                  // every field is the 2026 CAMA roll
  assert.ok(noConfidenceScore(b), 'values block must not emit a confidence/score');
});

test('values: the $45.6M special-feature subtraction renders (improvement = just-land-special)', () => {
  const b = renderValuesBlock(VF_MARION);
  const imp = b.fields.find((f) => f.key === 'improvementValue');
  assert.equal(imp.rendered.label, '$90,948,950');        // NOT $136,581,499 (the pre-fix, special-omitted number)
  assert.equal(imp.rendered.provenance.tier, 'government_derived');
});

test('values: an absent field renders the NULL string, never a number', () => {
  const b = renderValuesBlock(VF_MARION);
  const assessed = b.fields.find((f) => f.key === 'assessedValue');
  assert.equal(assessed.rendered.hasValue, false);
  assert.equal(assessed.rendered.label, NULL_STRINGS.assessed_value);
  assert.ok(!/\d/.test(assessed.rendered.label), 'absent value must not render a digit');
});

test('values: mixed rolls are SURFACED, not reconciled — both years named, never silently one', () => {
  const b = renderValuesBlock(VF_MIXED);
  assert.equal(b.rollSpan.mixed, true);
  assert.ok(/2026/.test(b.rollSpan.note) && /2025/.test(b.rollSpan.note), 'both rolls must appear in the note');
  // the per-field as_of dates each figure independently — a block-level year would misdate one
  assert.equal(b.fields.find((f) => f.key === 'justValue').asOf, '2026 roll (CAMA — live county file)');
  assert.equal(b.fields.find((f) => f.key === 'landValue').asOf, '2025 roll (NAL — DOR annual snapshot)');
});

// ── CENSUS BLOCK — subject is the BLOCK GROUP, never the parcel (real get_parcel_census_facts output) ──
// Volusia 744403020120 -> GEOID 121270828021 (tract 828.02 BG1): median $61,397, pop 1,280, 728 units.
// The fact's subject carries the geoid (a block-group geography), NOT the parcel — that's DEF-014 avoided.
const cfFact = (predicate, value) => ({
  subject: { type: 'census_block_group', geoid: '121270828021', contains_parcel: '74/744403020120' },
  predicate, value, field_status: value == null ? 'not_recorded' : 'present',
  source: value == null ? undefined : 'census_acs_data',
  source_tier: value == null ? undefined : 'federal_statistical',
  as_of: value == null ? undefined : 'ACS 5-year estimate — vintage inferred (2020-2024), not yet confirmed',
  note: value == null ? undefined : 'A 5-year sample estimate. The Census Bureau publishes a margin of error for this figure that we do not carry — read it as an estimate for the area, not an exact count.',
  vintage_note: value == null ? undefined : 'INFERRED from load date + ACS release calendar; not value-matched.',
  corroborators: [], contradictors: [],
});
const CF_PRESENT = {
  field_status: 'present',
  geography: { type: 'census_block_group', geoid: '121270828021', contains_parcel: '74/744403020120',
               name: 'Block Group 1; Census Tract 828.02; Volusia County; Florida' },
  containment: { subject: { parcel: '74/744403020120' }, predicate: 'contained_within',
    value: 'census block group 121270828021', field_status: 'present',
    source: 'census_block_groups', source_tier: 'government_derived',
    as_of: 'Census TIGER block-group boundaries', corroborators: [], contradictors: [] },
  facts: { median_household_income: cfFact('median_household_income', 61397),
           total_population: cfFact('total_population', 1280),
           total_housing_units: cfFact('total_housing_units', 728) },
  coverage_note: null,
};
const CF_GAP = { field_status: 'not_established', geography: null, facts: {},
  coverage_note: 'This parcel does not fall inside any census block group we hold. This is a gap in our coverage, not a statement about the parcel.' };
const CF_NULL_FIELD = { ...CF_PRESENT,
  facts: { ...CF_PRESENT.facts, median_household_income: cfFact('median_household_income', null) } };

test('census: geography is NAMED and the figure renders under it, tier federal_statistical', () => {
  const b = renderCensusBlock(CF_PRESENT);
  assert.equal(b.established, true);
  assert.equal(b.geography.geoid, '121270828021');
  assert.ok(/Census Tract 828\.02/.test(b.geography.name), 'the block group must be named in the render');
  const mhi = b.fields.find((f) => f.key === 'medianHouseholdIncome');
  assert.equal(mhi.rendered.label, '$61,397');
  assert.equal(mhi.rendered.provenance.tier, 'federal_statistical');   // a SAMPLE estimate, not county/roll/FEMA
});

test('census: the un-carried MOE is stated plainly and NEVER invented', () => {
  const b = renderCensusBlock(CF_PRESENT);
  const mhi = b.fields.find((f) => f.key === 'medianHouseholdIncome');
  assert.ok(/margin of error/i.test(mhi.rendered.provenance.note), 'must say a margin exists');
  assert.ok(/we do not carry|do not carry/i.test(mhi.rendered.provenance.note), 'must say we do not hold it');
  assert.ok(!/[±]|\+\/-|\bplus or minus\b/i.test(mhi.rendered.provenance.note), 'must NOT invent a ± figure');
});

test('census: vintage is surfaced as UNCONFIRMED, never a bare asserted period', () => {
  const b = renderCensusBlock(CF_PRESENT);
  assert.ok(/not yet confirmed/i.test(b.vintage.asOf), 'unconfirmed vintage must say so');
  const mhi = b.fields.find((f) => f.key === 'medianHouseholdIncome');
  assert.ok(/not yet confirmed/i.test(mhi.rendered.provenance.as_of), 'the as_of carries the unconfirmed flag');
});

test('census: containment is its own fact and is NOT federal_statistical (spatial op on TIGER)', () => {
  const b = renderCensusBlock(CF_PRESENT);
  assert.ok(/121270828021/.test(b.containment.text));
  assert.equal(b.containment.tier, 'government_derived');   // deterministic ST_Contains, not a sample estimate
});

test('census: a coverage gap is about US, never "the parcel has no income"', () => {
  const b = renderCensusBlock(CF_GAP);
  assert.equal(b.established, false);
  assert.equal(b.fields.length, 0);                          // no figures rendered under a gap
  assert.ok(/gap in our coverage|not a statement about the parcel/i.test(b.coverageNote));
  assert.ok(!/\$/.test(b.coverageNote), 'a gap must not render any figure');
});

test('census: an absent figure renders the NULL string, never a number or a parcel-level 0', () => {
  const b = renderCensusBlock(CF_NULL_FIELD);
  const mhi = b.fields.find((f) => f.key === 'medianHouseholdIncome');
  assert.equal(mhi.rendered.hasValue, false);
  assert.equal(mhi.rendered.label, NULL_STRINGS.median_household_income);
  assert.ok(!/\d/.test(mhi.rendered.label), 'absent value must not render a digit');
});

test('census: no confidence score on any rendered figure', () => {
  assert.ok(noConfidenceScore(renderCensusBlock(CF_PRESENT)), 'no confidence/score in census render');
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} fact-render controls; null + unverified render safe, no confidence score.` : `FAIL — ${failures.length}/${ran}`}`);
process.exit(failures.length === 0 ? 0 : 1);
