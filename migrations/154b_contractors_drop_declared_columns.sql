-- 154b: drop the business-declared columns from contractors, the DBPR register copy (ruling 744, step 3).
-- Runs only after 154a (no view serves them) and #80 (no code renders them).
--
-- 39 columns. Before dropping, each is RE-COUNTED INSIDE THIS MIGRATION and it aborts on any value
-- (recount-before-destructive-ddl). work_photos is the one exception to "empty": DEFAULT '{}' sat on
-- every row, an empty array asserting "no photos of their work" about every licensee - so for it the
-- abort condition is a NON-EMPTY array, and its column_default_authorship row said 'ours', which was
-- wrong: '{}' is a claim about the business. Recorded here because the row goes with the column.
--
-- Indexes that go with the columns: idx_con_emergency, idx_con_aging, idx_con_hurricane, idx_con_ada,
-- idx_con_bond, and idx_con_fts (a GIN tsvector over display_name/trade_label/city/state/... that
-- included a dropped column). idx_con_fts had 0 scans, and no function or app code runs text search
-- on contractors, so it is not recreated.
--
-- Writers checked before dropping: no pg_proc writes contractors; no cron job; no WSL or repo script;
-- data_source_registry 490 records pull_mode=manual, last pull 2026-08-15. Its derivation text named
-- "bond, workers comp, insurance" - corrected below.

set statement_timeout = 0;

do $m$
declare cols text[] := array['service_categories','phone','email','website','service_radius_km','service_lat','service_lng',
  'bond_amount','bond_company','bond_expiry','bond_status','workers_comp_on_file','insurance_company','insurance_expiry',
  'description','years_in_business','employee_count','certifications','specialist_notes','profile_photo','logo_url',
  'ada_compliant_work','aging_in_place','chemical_sensitivity_aware','mobility_accessible_worksite','hurricane_hardening',
  'impact_window_certified','roof_certification','storm_restoration','emergency_available','emergency_response_hours',
  'emergency_plumbing','emergency_roofing','emergency_electrical','emergency_storm_damage','emergency_water_damage',
  'emergency_board_up','qr_code_url'];
  c text; n bigint; v_rows bigint;
begin
  select count(*) into v_rows from public.contractors;
  foreach c in array cols loop
    execute format('select count(*) from public.contractors where %I is not null', c) into n;
    if n <> 0 then raise exception '154b: contractors.% holds % values - not dropping anything', c, n; end if;
  end loop;
  select count(*) into n from public.contractors where cardinality(work_photos) > 0;
  if n <> 0 then raise exception '154b: contractors.work_photos holds % non-empty arrays - not dropping anything', n; end if;

  -- the view must no longer reference any of them (154a applied)
  if exists (select 1 from pg_depend d join pg_attribute a on a.attrelid = d.refobjid and a.attnum = d.refobjsubid
              where d.refobjid = 'public.contractors'::regclass and a.attname = any(cols || 'work_photos'::text)
                and d.classid = 'pg_rewrite'::regclass) then
    raise exception '154b: a view still depends on a column in the drop set - apply 154a first'; end if;

  foreach c in array cols || 'work_photos'::text loop
    execute format('alter table public.contractors drop column %I', c);
  end loop;

  if (select count(*) from public.contractors) <> v_rows then raise exception '154b: contractors row count changed'; end if;
end $m$;

delete from public.column_default_authorship
 where table_name = 'contractors' and column_name in ('service_categories', 'certifications', 'work_photos');

update public.data_source_registry
   set derivation = 'Florida DBPR construction licence register copy: licence number, status and dates, trade codes, classifications, lead-based-paint licence fields, geocoding, and platform fields (claimed, verified, tier). Business-declared fields (description, photos, capability/emergency claims, service area, bond/insurance, contact) were dropped in 154b (ruling 744); a business''s own statements live in business_profile.'
 where id = 490 and table_name = 'contractors';

do $m$
declare f jsonb; s jsonb;
begin
  if (select count(*) from public.contractors_public) <> 114008 then raise exception '154b: contractors_public row count changed'; end if;
  if not has_table_privilege('anon', 'public.contractors_public', 'select') then raise exception '154b: anon lost SELECT on contractors_public'; end if;
  f := public.contractor_finder(null, 'Volusia', null, 5, 0);
  if (f->>'count')::int <> 3288 then raise exception '154b: finder Volusia count % <> 3288', f->>'count'; end if;
  s := public.contractor_register_search('smith', 5);
  if (s->>'count')::int <> 277 then raise exception '154b: register search smith count % <> 277', s->>'count'; end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'contractors'
              and column_name in ('service_categories', 'emergency_available', 'work_photos', 'description', 'phone')) then
    raise exception '154b: a column in the drop set survived'; end if;
end $m$;
