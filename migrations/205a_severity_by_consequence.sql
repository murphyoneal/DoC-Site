-- 205a - every active detection re-rated by CONSEQUENCE, and the launch flip recorded (ruling 936).
--
-- 936: the scale was saturated - 113 of 201 active detections were 'blocking' (81 of the expect-clean ones). "A severity
-- with no rule for what earns each level becomes a single level with three names." The levels, by consequence:
--   blocking = a user can read a false statement TODAY, or money or data can be lost;
--   material = a fact is missing or weaker than we claim, and a user would want to know;
--   cosmetic = neither.
-- "Today" means what a user can reach on 2026-10-02. That is the public contractor register (search, /c, /e, lists, the
-- contact card), the agent register, the free report preview and Roz in alpha. The free preview serves only the address,
-- county, frame label and parcel state (measured). The paid report is parked: checkout refuses every request. So a false
-- statement that exists ONLY on the paid report is material today. blocking_at_launch = true records that it becomes
-- blocking the day checkout opens, so the scale cannot silently understate on launch day.
-- Four read-only agents rated against these definitions, one line of basis each. cc spot-verified:
--   - the preview payload's keys;
--   - anon has no SELECT on the tables behind the anon-executable get_parcel_permit_facts / owner_join_key (all RLS, no grant).
-- One agent claim was corrected: register-row-field-shifted's 3 rows are NOT live (active=false, 0 served). Its detection
-- reads withdrawn rows; 205b fixes that.
-- RESULT: blocking 18, material 151, cosmetic 32. All 18 blocking rows are guards. Two are red today, and both are
-- detection defects (205b). Blocking defects live today: 0.

alter table public.data_defect_registry add column if not exists severity_basis text;
alter table public.data_defect_registry add column if not exists blocking_at_launch boolean;
comment on column public.data_defect_registry.severity_basis is
  '205a (ruling 936): why this severity, against the consequence definitions (blocking = a false statement readable today or loss; material = a fact missing or weaker than claimed; cosmetic = neither).';
comment on column public.data_defect_registry.blocking_at_launch is
  '205a (ruling 936): true when the defect is (or would be) a false statement or a loss on a surface that opens with the paid report. Re-read its severity as blocking the day checkout opens.';

create temp table _rate (defect_id text primary key, severity text not null, blocking_at_launch boolean not null, basis text not null) on commit drop;
insert into _rate values
('absence-claim-source-missing-temporal-extent','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('active-source-never-fetched','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('agent-register-search-anon-execute-missing','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('agent-register-status-orphans-must-not-read-as-inactive','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('amenity-features-null-co-no-keytypes','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('amenity-school-type-includes-non-k12','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('anon-callable-secdef-functions','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('anon-or-authenticated-hold-truncate','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('anon-reachable-table-grant-unexpected','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('assistant-log-records-nothing','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('bfe-missing-column-served-as-not-recorded','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('bfe-null-where-the-column-is-absent-not-where-fema-published-none','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('blank-not-null-defeats-a-populated-test','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('brownfield-served-volusia-only','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('business-name-cardinality-unruled','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('business-register-integrity','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('cadence-dead-source','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('cama-date-century-pivot-moves-with-the-clock','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('cama-is-a-table-set-resolved-as-a-single-layer','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('cama-key-hygiene-sweep-five-counties','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('cama-ragged-row-quarantine-accounting','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('cama-role-concept-must-resolve-exactly-one-table','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('cama-table-loaded-but-unregistered','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('chha-not-wireable-as-one-concept','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('citrus-sumter-firm-exact-thousand-truncation-suspect','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('citylimits-weeki-wachee-disincorporated','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('claim-row-leaks-into-finding-readers','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('coastal-only-concept-on-inland-parcel','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('cohort-source-and-serving-source-disagree','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('collier-child-table-parcelid-leading-zeros-stripped','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('collier-legal-description-assembled-from-ordered-fragments','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('collier-utf8-bom-on-every-file','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('column-default-asserts-unasked-fact','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('column-map-points-at-a-column-that-answers-nothing','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('compat-views-pending-retirement','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('concept-registered-but-unwired','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('confidence-score-table-contradicts-the-spec','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('confidentiality-flag-on-six-address-layers-undeclared','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('contamination-concepts-registered-but-unserved','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('contractor-name-truncated-at-30-characters','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('contractor-status-vocabulary-and-shape','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('contractors-county-vocabulary-drift','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('contractors-public-serves-street-or-rooftop-coordinates','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('county-layer-registry-misnamed-for-multilevel','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('county-name-saint-vs-st','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('county-parcel-keys-declared-without-measurement-six-of-ten-join-at-zero','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('county-parcel-layer-disagrees-with-the-statewide-spine-both-ways','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('cross-jurisdiction-layer-leak','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('data-quality-score-is-live-in-the-payload','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('declared-role-omits-an-ordinal-sibling-column','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('DEF-001','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('DEF-005','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('DEF-006','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('DEF-007','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('DEF-008','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('DEF-009','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('DEF-013','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('DEF-016','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('DEF-017','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('DEF-024','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('DEF-025','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('defect-detection-suite-not-completing','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('derived-deed-chain-behind-source','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('derived-flood-subdivision-matches-source','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('derived-permit-history-behind-source','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('detection-population-undeclared','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('disciplinary-history-asserted-without-source','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('disposition-vocabulary-contradicts-the-unchanged-record-rule','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('dor-ships-92043-keyless-geometry-only-polygons-at-co-no-zero','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('dor-use-code-descriptions-truncated-at-40-chars','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('duval-flood-zone-is-a-comma-separated-multi-zone-string','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('elevation-single-point-sample-unrepresentative','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('empty-encumbrance-array-reads-as-no-liens','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('entitlement-null-expiry-outside-owner-claim','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('entitlement-orphan-share','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('entitlement-sharing-abuse-signal','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('entitlement-wildcard-outside-subscription','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('erp-easement-type-is-technician-notes-not-a-classification','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('fdep-clm-no-contaminant-field','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('fdep-stcm-tank-ungeocoded-active-facility','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('fema-flood-zones-page-truncated','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('fgs-subsidence-voluntary-register','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('fixed-width-padding-loaded-intact-across-the-served-spine','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('flood-bfe-9999-sentinel-served-null','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('flood-column-map-points-at-an-internal-id-not-a-zone-code','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('flood-lake-county-name-trap','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('flood-zone-value-domain-is-not-uniform-across-67-layers','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('floodway-flag-column-holds-jurisdiction-names','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('fourteen-getters-emit-no-field-status','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('fuds-point-served-where-boundary-exists','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('fuds-state-stored-lowercase','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('geometry-resolution-served-path','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('get-pir-report-inline-volusia-coalesce','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('golden-report-within-production-timeout','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('gwca-orphaned-from-served-payload','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('handoff-status-pair-disagrees','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('hardcoded-county-branch-count-must-not-grow','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('hialeah-parcel-layer-loaded-twice-as-zoning-and-flu-carrying-owner-pii','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('i-declared-six-keys-unsolvable-and-all-six-were-solvable','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('inferred-hazard-flagged-as-requiring-disclosure','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('juridical-register-absent-from-the-payload','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('key-column-holds-prose-and-delimited-lists-not-one-key','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('layer-resolution-row-unverified','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('layer-trust-flags-stale','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('lens-same-topic-under-two-sections','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('licence-status-and-expiry-date-contradict-each-other','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('listed-species-habitat-is-three-counties-of-sixty-seven','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('live-false-statement-finding-unactioned','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('miamidade-municipal-zoning-inert-on-null-rowcount','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('miamidade-zoning-wired-to-unincorporated-only','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('municipal-boundary-annexation-lag','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('municipal-zoning-layers-hold-something-other-than-zoning','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('my-inference-backfill-put-a-3m-row-sales-register-under-amenity','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('named-owners-recorded-at-zero-percent-while-the-parcel-sums-to-unity','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('nhd-area-sub-in-sync','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('none-intersecting-renders-false-for-any-partial-coverage-layer','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('one-firm-published-as-two-tables-sfha-and-non-sfha-split','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('one-parcel-layer-loaded-twice-as-zoning-and-land-use','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('one-third-of-contractor-permit-matches-carry-their-own-ambiguity-flag','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('owner-and-contractor-names-truncated-across-three-derived-tables','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('ownership-served-path','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('palmbeach-null-confid-flag-reads-as-not-confidential','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('parcel-govt-source-two-schemas-two-different-keys','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('parcels-staging-geometry-read-not-aggregated','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('party-bearing-column-not-declared-in-the-column-map','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('pasco-per-file-staleness','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('payload-reports-gap-where-county-data-exists','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('payload-speaks-sixteen-absence-dialects','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('paywall-gate-not-enforced-deliberate','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('pcpao-assessor-flag-blank-is-not-negative','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('pcpao-format-staleness-divergence','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('pcpao-json-trailing-comma','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('pcpao-permit-date-sentinel-years','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('per-owner-path-hardcoded-to-one-county-pinellas-reports-one-owner-of-seventy-nine','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('permit-closeout-absence-served-as-signal-after-cliff','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('permit-completion-date-precedes-issue-date','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('permit-register-altkey-collides-with-dor-parcel-id','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('permit-surface-count-differs-from-store','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('pii-field-in-served-function','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('pii-in-amenity-and-parcel-layers-found-by-reading','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('pii-named-private-individual-in-a-neighbourhood-association-layer','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('pinellas-permit-signoff-null-on-98-percent-cannot-mean-unclosed','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('pinellas-qu-flg-undefined-code-not-served','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('pinellas-strap-format-mismatch','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('property-class-served-before-approval','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('published-free-text-fails-language-check','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('R281_CENSUS_ZERO_COLUMN_WIRED_TO_A_CONCEPT','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('R3_SENTINEL_NOT_NORMALISED_AT_SERVE','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('race-and-ethnicity-counts-in-a-parcel-joinable-layer','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('register-row-field-shifted','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('register-search-anon-execute-missing','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('register-state-file-older-than-45-days','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('registry-derivation-unexpressed','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('registry-entry-without-table','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('registry-page-size-zero','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('registry-rowcount-stamp-unreliable','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('registry-status-column-dual-purpose','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('relational-layer-key-does-not-reach-the-spine','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('reserved-prefix-row-not-a-registered-fixture','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('reserved-test-fixture-in-public-search','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('resolve-layer-cannot-compose','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('resolver-column-mismapped-to-wrong-semantics','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('resolver-picks-one-of-many-silently','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('resolver-single-county-geometry-assumptions','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('restrictions-are-recorded-against-the-subdivision-not-the-parcel','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('restrictions-bare-array-has-no-field-status','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('roz-glosses-opaque-codes-with-invented-meaning','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('roz-reports-not-available-where-data-exists','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('search-contractors-rank-after-limit','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('secdef-guard-missed-procedures','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('secdef-guard-must-stay-scoped-to-touched-objects','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('served-field-status-vocabulary-not-three-states','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('served-flood-legacy-fema-flood-zones','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('served-sum-multiplies-value-by-fragment-count','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('served-table-with-no-registry-entry','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('service-role-lost-table-privileges','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('single-county-lookup-unfiltered-by-county','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('single-county-table-served-as-universal','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('snapshot-party-key-without-scrub-manifest','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('source-encoding-is-per-file-not-per-publisher','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('special-district-assessments-misclassed-as-admin-boundaries','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('statute-without-concept','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('statutory-confidentiality-flag-held-and-unenforced','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('supabase-alert-spatial-ref-sys-false-positive','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('table-inventory-is-a-snapshot-that-drifts','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('table-provenance-comment-missing','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('tax-taxable-zero-unexplained','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('test-fixture-reachable-from-public-search','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('test-rows-left-in-a-published-production-layer','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('the-resolver-is-documentation-not-plumbing','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('trade-code-unmapped-must-surface-not-drop','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('trade-display-category-unlabelled','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('unverified-layer-activates-on-rowcount-backfill','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('values-flat-keys-duplicate-of-valuesfacts','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('verification-baseline-header-off-by-one','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect'),
('verified-encumbrance-candidates-held-back-from-the-served-match','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('work-photo-public-without-owner-approval','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('work-private-bucket-must-stay-private','blocking',true,'guards a surface a user can reach today (public register, agent register, personal data, a security grant): if it fires, a false statement is readable now or data can be lost or exposed'),
('zoning-code-is-a-composite-carrying-a-jurisdiction-prefix','material',true,'a false or misleading fact, but only on the paid report or Roz alpha, which no buyer can reach while checkout is parked: becomes blocking when checkout opens'),
('zoning-layer-without-code-column-crashes-the-report','material',false,'a fact is missing or weaker than claimed, and a user would want to know; no false statement on a surface reachable today'),
('zoning-shadow-duplicate-representation','cosmetic',false,'internal: registry, tooling or detection hygiene with no served effect');

do $$
declare n int;
begin
  select count(*) into n from public.data_defect_registry d where d.status = 'active' and not exists (select 1 from _rate r where r.defect_id = d.defect_id);
  if n is distinct from 0 then raise exception '205a: % active detections have no rating', n; end if;
  select count(*) into n from _rate r where not exists (select 1 from public.data_defect_registry d where d.defect_id = r.defect_id and d.status = 'active');
  if n is distinct from 0 then raise exception '205a: % ratings name no active detection', n; end if;
end $$;

select public._log_action('cc', 'severity_rerated_by_consequence', 'data_defect_registry', array['severity','severity_basis','blocking_at_launch'],
  (select jsonb_object_agg(defect_id, severity) from public.data_defect_registry where status = 'active'),
  (select jsonb_object_agg(defect_id, severity) from _rate),
  'Ruling 936: severity was saturated (113 of 201 active blocking). Re-rated by consequence; launch-conditional blocking recorded in blocking_at_launch.', null);

update public.data_defect_registry d
   set severity = r.severity, severity_basis = r.basis, blocking_at_launch = r.blocking_at_launch
  from _rate r where r.defect_id = d.defect_id;

do $$
declare b int; m int; c int; t int;
begin
  select count(*) filter (where severity = 'blocking'), count(*) filter (where severity = 'material'),
         count(*) filter (where severity = 'cosmetic'), count(*)
    into b, m, c, t from public.data_defect_registry where status = 'active';
  if b + m + c is distinct from t or exists (select 1 from public.data_defect_registry where status = 'active' and severity_basis is null) then
    raise exception '205a: unrated rows remain'; end if;
  if b > 20 then raise exception '205a: blocking % exceeds the ruling-936 bound', b; end if;
  raise notice '205a: blocking % / material % / cosmetic % (of %)', b, m, c, t;
end $$;
