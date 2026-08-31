// lib/qualifier-guard.mjs
//
// THE CLASS THIS EXISTS FOR. D1 through D4 and the Flora-Bama sinkhole line are one failure: the narrator
// reads a payload VALUE and discards the QUALIFIER bound to it.
//   D1  distance_ft 0            -> "0 ft setback per NHD"        (field name discarded)
//   D2  owner_count 1 + a note   -> "sole owner of record"        (note discarded)
//   D3  field_status not_recorded-> an invented conflict          (status discarded)
//   D4  nearest_m + nearest_m_us -> "the recorded 1,322 m"        (sibling discarded)
//   --  sinkholeFacts not_established -> "0 incidents within 1 km recorded"
//                                                                 (status AND radius invented)
// The numeric shadow cannot see any of it: it checks MAGNITUDE, and every one of these is a magnitude the
// payload licenses used to say something the payload does not.
//
// THREE ASSERTIONS, all against the served payload, no wordlists and no model:
//   1. A field whose status is not_available may narrate NO COUNT, NO ZERO and NO RADIUS. If we hold no
//      layer there is nothing to have counted and no radius to have searched.
//   2. Any radius narrated must appear in the payload. "within 1 km" over a payload that says 500 m is a
//      stronger claim than the one we hold.
//   3. Any count narrated must match a count the record carries.
//
// KNOWN LIMIT OF ASSERTION 2, STATED RATHER THAN DISCOVERED LATER. Radius licensing is PAYLOAD-WIDE, not
// per-field: a threshold stated anywhere in the record licenses that radius everywhere in the narration.
// On the founding report this is why "Superfund / RCRA-TSD / TRI / USTs within 1km" is NOT caught — the
// payload does state a ~1 km radius, but for a DIFFERENT field (pollutionNotices.search_radius_ft 3280 =
// 999.7 m), while the contamination counts it was attached to are 500 m. Catching that requires attributing
// each sentence to a field, which the sinkhole assertion does by keyword and this one does not yet.
// So assertion 2 catches a radius we state NOWHERE, and misses a radius borrowed from the wrong field.
//
// SHADOW FIRST, and the Item 95 lesson applies: a shadow that CANNOT fire teaches nothing, and an empty
// table reads as a pass. The founding case in qualifier-guard.test.mjs must go RED before this is trusted.

// Statuses that mean WE HOLD NOTHING. A narration about a field in one of these states may report the gap
// and who answers it, and nothing else numeric.
const ABSENT_STATUS = new Set([
  'not_available', 'not_established', 'not_recorded', 'not_evaluated',
  'not_computed', 'layer_not_loaded', 'county_not_covered', 'not_derived',
]);

// A radius as written for a reader: "within 500 m", "within about 1 km", "within ~3,280 ft", "within 1 mile".
const RADIUS_RX = /\bwithin\s+(?:about\s+|~\s*|approximately\s+)?([\d,]+(?:\.\d+)?)\s*(m|km|ft|feet|mi|miles?|meters?|metres?)\b/gi;

// A count bound to a noun: "2 FDEP-registered tank facility points", "0 incidents", "1 reported incident".
const COUNT_RX = /\b([\d,]+)\s+(?:reported\s+|registered\s+|mapped\s+|known\s+)?([a-z][a-z-]*(?:\s+[a-z][a-z-]*){0,3})\b/gi;

const toNum = (s) => Number(String(s).replace(/[,\s]/g, ''));
const M_PER = { m: 1, meter: 1, meters: 1, metre: 1, metres: 1, km: 1000, ft: 0.3048, feet: 0.3048, mi: 1609.344, mile: 1609.344, miles: 1609.344 };
const toMetres = (v, u) => v * (M_PER[String(u).toLowerCase()] ?? NaN);

// Walk the payload and collect (a) every field in an absent status with a keyword to recognise it by,
// (b) every number the payload contains, (c) every radius the payload states, including radii baked into
// field NAMES (cleanup_sites_within_500m) which is where the real search threshold usually lives.
export function readPayload(payloadText) {
  const absent = [];   // { key, keyword, status }
  const numbers = new Set();
  const radiiM = new Set();
  let root;
  try { root = JSON.parse(payloadText); } catch { root = null; }

  const keywordOf = (key) => String(key)
    .replace(/Facts$|Block$|Coverage$/i, '')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/[_-]+/g, ' ')
    .trim().toLowerCase();

  const walk = (node, key) => {
    if (node == null) return;
    if (Array.isArray(node)) { numbers.add(node.length); node.forEach((n) => walk(n, key)); return; }
    if (typeof node === 'number' && Number.isFinite(node)) { numbers.add(Math.abs(node)); return; }
    if (typeof node === 'string') {
      for (const m of node.matchAll(/-?\d[\d,]*(?:\.\d+)?/g)) {
        const n = toNum(m[0]); if (Number.isFinite(n)) numbers.add(Math.abs(n));
      }
      return;
    }
    if (typeof node !== 'object') return;

    const st = typeof node.field_status === 'string' ? node.field_status.toLowerCase() : null;
    if (st && ABSENT_STATUS.has(st) && key) absent.push({ key, keyword: keywordOf(key), status: st });

    for (const [k, v] of Object.entries(node)) {
      // A radius baked into a field NAME is the query's real threshold — capture it before recursing.
      const nameRadius = /_within_(\d+)(m|km|ft|mi)\b/i.exec(k) || /_(\d+)(m|km)\b/i.exec(k);
      if (nameRadius) {
        const r = toMetres(Number(nameRadius[1]), nameRadius[2]);
        if (Number.isFinite(r)) radiiM.add(r);
      }
      if (/radius/i.test(k) && typeof v === 'number') {
        const r = /ft/i.test(k) ? toMetres(v, 'ft') : v;   // *_radius_ft vs *_radius_m
        if (Number.isFinite(r)) radiiM.add(r);
      }
      walk(v, k);
    }
  };
  walk(root, null);
  return { absent, numbers: [...numbers], radiiM: [...radiiM] };
}

const near = (a, b, tol = 0.02) => Math.abs(a - b) <= Math.max(1, tol * Math.max(a, b));

export function checkQualifiers(narration, payloadText) {
  const text = String(narration || '');
  const { absent, numbers, radiiM } = readPayload(payloadText);
  const violations = [];
  const sentences = text.split(/(?<=[.!?])\s+|\n+|(?=\|)/).filter(Boolean);

  // ─── ASSERTION 1 — an absent field may narrate no count, no zero, no radius ───────────────────────
  for (const f of absent) {
    if (!f.keyword) continue;
    const kw = new RegExp(`\\b${f.keyword.split(/\s+/).map(w => w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('\\s+')}`, 'i');
    for (const s of sentences) {
      if (!kw.test(s)) continue;
      // COVERAGE LANGUAGE EXEMPTS THE SENTENCE. Naming the gap is the SPECIFIED behaviour, and the first
      // version of this guard fired on "No sinkhole-incident layer is held ... not a statement that the
      // parcel has no sinkhole risk" — which is the exact wording we want. A guard that flags the correct
      // output is muted within a week, so it must recognise a statement about OUR HOLDINGS and stand down.
      const aboutOurHoldings = /\b(?:we hold|is held|are held|not held|no\s+[a-z-]*\s*(?:layer|register|coverage)\b|gap in (?:our|the) (?:coverage|holdings)|coverage gap|not a statement|says nothing|not evidence|do(?:es)? not (?:hold|cover))/i.test(s);
      if (aboutOurHoldings) continue;
      const hasCount = /\b\d[\d,]*\s+(?:reported\s+|registered\s+|mapped\s+)?[a-z]/i.test(s);
      const hasZero = /\b(?:0|zero|none|no)\s+[a-z-]*\s*(?:incident|site|facilit|record|listing|point|case)/i.test(s);
      const hasRadius = RADIUS_RX.test(s); RADIUS_RX.lastIndex = 0;
      if (hasCount || hasZero || hasRadius) {
        violations.push({
          assertion: 'absent_field_narrated_numerically',
          field: f.key, status: f.status,
          detail: 'field_status is ' + f.status + ' — we hold nothing to count and no radius was searched',
          sentence: s.trim().slice(0, 240),
        });
        break;
      }
    }
  }

  // ─── ASSERTION 2 — a narrated radius must exist in the payload ───────────────────────────────────
  for (const m of text.matchAll(RADIUS_RX)) {
    const metres = toMetres(toNum(m[1]), m[2]);
    if (!Number.isFinite(metres)) continue;
    // Licensed only by a stated THRESHOLD, compared in metres. A bare payload number with the same
    // digits is not a radius: the first version licensed "within 1 km" off any 1 in the record, which
    // is how the doubled-radius founding case passed.
    const licensed = radiiM.some((r) => near(r, metres, 0.05))
      || numbers.some((n) => near(n, metres, 0.02));
    if (!licensed) {
      violations.push({
        assertion: 'radius_not_in_payload',
        detail: 'narrated radius ' + m[1] + ' ' + m[2] + ' (' + Math.round(metres) + ' m) is not a threshold the payload states',
        sentence: m[0],
      });
    }
  }

  // ─── ASSERTION 3 — a narrated count must match a number the record carries ───────────────────────
  const COUNTED = /(incident|facilit|site|listing|record|permit|notice|zone|point|propert|owner|building|well|tank)/i;
  for (const m of text.matchAll(COUNT_RX)) {
    if (!COUNTED.test(m[2])) continue;
    const v = toNum(m[1]);
    if (!Number.isFinite(v)) continue;
    // A YEAR IS NOT A COUNT. "2025 DOR NAL roll | Permits" parsed as a count of 2025 permits on the real
    // Flora-Bama report. Four digits in the calendar range, with no thousands separator, is a date.
    if (v >= 1900 && v <= 2100 && !/,/.test(m[1])) continue;
    // EXACT, not near(). A count is a cardinality: 3 facilities is not 2 facilities, and near()'s absolute
    // floor of 1 licensed every count within +/-1 of something the record held. That is how "3 tank
    // facilities" passed against a record carrying 2.
    if (!numbers.some((n) => n === v)) {
      violations.push({
        assertion: 'count_not_in_payload',
        detail: 'narrated count ' + m[1] + ' ' + m[2].trim() + ' does not match any number in the record',
        sentence: m[0],
      });
    }
  }

  return { violations, absentFields: absent.length, payloadNumbers: numbers.length, payloadRadii: radiiM.length };
}
