-- 148a — the first register outside Florida: Oregon Construction Contractors Board (ruling relayed
-- 2026-09-28: Oregon first, one state, one table, reported before the next).
--
-- SOURCE: data.oregon.gov dataset g77e-6bhs "CCB Active Licenses" (Socrata; Public Domain U.S.
-- Government). ACTIVE licences only, republished whole each day (every row's :created_at is the day
-- of publication, so Socrata's :id is NOT a stable key).
-- NATURAL KEY, MEASURED on all 56,341 rows (2026-09-28): (license_number, license_type) is unique -
-- license_number alone is not (45,619 distinct): one row per licence x endorsement type.
-- rmi_name - the Responsible Managing Individual, Oregon's QUALIFIER - is present on 50,701 rows.
-- license_type is the CCB's own code (RGC, RSC, CGC2, LBPR, ...); the source gives its own label for
-- each row in endorsement_text. No code list is published, so none is inferred.
--
-- ONE REGISTER, ONE TABLE (146b): its own schema, every column as the source names it, as text, as
-- the source wrote it. Typed values are derived when served, never stored over the original.
--
-- ACTIVE-ONLY SEMANTICS: a licence that lapses simply disappears from the next file. An upsert alone
-- would keep it forever. So each load stamps last_seen_at, and finish_or_ccb_load() marks every row
-- the latest file did not carry as absent_from_latest_file - the same two states the Florida register
-- uses. Nothing is deleted.

create schema if not exists reg_us_or;
revoke all on schema reg_us_or from public, anon, authenticated;
grant usage on schema reg_us_or to service_role;

create table if not exists reg_us_or.ccb_active_license (
  license_number   text not null,
  license_type     text not null,
  related_key      text,
  related_type     text,
  county_code      text,
  county_name      text,
  lic_exp_date     text,
  orig_regis_date  text,
  bond_company     text,
  bond_amount      text,
  bond_exp_date    text,
  ins_company      text,
  ins_amount       text,
  ins_exp_date     text,
  full_name        text,
  address          text,
  city             text,
  state            text,
  zip_code         text,
  phone_number     text,
  fax_number       text,
  rmi_name         text,
  exempt_text      text,
  endorsement_text text,
  socrata_row_id   text,
  source_rows_updated_at timestamptz not null,
  first_seen_at    timestamptz not null,
  last_seen_at     timestamptz not null,
  register_file_state text not null check (register_file_state in ('in_latest_file', 'absent_from_latest_file')),
  primary key (license_number, license_type)
);
alter table reg_us_or.ccb_active_license enable row level security;
revoke all on reg_us_or.ccb_active_license from public, anon, authenticated;
grant select, insert, update on reg_us_or.ccb_active_license to service_role;
comment on table reg_us_or.ccb_active_license is
  'PROVENANCE: Oregon Construction Contractors Board, "CCB Active Licenses", data.oregon.gov dataset g77e-6bhs (Socrata, Public Domain U.S. Government), active licences only, republished daily. Every source column kept verbatim as text. Natural key (license_number, license_type), measured unique on 56,341 rows 2026-09-28. rmi_name = Responsible Managing Individual (the qualifier). register_file_state: a licence absent from the latest file has lapsed from the ACTIVE list - it is kept, never deleted. 148a.';

-- one batch of source rows; upsert on the natural key
create or replace function public.load_or_ccb_batch(p_rows jsonb, p_retrieved timestamptz, p_source_updated timestamptz)
returns integer language plpgsql volatile security definer set search_path = public, reg_us_or as $$
declare n int;
begin
  insert into reg_us_or.ccb_active_license as t (license_number, license_type, related_key, related_type, county_code, county_name,
      lic_exp_date, orig_regis_date, bond_company, bond_amount, bond_exp_date, ins_company, ins_amount, ins_exp_date, full_name,
      address, city, state, zip_code, phone_number, fax_number, rmi_name, exempt_text, endorsement_text, socrata_row_id,
      source_rows_updated_at, first_seen_at, last_seen_at, register_file_state)
  select r->>'license_number', r->>'license_type', r->>'related_key', r->>'related_type', r->>'county_code', r->>'county_name',
      r->>'lic_exp_date', r->>'orig_regis_date', r->>'bond_company', r->>'bond_amount', r->>'bond_exp_date', r->>'ins_company',
      r->>'ins_amount', r->>'ins_exp_date', r->>'full_name', r->>'address', r->>'city', r->>'state', r->>'zip_code',
      r->>'phone_number', r->>'fax_number', r->>'rmi_name', r->>'exempt_text', r->>'endorsement_text', r->>':id',
      p_source_updated, p_retrieved, p_retrieved, 'in_latest_file'
    from jsonb_array_elements(p_rows) r
  on conflict (license_number, license_type) do update set
      related_key = excluded.related_key, related_type = excluded.related_type, county_code = excluded.county_code,
      county_name = excluded.county_name, lic_exp_date = excluded.lic_exp_date, orig_regis_date = excluded.orig_regis_date,
      bond_company = excluded.bond_company, bond_amount = excluded.bond_amount, bond_exp_date = excluded.bond_exp_date,
      ins_company = excluded.ins_company, ins_amount = excluded.ins_amount, ins_exp_date = excluded.ins_exp_date,
      full_name = excluded.full_name, address = excluded.address, city = excluded.city, state = excluded.state,
      zip_code = excluded.zip_code, phone_number = excluded.phone_number, fax_number = excluded.fax_number,
      rmi_name = excluded.rmi_name, exempt_text = excluded.exempt_text, endorsement_text = excluded.endorsement_text,
      socrata_row_id = excluded.socrata_row_id, source_rows_updated_at = excluded.source_rows_updated_at,
      last_seen_at = excluded.last_seen_at, register_file_state = 'in_latest_file';
  get diagnostics n = row_count;
  return n;
end $$;

-- close a load: assert it is complete, mark what the file no longer carries, record where it is held
create or replace function public.finish_or_ccb_load(p_retrieved timestamptz, p_source_updated timestamptz, p_expected integer)
returns jsonb language plpgsql volatile security definer set search_path = public, reg_us_or as $$
declare seen int; keys int; absent int; total int;
begin
  if p_expected is null or p_expected <= 0 then raise exception 'finish_or_ccb_load: expected count % - an empty source is not a load', p_expected; end if;
  select count(*), count(distinct (license_number, license_type)) into seen, keys
    from reg_us_or.ccb_active_license where last_seen_at = p_retrieved;
  if seen <> p_expected or keys <> p_expected then
    raise exception 'finish_or_ccb_load: this run carried % rows (% distinct keys), the source said %', seen, keys, p_expected;
  end if;
  update reg_us_or.ccb_active_license set register_file_state = 'absent_from_latest_file'
   where last_seen_at < p_retrieved and register_file_state <> 'absent_from_latest_file';
  get diagnostics absent = row_count;
  select count(*) into total from reg_us_or.ccb_active_license;
  update register_coverage set coverage_state = 'held',
      source = 'Oregon Construction Contractors Board, CCB Active Licenses (data.oregon.gov g77e-6bhs)',
      retrieved_date = p_retrieved::date, posted_date = p_source_updated::date,
      held_table = 'reg_us_or.ccb_active_license (Oregon CCB active licences)'
   where state_geo_id = 'US-41' and profession = 'construction';
  insert into data_source_registry (county_name, category, table_name, source_url, access_technique, page_size, last_count,
      last_successful_pull_date, notes, active, pull_mode, cadence_basis)
  select 'Statewide (Oregon)', 'contractors', 'reg_us_or.ccb_active_license', 'https://data.oregon.gov/resource/g77e-6bhs.json',
      'socrata_soda', 5000, p_expected, p_retrieved::date,
      'Oregon CCB Active Licenses. Active licences only; republished daily. Natural key (license_number, license_type). finish_or_ccb_load marks rows missing from the latest file as absent_from_latest_file (never deleted). 148a.',
      true, 'manual', 'publisher_stated'
  where not exists (select 1 from data_source_registry where table_name = 'reg_us_or.ccb_active_license');
  update data_source_registry set last_count = p_expected, last_successful_pull_date = p_retrieved::date
   where table_name = 'reg_us_or.ccb_active_license';
  return jsonb_build_object('rows_in_this_file', seen, 'distinct_keys', keys, 'newly_absent', absent, 'held_total', total);
end $$;

revoke all on function public.load_or_ccb_batch(jsonb, timestamptz, timestamptz), public.finish_or_ccb_load(timestamptz, timestamptz, integer)
  from public, anon, authenticated;
grant execute on function public.load_or_ccb_batch(jsonb, timestamptz, timestamptz), public.finish_or_ccb_load(timestamptz, timestamptz, integer)
  to service_role;
