// lib/fact-render.mjs
// The DETERMINISTIC renderer for fact records (get_parcel_*_fact output). This is the anti-fabrication
// core: the model may NARRATE around these records but may NEVER ORIGINATE a value. renderFact turns a
// record into rendered text via code only — no model in this path.
//
// Three load-bearing rules, each tied to a real production failure:
//   1. Absent value -> a FIXED, per-predicate string. Never a sentence, never an inferred number.
//      This is the line that kills "USGS 3DEP, ±0.96 ft at 95% confidence" — a value the model
//      composed over an ABSENT field. Absent -> hardcoded string, full stop.
//   2. Independence is rendered by STATUS, and anything not positively established renders
//      "not established", NEVER "independent". (The permit↔CAMA pair is 'partial', not independent.)
//   3. NO confidence score. Show source count, tier, dates, independence — a 0–100 number is the
//      next fabrication.

export const NULL_STRINGS = {
  area_sqft:  'Footprint not recorded by the county',
  built_year: 'Build year not recorded by the county',
};

// independence_status (from roz_source_relationship) -> human label. Unknown/missing fails SAFE to
// "not established" — it must never silently read as "independent".
const INDEPENDENCE_LABEL = {
  independent_verified: 'independent',
  partial:              'partially independent',
  unverified:           'not established',
  derived:              'same source — not corroboration',
};
function independenceLabel(status) {
  return INDEPENDENCE_LABEL[status] || 'not established';
}

function valueLabel(predicate, value) {
  if (predicate === 'area_sqft')  return `${Number(value).toLocaleString('en-US')} sq ft`;
  if (predicate === 'built_year') return `built ${value}`;
  return String(value);
}

export function renderFact(rec) {
  const empty = { label: 'Data unavailable', hasValue: false, provenance: null,
                  corroboration: [], openQuestions: [], contradictions: [] };
  if (!rec || typeof rec !== 'object' || rec.error) return empty;

  // Rule 1 — absent value renders a fixed string, no source line, no narration.
  if (rec.field_status === 'not_recorded' || rec.value == null) {
    return { ...empty, label: NULL_STRINGS[rec.predicate] || 'Not recorded by the county' };
  }

  const corrob = Array.isArray(rec.corroborators) ? rec.corroborators : [];
  // Rule 3 — provenance carries source_count / tier / date, never a confidence score.
  const provenance = {
    source: rec.source, tier: rec.source_tier, as_of: rec.as_of,
    source_count: 1 + corrob.length, note: rec.note || null,
  };
  // Rule 2 — corroboration labelled by independence status; 'partial' carries its caveat.
  const corroboration = corrob.map((c) => ({
    text: c.value,
    independence: independenceLabel(c.independence_status),
    caveat: c.independence_status === 'partial' ? (c.qualifier_note || null) : null,
  }));

  return {
    label: valueLabel(rec.predicate, rec.value),
    hasValue: true,
    provenance,
    corroboration,
    openQuestions:  (Array.isArray(rec.open_questions) ? rec.open_questions : []).map((q) => q.question),
    contradictions: (Array.isArray(rec.contradictors) ? rec.contradictors : []).map((c) => c.value || c),
  };
}
