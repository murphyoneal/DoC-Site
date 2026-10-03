-- 212a - restore the contractor register's address and file-state fields from the state file we hold, and fix the
-- matcher that let them diverge (audit 971, items A1-A4; ruling 976, approved as a RESTORATION, five conditions).
--
-- OUR LOADER OVERWROTE THE GOVERNMENT RECORD. Measured 2026-10-03 against the 7 Sep 2026 file (dbpr_construction_snapshot
-- snapshot 3, already held):
--   A1 state: 7,874 licences whose file state is not FL were served as FL. The frozen June baseline
--      (contractors_register_2026_06_27) already says FL for all 7,874, so the original June load wrote FL over the
--      state's value. Live: "ANNAPOLIS, FL, 21403".
--   A4 address: 4,612 licences in the latest file show a city that is not that licence's city in the file. 138a
--      deliberately refreshed only status and expiry and left name/city/zip/street "for a ruling" that never came.
--   A3 registrations: all 6,669 served business registrations (QB, no licence number) were marked
--      absent_from_latest_file. 6,407 match a 7 Sep registration on business name + zip5 + original date, each
--      unambiguously. 138a matched on licence number only, and registrations have none.
--   A2 4,142 QB rows carry a trade licence number (record_kind 'licence', from the June baseline whose file is
--      unrecoverable). For 3,805 of them the date matches a 7 Sep REGISTRATION, not the licence. They are registrations
--      with a licence number attached; 138a gave them the licence's status and the page labels the registration date
--      "Licence first issued" (Kass: 2001 on one page, 1987 on its twin). The file publishes these registrations with
--      no licence number.
--
-- THE FIVE CONDITIONS (976):
--  (a) Restore from the file, never infer. Every value written comes from the matched file row. A blank file field
--      never overwrites a value (the file may simply not carry it). Nothing is derived from a zip, city or area code.
--      The one derived field is county_name, recomputed from the FILE's county code with the map the register already
--      uses (67 codes, 0 ambiguous). Out-of-state codes give no FL county.
--  (b) The pre-correction value is kept: contractors_before_212a holds every changed column of every touched row.
--      A licence number moved off a registration is kept in contractors.license_number_june_baseline, not deleted.
--  (c) Fix the matcher, not the rows. refresh_register_from_snapshot(snapshot, file_date) declares the key for each
--      record type - licence: licence number (latest expiry wins, as 138a); business registration: business name +
--      zip5 + original date, unique keys only. It REFUSES to finish if either type matches zero rows: a refresh that
--      matches nothing is a failure, not a no-op. This migration is its first call; the next file uses the same function.
--  (d) Red run: detection register-row-disagrees-with-latest-file is run against the before-state, replayed inside a
--      subtransaction, and must reproduce the measured populations. After the restoration it must read clean.
--  (e) One migration, assertions inside. Any failure rolls the whole thing back.
-- Pins: where an address changes, the pin was geocoded from the old address, so lat/lng are cleared (geocoded false) -
-- a missing pin, not a wrong one - until re-geocoded. Where only the state changes, the pin stays.
-- NOT in this migration, reported: business names (the 7 Sep file renames some), business keys and slugs (slugs still
-- carry the June city/state, e.g. ...-annapolis-fl - redirectable, separate change), re-geocoding.

set statement_timeout = 0;

alter table public.contractors add column if not exists license_number_june_baseline text;
comment on column public.contractors.license_number_june_baseline is
  '212a: a licence number the June 2026 baseline attached to a business registration (trade QB). The 7 Sep 2026 state file publishes these registrations with no licence number, so it is no longer served as the row''s licence; kept here so nothing is lost.';

create table if not exists public.contractors_before_212a (
  id uuid primary key, state text, city text, zip_code text, address_line_1 text, address_line_2 text, county_code text,
  county_name text, county_name_method text, in_volusia boolean, lat double precision, lng double precision, geocoded boolean,
  geocode_quality text, county_geometry_check text, license_number text, record_kind text, license_status text,
  secondary_status text, expiry_date text, effective_date text, register_file_state text, register_file_date date,
  captured_at timestamptz not null default now());
alter table public.contractors_before_212a enable row level security;
revoke all on public.contractors_before_212a from public, anon, authenticated;
comment on table public.contractors_before_212a is
  '212a: every column the restoration changed, as served before it, for every touched row. Holds street addresses - closed to REST roles. Never update.';

create or replace function public.refresh_register_from_snapshot(p_snapshot_id int, p_file_date date)
returns jsonb language plpgsql set search_path to 'public', 'pg_temp' as $$
-- 212a (ruling 976): the register refresh, with the key each record type joins on DECLARED here, once.
--   licence               -> licence_number (several file rows: the latest expiry wins, as 138a)
--   business_registration -> business name + zip5 + original date (trade QB rows carry no licence number); unique keys only
-- Only non-blank file values are written. Refuses to finish if either type matches zero rows.
declare n_lic int; n_reg int; n_lic_addr int; n_reg_addr int; n_kind int;
begin
  create temp table _f_lic on commit drop as
  select distinct on (license_number) license_number, nullif(btrim(state),'') state, nullif(btrim(city),'') city,
         nullif(btrim(zip),'') zip, nullif(btrim(addr1),'') addr1, nullif(btrim(addr2),'') addr2, nullif(btrim(county_code),'') county_code
    from dbpr_construction_snapshot
   where snapshot_id = p_snapshot_id and license_number <> ''
   order by license_number, to_date(nullif(expiry_date,''),'MM/DD/YYYY') desc nulls last, row_no;

  create temp table _f_reg on commit drop as
  select full_name, left(zip,5) z5, original_date,
         min(nullif(btrim(state),'')) state, min(nullif(btrim(city),'')) city, min(nullif(btrim(zip),'')) zip,
         min(nullif(btrim(addr1),'')) addr1, min(nullif(btrim(addr2),'')) addr2, min(nullif(btrim(county_code),'')) county_code,
         min(status_code) status_code, min(expiry_date) expiry_date, min(effective_date) effective_date
    from dbpr_construction_snapshot
   where snapshot_id = p_snapshot_id and trade_code = 'QB' and license_number = ''
   group by full_name, left(zip,5), original_date
  having count(*) = 1;

  create temp table _cmap on commit drop as
  select county_code, min(county_name) county_name from contractors
   where county_name_method = 'dbpr_county_code' and county_name is not null group by county_code;

  create temp table _hit on commit drop as
  select c.id, 'licence'::text kind, f.state, f.city, f.zip, f.addr1, f.addr2, f.county_code,
         null::text status_code, null::text expiry_date, null::text effective_date
    from contractors c join _f_lic f on f.license_number = c.license_number
   where c.record_kind = 'licence' and c.trade_code is distinct from 'QB'
  union all
  select c.id, 'business_registration', f.state, f.city, f.zip, f.addr1, f.addr2, f.county_code, f.status_code, f.expiry_date, f.effective_date
    from contractors c join _f_reg f on f.full_name = c.business_name and f.z5 = left(c.zip_code,5) and f.original_date = c.original_date
   where c.trade_code = 'QB';

  select count(*) filter (where kind = 'licence'), count(*) filter (where kind = 'business_registration') into n_lic, n_reg from _hit;
  if n_lic = 0 then raise exception 'refresh_register_from_snapshot(%): ZERO licences matched - a refresh that matches nothing is a failure', p_snapshot_id; end if;
  if n_reg = 0 then raise exception 'refresh_register_from_snapshot(%): ZERO business registrations matched - a refresh that matches nothing is a failure', p_snapshot_id; end if;

  -- keep what is about to change
  insert into contractors_before_212a (id, state, city, zip_code, address_line_1, address_line_2, county_code, county_name, county_name_method,
         in_volusia, lat, lng, geocoded, geocode_quality, county_geometry_check, license_number, record_kind, license_status, secondary_status,
         expiry_date, effective_date, register_file_state, register_file_date)
  select c.id, c.state, c.city, c.zip_code, c.address_line_1, c.address_line_2, c.county_code, c.county_name, c.county_name_method,
         c.in_volusia, c.lat, c.lng, c.geocoded, c.geocode_quality, c.county_geometry_check, c.license_number, c.record_kind, c.license_status,
         c.secondary_status, c.expiry_date, c.effective_date, c.register_file_state, c.register_file_date
    from contractors c join _hit h on h.id = c.id
  on conflict (id) do nothing;

  -- address fields, from the file, non-blank only; pins cleared where the address itself changed
  with u as (
    update contractors c set
           state          = coalesce(h.state, c.state),
           city           = coalesce(h.city, c.city),
           zip_code       = coalesce(h.zip, c.zip_code),
           address_line_1 = coalesce(h.addr1, c.address_line_1),
           address_line_2 = case when h.addr1 is not null then h.addr2 else c.address_line_2 end,
           county_code    = coalesce(h.county_code, c.county_code),
           lat = case when addr_changed then null else c.lat end,
           lng = case when addr_changed then null else c.lng end,
           geocoded = case when addr_changed then false else c.geocoded end,
           geocode_quality = case when addr_changed then null else c.geocode_quality end,
           county_geometry_check = case when addr_changed then null else c.county_geometry_check end,
           updated_at = now()
      from (select h.*, (h.city is not null and upper(btrim(h.city)) is distinct from upper(btrim(c2.city)))
                     or (h.zip is not null and left(h.zip,5) is distinct from left(c2.zip_code,5))
                     or (h.addr1 is not null and upper(btrim(h.addr1)) is distinct from upper(btrim(c2.address_line_1))) as addr_changed
              from _hit h join contractors c2 on c2.id = h.id) h
     where h.id = c.id
       and (   (h.state is not null and h.state is distinct from c.state)
            or (h.city is not null and upper(btrim(h.city)) is distinct from upper(btrim(c.city)))
            or (h.zip is not null and h.zip is distinct from c.zip_code)
            or (h.addr1 is not null and upper(btrim(h.addr1)) is distinct from upper(btrim(c.address_line_1)))
            or (h.county_code is not null and h.county_code is distinct from c.county_code))
    returning c.id, h.kind)
  select count(*) filter (where kind = 'licence'), count(*) filter (where kind = 'business_registration') into n_lic_addr, n_reg_addr from u;

  -- county name from the FILE's county code (the register's own 67-code map); out-of-state codes carry no FL county
  update contractors c set
         county_name = m.county_name,
         county_name_method = case when m.county_name is not null then 'dbpr_county_code' else 'dbpr_county_code_out_of_state' end,
         in_volusia = coalesce(m.county_name = 'volusia', false)
    from _hit h left join _cmap m on m.county_code = h.county_code
   where h.id = c.id and h.county_code is not null
     and c.county_name is distinct from m.county_name;

  -- registrations: their file state and status come from their OWN registration record
  update contractors c set
         secondary_status    = nullif(h.status_code,''),
         license_status      = case h.status_code when 'A' then 'active' when 'I' then 'inactive' else 'not_stated' end,
         expiry_date         = coalesce(nullif(h.expiry_date,''), c.expiry_date),
         effective_date      = coalesce(nullif(h.effective_date,''), c.effective_date),
         register_file_state = 'in_latest_file',
         register_file_date  = p_file_date,
         updated_at          = now()
    from _hit h where h.id = c.id and h.kind = 'business_registration';

  -- a registration carries no licence number in the file: the June-attached number is kept aside, not served as its licence
  with k as (
    update contractors c set license_number_june_baseline = c.license_number, license_number = null, record_kind = 'business_registration'
      from _hit h where h.id = c.id and h.kind = 'business_registration' and c.record_kind = 'licence'
    returning c.id)
  select count(*) into n_kind from k;

  return jsonb_build_object('snapshot', p_snapshot_id, 'matched_licences', n_lic, 'matched_registrations', n_reg,
    'licences_address_restored', n_lic_addr, 'registrations_address_restored', n_reg_addr, 'registrations_licence_number_moved', n_kind);
end $$;
comment on function public.refresh_register_from_snapshot(int, date) is
  '212a (ruling 976): refreshes contractors from a held DBPR construction snapshot with a DECLARED key per record type (licence: licence number; business registration: name + zip5 + original date). Non-blank file values only; previous values kept in contractors_before_212a; refuses to finish when either type matches zero rows.';
revoke all on function public.refresh_register_from_snapshot(int, date) from public, anon, authenticated;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('register-row-disagrees-with-latest-file',
  'A served register row''s state or city disagrees with its own record in the latest state file, or a business registration that is in the file is served as absent from it',
  current_date, 'audit 971 A1/A3/A4: 7,874 out-of-state licences served as FL, 4,612 stale cities, 6,407 registrations wrongly absent',
  'entity_confusion', 'blocking',
$q$with snap as (select snapshot_id from public.dbpr_snapshot_log where is_register_source limit 1),
    lic as (select distinct on (license_number) license_number, nullif(btrim(state),'') state, nullif(btrim(city),'') city
              from public.dbpr_construction_snapshot where snapshot_id = (select snapshot_id from snap) and license_number <> ''
             order by license_number, to_date(nullif(expiry_date,''),'MM/DD/YYYY') desc nulls last, row_no),
    reg as (select full_name, left(zip,5) z5, original_date, min(nullif(btrim(state),'')) state, min(nullif(btrim(city),'')) city
              from public.dbpr_construction_snapshot where snapshot_id = (select snapshot_id from snap) and trade_code = 'QB' and license_number = ''
             group by 1,2,3 having count(*) = 1),
    l as (select (f.state is not null and c.state is distinct from f.state) bad_state,
                 (f.city is not null and upper(btrim(c.city)) is distinct from upper(btrim(f.city))) bad_city, false bad_file
            from public.contractors c join lic f on f.license_number = c.license_number
           where c.active is not false and c.record_kind = 'licence' and c.trade_code is distinct from 'QB'),
    r as (select (f.state is not null and c.state is distinct from f.state),
                 (f.city is not null and upper(btrim(c.city)) is distinct from upper(btrim(f.city))),
                 (c.register_file_state is distinct from 'in_latest_file')
            from public.contractors c join reg f on f.full_name = c.business_name and f.z5 = left(c.zip_code,5) and f.original_date = c.original_date
           where c.active is not false and c.trade_code = 'QB'),
    a as (select * from l union all select * from r)
select count(*) filter (where bad_state or bad_city or bad_file) = 0 as ok,
       count(*) filter (where bad_state or bad_city or bad_file) as row_count,
       count(*) filter (where bad_state) as wrong_state,
       count(*) filter (where bad_city) as wrong_city,
       count(*) filter (where bad_file) as registration_wrongly_absent,
       count(*) as population
  from a$q$,
  'clean', 'served rows matched to their own record in the register-source snapshot (licences by number; registrations by name + zip5 + original date)',
  'Two sources: our served row vs the state file row it matches. Red-run inside 212a against the replayed before-state. A blank file field is not compared. Rows with no unique file match are outside the population, not counted clean.',
  'active', 'ours', 'Refresh with refresh_register_from_snapshot (declared keys per record type); never write a value the file did not publish.',
  'contractors_public', 'blocking');

do $$
declare q text; before jsonb; red jsonb; res jsonb; after jsonb; n_pub_before int; n_pub_after int; n_biz int; slugs_before text;
begin
  select count(*) into n_pub_before from public.contractors_public;
  select count(*) into n_biz from public.businesses;
  select md5(string_agg(slug, ',' order by id)) into slugs_before from public.contractors;
  select detection_sql into q from public.data_defect_registry where defect_id = 'register-row-disagrees-with-latest-file';

  execute format('select to_jsonb(x) from (%s) x', q) into before;
  -- measured on the first (rolled-back) attempt: wrong_state 8,314, wrong_city 3,322, registration_wrongly_absent 6,823 (17,521 rows of
  -- 102,633 matched). The audit's 4,612 cities counted registrations-with-licence-numbers against the LICENCE; this detection
  -- scores them against their own registration record, as the matcher does. Guard: every population non-zero; the red run must
  -- reproduce the before-state exactly.
  if coalesce((before->>'wrong_state')::int,0) = 0 or coalesce((before->>'wrong_city')::int,0) = 0 or coalesce((before->>'registration_wrongly_absent')::int,0) = 0 then
    raise exception '212a: the before-state does not show the measured defects: %', before; end if;

  res := public.refresh_register_from_snapshot(3, date '2026-09-07');
  raise notice '212a refresh: %', res;

  execute format('select to_jsonb(x) from (%s) x', q) into after;
  if (after->>'ok')::boolean is distinct from true or coalesce((after->>'population')::int, 0) <= 0 then
    raise exception '212a: detection not clean after the restoration: %', after; end if;

  -- (d) red run: replay the before-state over the touched rows, measure, and undo
  begin
    update public.contractors c set state = b.state, city = b.city, zip_code = b.zip_code, address_line_1 = b.address_line_1,
           address_line_2 = b.address_line_2, county_code = b.county_code, license_number = b.license_number, record_kind = b.record_kind,
           register_file_state = b.register_file_state, register_file_date = b.register_file_date, license_status = b.license_status,
           license_number_june_baseline = null
      from public.contractors_before_212a b where b.id = c.id;
    execute format('select to_jsonb(x) from (%s) x', q) into red;
    raise exception 'redrun_done';
  exception when raise_exception then
    if sqlerrm <> 'redrun_done' then raise; end if;
  end;
  if (red->>'row_count')::int is distinct from (before->>'row_count')::int then
    raise exception '212a: red run % does not reproduce the before-state %', red, before; end if;

  -- nothing else moved
  select count(*) into n_pub_after from public.contractors_public;
  if n_pub_after <> n_pub_before then raise exception '212a: contractors_public % -> %', n_pub_before, n_pub_after; end if;
  if (select count(*) from public.businesses) <> n_biz then raise exception '212a: businesses changed'; end if;
  if (select md5(string_agg(slug, ',' order by id)) from public.contractors) <> slugs_before then raise exception '212a: a slug changed'; end if;
  if exists (select 1 from public.contractors where record_kind = 'business_registration' and coalesce(license_number,'') <> '') then
    raise exception '212a: a registration still carries a licence number'; end if;
  if has_table_privilege('anon', 'public.contractors_before_212a', 'SELECT') then raise exception '212a: before-state readable by anon'; end if;
  raise notice '212a: before %; after %; red run %', before, after, red;
end $$;

select public._log_action('cc', 'register_restored_from_state_file', 'contractors',
  array['state','city','zip_code','address_line_1','address_line_2','county_code','county_name','register_file_state','record_kind','license_number','refresh_register_from_snapshot','register-row-disagrees-with-latest-file'],
  jsonb_build_object('before_table', 'contractors_before_212a'), (select jsonb_build_object('rows_kept', count(*)) from public.contractors_before_212a),
  'Ruling 976: our loader overwrote the state record (state, city, registration file state); restored from the 7 Sep 2026 file with declared per-type keys.', null);
