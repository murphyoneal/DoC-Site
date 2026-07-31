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
  area_sqft:            'Footprint not recorded by the county',
  built_year:           'Build year not recorded by the county',
  grade:                'Grade not recorded by the county',
  replacement_cost_new: 'Replacement cost not recorded by the county',
  depreciated_value:    'Depreciated value not recorded by the county',
  pct_depreciated:      'Depreciation not computable (missing inputs)',
  service_life_vs_age:  'Service life not derived for this improvement type',
  ground_elevation:     'Ground elevation not recorded',
  just_value:           'Just (market) value not recorded by the county',
  assessed_value:       'Assessed value not recorded by the county',
  land_value:           'Land value not recorded by the county',
  improvement_value:    'Improvement value not recorded by the county',
  median_household_income: 'Median household income not held for this block group',
  total_population:        'Population not held for this block group',
  total_housing_units:     'Housing units not held for this block group',
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

// Plain-English gloss for a PARTIAL corroborator, so "partially independent" reads as a specific
// observation, not a hedge. A $706,819 permit with no description in the seawall's build year is
// "a large permit in the right year, but nothing identifies it as seawall work" — not "maybe".
function partialGloss(c, improvement) {
  const impWord = improvement ? String(improvement).replace(/[,(].*$/, '').trim() : 'this';
  if (c.work_matches) return `a permit describing matching work in the same year — the assessor may have used it to set the date`;
  const amt = Number(c.amount) || 0;
  if (amt >= 50000) return `a large permit ($${amt.toLocaleString('en-US')}) in the same year, but nothing identifies it as ${impWord} work`;
  return `a permit in the same year, but nothing identifies it as ${impWord} work`;
}

function valueLabel(predicate, value) {
  const n = (v) => Number(v).toLocaleString('en-US');
  switch (predicate) {
    case 'area_sqft':            return `${n(value)} sq ft`;
    case 'built_year':           return `built ${value}`;
    case 'grade':                return `grade ${value}`;
    case 'replacement_cost_new': return `$${n(value)} replacement cost new`;
    case 'depreciated_value':    return `$${n(value)} depreciated value`;
    case 'pct_depreciated':      return `${value}% depreciated`;
    case 'service_life_vs_age':  return Number(value) >= 0
      ? `${value} yr of assessed service life remaining`
      : `${Math.abs(Number(value))} yr past assessed service life`;
    case 'in_sfha':              return value === true ? 'In a Special Flood Hazard Area' : 'Not in a Special Flood Hazard Area';
    case 'base_flood_elevation_ft': return `${value} ft`;
    case 'just_value':
    case 'assessed_value':
    case 'land_value':
    case 'improvement_value':    return `$${n(value)}`;
    case 'median_household_income': return `$${n(value)}`;
    case 'total_population':      return n(value);        // predicate label carries the noun
    case 'total_housing_units':  return n(value);
    default: return String(value);
  }
}

export function renderFact(rec) {
  const empty = { label: 'Data unavailable', hasValue: false, provenance: null,
                  corroboration: [], openQuestions: [], contradictions: [] };
  if (!rec || typeof rec !== 'object' || rec.error) return empty;

  // Value deliberately WITHHELD — we hold a figure but rendering it would imply provenance/precision we
  // lack (a ground elevation with no recorded vertical datum). Render the asymmetry statement, NEVER the
  // number, and never a number-with-caveat. Distinct from not_recorded: we DO have a value, and we're
  // choosing not to show it because it can't be honestly qualified.
  if (rec.field_status === 'value_withheld') {
    return { ...empty, label: rec.note || 'Value withheld — insufficient provenance to render it honestly.' };
  }
  // Rule 1 — absent (or not-derived) value renders a fixed string, no source line, no narration.
  if (rec.field_status === 'not_recorded' || rec.field_status === 'not_derived' || rec.value == null) {
    return { ...empty, label: NULL_STRINGS[rec.predicate] || 'Not recorded by the county' };
  }

  const corrob = Array.isArray(rec.corroborators) ? rec.corroborators : [];
  // A value can be RECORDED (a source), DERIVED (arithmetic on records), or OUR INFERENCE (analysis tier).
  // The last must never read as the county's — it carries no external authority.
  const isOurInference = rec.source_tier === 'analysis_inference' || !!(rec.derivation && rec.derivation.our_inference);
  // Rule 3 — provenance carries source_count / tier / date / derivation, never a confidence score.
  const provenance = {
    source: rec.source, tier: rec.source_tier, as_of: rec.as_of,
    source_count: 1 + corrob.length, note: rec.note || null,
    derivation: rec.derivation || null,   // present => this value is COMPUTED, not recorded — it declares itself
    is_our_inference: isOurInference,
  };
  // Rule 2 — corroboration labelled by independence status; 'partial' carries a specific gloss.
  const improvement = rec.subject && rec.subject.improvement;
  const corroboration = corrob.map((c) => ({
    text: c.value,
    independence: independenceLabel(c.independence_status),
    caveat: c.independence_status === 'partial' ? (c.qualifier_note || null) : null,
    gloss:  c.independence_status === 'partial' ? partialGloss(c, improvement) : null,
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

// Render a whole marine block (get_parcel_marine_block output): each improvement's predicates rendered,
// its cross-examination open questions surfaced, and the material caveat carried from DEF-023 (the
// registry, not restated prose — consistent with the disclosure work).
export function renderMarineBlock(block) {
  if (!block || !Array.isArray(block.improvements)) return { parcel: block?.parcel ?? null, improvements: [], material: null };
  const improvements = block.improvements.map((imp) => {
    const facts = imp.facts || {};
    return {
      improvement: imp.improvement,
      built: imp.built,
      rendered: Object.fromEntries(Object.entries(facts).map(([pred, rec]) => [pred, renderFact(rec)])),
      openQuestions: Object.values(facts).flatMap((rec) =>
        rec && Array.isArray(rec.open_questions) ? rec.open_questions.map((q) => q.question) : []),
    };
  });
  const oq = block.open_questions || {};
  return renderMarineBlockInner(block, improvements);
}
function renderMarineBlockInner(block, improvements) {
  const oq = block.open_questions || {};
  return {
    parcel: block.parcel,
    fieldStatus: block.field_status || null,
    // Block-level roll-up: the HEADLINE finding, so the page never has to walk improvements to find the story.
    openQuestions: {
      count: oq.count || 0,
      headline: oq.headline || null,
      items: (Array.isArray(oq.items) ? oq.items : []).map((q) => q.question),
    },
    improvements,
    material: block.material_disclosure ? { kind: 'source_limit', text: block.material_disclosure.disclosure } : null,
  };
}

// Contamination facilities (get_parcel_contamination_facilities). On-parcel and active-remediation
// facilities are NAMED findings, never folded into an "N tanks nearby" count. cleanup_status=null is
// THE finding (a closed station with no recorded cleanup), rendered as a question — never blank, never
// "no cleanup needed" (the null_as_value defect that made "12 tanks, not alarming" possible). Ranked
// active-first, then distance. Both DEP URLs (documents + watch) surface where held.
export function renderContaminationFacilities(block) {
  if (!block || block.field_status !== 'present') return { facilities: [], areaContext: null };
  // distance is already US-units (distance_ft) from the resolver — no metric field reaches this render.
  const facilities = (Array.isArray(block.promoted) ? block.promoted : []).map((f) => ({
    name: f.name,
    onParcel: !!f.on_parcel,
    where: f.on_parcel ? 'on this parcel' : `${f.distance_ft ?? '—'} ft away`,
    type: f.facility_type || null,
    status: f.facility_status || null,
    remediation: f.remediation_status === 'ACTIVE' ? 'ACTIVE remediation'
      : (f.remediation_status ? `remediation ${f.remediation_status}` : null),
    // null cleanup is the finding, rendered as a question — NOT blank, NOT "no cleanup needed".
    cleanup: f.cleanup_status ? `cleanup status: ${f.cleanup_status}`
      : 'no cleanup status on record with FDEP — a closed site with no recorded remediation is a question for the seller',
    documentsUrl: f.documents_url || null,
    watchUrl: f.watch_url || null,
  }));
  const ac = block.area_context || {};
  return {
    facilities,
    areaContext: (ac.tank_facilities_within_500m || ac.cleanup_sites_within_500m)
      ? { tanks: ac.tank_facilities_within_500m || 0, cleanups: ac.cleanup_sites_within_500m || 0 } : null,
  };
}

// Flood renders differently from marine: the SFHA DETERMINATION is the subject (it triggers the federal
// insurance mandate), and zone/BFE/% hang off it. A coverage gap is a fact about OUR knowledge
// ("not established"), NEVER about the parcel ("not in a flood zone" — the St Pete failure). FEMA is a
// singular authority, so corroboration is correctly empty. The datum is surfaced; the elevation-above-BFE
// comparison is withheld AND the asymmetry is made visible (parcel_elevations carries no datum).
export function renderFloodBlock(block) {
  const empty = { fieldStatus: null, determination: null, bfe: null, elevationComparison: null, zones: [], datum: null };
  if (!block) return empty;
  const d = block.determination || {};
  const notEstablished = d.field_status === 'not_established';
  const inSfha = d.value === true;
  const determination = {
    established: !notEstablished,
    inSfha: notEstablished ? null : inSfha,
    label: notEstablished
      ? 'Flood determination not established — a coverage gap about our data, not the parcel'
      : (inSfha ? 'In a Special Flood Hazard Area' : 'Not in a Special Flood Hazard Area'),
    headline: d.determination_note || null,   // authored copy: mandate / not-in-SFHA / about-us
    tier: d.source_tier || null,              // federal_regulatory
    source: notEstablished ? null : (d.source || null),
    corroboration: [],                        // singular authority — none exists or may
  };
  const b = block.base_flood_elevation;
  const bfe = b && b.field_status === 'present'
    ? { label: `${b.value} ft${b.vertical_datum ? ` ${b.vertical_datum}` : ''}`, datum: b.vertical_datum || null }
    : null;
  const e = block.elevation_above_bfe;
  const elevationComparison = e && e.field_status === 'not_computed'
    ? { withheld: true, reason: (e.derivation && e.derivation.note) || null }
    : null;
  return {
    fieldStatus: block.field_status || null,
    determination, bfe, elevationComparison,
    zones: Array.isArray(block.zones) ? block.zones : [],
    datum: block.vertical_datum || null,
  };
}

// Values block (get_pir_report.values.valuesFacts). Each dollar figure is a value FACT with its OWN
// provenance rendered explicitly: which roll (2026 CAMA vs 2025 NAL) and which authority. The per-field
// as_of is load-bearing — a parcel can carry a CAMA 2026 just value beside an NAL 2025 land value, and a
// block-level year would MISDATE one of them, so the asymmetry is surfaced, never silently reconciled.
// corroborators are always [] here BY DESIGN: CAMA and NAL share DOR lineage (derives_from), so one is
// not an independent witness of the other — a same-lineage "agreement" is not corroboration. No score.
const VALUE_FIELDS = [
  ['justValue',        'just_value'],
  ['assessedValue',    'assessed_value'],
  ['landValue',        'land_value'],
  ['improvementValue', 'improvement_value'],
];
export function renderValuesBlock(valuesFacts) {
  if (!valuesFacts || typeof valuesFacts !== 'object') return { fields: [], rollSpan: null };
  const fields = VALUE_FIELDS.map(([key, pred]) => {
    const rec = valuesFacts[pred] || null;
    return {
      key, predicate: pred,
      rendered: renderFact(rec),
      asOf: rec && rec.field_status === 'present' ? (rec.as_of || null) : null,
    };
  });
  // The roll-year span is a fact about OUR sources, not a number to reconcile. If the present fields
  // disagree on roll, say so plainly and show every roll in play.
  const years = [...new Set(fields.map((f) => f.asOf).filter(Boolean))];
  const rollSpan = years.length > 1
    ? { mixed: true, years,
        note: `These figures come from different rolls (${years.join('; ')}). They are shown as recorded, not reconciled to a single year.` }
    : { mixed: false, years, note: years[0] || null };
  return { fields, rollSpan };
}

// Census renders UNLIKE every block before it: the SUBJECT IS THE BLOCK GROUP, not the parcel. A record
// shaped "parcel · median_household_income" is wrong no matter how carefully it's caveated — it asserts a
// property has an income. So the geography is NAMED in every render ("In this census block group
// (GEOID …), median household income is $X"), the parcel's contained_within relationship is its own
// stated fact, and the tier is federal_statistical — a 5-year SAMPLE estimate, not a measurement, a roll,
// or a determination. The Census Bureau publishes a margin of error we do NOT hold; that is said plainly
// on each figure and never invented (the elevation-fabrication shape). A coverage gap is a fact about OUR
// data ("not established"), never about the parcel. This is where DEF-014 (resolution mislabelling) is
// either committed or prevented — at the render.
const CENSUS_FIELDS = [
  ['medianHouseholdIncome', 'median_household_income'],
  ['population',            'total_population'],
  ['housingUnits',          'total_housing_units'],
];
export function renderCensusBlock(cf) {
  const empty = { established: false, geography: null, containment: null, fields: [], coverageNote: null, vintage: null };
  if (!cf || typeof cf !== 'object') return empty;
  if (cf.field_status !== 'present') {
    return { ...empty, coverageNote: cf.coverage_note
      || 'Census figures not established for this parcel — a gap in our coverage, not a statement about the parcel.' };
  }
  const geo = cf.geography || {};
  const fields = CENSUS_FIELDS.map(([key, pred]) => ({
    key, predicate: pred, rendered: renderFact((cf.facts || {})[pred] || null),
  }));
  // The vintage note is shared by all fields — surface it once, at block level. If the vintage is
  // unconfirmed, the as_of string already says so; the note carries the how-we-know.
  const anyRec = Object.values(cf.facts || {}).find((r) => r && r.field_status === 'present');
  const vintage = anyRec ? { asOf: anyRec.as_of || null, note: anyRec.vintage_note || null } : null;
  return {
    established: true,
    // geography is NAMED — the render must never show a figure without the block group it belongs to.
    geography: { geoid: geo.geoid || null, name: geo.name || null, containsParcel: geo.contains_parcel || null },
    containment: cf.containment
      ? { text: cf.containment.value, source: cf.containment.source, tier: cf.containment.source_tier }
      : null,
    fields,
    coverageNote: cf.coverage_note || null,
    vintage,
  };
}
