-- 136d — Standing check: no literal column default may assert a fact that is not ours.
-- Ruling 2026-09-26 (claude): "the test is WHOSE FACT IT IS". verified / claimed / active record OUR
-- state, so a default there is the truth. Anything describing the subject — a business, a property,
-- a county, a transaction — has no honest default, because we have not asked. A default written at
-- table creation becomes an assertion the moment anything reads it (disciplinary_history, 136a; the
-- 15 capability flags, 136c).
--
-- MECHANISM: every public base-table column with a LITERAL default (clock, sequence and uuid
-- defaults are excluded as mechanical) must be classified in column_default_authorship:
--   ours                     — our own state; the default is true by construction
--   theirs_unknown_sentinel  — a fact about the subject whose default SAYS it is not known
--                              ('unknown', 'not_checked', 'not_computed', 'location_not_checked')
--   theirs                   — a fact about the subject asserted by default: FAILS
--   review                   — ours by authorship, but the default asserts an OUTCOME (paid,
--                              confirmed, ok, success, present) that may not have happened: FAILS
-- An UNCLASSIFIED literal default also FAILS, so the next one is caught without anyone remembering.
-- A 'theirs' row stops failing when its default is dropped (only columns that HAVE a default are
-- checked), so the fix is the migration, not an edit to this table.
--
-- Classified by CC on 2026-09-26 from the full list of 227; the theirs/review lists below are the
-- review list for a ruling. Everything not listed was read and judged to be our own state.

create table if not exists public.column_default_authorship (
  table_name    text not null,
  column_name   text not null,
  authorship    text not null check (authorship in ('ours','theirs_unknown_sentinel','theirs','review')),
  reason        text not null,
  classified_by text not null,
  classified_on date not null default current_date,
  primary key (table_name, column_name)
);
comment on table public.column_default_authorship is
  'Whose fact does each literal column default describe? Read by detection column-default-asserts-unasked-fact. '
  'ours / theirs_unknown_sentinel pass; theirs / review / unclassified fail. Ruling 2026-09-26 (136d).';

insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by) values
 -- THEIRS: describes the subject; the default asserts it.
 ('contractors','service_categories','theirs','{} = "offers no services" about a business nobody asked; served in contractors_public','cc'),
 ('contractors','classifications','theirs','{} = "holds no classifications"; served in contractors_public','cc'),
 ('contractors','certifications','theirs','{} = "holds no certifications"; served in contractors_public','cc'),
 ('contractors','lbp_classes','theirs','{} = "no lead-based-paint classes"; served in contractors_public','cc'),
 ('contractors','personnel_names','theirs','{} = "no personnel"; not served in contractors_public','cc'),
 ('contractors','country','theirs','US by default is a location fact; true of today''s DBPR rows by construction, not of any future source','cc'),
 ('contractors','country_code','theirs','as country','cc'),
 ('contractors','in_volusia','theirs','false = "not in Volusia" before the location is computed; served','cc'),
 ('properties','homestead_exempt','theirs','false = "no homestead exemption", a tax fact about a property, by default','cc'),
 ('property_permit_history','in_replacement_window','theirs','false = "not in the replacement window"; the table''s own notes make not_evaluated a fourth state (6,515 NULL rows)','cc'),
 ('property_transaction_history','county_fips','theirs','127 (Volusia) stamped on any row that omits it: a location fact by default','cc'),
 ('property_transaction_history','state_code','theirs','as county_fips','cc'),
 ('construction_flaws','remediated','theirs','false = "not remediated", a fact about a flaw, by default','cc'),
 ('construction_flaws','country','theirs','NZ by default: a location fact','cc'),
 ('environmental_daily_readings','fire_nearby','theirs','false = "no fire nearby" by default, an environmental fact','cc'),
 ('attestation_register','disputes_finding','theirs','false = "the attester does not dispute" when they may not have said','cc'),
 ('county_export_survey','vendor_fingerprint','theirs','''none found'' before any survey ran; none-found is a FINDING, distinct from pending (the table''s own taxonomy)','cc'),
 ('county_export_survey','export_capability','theirs','as vendor_fingerprint','cc'),
 ('contractor_proven_areas','confirmed_permit_count','theirs','0 = "no confirmed permits" about a named business before any count ran','cc'),
 ('contractor_proven_areas','total_confirmed_in_county','theirs','as confirmed_permit_count','cc'),
 -- REVIEW: our state, but the default asserts an outcome.
 ('pir_purchases','status','review','''paid'' by default: a purchase row written without a status reads as paid','cc'),
 ('agent_parcel_claim','status','review','''confirmed'' by default','cc'),
 ('agent_parcel_claim','claimed_role','review','''sale_agent'' by default: the agent''s role on a sale, asserted','cc'),
 ('agent_parcel_claim','source','review','''address_paste'' provenance by default','cc'),
 ('import_log','status','review','''completed'' by default: empty is not done','cc'),
 ('source_observation','status','review','''ok'' by default','cc'),
 ('assistant_query_log','success','review','true by default; the log exists to count failures too','cc'),
 ('golden_parcel_baseline','value_checked','review','true by default','cc'),
 ('insurability_by_group','field_status','review','''present'' by default: a coverage state asserted','cc'),
 ('data_audit_runs','status','review','''running'' by default','cc'),
 ('property_permit_history','source_import_id','review','a fixed import id (VCPA_CAMA_2026_06_21) stamped on any future row','cc'),
 ('environmental_daily_readings','aqi_source','review','source attribution by default','cc'),
 ('environmental_daily_readings','fire_source','review','source attribution by default','cc'),
 ('county_registry','has_cama','review','false = "county has no CAMA"? or "we hold none"? The name does not say whose fact it is','cc'),
 ('county_registry','has_nal','review','as has_cama','cc'),
 ('county_registry','has_sdf','review','as has_cama','cc'),
 ('county_registry','has_gis_gio','review','as has_cama','cc'),
 ('county_registry','has_permits','review','as has_cama','cc'),
 ('county_registry','has_clerk_records','review','as has_cama','cc'),
 ('county_coverage_status','is_blackout','review','false by default before coverage is measured','cc'),
 ('dor_use_code','possibly_truncated','review','false = "measured, not truncated" by default','cc'),
 ('site_hazard_installations','utility_install_confirmed','review','false by default: confirmed-not vs not-yet-asked','cc'),
 ('site_hazard_installations','requires_emergency_disclosure','review','true by default: a disclosure obligation asserted per row','cc'),
 -- THEIRS, but the default says "not known".
 ('contractors','license_status','theirs_unknown_sentinel','''unknown''','cc'),
 ('derived_field_status','field_status','theirs_unknown_sentinel','''not_computed''','cc'),
 ('dea_clandestine_labs','three_state','theirs_unknown_sentinel','''not_checked''','cc'),
 ('site_hazard_installations','verification_method','theirs_unknown_sentinel','''unverified''','cc'),
 ('site_hazard_installations','location_confidence','theirs_unknown_sentinel','''unknown''','cc'),
 ('work_contribution','location_state','theirs_unknown_sentinel','''location_not_checked''','cc')
on conflict (table_name, column_name) do nothing;

-- Everything else with a literal default today, read and judged to be OUR state (workflow status,
-- is_test, active, counters starting at zero, our own flags and captions, table-scoped constants
-- that are true by construction such as volusia_official_records_private.county).
insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by)
select c.table_name, c.column_name, 'ours',
       'our own state; default true by construction (bulk-classified 2026-09-26 after reading all 227)', 'cc'
  from information_schema.columns c join information_schema.tables t using (table_schema, table_name)
 where c.table_schema = 'public' and t.table_type = 'BASE TABLE' and c.column_default is not null
   and c.column_default !~* '(now\(\)|current_(date|timestamp)|nextval|gen_random_uuid|uuid_generate|clock_timestamp|timezone\()'
   and c.table_name <> 'column_default_authorship'
on conflict (table_name, column_name) do nothing;

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('column-default-asserts-unasked-fact',
 'No literal column default may assert a fact about a subject (business, property, county) that nobody checked',
 date '2026-09-26', 'disciplinary_history (136a) and the capability flags (136c); ruling 2026-09-26', 'null_as_value', 'material',
 $d$with d as (
   select c.table_name, c.column_name, coalesce(a.authorship, 'unclassified') as authorship
     from information_schema.columns c
     join information_schema.tables t using (table_schema, table_name)
     left join public.column_default_authorship a on a.table_name = c.table_name and a.column_name = c.column_name
    where c.table_schema = 'public' and t.table_type = 'BASE TABLE' and c.column_default is not null
      and c.column_default !~* '(now\(\)|current_(date|timestamp)|nextval|gen_random_uuid|uuid_generate|clock_timestamp|timezone\()'
      and c.table_name <> 'column_default_authorship')
  select (count(*) filter (where authorship not in ('ours','theirs_unknown_sentinel')) = 0) as ok,
         count(*) filter (where authorship not in ('ours','theirs_unknown_sentinel')) as row_count,
         count(*) as examined,
         string_agg(table_name || '.' || column_name || ' [' || authorship || ']', ', ' order by authorship, table_name, column_name)
           filter (where authorship not in ('ours','theirs_unknown_sentinel')) as failing
    from d$d$,
 'every public base-table column with a literal (non-clock, non-sequence, non-uuid) default',
 'CATALOG CHECK over information_schema plus a judgement table (column_default_authorship). It cannot tell whether a DEFAULT was ever used; it flags the capacity to assert. RED BY DESIGN at creation: the theirs/review rows are the review list awaiting a ruling. A new literal default with no classification FAILS (unclassified), which is the point. Fix a theirs row by dropping the default (it then leaves the set); fix a review row by ruling it ours (update the row, with a reason) or by dropping the default.',
 'active', 'ours', 'defect',
 'Drop the default (NULL = not known) or, for our own state, classify the column ours with a reason.')
on conflict (defect_id) do nothing;
