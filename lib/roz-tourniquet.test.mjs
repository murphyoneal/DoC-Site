// lib/roz-tourniquet.test.mjs
//   node lib/roz-tourniquet.test.mjs
//
// Controls for the elevation-fabrication tourniquet after the 2026-08-29 payload-exemption change.
//
// THE HISTORY THIS ENCODES. Migration 125a put the honest caveat "the USGS 3DEP 1m elevation model" into
// the served payload. FABRICATION_RX matches \b3DEP\b, so the guard fired on a TRUTHFUL sentence, deleted
// it, and appended a hardcoded note asserting the vertical datum was not recorded — over a payload that
// records NAVD88. A guard became the thing manufacturing the false claim.
//
// The exemption that fixes it is the dangerous kind of fix, so the FIRST test here is the negative control:
// the real fabrication from roz_fabrication_block id 6 must STILL be blocked. An exemption that lets that
// through is a hole, not a repair.
//
// The logic below mirrors app/api/roz/route.ts. It is duplicated rather than imported because route.ts is
// a Next.js server route that pulls the Anthropic SDK and Supabase at module scope. THAT DUPLICATION IS
// ITSELF A RISK OF THE CLASS THIS FILE EXISTS TO CATCH — a second copy that drifts from the original is
// exactly how WITHHELD_ELEVATION_NOTE survived the 125a repair. If you change route.ts, change this too.

import assert from 'node:assert';

const FABRICATION_RX = /\b3DEP\b|\blidar\b|\b95\s*%\s*confidence\b|±\s*\d|\bNVA\b|\bVVA\b|vertical accuracy/i;

function elevationSubstitute(ge) {
  const status = ge && typeof ge.field_status === 'string' ? ge.field_status : null;
  if (status === 'present') {
    const us = typeof ge?.value_us === 'string' ? ge.value_us : null;
    const datum = typeof ge?.vertical_datum === 'string' ? ge.vertical_datum : null;
    const v = ge?.value != null && typeof ge.units === 'string' ? `${ge.value} ${ge.units}` : null;
    const figure = v && us ? `${v} (${us})` : (us ?? v);
    if (figure && datum) return `The record holds a ground elevation of ${figure} on ${datum}. It is a single sampled point, not a survey — a surveyed elevation certificate is the only authoritative figure for this parcel.`;
    if (figure) return `The record holds a ground elevation of ${figure}. It is a single sampled point, not a survey — a surveyed elevation certificate is the only authoritative figure for this parcel.`;
  }
  if (status === 'not_available' || status === 'not_recorded') {
    return 'No sampled ground elevation is held for this parcel. That is a gap in our holdings, not a finding that the parcel has no recorded elevation — a surveyed elevation certificate can establish it.';
  }
  return 'A precise ground elevation is not being stated here. Obtain a surveyed elevation certificate for an authoritative figure.';
}

function redactFabricatedPrecision(text, payloadText = '', elevationFact = null) {
  if (!text || !FABRICATION_RX.test(text)) return { text, triggered: false, terms: '', excerpt: '' };
  const g = new RegExp(FABRICATION_RX.source, 'gi');
  const matched = Array.from(new Set((text.match(g) ?? []).map(s => s.trim())));
  const hay = payloadText.toLowerCase();
  const unexempt = matched.filter(t => !hay.includes(t.toLowerCase()));
  if (unexempt.length === 0) return { text, triggered: false, terms: '', excerpt: '' };
  const esc = unexempt.map(t => t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|');
  const unexemptRx = new RegExp(esc, 'i');
  const parts = text.split(/(?<=[.!?])\s+|\n+/);
  const dropped = parts.filter(s => unexemptRx.test(s));
  const kept = parts.filter(s => !unexemptRx.test(s));
  let clean = kept.join(' ').replace(/\s{2,}/g, ' ').trim();
  clean = (clean ? clean + ' ' : '') + elevationSubstitute(elevationFact);
  return { text: clean, triggered: true, terms: unexempt.join(', '), excerpt: dropped.join(' ').slice(0, 2000) };
}

// The real served envelope for Collier 21/20765320102 after migration 125a.
const SERVED_PAYLOAD = JSON.stringify({ report: { groundElevation: {
  predicate: 'ground_elevation', value: 2.96, units: 'm', value_us: '10 ft',
  field_status: 'present', vertical_datum: 'NAVD88', source: 'parcel_elevations',
  as_of: 'USGS 3DEP 1m DEM, sampled at the parcel',
  caveat: 'This is a single elevation point sampled at the parcel from the USGS 3DEP 1m elevation model - not a survey, and not an average across the lot.',
} } });
const GE_PRESENT = JSON.parse(SERVED_PAYLOAD).report.groundElevation;

let ran = 0; const failures = [];
const check = (name, fn) => { ran++; try { fn(); } catch (e) { failures.push(`${name}: ${e.message}`); } };

// ─── 1. THE NEGATIVE CONTROL. Non-negotiable. ────────────────────────────────────────────────────────
// roz_fabrication_block id 6, 2026-08-29 10:26:35Z, parcel 20765320102, VERBATIM. Roz invented an accuracy
// band we hold for ZERO parcels statewide. This must still be blocked now that "3DEP" is exempt.
check('NEGATIVE CONTROL — the real id-6 fabrication is still blocked', () => {
  const fabricated = '| Ground elevation | 9.7 ft (NAVD88), single lidar-sampled point | USGS 3DEP 1m DEM; accuracy ±0.96 ft (vegetated) / ±0.64 ft (non-vegetated) at 95% confidence per acquisition |';
  const r = redactFabricatedPrecision(fabricated, SERVED_PAYLOAD, GE_PRESENT);
  assert.ok(r.triggered, 'MUST still trigger — the exemption is a hole if this passes');
  assert.ok(!/±\s*0\.96/.test(r.text), 'the invented accuracy band must not survive');
  assert.ok(!/95\s*%\s*confidence/i.test(r.text), 'the invented confidence level must not survive');
  assert.ok(!/9\.7 ft/.test(r.text), 'the self-computed figure must not survive');
  assert.ok(/lidar/i.test(r.terms), 'lidar is absent from the payload and must be reported as unexempt');
});

// The fabricated band sits in the SAME sentence as the quoted program name. Per-term exemption must not
// let the quote rescue the invention.
check('a fabricated band adjacent to a quoted term is still caught', () => {
  const mixed = 'Sampled from the USGS 3DEP 1m elevation model, accuracy ±0.96 ft at 95% confidence.';
  const r = redactFabricatedPrecision(mixed, SERVED_PAYLOAD, GE_PRESENT);
  assert.ok(r.triggered, 'must trigger on the unexempt band');
  assert.ok(!/±\s*0\.96/.test(r.text), 'band must be dropped despite sharing a sentence with "3DEP"');
});

// ─── 2. THE FALSE POSITIVE 125a CREATED. ─────────────────────────────────────────────────────────────
check('an honest narration quoting the payload caveat is NOT redacted', () => {
  const honest = 'Ground elevation is 2.96 m (10 ft) NAVD88. This is a single elevation point sampled at the parcel from the USGS 3DEP 1m elevation model - not a survey. A surveyed elevation certificate is the only authoritative figure for this parcel.';
  const r = redactFabricatedPrecision(honest, SERVED_PAYLOAD, GE_PRESENT);
  assert.ok(!r.triggered, 'quoting the payload is not fabricating');
  assert.strictEqual(r.text, honest, 'honest text must pass through byte-identical');
});

// ─── 3. THE SUBSTITUTE IS DERIVED, AND NEVER CONTRADICTS THE PAYLOAD. ────────────────────────────────
check('substitute never asserts "datum not recorded" over a payload that records one', () => {
  const s = elevationSubstitute(GE_PRESENT);
  assert.ok(!/datum is not|not recorded/i.test(s), 'THE 2026-08-29 DEFECT: must not deny a recorded datum');
  assert.ok(s.includes('NAVD88'), 'must name the datum the payload carries');
  assert.ok(s.includes('10 ft'), 'must use value_us, never a self-computed conversion');
  assert.ok(!/9\.7/.test(s), 'must not restate a computed figure');
});

check('substitute reports a real coverage gap as a gap, not as a finding', () => {
  const s = elevationSubstitute({ field_status: 'not_available' });
  assert.ok(/gap in our holdings/i.test(s), 'must name it as our gap');
  assert.ok(/not a finding/i.test(s), 'must not read as a statement about the parcel');
});

check('substitute asserts nothing when the envelope is unknown', () => {
  for (const ge of [null, undefined, {}, { field_status: 'weird' }]) {
    const s = elevationSubstitute(ge);
    assert.ok(!/not recorded|is on record/i.test(s), 'unknown state must not assert either direction');
    assert.ok(/surveyed elevation certificate/i.test(s), 'must still route the reader somewhere real');
  }
});

// ─── 4. THE ORIGINAL CLASS, UNCHANGED. ───────────────────────────────────────────────────────────────
check('the original 7th-occurrence fabrication is still blocked with an empty payload', () => {
  const original = 'Ground elevation: 15.9 ft, USGS 3DEP lidar-derived, ±0.96 ft at 95% confidence.';
  const r = redactFabricatedPrecision(original, '', null);
  assert.ok(r.triggered, 'must still fire when nothing in the payload licenses the terms');
  assert.ok(!/15\.9 ft/.test(r.text), 'the invented figure must not survive');
});

check('clean text is untouched', () => {
  const clean = 'The parcel fronts the Atlantic Ocean. Just value is $128,773,910 on the 2025 roll.';
  const r = redactFabricatedPrecision(clean, SERVED_PAYLOAD, GE_PRESENT);
  assert.ok(!r.triggered);
  assert.strictEqual(r.text, clean);
});

console.log(`\n${failures.length === 0
  ? `PASS — ${ran} tourniquet controls. Negative control holds: the id-6 fabrication is still blocked, and the honest caveat passes.`
  : `FAIL — ${failures.length}/${ran}\n` + failures.map(f => '  ' + f).join('\n')}`);
process.exit(failures.length === 0 ? 0 : 1);
