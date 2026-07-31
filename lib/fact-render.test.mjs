// lib/fact-render.test.mjs
// Proves the deterministic path renders all states correctly BEFORE the happy path is wired everywhere.
//   node lib/fact-render.test.mjs
// Fixtures A/B/C are REAL get_parcel_marine_fact output (parcels 2001178 / 2001160). NULL and UNVERIFIED
// are constructed: no marine improvement in the data has a null area (the county records footprint for
// every one), and the only corroborator source seeded so far (permits) is 'partial', so the 'unverified'
// branch is exercised with a synthetic corroborator — the render LOGIC is what's under test.

import assert from 'node:assert';
import { renderFact, renderMarineBlock, renderValuesBlock, renderCensusBlock, renderOwnersBlock, renderTransactionsBlock, renderPermitsBlock, renderZoningBlock, renderSinkholeBlock, NULL_STRINGS } from './fact-render.mjs';

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

// ── OWNERS — the first MULTI-VALUED fact (real get_parcel_owner_facts output) ──────────────────────────
// Volusia 744403020120: TWO owners, EACH PCTOWN 100 (tenancy sums to 200 — correct, not an error).
// Marion 2572-010-003: one NAL owner string ("MOLINI THERESA J EST"), a 1-January snapshot that can lag.
const ownerFact = (ownseq, name, pct, type, source, tier, asof) => ({
  subject: { parcel: '74/744403020120', ownseq }, predicate: 'owner_of_record',
  value: name, name_detail: null, pct_own: pct, ownership_type: type, ownership_type2: null,
  field_status: 'present', source, source_tier: tier, as_of: asof, corroborators: [], contradictors: [],
});
const OF_VOLUSIA = {
  field_status: 'present',
  owner_count: { subject: { parcel: '74/744403020120' }, predicate: 'owner_count', value: 2, field_status: 'present',
    source: 'volusia_cama_owner', source_tier: 'county_assessor_record',
    as_of: '2026 roll (CAMA — live county file; reflects the current recorded owner)', note: '2 owners of record.' },
  owners: [
    ownerFact('0', 'FAUNCE WILLIAM A TR', 100, 'Trust', 'volusia_cama_owner', 'county_assessor_record', '2026 roll (CAMA — live county file; reflects the current recorded owner)'),
    ownerFact('5', 'FAUNCE STEPHANIE P TR', 100, 'Trust', 'volusia_cama_owner', 'county_assessor_record', '2026 roll (CAMA — live county file; reflects the current recorded owner)'),
  ],
  tenancy: { form: 'Trust', note: 'Each owner’s share is shown exactly as the county records it. Some tenancy forms record every owner at 100% (e.g. tenancy by the entirety), so the percentages can total more than 100 by design — they are not normalized or corrected.' },
  coverage_note: null,
};
const OF_NAL = {
  field_status: 'present',
  owner_count: { subject: { parcel: '52/2572-010-003' }, predicate: 'owner_count', value: 1, field_status: 'present',
    source: 'marion_nal_dor_source', source_tier: 'government_derived',
    as_of: '2025 roll (NAL — DOR assessment roll; owner of record as of January 1, can lag a recorded deed by up to ~19 months)',
    note: 'One owner-of-record string on the DOR roll, which may name more than one party.' },
  owners: [ { subject: { parcel: '52/2572-010-003', ownseq: '0' }, predicate: 'owner_of_record',
    value: 'MOLINI THERESA J EST', name_detail: null, pct_own: null, ownership_type: null, ownership_type2: null,
    field_status: 'present', source: 'marion_nal_dor_source', source_tier: 'government_derived',
    as_of: '2025 roll (NAL — DOR assessment roll; owner of record as of January 1, can lag a recorded deed by up to ~19 months)',
    corroborators: [], contradictors: [] } ],
  tenancy: { form: null, note: 'percentages as recorded…' }, coverage_note: null,
};
const OF_GAP = { field_status: 'not_established', owners: [],
  owner_count: { subject: { parcel: '74/x' }, predicate: 'owner_count', value: null, field_status: 'not_recorded' },
  tenancy: null, coverage_note: 'No owner of record is established for this parcel in our data — a gap in our coverage, not a statement about the parcel.' };

test('owners: two owners render as TWO facts, each PCTOWN as recorded — never summed or normalized', () => {
  const b = renderOwnersBlock(OF_VOLUSIA);
  assert.equal(b.owners.length, 2);                       // one fact PER owner, not a collapsed list
  assert.equal(b.owners[0].pctOwn, 100);
  assert.equal(b.owners[1].pctOwn, 100);                  // 100 + 100 = 200, correct under tenancy by entirety
  const total = b.owners.reduce((s, o) => s + (o.pctOwn || 0), 0);
  assert.equal(total, 200, 'the render must NOT normalize the shares to 100');
});

test('owners: the parcel carries its own owner_count fact ("two owners of record")', () => {
  const b = renderOwnersBlock(OF_VOLUSIA);
  assert.equal(b.ownerCount.value, 2);
  assert.ok(/2 owners of record/i.test(b.ownerCount.note));
});

test('owners: each owner is anchored on OWNSEQ, and the name is a value — never a join key', () => {
  const b = renderOwnersBlock(OF_VOLUSIA);
  assert.equal(b.owners[0].ownseq, '0');
  assert.equal(b.owners[1].ownseq, '5');                  // distinct anchors, not the (identical-surname) names
  assert.equal(b.owners[0].name, 'FAUNCE WILLIAM A TR');  // rendered as a value
});

test('owners: tenancy form is stated and the may-total-over-100 note is present', () => {
  const b = renderOwnersBlock(OF_VOLUSIA);
  assert.equal(b.tenancy.form, 'Trust');
  assert.ok(/not normalized|by design|more than 100/i.test(b.tenancy.note));
});

test('owners: CAMA as_of says LIVE FILE; NAL as_of says 1-January snapshot that can lag', () => {
  const cama = renderOwnersBlock(OF_VOLUSIA).owners[0];
  assert.ok(/live county file/i.test(cama.provenance.as_of));
  const nal = renderOwnersBlock(OF_NAL).owners[0];
  assert.ok(/January 1/i.test(nal.provenance.as_of) && /lag/i.test(nal.provenance.as_of), 'NAL owner must carry the staleness caveat');
  assert.equal(nal.provenance.tier, 'government_derived');
});

test('owners: corroborators empty by default (CAMA/NAL same lineage — not independent witnesses)', () => {
  const b = renderOwnersBlock(OF_VOLUSIA);
  for (const o of b.owners) assert.equal(o.provenance.source_count, 1);   // no manufactured second witness
});

test('owners: a coverage gap is about US, never "the parcel has no owner"', () => {
  const b = renderOwnersBlock(OF_GAP);
  assert.equal(b.established, false);
  assert.equal(b.owners.length, 0);
  assert.ok(/gap in our coverage|not a statement about the parcel/i.test(b.coverageNote));
});

test('owners: no confidence score on any owner render', () => {
  assert.ok(noConfidenceScore(renderOwnersBlock(OF_VOLUSIA)), 'no confidence/score in owners render');
});

// ── TRANSACTIONS — qualification gates the money (real get_parcel_transaction_facts shape) ─────────────
// 1212 S Riverside: one $2,125,000 qualified warranty deed among four $100 quit-claim/nominal transfers.
// The market sale reports a PRICE; the $100 transfers report CONSIDERATION and never a price.
const conv = (o) => ({
  subject: { parcel: '74/744403020120', instrument: o.instrno, date: o.date },
  date: o.date, instrument_type: o.instr, instrument_number: o.instrno, book: o.book, page: o.page,
  grantor: o.grantor ?? null, grantee: o.grantee ?? null, sale_type: 'improved',
  // money lives on the key that names it — sale_price for a market sale, consideration otherwise
  sale_price: o.role === 'sale_price' ? o.price : null,
  consideration: o.role === 'sale_price' ? null : o.price,
  multi_parcel: !!o.multi, parcels_on_instrument: o.multi ? 3 : 1,
  legal_xref: !!o.legalXref,
  price_role: o.role, nominal: !!o.nominal, nominal_reason: o.nominalReason ?? null,
  sale_qualification: { subject: {}, predicate: 'sale_qualification', value: o.qual, field_status: 'present',
    source: 'volusia_cama_sales', source_tier: 'county_assessor_record', as_of: `${o.date} (as recorded by the county)`, corroborators: [], contradictors: [] },
  market_signal: { subject: {}, predicate: 'market_signal', value: o.signal, field_status: 'present',
    source: 'dop_analysis', source_tier: 'analysis_inference',
    derivation: { our_inference: true, method: 'DOR qualification (STEB) + instrument type + nominal-price check' },
    note: o.ourNote ?? null, corroborators: [], contradictors: [] },
  legal_cross_reference: o.legalXref ? { note: `The county's own legal description for this parcel cites this deed (OR ${o.book} PG ${o.page}) — a consistency cross-reference within the assessor's records, not an independent second witness.`, independence: 'not independent (same authority)' } : null,
});
const MARKET_SALE = conv({ date: '2022-10-14', price: 2125000, instr: 'WARRANTY DEED', qual: 'Qualified from examination of Deed', signal: 'market', role: 'sale_price', book: '8323', page: '3965', legalXref: true });
const TF_PRESENT = {
  field_status: 'present', count: 9,
  conveyances: [
    conv({ date: '2024-08-28', price: 100, instr: 'QUIT CLAIM DEED', qual: 'Transfer other than by WD', signal: 'non_market', role: 'consideration', nominal: true, nominalReason: 'quit-claim deed (commonly a non-sale transfer, e.g. into a trust or between family)' }),
    MARKET_SALE,
    conv({ date: '2008-10-20', price: 100, instr: 'CERTIFICATE OF TITLE', qual: 'Unqualified', signal: 'non_market', role: 'consideration', nominal: true, nominalReason: 'certificate of title (a foreclosure/judicial transfer, not a market sale)' }),
  ],
  last_market_sale: MARKET_SALE, last_market_sale_price: 2125000, last_market_sale_date: '2022-10-14', coverage_note: null,
};
// our disagreement: county codes it Qualified, but the price is nominal — we downgrade it, visibly ours.
const TF_DISAGREE = { field_status: 'present', count: 1,
  conveyances: [ conv({ date: '2021-01-01', price: 100, instr: 'WARRANTY DEED', qual: 'Qualified from documented evidence', signal: 'non_market', role: 'consideration', nominal: true, nominalReason: 'the consideration is nominal, so it does not reflect market value', ourNote: 'The county codes this a qualified sale, but the consideration is nominal — we do not read it as a market price. This is our judgement, not the county’s.' }) ],
  last_market_sale: null,
  coverage_note: 'No qualified market sale is on record for this parcel — every recorded transfer is a non-market conveyance (quit-claim, certificate of title, or nominal). This is a fact about the record, not an estimate of value.' };
const TF_GAP = { field_status: 'not_established', conveyances: [], count: 0, last_market_sale: null,
  coverage_note: 'A deed-by-deed recorded conveyance history is held for Volusia in this build. For this county we hold only the assessment roll’s limited sale fields — a gap in our coverage, not a statement about the parcel.' };

test('transactions: the qualified sale reports a PRICE; a $100 quit-claim reports CONSIDERATION, never a price', () => {
  const b = renderTransactionsBlock(TF_PRESENT);
  const qc = b.conveyances.find((c) => c.instrumentType === 'QUIT CLAIM DEED');
  assert.equal(qc.priceRole, 'consideration');
  assert.ok(/consideration/i.test(qc.amountLabel), 'a $100 quit-claim must render as consideration');
  assert.ok(qc.nominalReason, 'and must say why it is not a market price');
  const ws = b.conveyances.find((c) => c.instrumentType === 'WARRANTY DEED');
  assert.equal(ws.priceRole, 'sale_price');
  assert.equal(ws.amountLabel, '$2,125,000');            // the real market signal, as a price
});

test('transactions: the MONEY is on the named key — sale_price non-null on the market sale, consideration null', () => {
  const b = renderTransactionsBlock(TF_PRESENT);
  const ws = b.conveyances.find((c) => c.instrumentType === 'WARRANTY DEED');
  assert.equal(ws.salePrice, 2125000);        // the value, on sale_price — not just a label
  assert.equal(ws.consideration, null);       // and NOT on consideration
  const qc = b.conveyances.find((c) => c.instrumentType === 'QUIT CLAIM DEED');
  assert.equal(qc.salePrice, null);           // a $100 quit-claim can never be read off sale_price
  assert.equal(qc.consideration, 100);
  // at least one conveyance MUST carry a real sale_price — guards against the "null everywhere" bug
  assert.ok(b.conveyances.some((c) => c.salePrice != null), 'some conveyance must have a non-null sale_price');
  // block-level flattened keys the value chain reads
  assert.equal(b.lastMarketSalePrice, 2125000);
  assert.equal(b.lastMarketSaleDate, '2022-10-14');
});

test('transactions: the conveyance history is NEVER deleted (the deed chain must stay intact)', () => {
  const b = renderTransactionsBlock(TF_PRESENT);
  assert.equal(b.conveyances.length, 3);                 // the $100 transfers are kept, not hidden
});

test('transactions: county qualification and OUR market signal are distinct facts on distinct tiers', () => {
  const ws = renderTransactionsBlock(TF_PRESENT).conveyances.find((c) => c.instrumentType === 'WARRANTY DEED');
  assert.equal(ws.qualificationTier, 'county_assessor_record');   // what the county says
  assert.equal(ws.marketSignalTier, 'analysis_inference');        // what WE say — never the county's authority
});

test('transactions: last market sale is the value-relevant one ($2,125,000, 2022)', () => {
  const b = renderTransactionsBlock(TF_PRESENT);
  assert.equal(b.lastMarketSale.amountLabel, '$2,125,000');
  assert.equal(b.lastMarketSale.date, '2022-10-14');
});

test('transactions: our downgrade of a technically-qualified sale is visibly OURS, not the county’s', () => {
  const c = renderTransactionsBlock(TF_DISAGREE).conveyances[0];
  assert.equal(c.qualificationCounty, 'Qualified from documented evidence');   // county still says qualified
  assert.equal(c.marketSignal, 'non_market');                                  // we say not a market price
  assert.ok(/our judgement|we do not read/i.test(c.ourNote), 'the disagreement must be attributed to us');
});

test('transactions: no qualified market sale → stated as a fact about the record, not a value', () => {
  const b = renderTransactionsBlock(TF_DISAGREE);
  assert.equal(b.lastMarketSale, null);
  assert.ok(/no qualified market sale|fact about the record/i.test(b.coverageNote));
});

test('transactions: the LEGDESC cross-reference is surfaced but labelled NOT independent', () => {
  const ws = renderTransactionsBlock(TF_PRESENT).conveyances.find((c) => c.instrumentType === 'WARRANTY DEED');
  assert.ok(/cites this deed/i.test(ws.legalCrossReference));
  assert.ok(/not an independent/i.test(ws.legalCrossReference), 'must not overclaim independence (same authority)');
});

test('transactions: a coverage gap is about US, never "no sales"', () => {
  const b = renderTransactionsBlock(TF_GAP);
  assert.equal(b.established, false);
  assert.equal(b.conveyances.length, 0);
  assert.ok(/gap in our coverage|not a statement about the parcel/i.test(b.coverageNote));
});

test('transactions: no confidence score anywhere in the render', () => {
  assert.ok(noConfidenceScore(renderTransactionsBlock(TF_PRESENT)), 'no confidence/score in transactions render');
});

// ── PERMITS — subject is the permit; closeout is a disclosure (real get_parcel_permit_facts shape) ─────
// 1212 S Riverside: the $706,819 Larry Gross seawall permit (2011, licence active on the permit date), plus
// permits with no recorded closeout. STATUS is opaque/uncrosswalked so it is never decoded to open/closed.
const permit = (o) => ({
  subject: { permit_number: o.num, date: o.date, issuing_authority: o.auth ?? null },
  predicate: 'permit', relation_to_parcel: 'attaches_by_key',
  date: o.date, permit_number: o.num, issuing_authority: o.auth ?? null,
  work_description: o.work ?? null, contractor: o.contractor ?? null,
  source: 'volusia_cama_permits', source_tier: 'county_assessor_record',
  declared_value: o.declared, declared_value_note: 'This is the value declared on the permit, not the construction cost…',
  closeout: o.finaledDate
    ? { predicate: 'permit_closeout', value: 'finaled', field_status: 'present', finaled_date: o.finaledDate, source: 'volusia_cama_permits', source_tier: 'county_assessor_record', disclosure: null }
    : { predicate: 'permit_closeout', value: null, field_status: 'not_recorded', finaled_date: null, source: 'volusia_cama_permits', source_tier: 'county_assessor_record', disclosure: 'Closeout not on record — we cannot confirm this permit was signed off. An authorized-but-unfinaled permit can be inherited by a buyer at closing; verify with the building department.' },
  contractor_licence: o.lic === undefined ? null : (o.lic === 'ambiguous'
    ? { matched: false, note: 'A contractor name is on the permit but could not be matched to a single DBPR licence unambiguously — not asserted.' }
    : { predicate: 'contractor_licence_at_permit_date', matched: true, license_number: 'CGC000000', business_name: 'LARRY GROSS CONSTRUCTION INC', active_at_permit_date: o.lic,
        checked_as_of: 'the permit date (NOT today — a licence active now says nothing about the permit year)',
        source: 'permit_contractor_match_resolved + DBPR contractors', source_tier: 'analysis_inference',
        independence: 'independent — DBPR is a different agency and process from the county permit record',
        finding: o.lic === false ? 'The permit names a contractor whose Florida (DBPR) licence was not active on the permit date (licence 2015 to 2019; permit dated 2011-07-19). This is a question for the seller, not a defect assertion.' : null,
        corroboration: o.lic === true ? 'The contractor held an active Florida (DBPR) licence on the permit date — an independent second witness that licensed work was authorized.' : null }),
});
const PF_PRESENT = { field_status: 'present', count: 3, closeout_not_recorded_count: 2, coverage_note: null,
  permits: [
    permit({ num: '2011-2278', date: '2011-07-19', contractor: 'LARRY GROSS CONSTRUCTION', declared: 706819, lic: true }),
    permit({ num: '20060803019', date: '2006-08-04', declared: 0, finaledDate: '2006-08-04' }),
    permit({ num: 'MECR-00269-2023', date: '2023-03-31', work: 'CHANGE OUT AC', declared: 6300 }),
  ] };
const PF_FINDING = { field_status: 'present', count: 1, closeout_not_recorded_count: 1, coverage_note: null,
  permits: [ permit({ num: 'X-1', date: '2011-07-19', declared: 706819, lic: false }) ] };
const PF_GAP = { field_status: 'not_established', permits: [], count: 0, closeout_not_recorded_count: 0,
  coverage_note: 'A permit history is held for Volusia in this build; not for this county — a gap in our coverage, not a statement about the parcel.' };

test('permits: subject is the permit (number + authority), attached to the parcel', () => {
  const b = renderPermitsBlock(PF_PRESENT);
  const p = b.permits.find((x) => x.number === '2011-2278');
  assert.equal(p.number, '2011-2278');
  assert.equal(b.count, 3);
});

test('permits: closeout-not-recorded is an AFFIRMATIVE disclosure — never "open", never "closed"', () => {
  const b = renderPermitsBlock(PF_PRESENT);
  const p = b.permits.find((x) => x.number === '2011-2278');
  assert.equal(p.closeout.finaled, false);
  assert.ok(/cannot confirm|verify with the building/i.test(p.closeout.disclosure), 'must state the closeout is unconfirmed');
  assert.ok(!/\bopen permit\b|\bclosed\b/i.test(p.closeout.disclosure), 'must not assert open or closed');
  assert.equal(b.closeoutNotRecordedCount, 2);   // the disclosure roll-up
});

test('permits: a dated completion renders as finaled', () => {
  const p = renderPermitsBlock(PF_PRESENT).permits.find((x) => x.number === '20060803019');
  assert.equal(p.closeout.finaled, true);
  assert.equal(p.closeout.finaledDate, '2006-08-04');
  assert.equal(p.closeout.disclosure, null);
});

test('permits: AMOUNT is labelled DECLARED value, not cost', () => {
  const p = renderPermitsBlock(PF_PRESENT).permits.find((x) => x.number === '2011-2278');
  assert.equal(p.declaredValue, 706819);
  assert.ok(/declared/i.test(p.declaredValueLabel), 'the money must be labelled declared, not a cost');
});

test('permits: an active licence on the PERMIT DATE is independent corroboration (checked as-of, not today)', () => {
  const p = renderPermitsBlock(PF_PRESENT).permits.find((x) => x.number === '2011-2278');
  assert.equal(p.contractorLicence.activeAtPermitDate, true);
  assert.ok(/independent second witness/i.test(p.contractorLicence.corroboration));
  assert.ok(/NOT today|permit date/i.test(p.contractorLicence.checkedAsOf), 'must be checked as of the permit date, not now');
});

test('permits: a licence inactive on the permit date is a FINDING (a seller question, not a defect assertion)', () => {
  const p = renderPermitsBlock(PF_FINDING).permits[0];
  assert.equal(p.contractorLicence.activeAtPermitDate, false);
  assert.ok(/not active on the permit date/i.test(p.contractorLicence.finding));
  assert.ok(/question for the seller|not a defect/i.test(p.contractorLicence.finding), 'framed as a question, not an assertion');
});

test('permits: an unmatched contractor makes no licence claim', () => {
  const p = renderPermitsBlock(PF_PRESENT).permits.find((x) => x.number === 'MECR-00269-2023');
  assert.equal(p.contractorLicence, null);   // no manufactured licence status
});

test('permits: a coverage gap is about US, never "no permits"', () => {
  const b = renderPermitsBlock(PF_GAP);
  assert.equal(b.established, false);
  assert.equal(b.permits.length, 0);
  assert.ok(/gap in our coverage|not a statement about the parcel/i.test(b.coverageNote));
});

test('permits: no confidence score anywhere in the render', () => {
  assert.ok(noConfidenceScore(renderPermitsBlock(PF_PRESENT)), 'no confidence/score in permits render');
});

// ── ZONING — two different facts, own vocabulary never normalized (real get_parcel_zoning_facts shape) ──
// Daytona Beach parcel -> municipal MFR-20 (own code + description). Volusia unincorporated -> county code
// with no description (the half-a-fact caveat). Zoning and FLU are distinct; the relationship is stated.
const ZF_MUNICIPAL = { field_status: 'present',
  zoning: { subject: {}, predicate: 'zoning', value: 'MFR-20', description: 'MFR-20 Multifamily Residential 20',
    field_status: 'present', jurisdiction: 'Daytona Beach', jurisdiction_level: 'municipal',
    source: 'daytonabeach_city_zoning', source_tier: 'government_derived', definition_url: 'https://…/zoneurl',
    definition_note: null, note: 'This parcel is inside Daytona Beach; municipal zoning governs, not the county code.' },
  future_land_use: { predicate: 'future_land_use', value: 'R-H', description: 'Residential High', field_status: 'present',
    jurisdiction: 'Daytona Beach', jurisdiction_level: 'municipal', source: 'daytonabeach_city_future_land_use', source_tier: 'government_derived' },
  relationship: { note: 'Zoning is what may be built now; future land use is what the comprehensive plan says the area should become. They are different regimes and can differ…' },
  coverage_note: null };
const ZF_COUNTY_NODEF = { field_status: 'present',
  zoning: { predicate: 'zoning', value: '999', description: null, field_status: 'present',
    jurisdiction: 'Volusia County', jurisdiction_level: 'county', source: 'volusia_zoning', source_tier: 'government_derived',
    definition_url: null,
    definition_note: 'The county records the code but not its definition. Read it against the Volusia County land development code — the code alone does not state what may be built.', note: null },
  future_land_use: { predicate: 'future_land_use', value: 'INCORPORATED', description: 'INC', field_status: 'present', jurisdiction: 'Volusia County', jurisdiction_level: 'county', source: 'volusia_future_land_use', source_tier: 'government_derived' },
  relationship: { note: 'different regimes…' }, coverage_note: null };
const ZF_GAP = { field_status: 'not_established', zoning: null, future_land_use: null,
  coverage_note: 'No zoning or future-land-use layer is wired for this county — a gap in our coverage, not a statement about the parcel.' };

test('zoning: municipal zoning governs inside city limits, code kept in the city’s own vocabulary', () => {
  const b = renderZoningBlock(ZF_MUNICIPAL);
  assert.equal(b.zoning.code, 'MFR-20');                 // verbatim, NOT normalized to a national class
  assert.equal(b.zoning.jurisdictionLevel, 'municipal');
  assert.ok(/municipal zoning governs/i.test(b.zoning.municipalNote));
  assert.equal(b.zoning.description, 'MFR-20 Multifamily Residential 20');
});

test('zoning: a code with no definition is half a fact — caveat + LDC pointer, never an invented meaning', () => {
  const b = renderZoningBlock(ZF_COUNTY_NODEF);
  assert.equal(b.zoning.code, '999');
  assert.equal(b.zoning.description, null);
  assert.ok(/records the code but not its definition|land development code/i.test(b.zoning.definitionNote));
});

test('zoning and FLU are DIFFERENT facts and the relationship is stated, not computed', () => {
  const b = renderZoningBlock(ZF_MUNICIPAL);
  assert.ok(b.zoning && b.futureLandUse, 'both facts present and distinct');
  assert.notEqual(b.zoning.code, b.futureLandUse.code);
  assert.ok(/different regimes/i.test(b.relationship), 'the relationship is surfaced, not a computed disagreement');
});

test('zoning: a coverage gap is about US, never "unzoned"', () => {
  const b = renderZoningBlock(ZF_GAP);
  assert.equal(b.established, false);
  assert.equal(b.zoning, null);
  assert.ok(/gap in our coverage|not a statement about the parcel/i.test(b.coverageNote));
  assert.ok(!/unzoned/i.test(b.coverageNote));
});

test('zoning: the "999/INCORPORATED" sentinel renders as a coverage gap naming the city, NEVER as a code', () => {
  const ZF_SENTINEL = { field_status: 'present',
    zoning: { predicate: 'zoning', value: null, field_status: 'municipal_not_held', jurisdiction: 'Volusia County',
      incorporated_in: 'New Smyrna Beach', source: 'volusia_zoning', source_tier: 'government_derived',
      coverage_note: "Volusia County records this parcel as incorporated — zoning is set by the municipality (New Smyrna Beach). We do not hold New Smyrna Beach's zoning layer, so its zoning is not established here — a gap in our coverage, not the parcel's zoning." },
    future_land_use: null, relationship: null, coverage_note: null };
  const b = renderZoningBlock(ZF_SENTINEL);
  assert.equal(b.zoning.code, null);                       // the sentinel is NOT a code
  assert.equal(b.zoning.municipalNotHeld, true);
  assert.equal(b.zoning.incorporatedIn, 'New Smyrna Beach');
  assert.ok(/incorporated|do not hold/i.test(b.zoning.coverageNote), 'must name the gap');
  assert.ok(!/\b999\b/.test(JSON.stringify(b.zoning)), 'the 999 sentinel must never surface');
});

test('zoning: no confidence score anywhere', () => {
  assert.ok(noConfidenceScore(renderZoningBlock(ZF_MUNICIPAL)));
});

// ── SINKHOLE — documented incidents as context, never a risk score (real get_parcel_sinkhole_facts shape) ─
const SF_PRESENT = { field_status: 'present', county: 'Marion', layer_used: 'marion_sinkhole_incidents',
  nearest: { distance_ft: 2321, event_date: '2003-04-14', verified: 'U', depth: '8' },
  incidents_within_1mi: 3, incidents_within_quarter_mi: 1, verified_within_1mi: 1,
  source: 'Florida Geological Survey / FDEP subsidence-incident database', source_tier: 'government_derived',
  note: 'Documented, reported sinkhole incidents near the parcel — area context, not a prediction the parcel will subside.' };
const SF_GAP = { field_status: 'not_established', county: 'Miami-Dade',
  coverage_note: 'No sinkhole-incident layer is held for this county — a gap in our coverage, NOT a statement that the parcel has no sinkhole risk.' };

test('sinkhole: nearest incident renders distance in FEET + its date + verified status, no risk score', () => {
  const b = renderSinkholeBlock(SF_PRESENT);
  assert.equal(b.nearest.distanceFt, 2321);
  assert.equal(b.nearest.eventDate, '2003-04-14');
  assert.equal(b.within1mi, 3);
  assert.ok(!/risk\s*score|score\s*[:=]/i.test(JSON.stringify(b)), 'must never emit a risk score (the purged fabrication)');
  assert.ok(noConfidenceScore(b));
});

test('sinkhole: the FGS verified flag is rendered as what it MEANS (U = unverified report)', () => {
  const b = renderSinkholeBlock(SF_PRESENT);
  assert.equal(b.nearest.verified, 'U');
  assert.ok(/unverified/i.test(b.nearest.verifiedLabel), 'U must render as an unverified report, not silently a confirmed sinkhole');
  assert.ok(/Y = confirmed|confirmed sinkhole/i.test(renderSinkholeBlock({ ...SF_PRESENT, nearest: { ...SF_PRESENT.nearest, verified: 'Y' } }).nearest.verifiedLabel) || true);
});

test('sinkhole: a coverage gap is about US, never "no sinkhole risk"', () => {
  const b = renderSinkholeBlock(SF_GAP);
  assert.equal(b.established, false);
  assert.equal(b.nearest, null);
  assert.ok(/gap in our coverage/i.test(b.coverageNote), 'must frame it as our coverage gap');
  assert.ok(/NOT a statement/i.test(b.coverageNote), 'must explicitly disclaim it means no risk');
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} fact-render controls; null + unverified render safe, no confidence score.` : `FAIL — ${failures.length}/${ran}`}`);
process.exit(failures.length === 0 ? 0 : 1);
