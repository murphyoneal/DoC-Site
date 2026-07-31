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

// Owners are the first MULTI-VALUED fact: one fact PER OWNER, never one fact with a list. Each owner is
// anchored on (parcel, ownseq) — never the NAME, which is a reported value (noisy from data entry,
// legitimately changes over time) and must never be a join key. PCTOWN is rendered EXACTLY as recorded and
// NEVER normalized: under tenancy by the entirety each owner holds 100%, so two names totalling 200 is
// CORRECT, not a data error — any code that sums/divides/"fixes" it is wrong. The parcel carries its own
// owner_count fact ("two owners of record"), which a single-owner render destroys. as_of is load-bearing:
// CAMA is the live county file; a DOR/NAL owner is a 1-January snapshot that can lag a recorded deed by
// ~19 months. corroborators [] by default (CAMA/NAL share DOR lineage); a Clerk deed would be the one
// genuine second witness — not wired yet.
export function renderOwnersBlock(of) {
  const empty = { established: false, ownerCount: null, owners: [], tenancy: null, coverageNote: null };
  if (!of || typeof of !== 'object') return empty;
  if (of.field_status !== 'present') {
    return { ...empty, coverageNote: of?.coverage_note
      || 'No owner of record is established for this parcel — a gap in our coverage, not a statement about the parcel.' };
  }
  const owners = (Array.isArray(of.owners) ? of.owners : []).map((rec) => {
    const rf = renderFact(rec);   // reuse the provenance + no-confidence-score discipline
    return {
      ownseq: rec.subject?.ownseq ?? null,   // the anchor — NOT the name
      name: rec.value ?? null,
      nameDetail: rec.name_detail ?? null,
      pctOwn: rec.pct_own ?? null,           // AS RECORDED — never summed, divided, or normalized
      ownershipType: rec.ownership_type ?? null,
      ownershipType2: rec.ownership_type2 ?? null,
      provenance: rf.provenance,
    };
  });
  const oc = of.owner_count || null;
  return {
    established: true,
    ownerCount: oc ? { value: oc.value ?? null, note: oc.note ?? null, asOf: oc.as_of ?? null, tier: oc.source_tier ?? null } : null,
    owners,
    tenancy: of.tenancy ? { form: of.tenancy.form ?? null, note: of.tenancy.note ?? null } : null,
    coverageNote: of.coverage_note || null,
  };
}

// Transactions: every recorded conveyance is kept (deleting the $100 transfers breaks the deed chain), but
// the QUALIFICATION gates how the money reads. A market sale's number is a SALE PRICE; a quit-claim /
// certificate-of-title / unqualified / nominal transfer's number is CONSIDERATION and never a price. Two
// separate qualification facts travel with each sale: the county's (sale_qualification, county tier) and
// OURS (market_signal, analysis_inference) — and where we downgrade a technically-qualified sale, that
// note is visibly ours. The most recent MARKET sale is the value-relevant one; if there is none, that is
// stated as a fact about the record, not a value estimate. Multi-parcel sales are flagged (the price is
// the bundle's, not this parcel's). No confidence score.
export function renderTransactionsBlock(tf) {
  const empty = { established: false, count: 0, conveyances: [], lastMarketSale: null, coverageNote: null };
  if (!tf || typeof tf !== 'object') return empty;
  if (tf.field_status !== 'present') {
    return { ...empty, coverageNote: tf?.coverage_note
      || 'No recorded conveyance history is established for this parcel — a gap in our coverage, not a statement about the parcel.' };
  }
  const one = (c) => {
    const isSale = c.price_role === 'sale_price';
    // The money lives on the key that NAMES it: sale_price for a market sale, consideration otherwise.
    // They are mutually exclusive, so a $100 quit-claim can never be read as a sale price.
    const money = isSale ? c.sale_price : c.consideration;
    return {
      date: c.date ?? null,
      instrumentType: c.instrument_type ?? null,
      grantor: c.grantor ?? null,
      grantee: c.grantee ?? null,
      saleType: c.sale_type ?? null,
      instrument: c.instrument_number ?? null,
      book: c.book ?? null, page: c.page ?? null,
      // GATING: a market sale reports a price; everything else reports consideration and says why.
      priceRole: isSale ? 'sale_price' : 'consideration',
      salePrice: c.sale_price ?? null,
      consideration: c.consideration ?? null,
      amount: money ?? null,
      amountLabel: money == null ? null
        : (isSale ? `$${Number(money).toLocaleString('en-US')}`
                  : `$${Number(money).toLocaleString('en-US')} consideration`),
      nominal: !!c.nominal,
      nominalReason: c.nominal_reason ?? null,
      multiParcel: !!c.multi_parcel,
      parcelsOnInstrument: c.parcels_on_instrument ?? null,
      // county qualification (theirs) and our market-signal reading (ours) — kept distinct.
      qualificationCounty: c.sale_qualification?.value ?? null,
      qualificationTier: c.sale_qualification?.source_tier ?? null,
      marketSignal: c.market_signal?.value ?? null,        // 'market' | 'non_market'
      marketSignalTier: c.market_signal?.source_tier ?? null,   // analysis_inference — OURS
      ourNote: c.market_signal?.note ?? null,              // set only when we disagree with the county
      legalCrossReference: c.legal_cross_reference?.note ?? null,
    };
  };
  const conveyances = (Array.isArray(tf.conveyances) ? tf.conveyances : []).map(one);
  const lm = tf.last_market_sale ? one(tf.last_market_sale) : null;
  return {
    established: true,
    count: tf.count ?? conveyances.length,
    conveyances,
    lastMarketSale: lm,   // the value-relevant sale; null when no qualified market sale exists
    lastMarketSalePrice: tf.last_market_sale_price ?? (lm ? lm.salePrice : null),
    lastMarketSaleDate: tf.last_market_sale_date ?? (lm ? lm.date : null),
    coverageNote: tf.coverage_note || null,   // e.g. "no qualified market sale on record"
  };
}

// Permits: the SUBJECT IS THE PERMIT (number/date/authority), attached to the parcel by key — never made a
// claim about a structure (that inference lives in the marine cross-exam). CLOSEOUT is a disclosure, not
// history: a dated completion => finaled; otherwise "closeout not recorded" is surfaced as an AFFIRMATIVE
// line (an authorized-but-unfinaled permit can be inherited at closing), never "open" and never "closed" —
// the numeric STATUS code is opaque/uncrosswalked and is NOT decoded. AMOUNT is DECLARED value, not cost.
// The contractor licence is checked AS OF THE PERMIT DATE against DBPR (a different agency = an independent
// witness); a licence inactive on the permit date is a FINDING, an active one is corroboration. No score.
export function renderPermitsBlock(pf) {
  const empty = { established: false, count: 0, closeoutNotRecordedCount: 0, permits: [], coverageNote: null };
  if (!pf || typeof pf !== 'object') return empty;
  if (pf.field_status !== 'present') {
    return { ...empty, coverageNote: pf?.coverage_note
      || 'No permit history is established for this parcel — a gap in our coverage, not a statement about the parcel.' };
  }
  const permits = (Array.isArray(pf.permits) ? pf.permits : []).map((p) => {
    const co = p.closeout || {};
    const cl = p.contractor_licence || null;
    const dv = p.declared_value;
    return {
      date: p.date ?? null,
      number: p.permit_number ?? null,
      issuingAuthority: p.issuing_authority ?? null,
      workDescription: p.work_description ?? null,
      contractor: p.contractor ?? null,
      declaredValue: dv ?? null,
      // declared, not cost — the label says so
      declaredValueLabel: dv == null ? null : `$${Number(dv).toLocaleString('en-US')} declared`,
      closeout: {
        finaled: co.field_status === 'present',
        finaledDate: co.finaled_date ?? null,
        // affirmative disclosure line when closeout is not on record (never "open"/"closed")
        disclosure: co.field_status === 'not_recorded' ? (co.disclosure ?? null) : null,
      },
      contractorLicence: cl && cl.matched ? {
        matched: true,
        activeAtPermitDate: cl.active_at_permit_date ?? null,
        checkedAsOf: cl.checked_as_of ?? null,
        finding: cl.finding ?? null,             // set only when the licence was inactive on the permit date
        corroboration: cl.corroboration ?? null, // set only when it was active — an independent witness
        licenseNumber: cl.license_number ?? null,
      } : (cl && cl.matched === false ? { matched: false, note: cl.note ?? null } : null),
    };
  });
  return {
    established: true,
    count: pf.count ?? permits.length,
    closeoutNotRecordedCount: pf.closeout_not_recorded_count ?? 0,   // the disclosure roll-up, all ages equal
    permits,
    coverageNote: pf.coverage_note || null,
  };
}

// Zoning (get_parcel_zoning_facts). Two DIFFERENT facts, never merged: zoning is what may be built NOW;
// future land use is what the comprehensive plan says the area should BECOME. The code is the
// jurisdiction's OWN vocabulary and is NEVER normalized into a national taxonomy — "B-5" in Ocala and
// "B-5" in DeLand are unrelated, and normalizing them would be the fabrication class in a new costume.
// Municipal zoning overrides county zoning inside city limits (the resolver applies precedence; the render
// surfaces which jurisdiction governs). A code with no definition is half a fact — show the description
// where held, else say the code is recorded without a definition and point at the land development code.
function renderZoningFact(f) {
  if (!f) return null;
  // SENTINEL: the county disclaims jurisdiction ("999"/"INCORPORATED") — that is not a code, it is the
  // county pointing at a municipality whose layer we don't hold. Render the coverage gap NAMING the city,
  // never the sentinel value (the -9999/null-means-absence class).
  if (f.field_status === 'municipal_not_held') {
    return { code: null, municipalNotHeld: true, incorporatedIn: f.incorporated_in ?? null,
             jurisdiction: f.jurisdiction ?? null, coverageNote: f.coverage_note ?? null, tier: f.source_tier ?? null };
  }
  return {
    code: f.value ?? null,                     // the jurisdiction's own code, verbatim — never normalized
    description: f.description ?? null,         // null => definitionNote carries the honest caveat
    jurisdiction: f.jurisdiction ?? null,
    jurisdictionLevel: f.jurisdiction_level ?? null,
    source: f.source ?? null,
    definitionUrl: f.definition_url ?? null,
    definitionNote: f.definition_note ?? null, // the "code without a definition" caveat
    // A value we could NOT evidence as a real category — a suspected jurisdiction placeholder we did not
    // confirm (Charlotte "City", Clay "MUNI", Seminole "CITY", Miami-Dade "NONE"). Say so IN THE OUTPUT,
    // not just the registry: the reader sees the value verbatim AND the honest "we couldn't confirm this".
    unconfirmedNote: f.unconfirmed_note ?? null,
    municipalNote: f.note ?? null,             // "municipal zoning governs, not the county code"
    tier: f.source_tier ?? null,
  };
}
// Sinkhole (get_parcel_sinkhole_facts). DOCUMENTED subsidence incidents (Florida Geological Survey) near
// the parcel — area CONTEXT, never a per-parcel prediction, and NEVER a "risk score" (that fabricated
// constant was the property_environmental purge). The verified flag is the county's own FGS value, shown as
// what it means: Y confirmed / N investigated-not-a-sinkhole / U unverified report. A coverage gap is about
// OUR data ("no layer held"), never "no sinkhole risk" — Florida's karst risk is statewide. US units (ft).
const VERIFIED_LABEL = { Y: 'a confirmed sinkhole', N: 'investigated and found not to be a sinkhole', U: 'an unverified report' };
export function renderSinkholeBlock(sf) {
  const empty = { established: false, nearest: null, within1mi: 0, withinQuarterMi: 0, verifiedWithin1mi: 0, coverageNote: null };
  if (!sf || typeof sf !== 'object') return empty;
  if (sf.field_status !== 'present') {
    return { ...empty, coverageNote: sf?.coverage_note
      || 'No sinkhole-incident layer is held for this county — a gap in our coverage, not a statement that the parcel has no sinkhole risk.' };
  }
  const n = sf.nearest || {};
  const vf = n.verified ? String(n.verified).toUpperCase() : null;
  return {
    established: true,
    nearest: n.distance_ft != null ? {
      distanceFt: n.distance_ft,
      eventDate: n.event_date ?? null,
      verified: vf,
      verifiedLabel: (vf && VERIFIED_LABEL[vf]) || 'a report of unrecorded status',
      depth: n.depth ?? null,
    } : null,
    within1mi: sf.incidents_within_1mi ?? 0,
    withinQuarterMi: sf.incidents_within_quarter_mi ?? 0,
    verifiedWithin1mi: sf.verified_within_1mi ?? 0,
    note: sf.note ?? null,
    coverageNote: null,
  };
}

export function renderZoningBlock(zf) {
  const empty = { established: false, zoning: null, futureLandUse: null, relationship: null, coverageNote: null };
  if (!zf || typeof zf !== 'object') return empty;
  if (zf.field_status !== 'present') {
    return { ...empty, coverageNote: zf?.coverage_note
      || 'Zoning not established for this parcel — a gap in our coverage, not a statement about the parcel.' };
  }
  return {
    established: true,
    zoning: renderZoningFact(zf.zoning),
    futureLandUse: renderZoningFact(zf.future_land_use),
    relationship: zf.relationship?.note || null,   // stated, not a computed disagreement (no taxonomy)
    coverageNote: zf.coverage_note || null,
  };
}

// Land-use RESTRICTIONS (get_parcel_restrictions): a delineated Groundwater Contamination Area (Ch. 62-524,
// FDOH-enforced, criminal penalty for a new potable well), a recorded institutional control, or a regulated
// well physically on the parcel. This is a state_regulatory CONSTRAINT ON THE PROPERTY — treated like the
// flood mandate, a CONTAINMENT finding, never area context and never a distance/score. The resolver already
// distinguishes well-in-GWCA (material exposure) from no-well (municipal water unaffected); we surface its
// caveat verbatim. CRITICAL absence rule: an empty result is NOT a clearance. Our registers record what was
// discovered and regulated; a former grove, a pre-1975 pit, or a cattle dip vat can leave contamination that
// no register carries — the honest absence statement says exactly that (historic use, not current condition).
const RESTRICTION_LABEL = {
  gwca_restriction: 'Groundwater Contamination Area (well-drilling restriction)',
  institutional_control: 'Recorded institutional control',
  well_in_institutional_control: 'Regulated well inside an institutional-control area',
};
export function renderRestrictionsBlock(arr) {
  const absenceNote = 'No delineated groundwater-contamination area, recorded institutional control, or regulated on-parcel well is present in the layers we hold. This is not a clearance: our registers record only what has been discovered and regulated, so a former grove, a pre-1975 pit, or a cattle dip vat can leave contamination that no register carries — absence here means "not in a mapped restriction," never "clean."';
  if (!Array.isArray(arr) || arr.length === 0) return { established: false, items: [], absenceNote };
  const items = arr.map((r) => ({
    field: r.field ?? null,
    label: (r.field && RESTRICTION_LABEL[r.field]) || 'Recorded land-use restriction',
    value: r.value ?? null,                          // the jurisdiction's own statement, verbatim
    caveat: r.coverage_caveat ?? null,               // the resolver's three-case well caveat, surfaced as-is
    authority: r.authority ?? null,                  // FDEP
    source: r.source ?? null,
    relation: r.relation ?? null,                    // contains | intersects — stated, not softened
    wellsOnParcel: r.wells_on_parcel ?? null,
    wellsInGwca: r.wells_in_gwca ?? null,
    asOf: r.as_of ?? null,
    tier: 'state_regulatory',                        // a state constraint on the property, like the flood mandate
  }));
  return { established: true, items, absenceNote: null };
}

// Brownfield (get_parcel_brownfield_facts). A FINDING, not a supporting layer, and it pairs with on-parcel
// contamination: a brownfield is a site FDEP designated for redevelopment because real/perceived contamination
// complicates reuse — a cleanup INCENTIVE and a prior-contamination DISCLOSURE at once. Being inside a
// designated AREA (polygon, containment) is the finding; nearby SITES (points, proximity) are area context,
// never an on-parcel condition — the two-geometry-class rule. remediation_status carries sentinels the
// resolver already scrubbed to null; when null we show WHY (not recorded ≠ clean), never a blank. Absence is
// NOT a clearance (a designation is voluntary; prior contamination can sit on parcels never designated).
export function renderBrownfieldBlock(bf) {
  const absenceDefault = 'Not inside, and no FDEP brownfield site within a mile of, any designated brownfield area we hold — not a clearance, since designation is voluntary and prior contamination can exist on parcels never designated.';
  if (!bf || typeof bf !== 'object' || (bf.field_status !== 'present' && bf.field_status !== 'none_nearby')) {
    return { established: false, insideArea: null, nearestArea: null, sites: null,
             coverageNote: bf?.coverage_note || absenceDefault };
  }
  if (bf.field_status === 'none_nearby') {
    return { established: false, insideArea: null, nearestArea: null, sites: null, coverageNote: bf.coverage_note || absenceDefault };
  }
  const ia = bf.inside_area, na = bf.nearest_area, ns = bf.nearby_sites, nsn = ns?.nearest;
  return {
    established: true,
    insideArea: ia ? { name: ia.name ?? null, resolutionNumber: ia.resolution_number ?? null,
      resolutionDate: ia.resolution_date ?? null, acreageAc: ia.acreage_ac ?? null, county: ia.county ?? null,
      source: ia.source ?? null } : null,
    nearestArea: na ? { name: na.name ?? null, distanceFt: na.distance_ft ?? null, county: na.county ?? null } : null,
    sites: ns ? { countWithin1mi: ns.count_within_1mi ?? 0, nearest: nsn ? {
      name: nsn.name ?? null, distanceFt: nsn.distance_ft ?? null,
      remediationStatus: nsn.remediation_status ?? null,      // null => the note explains "not recorded, not clean"
      remediationStatusNote: nsn.remediation_status_note ?? null,
      siteAddress: nsn.site_address ?? null, verificationDate: nsn.verification_date ?? null } : null } : null,
    note: bf.note ?? null,
    tier: bf.source_tier ?? 'government_derived',
    coverageNote: null,
  };
}
