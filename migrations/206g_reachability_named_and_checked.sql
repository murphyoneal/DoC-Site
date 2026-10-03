-- 206g - a severity that depends on a surface names the surface and is checked against whether that surface is live
-- (ruling 937 section 2). This replaces 205a's blocking_at_launch flag.
--
-- 937: "a bare 'blocking at launch' flag is the same trap one level up: a boolean that means 'later' goes stale the day
-- later arrives, and nothing makes it fire." So there are two fields and a detection:
--   reachable_on           the served surface that makes the defect readable, by name
--   severity_if_reachable  the severity it takes when that surface is live
--   detection severity-understated-on-a-live-surface: RED when a row's surface is live and severity <> severity_if_reachable.
-- Two independent sources: the declared fields, and served_surface.liveness_sql, which MEASURES liveness. It is not a
-- flag either. The pir_report surface is live when a paid purchase exists: pir_is_unlocked is exactly
-- "exists a paid pir_purchases row for this parcel" (pg_proc measured), and 937 measured 0 paid. The day the first report
-- is paid for, the 58 rows that are blocking-if-reachable on pir_report turn this detection red until they are re-rated.
-- Vocabulary: 937 named register_search | contractors_public | pir_preview | pir_report | none. Four more are needed
-- because 18 blocking guards sit on surfaces outside that list: agent_register, public_api (anything the published anon
-- key reaches), public_storage (public buckets), and any_public (guards whose defect would surface on whichever public
-- surface it touches: live false statements, PII, statutory confidentiality).
-- Mapping: the 18 blocking guards -> the surface each guards. The 58 paid-report false statements -> pir_report, blocking
-- if reachable. Every other row -> none, with severity_if_reachable = severity (not conditional on a surface).

create table if not exists public.served_surface (
  surface text primary key,
  description text not null,
  liveness_sql text not null
);
comment on table public.served_surface is
  '206g (ruling 937): each named served surface and a query that MEASURES whether it is live today. reachable_on names one of these; severity-understated-on-a-live-surface compares the two.';
alter table public.served_surface enable row level security;
revoke all on public.served_surface from public, anon, authenticated;

insert into public.served_surface (surface, description, liveness_sql) values
  ('register_search', 'Public two-board / contractor register search (browser RPCs)',
   $l$select has_function_privilege('anon','public.register_search(text,integer)','EXECUTE') and jsonb_array_length(public.register_search('roofing',1)->'results') > 0$l$),
  ('contractors_public', 'Contractor register pages /c, /c/[slug], /e, lists, contact card (server-read view)',
   $l$select exists (select 1 from public.contractors_public)$l$),
  ('agent_register', 'Public agent register search',
   $l$select has_function_privilege('anon','public.agent_register_search(text,integer)','EXECUTE') and jsonb_array_length(public.agent_register_search('GARCIA',1)::jsonb->'results') > 0$l$),
  ('public_api', 'Anything the published anon key reaches through PostgREST',
   $l$select exists (select 1 from pg_roles where rolname = 'anon')$l$),
  ('public_storage', 'Public storage buckets',
   $l$select exists (select 1 from storage.buckets where public)$l$),
  ('any_public', 'Whichever public surface the defect touches',
   $l$select has_function_privilege('anon','public.register_search(text,integer)','EXECUTE') or exists (select 1 from public.contractors_public)$l$),
  ('pir_preview', 'Free report preview (address, county, frame label, parcel state)',
   $l$select to_regprocedure('public.get_pir_preview(numeric,text)') is not null or exists (select 1 from pg_proc where proname = 'get_pir_preview')$l$),
  ('pir_report', 'The paid report: readable only after a paid purchase (pir_is_unlocked)',
   $l$select exists (select 1 from public.pir_purchases where status = 'paid')$l$),
  ('none', 'Not reachable by a reader; severity does not depend on a surface',
   $l$select false$l$)
on conflict (surface) do update set description = excluded.description, liveness_sql = excluded.liveness_sql;

create or replace function public.served_surface_live(p_surface text)
returns boolean language plpgsql stable set search_path to 'public', 'pg_temp' as $$
declare q text; v boolean;
begin
  select liveness_sql into q from public.served_surface where surface = p_surface;
  if q is null then return null; end if;   -- an undeclared surface is unknown, never "not live"
  execute q into v;
  return v;
end $$;
revoke all on function public.served_surface_live(text) from public, anon, authenticated;
grant execute on function public.served_surface_live(text) to service_role;

alter table public.data_defect_registry add column if not exists reachable_on text references public.served_surface(surface);
alter table public.data_defect_registry add column if not exists severity_if_reachable text;
alter table public.data_defect_registry drop constraint if exists ddr_severity_if_reachable_vocab;
alter table public.data_defect_registry add constraint ddr_severity_if_reachable_vocab
  check (severity_if_reachable is null or severity_if_reachable in ('blocking','material','cosmetic'));
comment on column public.data_defect_registry.reachable_on is
  '206g (ruling 937): the served surface that makes this defect readable (served_surface). none = not conditional on a surface.';
comment on column public.data_defect_registry.severity_if_reachable is
  '206g (ruling 937): the severity this defect takes when reachable_on is live. severity-understated-on-a-live-surface is red when the surface is live and severity differs.';

create temp table _reach (defect_id text primary key, reachable_on text not null, severity_if_reachable text not null) on commit drop;
insert into _reach values
('absence-claim-source-missing-temporal-extent','none','material'),
('active-source-never-fetched','none','material'),
('agent-register-search-anon-execute-missing','none','material'),
('agent-register-status-orphans-must-not-read-as-inactive','agent_register','blocking'),
('amenity-features-null-co-no-keytypes','none','material'),
('amenity-school-type-includes-non-k12','none','material'),
('anon-callable-secdef-functions','public_api','blocking'),
('anon-or-authenticated-hold-truncate','public_api','blocking'),
('anon-reachable-table-grant-unexpected','public_api','blocking'),
('assistant-log-records-nothing','none','cosmetic'),
('bfe-missing-column-served-as-not-recorded','pir_report','blocking'),
('bfe-null-where-the-column-is-absent-not-where-fema-published-none','pir_report','blocking'),
('blank-not-null-defeats-a-populated-test','none','material'),
('brownfield-served-volusia-only','none','material'),
('business-name-cardinality-unruled','none','material'),
('business-register-integrity','contractors_public','blocking'),
('cadence-dead-source','none','material'),
('cama-date-century-pivot-moves-with-the-clock','pir_report','blocking'),
('cama-is-a-table-set-resolved-as-a-single-layer','none','material'),
('cama-key-hygiene-sweep-five-counties','none','material'),
('cama-ragged-row-quarantine-accounting','none','material'),
('cama-role-concept-must-resolve-exactly-one-table','none','material'),
('cama-table-loaded-but-unregistered','none','cosmetic'),
('chha-not-wireable-as-one-concept','pir_report','blocking'),
('citrus-sumter-firm-exact-thousand-truncation-suspect','pir_report','blocking'),
('citylimits-weeki-wachee-disincorporated','pir_report','blocking'),
('claim-row-leaks-into-finding-readers','pir_report','blocking'),
('coastal-only-concept-on-inland-parcel','pir_report','blocking'),
('cohort-source-and-serving-source-disagree','none','material'),
('collier-child-table-parcelid-leading-zeros-stripped','none','material'),
('collier-legal-description-assembled-from-ordered-fragments','pir_report','blocking'),
('collier-utf8-bom-on-every-file','none','material'),
('column-default-asserts-unasked-fact','none','material'),
('column-map-points-at-a-column-that-answers-nothing','pir_report','blocking'),
('compat-views-pending-retirement','none','cosmetic'),
('concept-registered-but-unwired','none','cosmetic'),
('confidence-score-table-contradicts-the-spec','pir_report','blocking'),
('confidentiality-flag-on-six-address-layers-undeclared','none','material'),
('contamination-concepts-registered-but-unserved','none','material'),
('contractor-name-truncated-at-30-characters','none','material'),
('contractor-status-vocabulary-and-shape','contractors_public','blocking'),
('contractors-county-vocabulary-drift','none','material'),
('contractors-public-serves-street-or-rooftop-coordinates','contractors_public','blocking'),
('county-layer-registry-misnamed-for-multilevel','none','cosmetic'),
('county-name-saint-vs-st','none','material'),
('county-parcel-keys-declared-without-measurement-six-of-ten-join-at-zero','none','material'),
('county-parcel-layer-disagrees-with-the-statewide-spine-both-ways','none','material'),
('cross-jurisdiction-layer-leak','pir_report','blocking'),
('data-quality-score-is-live-in-the-payload','pir_report','blocking'),
('declared-role-omits-an-ordinal-sibling-column','none','material'),
('DEF-001','none','cosmetic'),
('DEF-005','none','material'),
('DEF-006','pir_report','blocking'),
('DEF-007','pir_report','blocking'),
('DEF-008','none','material'),
('DEF-009','none','material'),
('DEF-013','none','cosmetic'),
('DEF-016','none','material'),
('DEF-017','none','cosmetic'),
('DEF-024','none','material'),
('DEF-025','none','material'),
('defect-detection-suite-not-completing','none','cosmetic'),
('derived-deed-chain-behind-source','none','material'),
('derived-flood-subdivision-matches-source','pir_report','blocking'),
('derived-permit-history-behind-source','none','material'),
('detection-population-undeclared','none','cosmetic'),
('disciplinary-history-asserted-without-source','none','material'),
('disposition-vocabulary-contradicts-the-unchanged-record-rule','none','cosmetic'),
('dor-ships-92043-keyless-geometry-only-polygons-at-co-no-zero','none','material'),
('dor-use-code-descriptions-truncated-at-40-chars','none','material'),
('duval-flood-zone-is-a-comma-separated-multi-zone-string','pir_report','blocking'),
('elevation-single-point-sample-unrepresentative','none','material'),
('empty-encumbrance-array-reads-as-no-liens','pir_report','blocking'),
('entitlement-null-expiry-outside-owner-claim','pir_report','blocking'),
('entitlement-orphan-share','pir_report','blocking'),
('entitlement-sharing-abuse-signal','none','cosmetic'),
('entitlement-wildcard-outside-subscription','pir_report','blocking'),
('erp-easement-type-is-technician-notes-not-a-classification','none','material'),
('fdep-clm-no-contaminant-field','none','material'),
('fdep-stcm-tank-ungeocoded-active-facility','none','material'),
('fema-flood-zones-page-truncated','none','cosmetic'),
('fgs-subsidence-voluntary-register','pir_report','blocking'),
('fixed-width-padding-loaded-intact-across-the-served-spine','none','material'),
('flood-bfe-9999-sentinel-served-null','pir_report','blocking'),
('flood-column-map-points-at-an-internal-id-not-a-zone-code','pir_report','blocking'),
('flood-lake-county-name-trap','pir_report','blocking'),
('flood-zone-value-domain-is-not-uniform-across-67-layers','pir_report','blocking'),
('floodway-flag-column-holds-jurisdiction-names','pir_report','blocking'),
('fourteen-getters-emit-no-field-status','pir_report','blocking'),
('fuds-point-served-where-boundary-exists','none','material'),
('fuds-state-stored-lowercase','none','material'),
('geometry-resolution-served-path','none','material'),
('get-pir-report-inline-volusia-coalesce','none','cosmetic'),
('golden-report-within-production-timeout','none','material'),
('gwca-orphaned-from-served-payload','none','material'),
('handoff-status-pair-disagrees','none','cosmetic'),
('hardcoded-county-branch-count-must-not-grow','none','cosmetic'),
('hialeah-parcel-layer-loaded-twice-as-zoning-and-flu-carrying-owner-pii','none','material'),
('i-declared-six-keys-unsolvable-and-all-six-were-solvable','none','material'),
('inferred-hazard-flagged-as-requiring-disclosure','pir_report','blocking'),
('juridical-register-absent-from-the-payload','none','material'),
('key-column-holds-prose-and-delimited-lists-not-one-key','none','cosmetic'),
('layer-resolution-row-unverified','pir_report','blocking'),
('layer-trust-flags-stale','none','cosmetic'),
('lens-same-topic-under-two-sections','none','cosmetic'),
('listed-species-habitat-is-three-counties-of-sixty-seven','none','material'),
('live-false-statement-finding-unactioned','any_public','blocking'),
('miamidade-municipal-zoning-inert-on-null-rowcount','pir_report','blocking'),
('miamidade-zoning-wired-to-unincorporated-only','none','material'),
('municipal-boundary-annexation-lag','none','material'),
('municipal-zoning-layers-hold-something-other-than-zoning','pir_report','blocking'),
('my-inference-backfill-put-a-3m-row-sales-register-under-amenity','none','cosmetic'),
('named-owners-recorded-at-zero-percent-while-the-parcel-sums-to-unity','pir_report','blocking'),
('nhd-area-sub-in-sync','none','material'),
('none-intersecting-renders-false-for-any-partial-coverage-layer','pir_report','blocking'),
('one-firm-published-as-two-tables-sfha-and-non-sfha-split','pir_report','blocking'),
('one-parcel-layer-loaded-twice-as-zoning-and-land-use','none','cosmetic'),
('one-third-of-contractor-permit-matches-carry-their-own-ambiguity-flag','pir_report','blocking'),
('owner-and-contractor-names-truncated-across-three-derived-tables','none','material'),
('ownership-served-path','none','material'),
('palmbeach-null-confid-flag-reads-as-not-confidential','pir_report','blocking'),
('parcel-govt-source-two-schemas-two-different-keys','none','material'),
('parcels-staging-geometry-read-not-aggregated','none','material'),
('party-bearing-column-not-declared-in-the-column-map','pir_report','blocking'),
('pasco-per-file-staleness','none','material'),
('payload-reports-gap-where-county-data-exists','none','material'),
('payload-speaks-sixteen-absence-dialects','none','material'),
('paywall-gate-not-enforced-deliberate','pir_report','blocking'),
('pcpao-assessor-flag-blank-is-not-negative','pir_report','blocking'),
('pcpao-format-staleness-divergence','none','material'),
('pcpao-json-trailing-comma','none','material'),
('pcpao-permit-date-sentinel-years','pir_report','blocking'),
('per-owner-path-hardcoded-to-one-county-pinellas-reports-one-owner-of-seventy-nine','pir_report','blocking'),
('permit-closeout-absence-served-as-signal-after-cliff','pir_report','blocking'),
('permit-completion-date-precedes-issue-date','none','material'),
('permit-register-altkey-collides-with-dor-parcel-id','pir_report','blocking'),
('permit-surface-count-differs-from-store','pir_report','blocking'),
('pii-field-in-served-function','any_public','blocking'),
('pii-in-amenity-and-parcel-layers-found-by-reading','none','material'),
('pii-named-private-individual-in-a-neighbourhood-association-layer','none','material'),
('pinellas-permit-signoff-null-on-98-percent-cannot-mean-unclosed','pir_report','blocking'),
('pinellas-qu-flg-undefined-code-not-served','none','material'),
('pinellas-strap-format-mismatch','none','material'),
('property-class-served-before-approval','contractors_public','blocking'),
('published-free-text-fails-language-check','none','material'),
('R281_CENSUS_ZERO_COLUMN_WIRED_TO_A_CONCEPT','none','material'),
('R3_SENTINEL_NOT_NORMALISED_AT_SERVE','pir_report','blocking'),
('race-and-ethnicity-counts-in-a-parcel-joinable-layer','none','material'),
('register-row-field-shifted','contractors_public','blocking'),
('register-search-anon-execute-missing','none','material'),
('register-state-file-older-than-45-days','contractors_public','blocking'),
('registry-derivation-unexpressed','none','cosmetic'),
('registry-entry-without-table','none','cosmetic'),
('registry-page-size-zero','none','cosmetic'),
('registry-rowcount-stamp-unreliable','none','material'),
('registry-status-column-dual-purpose','none','material'),
('relational-layer-key-does-not-reach-the-spine','pir_report','blocking'),
('reserved-prefix-row-not-a-registered-fixture','none','material'),
('reserved-test-fixture-in-public-search','register_search','blocking'),
('resolve-layer-cannot-compose','none','material'),
('resolver-column-mismapped-to-wrong-semantics','pir_report','blocking'),
('resolver-picks-one-of-many-silently','none','material'),
('resolver-single-county-geometry-assumptions','none','material'),
('restrictions-are-recorded-against-the-subdivision-not-the-parcel','none','material'),
('restrictions-bare-array-has-no-field-status','pir_report','blocking'),
('roz-glosses-opaque-codes-with-invented-meaning','none','material'),
('roz-reports-not-available-where-data-exists','none','material'),
('search-contractors-rank-after-limit','none','material'),
('secdef-guard-missed-procedures','none','material'),
('secdef-guard-must-stay-scoped-to-touched-objects','none','material'),
('served-field-status-vocabulary-not-three-states','none','material'),
('served-flood-legacy-fema-flood-zones','none','material'),
('served-sum-multiplies-value-by-fragment-count','pir_report','blocking'),
('served-table-with-no-registry-entry','none','cosmetic'),
('service-role-lost-table-privileges','none','material'),
('single-county-lookup-unfiltered-by-county','pir_report','blocking'),
('single-county-table-served-as-universal','none','material'),
('snapshot-party-key-without-scrub-manifest','pir_report','blocking'),
('source-encoding-is-per-file-not-per-publisher','pir_report','blocking'),
('special-district-assessments-misclassed-as-admin-boundaries','none','material'),
('statute-without-concept','none','material'),
('statutory-confidentiality-flag-held-and-unenforced','any_public','blocking'),
('supabase-alert-spatial-ref-sys-false-positive','none','cosmetic'),
('table-inventory-is-a-snapshot-that-drifts','none','cosmetic'),
('table-provenance-comment-missing','none','cosmetic'),
('tax-taxable-zero-unexplained','pir_report','blocking'),
('test-fixture-reachable-from-public-search','register_search','blocking'),
('test-rows-left-in-a-published-production-layer','pir_report','blocking'),
('the-resolver-is-documentation-not-plumbing','none','cosmetic'),
('trade-code-unmapped-must-surface-not-drop','none','material'),
('trade-display-category-unlabelled','contractors_public','blocking'),
('unverified-layer-activates-on-rowcount-backfill','pir_report','blocking'),
('values-flat-keys-duplicate-of-valuesfacts','none','cosmetic'),
('verification-baseline-header-off-by-one','none','cosmetic'),
('verified-encumbrance-candidates-held-back-from-the-served-match','none','material'),
('work-photo-public-without-owner-approval','public_storage','blocking'),
('work-private-bucket-must-stay-private','public_storage','blocking'),
('zoning-code-is-a-composite-carrying-a-jurisdiction-prefix','pir_report','blocking'),
('zoning-layer-without-code-column-crashes-the-report','none','material'),
('zoning-shadow-duplicate-representation','none','cosmetic'),
('licence-status-served-without-date-and-caveat','register_search','blocking'),
('resolver-geom-column-not-in-catalogue','none','material');

do $$
declare n int; flag_n int; new_n int;
begin
  select count(*) into n from public.data_defect_registry d where d.status = 'active' and not exists (select 1 from _reach r where r.defect_id = d.defect_id);
  if n is distinct from 0 then raise exception '206g: % active detections unmapped', n; end if;
  select count(*) into n from _reach r where not exists (select 1 from public.data_defect_registry d where d.defect_id = r.defect_id and d.status = 'active');
  if n is distinct from 0 then raise exception '206g: % mappings name no active detection', n; end if;
  -- the flag being replaced must carry over exactly: launch-conditional rows = blocking-if-reachable but not blocking today
  select count(*) into flag_n from public.data_defect_registry where status = 'active' and blocking_at_launch and severity <> 'blocking';
  select count(*) into new_n from _reach r join public.data_defect_registry d using (defect_id)
   where r.severity_if_reachable = 'blocking' and d.severity <> 'blocking';
  if flag_n is distinct from new_n then raise exception '206g: blocking_at_launch % does not carry to severity_if_reachable %', flag_n, new_n; end if;
end $$;

update public.data_defect_registry d set reachable_on = r.reachable_on, severity_if_reachable = r.severity_if_reachable
  from _reach r where r.defect_id = d.defect_id;

alter table public.data_defect_registry drop constraint if exists ddr_active_declares_reachability;
alter table public.data_defect_registry add constraint ddr_active_declares_reachability
  check (status <> 'active' or (reachable_on is not null and severity_if_reachable is not null));

-- the flag is replaced, not kept beside the fields (two sources of the same fact drift)
alter table public.data_defect_registry drop column blocking_at_launch;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('severity-understated-on-a-live-surface',
  'A detection''s severity is lower than its severity_if_reachable while the surface it names is live - the board understating a defect a reader can see',
  current_date, 'ruling 937 section 2', 'access_control', 'blocking',
$q$with a as (
      select d.defect_id, d.severity, d.severity_if_reachable, d.reachable_on, public.served_surface_live(d.reachable_on) live
        from public.data_defect_registry d where d.status = 'active'),
    bad as (select * from a where (live is true and severity is distinct from severity_if_reachable) or live is null)
select not exists (select 1 from bad) as ok,
       (select count(*) from bad) as row_count,
       (select string_agg(defect_id || ' (' || reachable_on || ')', ', ') from bad) as understated,
       (select count(*) from a where reachable_on <> 'none') as population$q$,
  'clean', 'active detections whose severity depends on a named surface',
  'Liveness is MEASURED per surface (served_surface.liveness_sql), not declared. pir_report goes live with the first paid purchase; on that day the 58 pir_report rows read red here until re-rated. An undeclared or unmeasurable surface (live is null) reads red too.',
  'active', 'ours', 'Re-rate the named rows to severity_if_reachable (or correct reachable_on) the day their surface goes live.', 'any_public', 'blocking');

do $$
declare j jsonb; live jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'severity-understated-on-a-live-surface')) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) <= 0 then raise exception '206g: detection %', j; end if;
  select jsonb_object_agg(surface, public.served_surface_live(surface)) into live from public.served_surface;
  if (live->>'pir_report')::boolean is distinct from false or (live->>'register_search')::boolean is distinct from true then raise exception '206g: liveness %', live; end if;
  raise notice '206g: % | live %', j, live;
end $$;

select public._log_action('cc', 'reachability_named_and_checked', 'data_defect_registry', array['reachable_on','severity_if_reachable','served_surface','severity-understated-on-a-live-surface'],
  jsonb_build_object('blocking_at_launch', 'boolean flag (205a)'), jsonb_build_object('reachable_on', 'named surface', 'severity_if_reachable', 'severity', 'liveness', 'measured'),
  'Ruling 937 section 2: a severity conditional on a surface names the surface and is checked against whether that surface is live.', null);
