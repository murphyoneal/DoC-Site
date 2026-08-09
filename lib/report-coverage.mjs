// lib/report-coverage.mjs
// Pure copy + state logic for the coverage-aware report blocks (marine improvements, tax-deed
// status). No JSX and no DB, so report-coverage.test.mjs can assert the exact words each state
// renders — in plain node, no site/keys/env. The PIR page renders FROM this module, so the test
// asserts what actually ships (they cannot drift).
//
// Why this exists: the marine block passed `tsc` but its rendered output was never seen — the same
// shape as the fabricated wind dial (a rule satisfied at the type level while the output goes
// unverified). The load-bearing rule: a `not_available` (coverage gap) must NEVER read as an
// affirmative negative finding. "We don't hold this county's file" is not "this parcel has no dock"
// / "no tax exposure". These phrases are banned from any coverage-gap copy and the test enforces it.

export const FORBIDDEN_IN_COVERAGE_GAP = [
  'no dock', 'no seawall', 'no structure', 'none', 'no tax exposure',
  'not for sale', 'no marine', 'free of tax', 'no exposure',
  // flood: a coverage gap must never read as "not in a flood zone"
  'no flood zone', 'not in a flood', 'no flood risk', 'no special flood', 'outside the sfha', 'outside a special flood',
];

// True if `text` contains any banned phrase (case-insensitive). Used by the coverage-gap states
// and by the test as the negative control.
export function hasForbiddenCoverageGapPhrase(text) {
  const t = String(text || '').toLowerCase();
  return FORBIDDEN_IN_COVERAGE_GAP.some((p) => t.includes(p));
}

// THE LEAD ranking (spec v5 §0.1) — pure, so report-coverage.test.mjs asserts the exact order.
// The single most consequential regulatory fact, ordered by what a buyer must act on:
// contamination containment → SFHA flood mandate → GWCA well prohibition → institutional control →
// lead-paint duty → historic district. First present wins; contamination + GWCA combine (they are
// causally linked); ceiling of TWO clauses. none:true when nothing is present, so the page says so
// and points at §7 — silence must never read as clearance. Nothing here is originated.
export function selectLead(sig) {
  const s = sig || {};
  const clauses = [];
  if (s.contamOn) {
    clauses.push('on a designated contamination site');
    if (s.gwca) clauses.push('inside a groundwater-contamination area where new potable wells are prohibited');
  }
  if (clauses.length < 2 && s.inSfha) clauses.push(`in a FEMA Special Flood Hazard Area${s.sfhaZone ? ` (Zone ${s.sfhaZone})` : ''} — flood insurance is mandated with a federally-backed mortgage`);
  if (clauses.length < 2 && !s.contamOn && s.gwca) clauses.push('inside a groundwater-contamination area where new potable wells are prohibited');
  if (clauses.length < 2 && s.ic) clauses.push('subject to a recorded institutional control limiting site use');
  if (clauses.length < 2 && s.leadPaint) clauses.push(`built in ${s.yearBuilt} — pre-1978, so the federal lead-paint disclosure duty applies on sale or lease`);
  if (clauses.length < 2 && s.historic) clauses.push('within a listed historic district, which commonly triggers local review');
  const top = clauses.slice(0, 2);
  return { clauses: top, regulatory: top.join(', '), none: clauses.length === 0 };
}

// §3-vs-§4 split for contamination facilities (the hard rule: no distance above §4). On-parcel OR
// active-remediation is a fact about THIS ground → §3; everything else is proximity → §4.
export function isOnParcelContamination(f) {
  return !!(f && (f.onParcel || /ACTIVE/i.test(f.remediation || '')));
}

// Recursively collect the paths of distance-bearing fields with a non-null value. The test uses it
// to enforce §0.1's hard rule on the assembled §1–§3 view models: a distance there reads as "on the
// parcel". Deliberately does NOT match area units (sqft) — only proximity.
const DISTANCE_KEY = /distance|nearestwater|tortoisenearest|within\d*mi/i;
export function findDistanceKeys(obj, path = '') {
  const hits = [];
  if (obj == null || typeof obj !== 'object') return hits;
  for (const [k, val] of Object.entries(obj)) {
    const p = path ? `${path}.${k}` : k;
    if (val != null && (typeof val === 'number' || typeof val === 'string') && DISTANCE_KEY.test(k)) hits.push(p);
    else if (val && typeof val === 'object') hits.push(...findDistanceKeys(val, p));
  }
  return hits;
}

export function marineView(m) {
  const title = 'Marine improvements';
  if (!m || m.field_status === 'not_available') {
    return {
      mode: 'coverage_gap', title,
      note: 'Coverage gap, not a finding — the county assessor other-improvements file is held for Volusia only.',
      body: 'Whether this parcel has waterfront structures (a dock, seawall, boat house, lift or slip) is simply not known here — its absence is not evidence either way.',
    };
  }
  if (m.field_status === 'none_recorded') {
    return {
      mode: 'none_recorded', title,
      note: m.coverage_caveat || '',
      body: 'The county appraiser has assessed no marine improvement on this parcel. Unassessed, unpermitted or newly built structures may still exist.',
    };
  }
  return {
    mode: 'present', title,
    note: m.material_caveat || '',
    items: Array.isArray(m.items) ? m.items : [],
    basis: [m.waterfront_basis, m.service_life_basis].filter(Boolean).join(' '),
  };
}

export function floodView(f) {
  const title = 'Flood zone';
  const status = f && f.field_status;
  // Coverage gap OR unresolvable geometry → never render as absence of flood risk.
  if (!f || status === 'not_available' || status === 'parcel_not_resolved') {
    return {
      mode: 'coverage_gap', title,
      note: status === 'parcel_not_resolved'
        ? 'Flood zone was not evaluated — the parcel geometry could not be resolved. This is not a statement about flood risk.'
        : 'Coverage gap, not a finding — the county FEMA flood layer is not held for this parcel. Its absence here is not evidence about flood risk; check the FEMA Map Service Center (msc.fema.gov).',
      body: 'Whether this parcel lies in a Special Flood Hazard Area is not known here — its absence is not evidence either way.',
    };
  }
  if (status === 'none_intersecting') {
    return {
      mode: 'none_intersecting', title,
      note: 'The county flood layer was queried and no zone polygon intersects this parcel. For a complete NFHL extract that is unusual and may indicate a gap in the layer — verify at msc.fema.gov before concluding anything about flood risk.',
      body: '',
    };
  }
  // present
  return {
    mode: 'present', title,
    inSfha: f.in_sfha === true,
    bfe: f.base_flood_elevation_ft ?? null,
    datum: f.vertical_datum ?? null,
    layer: f.layer_used ?? null,
    zones: Array.isArray(f.zones) ? f.zones : [],
    note: 'Zone and BFE are from the county FEMA NFHL extract, not an elevation certificate. A parcel may span several zones; it is in an SFHA if ANY part lies in one.',
  };
}

export function taxDeedView(t) {
  const title = 'Tax-deed status';
  if (!t || t.field_status === 'not_available') {
    return {
      mode: 'coverage_gap', title,
      note: 'Coverage gap, not a finding — the county Lands Available for Taxes register is not held for this county.',
      body: 'Whether this parcel carries tax-deed exposure is not known here — its absence is not evidence either way.',
    };
  }
  if (t.field_status === 'not_on_list') {
    const asOf = t.as_of || null;
    return {
      mode: 'not_on_list', title, asOf,
      note: t.coverage_caveat || '',
      body: `This parcel does not appear on the Lands Available for Taxes register as of ${asOf || 'the snapshot date'}. That register lists only parcels that went unsold at a tax-deed auction; it does not speak to whether taxes are current or a certificate is outstanding.`,
    };
  }
  // present — as_of MUST render: a stale tax-deed listing acted on is worse than none.
  // Two money concepts stay distinct: opening bid (a floor) vs estimated purchase price
  // (Putnam's estimate of the total). Escheat is published-first, else computed+approximate,
  // never asserted. Availability is three states.
  return {
    mode: 'present', title, asOf: t.as_of || null,
    openingBid: t.opening_bid_usd ?? null,
    openingBidNote: t.opening_bid_is_a_floor || null,
    estimatedPrice: t.estimated_purchase_price ?? null,
    estimatedPriceNote: t.estimated_purchase_price_is_not_final || null,
    certificate: t.certificate_number || null,
    dateAvailable: t.date_available_to_public || null,
    availabilityStatus: t.availability_status || null,
    availabilityNote: t.availability_note || '',
    publishedEscheat: t.published_escheat_date || null,
    computedEscheat: t.statutory_escheat_date_computed || null,
    escheatSource: t.escheat_source || null,
    escheatNote: t.escheat_note || '',
    countyContactName: t.county_contact_name || null,
    countyContactPhone: t.county_contact_phone || null,
    meaning: t.meaning || '',
    staleness: t.staleness_warning || '',
    notLegalAdvice: t.not_legal_advice || '',
  };
}

// Source limitations — the get_pir_report `disclosures` array (from get_parcel_disclosures).
// A source/disclose defect is a FINDING about what the county's public record does and does not
// publish — NOT a coverage gap ("we don't hold this layer") and NOT a disclaimer. It has its own
// weight because a stated source limit is the thing no competitor produces. The page must render it
// as a finding, visually distinct from a `coverage_gap`. mode is 'source_limit', never 'coverage_gap'.
export function disclosuresView(disclosures) {
  const title = 'Source limitations';
  const items = (Array.isArray(disclosures) ? disclosures : [])
    .filter((d) => d && d.kind === 'source_limit' && d.disclosure)
    .map((d) => ({ defect_id: d.defect_id, text: d.disclosure }));
  if (items.length === 0) return { mode: 'none', title, items: [] };
  return {
    mode: 'source_limit', title,
    note: 'Stated limits of the public record itself — what the county source does not publish. ' +
      'A finding about the data, distinct from a layer we do not hold (a coverage gap).',
    items,
  };
}
