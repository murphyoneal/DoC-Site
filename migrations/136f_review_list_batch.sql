-- 136f — The 136d review list, batched (ruling 2026-09-26): does the default assert something about
-- a subject, and can a row be created without its writer setting it? Unreachable -> classified with
-- the reason. Reachable and asserting -> default dropped. Arguable -> left failing, brought back.
-- "Reachable" was measured from the writers themselves: every INSERT column list in pg_proc, plus a
-- grep of the repo and the WSL scripts. A table with NO identifiable writer counts as reachable,
-- because nothing proves the next insert names the column.
--
-- EXISTING ROWS ARE NOT CHANGED here. Each was checked, and none is shown to be default-filled AND false:
--   in_replacement_window agrees with replacement_urgency on all 983,991 rows (0 false where due/
--   overdue/approaching/past; not_evaluated is NULL); in_volusia agrees with the county on every
--   Volusia row; insurability_by_group has data on all 67 'present' rows; country/country_code 'US' and
--   property_transaction_history '127'/'FL' are true of the sources loaded (the DBPR FL register, the
--   Volusia roll). environmental_daily_readings has no identifiable writer or reader; its values are
--   left as loaded and their provenance is unknown.

-- A. Reachable and asserting: drop the default. The column then leaves the check's set.
alter table public.property_permit_history      alter column in_replacement_window drop default; -- issue_permit_with_audit and verify_permit_submission both omit it; get_parcel_roof_lifespan reads it
alter table public.attestation_register         alter column disputes_finding drop default;      -- 0 rows, NOT NULL stays: a writer must now state it
alter table public.construction_flaws           alter column remediated drop default;            -- 0 rows, no writer or reader
alter table public.construction_flaws           alter column country drop default;
alter table public.import_log                   alter column status drop default;                -- 0 rows, no writer: 'completed' by default is empty-is-done
alter table public.environmental_daily_readings alter column fire_nearby drop default;           -- no identifiable writer
alter table public.environmental_daily_readings alter column aqi_source drop default;
alter table public.environmental_daily_readings alter column fire_source drop default;
alter table public.property_transaction_history alter column county_fips drop default;           -- Volusia stamped on any row that omits it
alter table public.property_transaction_history alter column state_code drop default;
alter table public.contractors                  alter column country drop default;
alter table public.contractors                  alter column country_code drop default;
alter table public.contractors                  alter column in_volusia drop default;            -- no identifiable writer
alter table public.insurability_by_group        alter column field_status drop default;          -- 'present' by default; NOT NULL stays

update public.column_default_authorship set classified_on = current_date,
       reason = reason || ' | 136f: DEFAULT DROPPED (reachable and asserting); existing rows checked and left as loaded.'
 where (table_name, column_name) in (
   ('property_permit_history','in_replacement_window'),('attestation_register','disputes_finding'),
   ('construction_flaws','remediated'),('construction_flaws','country'),('import_log','status'),
   ('environmental_daily_readings','fire_nearby'),('environmental_daily_readings','aqi_source'),
   ('environmental_daily_readings','fire_source'),('property_transaction_history','county_fips'),
   ('property_transaction_history','state_code'),('contractors','country'),('contractors','country_code'),
   ('contractors','in_volusia'),('insurability_by_group','field_status'));

-- B. Unreachable: every identified writer names the column in its INSERT list. Classified 'ours'
--    with the writer as the reason. Caveat recorded in each reason: a NEW writer that omits the
--    column makes it reachable again, and this check will not see that.
update public.column_default_authorship a set authorship = 'ours', classified_on = current_date,
       reason = 'UNREACHABLE (136f): sole writer ' || v.writer || ' names the column in its INSERT. A new writer that omits it would make the default reachable again; this check cannot see that.'
  from (values
   ('agent_parcel_claim','status','agent_claim_confirm'),
   ('agent_parcel_claim','claimed_role','agent_claim_confirm'),
   ('agent_parcel_claim','source','agent_claim_confirm'),
   ('source_observation','status','cadence_sweep_collect'),
   ('site_hazard_installations','requires_emergency_disclosure','file_hazard_from_intake_answers (both INSERTs)'),
   ('golden_parcel_baseline','value_checked','rebaseline_golden_parcels'),
   ('contractor_proven_areas','confirmed_permit_count','recompute_proven_areas'),
   ('contractor_proven_areas','total_confirmed_in_county','recompute_proven_areas'),
   ('assistant_query_log','success','roz_log_query'),
   ('property_permit_history','source_import_id','issue_permit_with_audit and verify_permit_submission (both name it)')
  ) v(t, c, writer)
 where a.table_name = v.t and a.column_name = v.c;

-- C. Not an assertion about a subject: our own process state, and the default is the truth.
update public.column_default_authorship set authorship = 'ours', classified_on = current_date,
       reason = 'OURS (136f): false = WE have not confirmed the install, which is true until we do. Not a claim about the site.'
 where table_name = 'site_hazard_installations' and column_name = 'utility_install_confirmed';
update public.column_default_authorship set authorship = 'ours', classified_on = current_date,
       reason = 'OURS (136f): a run row begins as running; that is true at insert.'
 where table_name = 'data_audit_runs' and column_name = 'status';

-- D. Left failing on purpose (arguable, brought back): properties.homestead_exempt,
--    county_registry.has_cama/has_nal/has_sdf/has_gis_gio/has_permits/has_clerk_records,
--    county_coverage_status.is_blackout, dor_use_code.possibly_truncated.

do $a$
declare n int;
begin
  select count(*) into n
    from public.column_default_authorship a
    join information_schema.columns c on c.table_schema = 'public' and c.table_name = a.table_name
                                     and c.column_name = a.column_name and c.column_default is not null
   where a.authorship in ('theirs','review');
  if n <> 9 then raise exception '136f: expected 9 left on the review list, found %', n; end if;
end $a$;
