// lib/numeric-provenance.mjs
// Item 95 — the DURABLE fabrication fix, replacing the vocabulary tourniquet (redactFabricatedPrecision).
// The model invents a MEASUREMENT the payload never contained ("Ground elevation: 15.9 ft, ±0.96 ft at 95%
// confidence") — seven times, escalating. The tourniquet blocks seven strings; the model can invent an
// eighth. This validates the COMPLETE class: every measurement in the narration must trace to a number the
// payload justifies, or it is a fabrication.
//
// Four rules keep it from crying wolf (a validator that rejects truthful sentences gets muted within a week):
//   1. ROUNDING passes. "about 1,600 ft" against 1,640 is honest — a relative tolerance band, not exact match.
//   2. UNIT CONVERSIONS pass. 1.56 m must license 5.1 ft — the provenance set carries m/ft/mi forms of every value.
//   3. NON-MEASUREMENT numbers pass. Statute cites (872.02), permit/parcel/instrument numbers, phones, years
//      carry no measurement unit, so they are never EXTRACTED — only $/ft/mi/sqft/acre/%/mph numbers are.
//   4. ARITHMETIC over payload values (a $50,512 sum of four RCN figures) is NOT auto-licensed here — the
//      resolver should emit any total it wants narrated. Shadow mode surfaces the real sums before we decide.
//
// SHADOW-FIRST: validateNarration only REPORTS. The caller logs flags without redacting, reads what it would
// have blocked against real reports, and only then enforces. If it would flag the $2,125,000 sale price or a
// 140 mph wind speed, the design is wrong and we learn it before it is live. The tourniquet stays on underneath.

const FT_PER_M = 3.280839895;
const M_PER_MI = 1609.344;

// A measurement token: a number carrying a unit that marks it as a physical quantity (the fabrication
// surface). Dollar amounts are prefix ($X); the rest are suffix (X ft). Bare integers, IDs, statutes,
// years and phone numbers carry none of these and are deliberately NOT matched.
const MEASUREMENT_RX =
  /(?<dollar>\$\s?\d[\d,]*(?:\.\d+)?)|(?<val>\d[\d,]*(?:\.\d+)?)\s*(?<unit>ft\b|feet\b|foot\b|mi\b|miles?\b|sq\.?\s?ft\b|acres?\b|%|mph\b|meters?\b|m\b)/gi;

// Any number at all (for building the payload provenance set — we license generously FROM the payload;
// the fabrication has no payload source, so over-licensing the payload never lets a fabrication through).
const ANY_NUMBER_RX = /-?\d[\d,]*(?:\.\d+)?/g;

const toNum = (s) => Number(String(s).replace(/[$,\s]/g, ''));

// Build the licensed set from the exact payload text Roz saw (payloadParts joined). Every number, plus its
// unit conversions, so a converted narration form (m -> ft -> mi) is licensed.
export function buildProvenanceSet(payloadText) {
  const nums = new Set();
  const add = (n) => { if (Number.isFinite(n)) nums.add(Math.abs(n)); };
  for (const m of String(payloadText || '').matchAll(ANY_NUMBER_RX)) {
    const n = toNum(m[0]);
    if (!Number.isFinite(n)) continue;
    add(n);
    // conversions in every direction — we don't know the source unit, so license all plausible forms
    add(n * FT_PER_M);        // metres -> feet
    add(n / FT_PER_M);        // feet -> metres
    add(n / M_PER_MI);        // metres -> miles
    add(n * M_PER_MI);        // miles -> metres
    add(n * FT_PER_M / M_PER_MI); // metres -> miles-in-feet edge
  }
  return { numbers: [...nums].sort((a, b) => a - b) };
}

// A claimed value is licensed if it is within a rounding tolerance of any payload number (or a conversion
// of one). Tolerance is the larger of a relative band (covers "about 1,600" vs 1,640) and a small absolute
// floor (covers small values and percentages: "a third" 33.3 vs 34.4).
export function isLicensed(value, provenanceSet, { relTol = 0.06, absTol = 1.0 } = {}) {
  const v = Math.abs(value);
  for (const p of provenanceSet.numbers) {
    const tol = Math.max(absTol, relTol * p);
    if (Math.abs(v - p) <= tol) return true;
  }
  return false;
}

// Extract measurement claims from the narration. Skips a number when its immediate left context marks it as
// a non-measurement identifier even if a unit-like token follows (statute/permit/parcel/instrument/§).
const NON_MEASUREMENT_CONTEXT = /(statute|f\.?s\.?|§|chapter|permit|instrument|parcel|nrhp|book|page|phone|call)\s*[#:]?\s*$/i;
export function extractMeasurements(narration) {
  const text = String(narration || '');
  const out = [];
  for (const m of text.matchAll(MEASUREMENT_RX)) {
    const before = text.slice(Math.max(0, m.index - 24), m.index);
    if (NON_MEASUREMENT_CONTEXT.test(before)) continue;
    const isDollar = !!m.groups.dollar;
    const raw = isDollar ? m.groups.dollar : `${m.groups.val} ${m.groups.unit}`;
    const value = toNum(isDollar ? m.groups.dollar : m.groups.val);
    const unit = isDollar ? '$' : m.groups.unit.toLowerCase();
    if (Number.isFinite(value)) out.push({ raw: raw.trim(), value, unit, index: m.index });
  }
  return out;
}

// The whole check. Returns the measurements that are NOT licensed by the payload — the fabrication
// candidates. SHADOW: the caller logs `flagged` and does not act on it until the design is proven.
export function validateNarration(narration, payloadText, opts = {}) {
  const provenanceSet = buildProvenanceSet(payloadText);
  const claims = extractMeasurements(narration);
  const flagged = claims.filter((c) => !isLicensed(c.value, provenanceSet, opts));
  return {
    flagged,                              // measurements with no payload provenance — likely fabricated
    claimCount: claims.length,
    licensedCount: claims.length - flagged.length,
    provenanceSize: provenanceSet.numbers.length,
  };
}
