// lib/roz-tourniquet.mjs
// Post-generation tourniquet for the elevation-fabrication class (7th occurrence, 2026-07-31). The model
// invents a lidar-accuracy figure ("15.9 ft, USGS 3DEP lidar-derived, ±0.96 ft at 95% confidence") — pure
// GENERATION, not payload exposure, so removing keys cannot reach it and three instruction guards failed.
// A mechanical gate at the response boundary can stop what instruction could not.
//
// EXTRACTED TO lib/ ON 2026-08-29, and the reason is the bug it was extracted after. This logic previously
// lived inline in app/api/roz/route.ts and was DUPLICATED in its test. A second copy that drifts from the
// original is exactly how the stale WITHHELD_ELEVATION_NOTE survived the 125a repair — the getter was fixed
// and a hardcoded twin in the consumer kept emitting the old sentence for a day. Keeping a duplicate inside
// the test that proves that fix would have rebuilt the same defect deliberately. One copy, imported twice.
//
// WHY THE PAYLOAD EXEMPTION EXISTS. Migration 125a put the honest caveat "the USGS 3DEP 1m elevation model"
// into the served payload. FABRICATION_RX matches \b3DEP\b, so the guard fired on a TRUTHFUL sentence,
// deleted it, and appended a hardcoded note asserting the vertical datum was not recorded — over a payload
// that records NAVD88. THE GUARD BECAME THE THING MANUFACTURING THE FALSE CLAIM.
// "Zero false positives by construction" was written as a permanent property of this guard. It was
// contingent on no honest payload carrying the terms, and one migration broke it.
//
// STANDING RULE: a guard keyed on VOCABULARY must be re-checked against the payload every time the
// payload's vocabulary changes. The guard and the getter are not correct separately — only together.

export const FABRICATION_RX = /\b3DEP\b|\blidar\b|\b95\s*%\s*confidence\b|±\s*\d|\bNVA\b|\bVVA\b|vertical accuracy/i;

// The substitute sentence is DERIVED from field_status, never hardcoded. A fixed sentence that was true
// when written is precisely what failed on 2026-08-29; derived, the next payload change cannot make it a lie.
export function elevationSubstitute(ge) {
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
  // An UNKNOWN state must assert nothing in either direction. Claiming "not recorded" here is the defect
  // this function exists to remove; claiming a value would be worse.
  return 'A precise ground elevation is not being stated here. Obtain a surveyed elevation certificate for an authoritative figure.';
}

// PER-TERM exemption, never per-sentence. A matched term appearing VERBATIM in the payload is a quote, not
// an invention. Only terms absent from the payload are evidence of fabrication.
// The per-term split is what keeps this from becoming a hole: the real fabrication of 2026-08-29 put an
// invented accuracy band in the SAME SENTENCE as a quoted program name, so a per-sentence exemption would
// have passed the whole thing. Its own terms (lidar, ±0.96, 95% confidence) are absent from the payload,
// stay unexempt, and the sentence still falls. Asserted by the negative control in roz-tourniquet.test.mjs.
export function redactFabricatedPrecision(text, payloadText = '', elevationFact = null) {
  if (!text || !FABRICATION_RX.test(text)) return { text, triggered: false, terms: '', excerpt: '' };
  const g = new RegExp(FABRICATION_RX.source, 'gi');
  const matched = Array.from(new Set((text.match(g) ?? []).map(s => s.trim())));
  const hay = String(payloadText || '').toLowerCase();
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
