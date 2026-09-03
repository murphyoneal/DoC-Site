// lib/qualifier-guard.test.mjs
//   node lib/qualifier-guard.test.mjs
//
// FOUNDING CASE FIRST, and it must go RED. Ruling 271: a detection that has never been red on the
// condition it names has not been shown to test anything, and Item 95's empty shadow table is what
// happens when that discipline is skipped — 0 rows read as "it never cries wolf" when the truth was
// "it cannot fire".
//
// The founding case is the live Flora-Bama report, Escambia 27/014S331001000001, 2026-08-31:
//   payload  sinkholeFacts.field_status = "not_established", plus a coverage_note saying in terms that
//            it is NOT a statement that the parcel has no sinkhole risk
//   narrated "0 incidents within 1 km recorded"
// and separately:
//   payload  cleanup_sites_within_500m: 0, tank_facilities_within_500m: 0
//   narrated "within 1km — 0 each"        <- the radius was DOUBLED
//
// The guard must also stay silent on the parts of that same report that were CORRECT, because a guard
// that fires on honest narration gets muted within a week.

import assert from 'node:assert';
import { checkQualifiers, readPayload } from './qualifier-guard.mjs';

// Trimmed from the real served payload for this parcel.
const PAYLOAD = JSON.stringify({
  sinkholeFacts: {
    county: 'Escambia', field_status: 'not_established', resolver_state: 'not_available',
    coverage_note: 'No sinkhole-incident layer is held for this county — a gap in our coverage, NOT a statement that the parcel has no sinkhole risk.',
  },
  contaminationFacilities: {
    field_status: 'present',
    area_context: { cleanup_sites_within_500m: 0, tank_facilities_within_500m: 0 },
  },
  pollutionNotices: {
    field_status: 'present',
    notices: [
      { on_parcel: false, distance_ft: 240, incident_number: '20246585' },
      { on_parcel: false, distance_ft: 2780, incident_number: '20193167' },
    ],
  },
  permitFacts: {
    count: 0, permits: [], field_status: 'not_available',
    coverage_note: 'We hold no permit register for Escambia County.',
  },
  groundElevation: { field_status: 'present', value: 4.16, units: 'm', value_us: '14 ft', vertical_datum: 'NAVD88' },
});

let ran = 0; const failures = [];
const check = (name, fn) => { ran++; try { fn(); } catch (e) { failures.push(`${name}: ${e.message}`); } };
const has = (r, a) => r.violations.some(v => v.assertion === a);

// ─── 1. THE FOUNDING CASE. Must be RED. ──────────────────────────────────────────────────────────────
check('FOUNDING CASE — "0 incidents within 1 km" over a not_established sinkhole field is caught', () => {
  const r = checkQualifiers(
    'Sinkhole setting | Area IV — cover >200 ft thick, cover-collapse type; 0 sinkhole incidents within 1 km recorded.',
    PAYLOAD);
  assert.ok(has(r, 'absent_field_narrated_numerically'),
    'MUST fire: we hold no sinkhole layer, so there is nothing to have counted');
  const v = r.violations.find(x => x.assertion === 'absent_field_narrated_numerically');
  assert.strictEqual(v.field, 'sinkholeFacts');
  assert.strictEqual(v.status, 'not_established');
});

check('FOUNDING CASE — the doubled radius is caught (payload says 500 m, report said 1 km)', () => {
  const r = checkQualifiers('Superfund / RCRA-TSD / TRI / USTs within 1km — 0 each.', PAYLOAD);
  assert.ok(has(r, 'radius_not_in_payload'), 'MUST fire: 1 km is not a threshold the payload states');
});

check('the payload radius itself passes — "within 500 m" is licensed by cleanup_sites_within_500m', () => {
  const r = checkQualifiers('No cleanup sites within 500 m.', PAYLOAD);
  assert.ok(!has(r, 'radius_not_in_payload'), '500 m IS the stated threshold and must not be flagged');
});

// ─── 2. THE OTHER MEMBERS OF THE CLASS ───────────────────────────────────────────────────────────────
check('a count with no basis in the record is caught', () => {
  const r = checkQualifiers('3 FDEP-registered tank facilities were identified.', PAYLOAD);
  assert.ok(has(r, 'count_not_in_payload'), '3 appears nowhere in the record');
});

check('a count the record carries passes — 2 notices are in the payload', () => {
  const r = checkQualifiers('The record carries 2 pollution notices.', PAYLOAD);
  assert.ok(!has(r, 'count_not_in_payload'), '2 is the length of notices[] and appears in the record');
});

check('a not_available permit register may not be narrated as a zero', () => {
  const r = checkQualifiers('Permits: 0 permit records on file for this parcel.', PAYLOAD);
  assert.ok(has(r, 'absent_field_narrated_numerically'), 'permitFacts is not_available — a zero is a claim we cannot make');
});

// ─── 3. IT MUST STAY SILENT ON HONEST NARRATION. ─────────────────────────────────────────────────────
check('naming the gap without a number is CORRECT and must not fire', () => {
  const r = checkQualifiers(
    'No sinkhole-incident layer is held for Escambia County — a gap in our coverage, not a statement that the parcel has no sinkhole risk. Ask the Florida Geological Survey.',
    PAYLOAD);
  assert.strictEqual(r.violations.length, 0, 'reporting a gap as a gap is the specified behaviour');
});

check('the correct permit wording does not fire', () => {
  const r = checkQualifiers(
    'We hold no permit register for Escambia County. This says nothing about whether this parcel has permits — ask the county building department.',
    PAYLOAD);
  assert.strictEqual(r.violations.length, 0);
});

check('the elevation sentence that 125a/207 produce does not fire', () => {
  const r = checkQualifiers(
    'The record holds a ground elevation of 4.16 m (14 ft) on NAVD88. It is a single sampled point, not a survey.',
    PAYLOAD);
  assert.strictEqual(r.violations.length, 0, 'a present field narrated from its own values is honest');
});

check('the Escambia owner wording — the one D2 form we got RIGHT — does not fire', () => {
  const r = checkQualifiers(
    'FLORA BAMA LOUNGE & PACKAGE ST (single string; no ownership % published).', PAYLOAD);
  assert.strictEqual(r.violations.length, 0, 'this wording is the target, not the defect');
});

// ─── 3b. ASSERTION 4 — CONTAINMENT OVER AN INDICATION (item 253). ────────────────────────────────────
// The first three assertions are all NUMERIC, so a claim with no number in it fired nothing. This is the
// Bok Tower case: Roz stated flat membership of a historic district whose boundary is a 5-point nomination
// bounding box over 1,040 acres — a shape that can indicate membership and cannot determine it.
const BOK = JSON.stringify({
  historicDesignations: {
    field_status: 'present',
    in_district: true,
    district_relation: 'indication',
    districts: [{
      name: 'Mountain Lake Estates Historic District',
      nrhp_reference_number: '93000871',
      relation: 'district_membership',
      boundary_vertices: 5,
      boundary_basis: 'nomination_bbox',
      containment_status: 'indication',
    }],
    district_caveat: 'NPS derives these boundaries from the bounding coordinates recorded in the nomination, not from survey. Treat membership as an indication requiring confirmation, not a determination.',
  },
  landRestrictions: [{
    field: 'gwca_restriction', field_status: 'present',
    value: 'within a delineated Groundwater Contamination Area (Ch. 62-524)',
  }],
});

check('FOUNDING CASE — flat district membership over an indication-only boundary is caught', () => {
  const r = checkQualifiers(
    'The Singing Tower sits on the largest parcel, which is also within the Mountain Lake Estates Historic District (ref 93000871).',
    BOK);
  assert.ok(has(r, 'containment_asserted_over_indication'),
    'MUST fire: a 5-point nomination box can indicate membership, not determine it');
  const v = r.violations.find(x => x.assertion === 'containment_asserted_over_indication');
  assert.strictEqual(v.status, 'indication');
});

check('THE HONEST FORM PASSES — the report page wording must not be flagged', () => {
  // Verbatim from app/report/[coNo]/[parcelId]/page.tsx, which was already right before the data was.
  const r = checkQualifiers(
    'Within a listed National Register historic district — an indication to confirm against the NPS record (boundaries are nomination-derived, not survey); it constrains alteration/demolition and gates rehabilitation tax credits',
    BOK);
  assert.strictEqual(r.violations.length, 0,
    'reporting an indication AS an indication is the specified behaviour — flagging it is the tourniquet mistake');
});

check('hedged prose naming the district passes', () => {
  const r = checkQualifiers(
    'The parcel falls within the Mountain Lake Estates Historic District as mapped, but that boundary is the nomination bounding box — an indication requiring confirmation, not a determination.',
    BOK);
  assert.ok(!has(r, 'containment_asserted_over_indication'));
});

check('A DETERMINABLE record licenses the flat claim', () => {
  const digitized = JSON.stringify({ historicDesignations: { field_status: 'present', in_district: true,
    district_relation: 'containment',
    districts: [{ name: 'Pensacola Naval Air Station Historic District', boundary_vertices: 8,
                  boundary_basis: 'digitized', containment_status: 'containment' }] } });
  const r = checkQualifiers('The parcel is within the Pensacola Naval Air Station Historic District.', digitized);
  assert.ok(!has(r, 'containment_asserted_over_indication'),
    'a digitized boundary determines containment — the flat claim is licensed');
});

check('REAL POLYGON CONTAINMENT IS UNTOUCHED — the GWCA sentence must not fire', () => {
  const r = checkQualifiers(
    'FDEP records all three parcels as inside a delineated Groundwater Contamination Area (Ch. 62-524), which restricts new potable wells.',
    BOK);
  assert.ok(!has(r, 'containment_asserted_over_indication'),
    'the GWCA record carries no containment_status, so it is not subject to this assertion — containment from a surveyed polygon is not in question');
});

check('MIXED — the indication district is caught, the determinable one is not', () => {
  const mixed = JSON.stringify({ historicDesignations: { field_status: 'present', in_district: true,
    district_relation: 'mixed',
    districts: [
      { name: 'Old Box District', boundary_vertices: 5, boundary_basis: 'nomination_bbox', containment_status: 'indication' },
      { name: 'Pensacola Naval Air Station Historic District', boundary_vertices: 8, boundary_basis: 'digitized', containment_status: 'containment' },
    ] } });
  const bad = checkQualifiers('The parcel is within the Old Box District.', mixed);
  assert.ok(has(bad, 'containment_asserted_over_indication'), 'naming the indication district flatly must fire');
  const ok = checkQualifiers('The parcel is within the Pensacola Naval Air Station Historic District.', mixed);
  assert.ok(!ok.violations.some(v => v.assertion === 'containment_asserted_over_indication' && v.field === 'Pensacola Naval Air Station Historic District'),
    'the determinable district must not be flagged');
});

check('A DENIAL OF CONTAINMENT MUST PASS — found by running the assertion against what should stay silent', () => {
  // The first cut fired on all of these. A negative claim is not a containment claim, and flagging it
  // would have muted the guard on the exact honest wording we want from the narrator.
  for (const sen of [
    'This parcel is not within any historic district.',
    'The parcel does not fall within the Mountain Lake Estates Historic District.',
    'No listed historic district contains this parcel.',
    'It is unclear whether the parcel sits in the Mountain Lake Estates Historic District.',
  ]) {
    const r = checkQualifiers(sen, BOK);
    assert.ok(!has(r, 'containment_asserted_over_indication'), `must stay silent: ${sen}`);
  }
});

check('a negation LATER in the sentence does not launder an assertion made earlier', () => {
  const r = checkQualifiers(
    'The parcel is inside the Mountain Lake Estates Historic District, which is not a small area.', BOK);
  assert.ok(has(r, 'containment_asserted_over_indication'),
    'the negation window is checked BEFORE the verb, so a later "not" cannot excuse the claim');
});

// ─── 4. THE READER ITSELF ────────────────────────────────────────────────────────────────────────────
check('readPayload finds the absent fields and the name-baked radius', () => {
  const p = readPayload(PAYLOAD);
  const keys = p.absent.map(a => a.key).sort();
  assert.deepStrictEqual(keys, ['permitFacts', 'sinkholeFacts']);
  assert.ok(p.radiiM.includes(500), 'cleanup_sites_within_500m must register 500 m as a stated threshold');
});

console.log(`\n${failures.length === 0
  ? `PASS — ${ran} qualifier controls. Founding cases RED: the sinkhole zero, the doubled radius, and flat district membership over an indication-only boundary. The correct wording from the same reports stays silent — including the report page's own historic-district sentence.`
  : `FAIL — ${failures.length}/${ran}\n` + failures.map(f => '  ' + f).join('\n')}`);
process.exit(failures.length === 0 ? 0 : 1);
