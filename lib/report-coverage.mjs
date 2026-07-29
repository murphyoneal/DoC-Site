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
];

// True if `text` contains any banned phrase (case-insensitive). Used by the coverage-gap states
// and by the test as the negative control.
export function hasForbiddenCoverageGapPhrase(text) {
  const t = String(text || '').toLowerCase();
  return FORBIDDEN_IN_COVERAGE_GAP.some((p) => t.includes(p));
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

export function taxDeedView(t) {
  const title = 'Tax-deed status';
  if (!t || t.field_status === 'not_available') {
    return {
      mode: 'coverage_gap', title,
      note: 'Coverage gap, not a finding — the county Lands Available for Taxes register is held for Volusia only.',
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
  return {
    mode: 'present', title, asOf: t.as_of || null,
    openingBid: t.opening_bid_usd ?? null,
    certificate: t.certificate_number || null,
    dateAvailable: t.date_available_to_public || null,
    meaning: t.meaning || '',
    staleness: t.staleness_warning || '',
    notLegalAdvice: t.not_legal_advice || '',
  };
}
