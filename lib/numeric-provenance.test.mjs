// lib/numeric-provenance.test.mjs
//   node lib/numeric-provenance.test.mjs
// The load-bearing tests are the maintainer's cry-wolf guardrails: real payload values, rounding,
// conversions and non-measurement numbers MUST pass. Only a measurement with NO payload provenance is
// flagged. If this suite ever flags the $2,125,000 sale price or a 140 mph wind speed, the design is wrong.

import assert from 'node:assert';
import { validateNarration, buildProvenanceSet, isLicensed, extractMeasurements } from './numeric-provenance.mjs';

let ran = 0; const failures = [];
function test(name, fn) { ran++; try { fn(); console.log(`  ok   ${name}`); }
  catch (e) { failures.push(name); console.log(`  FAIL ${name} — ${e.message}`); } }

// A realistic payload slice (the text Roz sees): a sale, a just value, a wind speed, a distance in metres,
// a repetitive-loss count, a percentage, a permit amount, a parcel id, a year, a phone.
const PAYLOAD = JSON.stringify({
  values: { justValue: 2094505, salePrice: 2125000, improvement: 1179505 },
  wind: { designSpeedMph: 140 },
  water: { nearestWaterM: 1.56 },              // 1.56 m -> ~5.1 ft
  flood: { areaRepetitiveLoss: { properties: 1640 } },
  pct: 34.4,
  permit: { number: '2011-2278', declared: 706819 },
  parcel: '744403020120', builtYear: 2022, phone: '386-736-2700',
});

// ── The FABRICATION must be flagged (no elevation number in the payload — it is withheld) ─────────────
test('fabrication: an invented elevation with no payload source is flagged', () => {
  const r = validateNarration('Ground elevation: 15.9 ft, accurate to about a foot.', PAYLOAD);
  assert.ok(r.flagged.some((f) => Math.round(f.value) === 16 || f.value === 15.9), 'the invented 15.9 ft must be flagged');
});

// ── The maintainer's explicit tripwires: these MUST pass ─────────────────────────────────────────────
test('cry-wolf: the $2,125,000 sale price passes (it is in the payload)', () => {
  const r = validateNarration('The last qualified sale was $2,125,000 in 2022.', PAYLOAD);
  assert.equal(r.flagged.length, 0, `must not flag the real sale price; flagged: ${JSON.stringify(r.flagged)}`);
});

test('cry-wolf: a 140 mph wind speed passes (it is in the payload)', () => {
  const r = validateNarration('The design wind speed is 140 mph.', PAYLOAD);
  assert.equal(r.flagged.length, 0, `must not flag the real wind speed; flagged: ${JSON.stringify(r.flagged)}`);
});

// ── Rounding passes ──────────────────────────────────────────────────────────────────────────────────
test('rounding: "about 1,600 ft" passes against a payload 1,640', () => {
  const r = validateNarration('There are records for about 1,600 ft of frontage.', PAYLOAD);
  assert.equal(r.flagged.length, 0, `rounding within tolerance must pass; flagged: ${JSON.stringify(r.flagged)}`);
});

test('rounding: "roughly 34%" passes against a payload 34.4', () => {
  const r = validateNarration('Roughly 34% of the parcel is affected.', PAYLOAD);
  assert.equal(r.flagged.length, 0);
});

// ── Unit conversions pass (1.56 m licenses 5.1 ft) ───────────────────────────────────────────────────
test('conversion: "5.1 ft" passes against a payload 1.56 m', () => {
  const r = validateNarration('The nearest water feature is 5.1 ft away.', PAYLOAD);
  assert.equal(r.flagged.length, 0, `metre->foot conversion must be licensed; flagged: ${JSON.stringify(r.flagged)}`);
});

// ── Non-measurement numbers pass (never extracted — they carry no measurement unit) ──────────────────
test('non-measurement: statute cite 872.02 is not extracted', () => {
  const claims = extractMeasurements('This is governed by Florida Statute 872.02 and chapter 403.077.');
  assert.equal(claims.length, 0, `statute cites must not be treated as measurements; got ${JSON.stringify(claims)}`);
});

test('non-measurement: parcel id, permit number, year and phone are not flagged', () => {
  const r = validateNarration('Parcel 744403020120, permit 2011-2278, built 2022, phone 386-736-2700.', PAYLOAD);
  assert.equal(r.flagged.length, 0, `identifiers must not be flagged; flagged: ${JSON.stringify(r.flagged)}`);
});

// ── The permit's declared value (a real payload dollar figure) passes ────────────────────────────────
test('the $706,819 permit value passes (payload figure)', () => {
  const r = validateNarration('A $706,819 permit was filed.', PAYLOAD);
  assert.equal(r.flagged.length, 0);
});

// ── Mechanics ────────────────────────────────────────────────────────────────────────────────────────
test('isLicensed: exact, converted, and rounded values license; a far value does not', () => {
  const p = buildProvenanceSet(JSON.stringify({ a: 500, b: 1.56 }));
  assert.ok(isLicensed(500, p));                 // exact
  assert.ok(isLicensed(1640.4, p));              // 500 m -> ft
  assert.ok(isLicensed(510, p, { relTol: 0.06 }));// rounded within band
  assert.ok(!isLicensed(15.9, p));               // no source
});

test('a real fabrication string is caught while a co-located real figure is not', () => {
  const r = validateNarration('The dock is worth $1,179,505. Ground elevation: 15.9 ft (USGS 3DEP, ±0.96 ft).', PAYLOAD);
  assert.ok(r.flagged.some((f) => /15\.9|0\.96/.test(String(f.value)) || f.unit === 'ft'), 'the invented ft figures are flagged');
  assert.ok(!r.flagged.some((f) => f.value === 1179505), 'the real improvement value is not flagged');
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} numeric-provenance controls; real values/rounding/conversions/ids pass, only unprovenanced measurements flag.` : `FAIL — ${failures.length}/${ran}`}`);
process.exit(failures.length === 0 ? 0 : 1);
