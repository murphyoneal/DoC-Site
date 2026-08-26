// lib/report-coverage.test.mjs
// Render smoke test for the coverage-aware report blocks — the check that would have caught the
// unseen marine states (and the fabricated wind dial's shape). Plain node, no site/keys/env:
//   node lib/report-coverage.test.mjs
// Fixtures mirror the live get_parcel_marine_improvements / get_parcel_tax_deed_status shapes.

import assert from 'node:assert';
import { marineView, taxDeedView, floodView, disclosuresView, hasForbiddenCoverageGapPhrase,
  selectLead, isOnParcelContamination, findDistanceKeys } from './report-coverage.mjs';
import { renderMarineBlock, renderFloodBlock, renderContaminationFacilities, renderOwnersBlock } from './fact-render.mjs';

let ran = 0; const failures = [];
function test(name, fn) { ran++; try { fn(); console.log(`  ok   ${name}`); }
  catch (e) { failures.push(name); console.log(`  FAIL ${name} — ${e.message}`); } }

const text = (v) => [v.note, v.body].filter(Boolean).join(' ');
// Full rendered text incl. every disclosure item — what a reader on that county's page would actually see.
const renderText = (v) => [v.note, v.body, ...(v.items || []).map((i) => i.text || '')].filter(Boolean).join(' ');
// Volusia-specific figures that must NEVER appear on another county's report (the cross-county leak).
const VOLUSIA_ONLY_FIGURES = ['8.8%', '27,618'];

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

const floodPresent = { field_status: 'present', in_sfha: true, base_flood_elevation_ft: 11, vertical_datum: 'NAVD88',
  layer_used: 'pinellas_flood_zones',
  zones: [{ zone: 'AE', in_sfha: true, pct_of_parcel: 22, base_flood_elevation_ft: 10 }, { zone: 'X', in_sfha: false, pct_of_parcel: 60.6 }] };
// DB caveat deliberately contains "outside a Special Flood Hazard Area" — floodView must NOT echo it.
const floodNotAvail = { field_status: 'not_available', in_sfha: null,
  coverage_caveat: 'COVERAGE GAP … NOT a statement that the parcel is outside a Special Flood Hazard Area.' };
const floodNoneIntersect = { field_status: 'none_intersecting', zones: [], in_sfha: null };

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

test('flood not_available → coverage gap, never "no flood zone"/"outside the SFHA"', () => {
  const v = floodView(floodNotAvail);
  assert.equal(v.mode, 'coverage_gap');
  assert.ok(/coverage gap/i.test(text(v)), 'must state it is a coverage gap');
  assert.ok(!hasForbiddenCoverageGapPhrase(text(v)),
    `flood coverage-gap leaked a finding phrase (incl. the echoed DB caveat): "${text(v)}"`);
});

test('flood present carries the SFHA determination + BFE (the incident answer)', () => {
  const v = floodView(floodPresent);
  assert.equal(v.mode, 'present');
  assert.equal(v.inSfha, true);
  assert.equal(v.bfe, 11);
  assert.equal(v.zones.length, 2);
});

test('flood coverage_gap and none_intersecting are DISTINCT modes', () => {
  assert.equal(floodView(floodNotAvail).mode, 'coverage_gap');
  assert.equal(floodView(floodNoneIntersect).mode, 'none_intersecting');
  assert.notEqual(floodView(floodNotAvail).mode, floodView(floodNoneIntersect).mode);
});

// ── Disclosures (source/disclose) — the get_pir_report `disclosures` array, per county ───────────
const disclosuresVolusia = [{ defect_id: 'DEF-019', kind: 'source_limit',
  disclosure: "The county property appraiser assesses more parcels than it publishes geometry for - roughly 8.8% here - so no map-based statement can be made about those parcels. This is a limit of the county's published data, not of the search." }];
const disclosuresStJohnsFragment = [{ defect_id: 'DEF-003', kind: 'source_limit',
  disclosure: 'This parcel is published as multiple geometry fragments that together form the whole. Area is aggregated across fragments; reading a single fragment would understate it.' }];
const disclosuresOrangeNone = [];

test('disclosures Volusia → source_limit finding carrying the 8.8% figure', () => {
  const v = disclosuresView(disclosuresVolusia);
  assert.equal(v.mode, 'source_limit');
  assert.equal(v.items.length, 1);
  assert.equal(v.items[0].defect_id, 'DEF-019');
  assert.ok(renderText(v).includes('8.8%'), 'Volusia disclosure must state the figure');
});

test('disclosures are a source_limit, NOT a coverage_gap (the load-bearing distinction)', () => {
  assert.equal(disclosuresView(disclosuresVolusia).mode, 'source_limit');
  assert.notEqual(disclosuresView(disclosuresVolusia).mode, marineView(marineNotAvail).mode); // never coverage_gap
});

test('LEAK GUARD — St Johns shows the fragment disclosure and NOT Volusia figures', () => {
  const v = disclosuresView(disclosuresStJohnsFragment);
  assert.equal(v.mode, 'source_limit');
  assert.ok(renderText(v).includes('fragments'), 'must show the fragment disclosure');
  for (const leaked of VOLUSIA_ONLY_FIGURES)
    assert.ok(!renderText(v).includes(leaked), `Volusia figure leaked into a St Johns report: "${leaked}"`);
});

test('LEAK GUARD — Orange (no disclosures) renders nothing and no Volusia figure', () => {
  const v = disclosuresView(disclosuresOrangeNone);
  assert.equal(v.mode, 'none');
  assert.equal(v.items.length, 0);
  for (const leaked of VOLUSIA_ONLY_FIGURES)
    assert.ok(!renderText(v).includes(leaked), `Orange fixture leaked "${leaked}"`);
});

// The envelope path (get_parcel_disclosures_facts -> r.disclosuresFacts). The array path above
// is untouched. What these assert is that THE TWO SILENCES ARE DIFFERENT: an empty section is
// honest when we searched and nothing applied, and a false clearance when we never looked.
test('disclosures envelope: none_recorded stays silent — searched, nothing applies, no claim made', () => {
  const v = disclosuresView({ field_status: 'none_recorded', disclosures: [], active_disclosures_held: 174 });
  assert.equal(v.mode, 'none');
  assert.equal(v.items.length, 0);
});
test('disclosures envelope: not_available SAYS SO — silence there would imply the source has no limits', () => {
  const v = disclosuresView({
    field_status: 'not_available', disclosures: [],
    coverage_caveat: 'We could not consult our record of source limitations for this parcel.',
  });
  assert.equal(v.mode, 'not_available');
  assert.equal(v.items.length, 0);
  assert.ok(v.note, 'not_available must carry a note - an empty section is the defect');
  assert.notEqual(v.mode, 'none', 'not_available must never collapse into the silent mode');
});
test('disclosures envelope: items render identically whether wrapped or bare', () => {
  const bare = disclosuresView(disclosuresVolusia);
  const wrapped = disclosuresView({ field_status: 'present', disclosures: disclosuresVolusia });
  assert.equal(wrapped.mode, 'source_limit');
  assert.deepEqual(wrapped.items, bare.items);
});

// ── Marine block (fact index) — the moat, and it must not manufacture or leak ────
const marineBlockNoPermits = { field_status: 'present',
  open_questions: { count: 3, total_improvements: 4, headline: '3 of 4 marine improvements have no county building permit in the year the assessor records them built', items: [{ question: 'Assessed dock, boat built 2009, but no county building permit within a year corroborates it.' }] },
  improvements: [{ improvement: 'dock, boat', built: 2009, facts: { built_year: { predicate: 'built_year', value: 2009, field_status: 'present', source: 'volusia_cama_misc.YRBLT', source_tier: 'county_assessor_record', subject: { improvement: 'dock, boat' }, corroborators: [], contradictors: [], open_questions: [{ question: 'no permit' }] } } }],
  material_disclosure: null };
const marineBlockCorroborated = { field_status: 'present',
  open_questions: { count: 0, total_improvements: 1, headline: null, items: [] },
  improvements: [{ improvement: 'sea wall (bulkheads)', built: 2010, facts: { built_year: { predicate: 'built_year', value: 2010, field_status: 'present', source: 'volusia_cama_misc.YRBLT', source_tier: 'county_assessor_record', subject: { improvement: 'sea wall (bulkheads)' }, corroborators: [{ value: 'permit', independence_status: 'partial', amount: 706819, work_matches: false }], contradictors: [], open_questions: [] } } }],
  material_disclosure: null };

test('marine: improvements with no permits render the cross-examination headline (the moat)', () => {
  const r = renderMarineBlock(marineBlockNoPermits);
  assert.ok(r.openQuestions.headline, 'must surface the block-level headline');
  assert.ok(r.openQuestions.count >= 1);
  assert.ok(r.improvements[0].openQuestions.length >= 1);
});

test('marine: a corroborated improvement does NOT manufacture an open question', () => {
  const r = renderMarineBlock(marineBlockCorroborated);
  assert.equal(r.openQuestions.count, 0);
  assert.equal(r.improvements[0].openQuestions.length, 0);
  // and its partial corroborator renders a specific gloss, never a bare "independent"
  const c = r.improvements[0].rendered.built_year.corroboration[0];
  assert.equal(c.independence, 'partially independent');
  assert.ok(/large permit/i.test(c.gloss) && /nothing identifies it/i.test(c.gloss), `gloss must be specific: "${c.gloss}"`);
});

test('marine coverage gap (non-Volusia) never reads as "no dock"', () => {
  // the page renders this copy for field_status='not_available'
  const pageCoverageGapCopy = 'Whether this parcel has waterfront structures (dock, seawall, lift, boat house) is not known here — its absence is not evidence either way.';
  assert.ok(!hasForbiddenCoverageGapPhrase(pageCoverageGapCopy), 'coverage-gap copy must not read as a finding');
});

// ── Flood block (fact index) — legal consequence, so the coverage gap must not substitute ────────
const floodBlockPresent = { field_status: 'present', vertical_datum: 'NAVD88',
  determination: { predicate: 'in_sfha', value: true, field_status: 'present', source: 'pinellas_flood_zones', source_tier: 'federal_regulatory',
    determination_note: 'In a Special Flood Hazard Area — flood insurance is federally required with a federally-backed mortgage.', corroborators: [], contradictors: [] },
  base_flood_elevation: { predicate: 'base_flood_elevation_ft', value: 11, field_status: 'present', source_tier: 'federal_regulatory', vertical_datum: 'NAVD88' },
  elevation_above_bfe: { field_status: 'not_computed', derivation: { note: 'Withheld, not omitted. The BFE datum is NAVD88 (known), but parcel_elevations carries NO recorded vertical datum — comparing them would require fabricating the parcel elevation datum.' } },
  zones: [{ zone: 'AE', in_sfha: true, pct_of_parcel: 22 }, { zone: 'X', in_sfha: false, pct_of_parcel: 60.6 }] };
const floodBlockGap = { field_status: 'not_available', vertical_datum: null,
  determination: { predicate: 'in_sfha', value: null, field_status: 'not_established', source: 'none', source_tier: 'federal_regulatory',
    determination_note: 'Not established — no county FEMA NFHL layer is held for this county here. This is a statement about OUR coverage, NOT about the parcel; it is not a finding that the parcel is outside a flood zone. Check the FEMA Map Service Center (msc.fema.gov).', corroborators: [], contradictors: [] },
  base_flood_elevation: { field_status: 'not_recorded' }, elevation_above_bfe: { field_status: 'not_computed', derivation: { note: 'x' } }, zones: [] };

test('flood present: the SFHA determination is the finding, federal_regulatory, no manufactured corroborator', () => {
  const r = renderFloodBlock(floodBlockPresent);
  assert.equal(r.determination.established, true);
  assert.equal(r.determination.inSfha, true);
  assert.equal(r.determination.tier, 'federal_regulatory');
  assert.equal(r.determination.corroboration.length, 0);         // singular authority — none exists or may
  assert.equal(r.bfe.datum, 'NAVD88');                            // the one provenance we actually hold
  assert.ok(r.elevationComparison.withheld && /no recorded vertical datum/i.test(r.elevationComparison.reason),
    'elevation-vs-BFE must be withheld with the datum-asymmetry reason visible');
});

test('flood coverage gap: "not established" about OUR data, NEVER "not in a flood zone" (the St Pete failure)', () => {
  const r = renderFloodBlock(floodBlockGap);
  assert.equal(r.determination.established, false);
  assert.equal(r.determination.inSfha, null);
  assert.ok(/not established/i.test(r.determination.label));
  assert.ok(!hasForbiddenCoverageGapPhrase(r.determination.label + ' ' + (r.determination.headline || '')),
    `flood coverage gap leaked a finding phrase: "${r.determination.label} — ${r.determination.headline}"`);
});

// RULING 251 — ZONE D. FEMA performed NO analysis: neither in nor out of the SFHA. This is a
// THIRD state, distinct from the coverage gap above: that one is a hole in OUR data, this is a
// hole in FEMA's. The deployed SFHA test was equality over the whole zone string, so D fell to
// "false" and rendered as a clearance on 110 polygons across six SERVED layers.
const floodBlockZoneD = { field_status: 'undetermined', vertical_datum: null,
  determination: { predicate: 'in_sfha', value: null, field_status: 'undetermined',
    source: 'hardee_flood_zones', source_tier: 'federal_regulatory',
    determination_note: 'ZONE D — UNDETERMINED RISK. The county FEMA layer IS held and WAS queried, and it places this parcel in Zone D: an area where FEMA has performed NO flood analysis. This is NOT a finding that the parcel is outside a Special Flood Hazard Area, and it is NOT a gap in our data. A lender may still require flood insurance. Verify at msc.fema.gov.',
    corroborators: [], contradictors: [] },
  base_flood_elevation: null, elevation_above_bfe: null,
  zones: [{ zone: 'D', in_sfha: null, pct_of_parcel: 100 }] };

test('flood ZONE D: undetermined is NOT a clearance and NOT our coverage gap (ruling 251)', () => {
  const r = renderFloodBlock(floodBlockZoneD);
  assert.equal(r.determination.undetermined, true, 'Zone D must set undetermined');
  assert.equal(r.determination.inSfha, null, 'undetermined must never collapse to false');
  assert.equal(r.determination.established, true,
    'Zone D is NOT a coverage gap — we hold the layer; FEMA did no analysis');
  assert.ok(!/not in a special flood hazard area/i.test(r.determination.label),
    `Zone D rendered as a clearance: "${r.determination.label}"`);
  assert.ok(/undetermined/i.test(r.determination.label), 'the label must say undetermined');
  // the zone row itself must not render like a cleared zone
  assert.equal(r.zones[0].in_sfha, null);
});

test('flood ZONE D: a truthy in_sfha test would render it identically to X — the regression guard', () => {
  const r = renderFloodBlock(floodBlockZoneD);
  const naive = r.zones.map(z => `${z.zone}${z.in_sfha ? ' · SFHA' : ''}`).join(' ');
  const honest = r.zones.map(z => `${z.zone}${z.in_sfha === true ? ' · SFHA' : z.in_sfha == null ? ' · undetermined, not a clearance' : ''}`).join(' ');
  assert.equal(naive, 'D', 'demonstrates the bug: truthy test strips the qualifier entirely');
  assert.ok(/undetermined/.test(honest), 'the shipped render must keep the qualifier');
});

// RULING 266 — shareCheck three states. A null must render as NOTHING; the 115,767 Volusia parcels
// that sum over 100 are tenancy-by-the-entirety recording each spouse at the full share BY DESIGN,
// and rendering those as FALSE would train every reader to ignore the six that matter.
const ownersTicOver = { field_status: 'present',
  owner_count: { value: 3, field_status: 'present', note: '3 owners of record.', source: 'volusia_cama_owner' },
  owners: [{ value: 'A', pct_own: 150, subject: {} }, { value: 'B', pct_own: 100, subject: {} }, { value: 'C', pct_own: 50, subject: {} }],
  tenancy: { form: 'Tenancy in Common', forms_recorded: 1, mixed: false, note: 'x' },
  share_check: { value: false, field_status: 'present', reason: 'over_allocated', note: 'TENANCY IN COMMON, AND THE RECORDED SHARES TOTAL 300.0% OF THE WHOLE INTEREST.' } };
const ownersEntirety = { field_status: 'present',
  owner_count: { value: 2, field_status: 'present', note: '2 owners of record.', source: 'volusia_cama_owner' },
  owners: [{ value: 'H', pct_own: 100, subject: {} }, { value: 'W', pct_own: 100, subject: {} }],
  tenancy: { form: 'Tenancy in the Entirety', forms_recorded: 1, mixed: false, note: 'x' },
  share_check: { value: null, field_status: 'not_computed', reason: 'not_applicable_tenancy', note: 'not fractions of a single whole' } };

test('owners: shareCheck FALSE surfaces as a finding, and every owner is named (ruling 266)', () => {
  const r = renderOwnersBlock(ownersTicOver);
  assert.equal(r.owners.length, 3, 'every owner named, however many');
  assert.equal(r.ownerCount.value, 3, 'owner_count is its own fact');
  assert.equal(r.shareCheck.failed, true);
  assert.equal(r.tenancy.form, 'Tenancy in Common', 'tenancy renders beside the owners always');
});

test('owners: tenancy by the entirety at 100 each is NOT a share failure — null renders nothing', () => {
  const r = renderOwnersBlock(ownersEntirety);
  assert.equal(r.shareCheck, null,
    'a not_applicable_tenancy null must produce NO shareCheck object — anything rendered is the Zone D bug');
  assert.equal(r.tenancy.form, 'Tenancy in the Entirety');
  assert.equal(r.owners.length, 2, 'both spouses named');
});

// RULING 267 — a named party at a ZERO share is NOT a 0% owner. Polk records the entirety pattern
// a THIRD way, 1.0 + 0.0, which SUMS TO 1 AND CONCEALS ITSELF: 15,455 parcels have every owner but
// one at zero. Rendering "0% as recorded" would tell a buyer that party's signature is not needed.
const ownersWithZeroShare = { field_status: 'present',
  owner_count: { value: 2, field_status: 'present', note: '2 owners of record.', source: 'polk_owners' },
  owners: [
    { value: 'MOSS NAN K REVOCABLE TRUST AGREEMENT', pct_own: 1.0, share_status: 'recorded', subject: {} },
    { value: 'HINKSON LISA C A', pct_own: 0, share_status: 'zero_recorded',
      share_note: 'THE COUNTY RECORDS THIS PARTY WITH NO PERCENTAGE INTEREST.', subject: {} }],
  tenancy: { form: null, forms_recorded: 1, mixed: false, note: 'x' },
  share_check: { value: null, field_status: 'not_computed', reason: 'tenancy_not_recorded', note: 'y' } };

test('owners: a ZERO share is never rendered as a percentage, and the party is still named (ruling 267)', () => {
  const r = renderOwnersBlock(ownersWithZeroShare);
  assert.equal(r.owners.length, 2, 'the zero-share party is STILL NAMED — suppressing the party would be worse');
  const zero = r.owners[1];
  assert.equal(zero.pctOwn, null, 'pctOwn must be suppressed so it cannot print "0% as recorded"');
  assert.equal(zero.shareStatus, 'zero_recorded');
  assert.ok(/no percentage interest/i.test(zero.shareNote), 'the caveat travels with the party');
  assert.equal(r.shareCheck, null, 'sum 1.0 here must NOT read as a verified allocation');
});

// ── Contamination (item 82) — the "12 tanks, not alarming" failure must not recur ────────────────
const contamBlock = { field_status: 'present', promoted: [
  { name: 'FORMER MAIN STREET 66 GAS STATION', source: 'clm_cleanup', on_parcel: false, distance_ft: 279, remediation_status: 'ACTIVE', facility_type: 'PETRO', cleanup_status: null, documents_url: 'http://dep/docs', watch_url: 'http://dep/watch' },
  { name: 'JOES AUTOMOTIVE CLINIC', source: 'stcm_tank', on_parcel: true, distance_ft: 0, remediation_status: null, facility_type: 'Retail Station', facility_status: 'CLOSED', cleanup_status: null, documents_url: 'http://dep/docs2', watch_url: null },
], area_context: { tank_facilities_within_500m: 12, cleanup_sites_within_500m: 1 } };

test('contamination: on-parcel + active facilities are NAMED, active ranked first, never a bare count', () => {
  const r = renderContaminationFacilities(contamBlock);
  assert.equal(r.facilities.length, 2);
  assert.equal(r.facilities[0].name, 'FORMER MAIN STREET 66 GAS STATION');  // ACTIVE ranked first (resolver order)
  assert.equal(r.areaContext.tanks, 12);                                     // the 12 stay area context
  const joes = r.facilities.find((f) => f.name === 'JOES AUTOMOTIVE CLINIC');
  assert.equal(joes.onParcel, true);
  assert.ok(joes.documentsUrl, 'DEP documents url must surface');
});

test('contamination: null cleanup_status is THE finding — a question, never blank or "no cleanup needed"', () => {
  const r = renderContaminationFacilities(contamBlock);
  const joes = r.facilities.find((f) => f.name === 'JOES AUTOMOTIVE CLINIC');
  assert.ok(/no cleanup status on record/i.test(joes.cleanup), 'null cleanup must render the finding');
  assert.ok(joes.cleanup.trim().length > 0 && !/no cleanup needed/i.test(joes.cleanup), 'never blank, never "no cleanup needed"');
});

// ── THE LEAD ranking (spec v5 §0.1 / ruling 74 C9) — order is by what a buyer must act on ─────────
test('lead: contamination is the lead and combines with GWCA, ceiling of two clauses', () => {
  const l = selectLead({ contamOn: true, gwca: true, inSfha: true, historic: true });
  assert.equal(l.none, false);
  assert.equal(l.clauses.length, 2);
  assert.ok(/contamination site/.test(l.clauses[0]), 'contamination leads');
  assert.ok(/groundwater-contamination/.test(l.clauses[1]), 'GWCA is the second, causally-linked clause');
  assert.ok(!/Flood/.test(l.regulatory), 'the 2-clause ceiling excludes SFHA here');
});
test('lead: SFHA wins when no contamination, and carries the zone', () => {
  const l = selectLead({ inSfha: true, sfhaZone: 'AE', historic: true, leadPaint: true, yearBuilt: 1930 });
  assert.ok(/Special Flood Hazard Area \(Zone AE\)/.test(l.regulatory), 'SFHA + zone leads');
  assert.equal(l.clauses[0].includes('Special Flood Hazard Area'), true);
});
test('lead: ranking — lead-paint outranks historic, historic never displaces it', () => {
  const l = selectLead({ leadPaint: true, yearBuilt: 1930, historic: true });
  assert.ok(/pre-1978/.test(l.clauses[0]), 'lead-paint duty comes before historic district');
});
test('lead: none present → none:true and empty regulatory (silence must not read as clearance)', () => {
  const l = selectLead({});
  assert.equal(l.none, true);
  assert.equal(l.regulatory, '');
});

// ── HARD RULE (spec v5 §0.1): no distance-bearing field may appear in a §1–§3 view model ──────────
test('findDistanceKeys catches proximity keys but never area (sqft is not a distance)', () => {
  assert.deepEqual(findDistanceKeys({ livingSqft: 2000, totalSqft: 3000 }), [], 'square footage is area, not distance');
  assert.ok(findDistanceKeys({ gopherTortoiseNearestM: 1200 }).includes('gopherTortoiseNearestM'));
  assert.ok(findDistanceKeys({ water: { nearestWaterM: 40 } }).includes('water.nearestWaterM'));
  assert.equal(findDistanceKeys({ sites: { nearest: { distanceFt: 900 } } }).length, 1);
  assert.deepEqual(findDistanceKeys({ name: 'x', onParcel: true, cleanup: 'active' }), []);
});
test('§3 land model is containment-only; the nearest-habitat distance lives in §4 (ruling 74 C1)', () => {
  const raw = { gopherTortoiseCoverage: 'covered', gopherTortoiseInside: false, gopherTortoiseNearestM: 1200 };
  const section3Land = { coverage: raw.gopherTortoiseCoverage, inside: raw.gopherTortoiseInside }; // what §3 renders
  assert.deepEqual(findDistanceKeys(section3Land), [], '§3 land must carry no distance');
  assert.ok(findDistanceKeys(raw).includes('gopherTortoiseNearestM'), 'the guard has teeth: a leaked nearestM is caught');
});
test('§3 contamination render (on-parcel/active) exposes no distance-named field', () => {
  const r = renderContaminationFacilities(contamBlock);
  const onParcel = r.facilities.filter(isOnParcelContamination); // the split the page uses for §3
  assert.ok(onParcel.length >= 1, 'fixture must have an on-parcel/active facility');
  const s3 = (f) => ({ name: f.name, type: f.type, status: f.status, where: f.where, remediation: f.remediation, cleanup: f.cleanup, onParcel: f.onParcel });
  for (const f of onParcel) assert.deepEqual(findDistanceKeys(s3(f)), [], `§3 facility leaked a distance field: ${f.name}`);
});
test('isOnParcelContamination routes on-parcel and active to §3, closed-nearby to §4', () => {
  assert.equal(isOnParcelContamination({ onParcel: true, remediation: null }), true);
  assert.equal(isOnParcelContamination({ onParcel: false, remediation: 'ACTIVE' }), true);
  assert.equal(isOnParcelContamination({ onParcel: false, remediation: null }), false);
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} render controls, coverage gap never reads as a finding.` : `FAIL — ${failures.length}/${ran}`}`);
process.exit(failures.length === 0 ? 0 : 1);
