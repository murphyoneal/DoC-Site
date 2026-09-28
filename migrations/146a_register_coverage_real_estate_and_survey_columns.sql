-- 146a — register_coverage gains real estate, and the columns the 50-state register survey needs
-- (work orders 716, 717).
--
-- THE "FLORIDA REAL ESTATE READS not_held" PREMISE: there was no real-estate row at all. The table held
-- 51 x {construction, electrical}; the Florida not_held row is ELECTRICAL, which is correct (electrical
-- licences are not in the construction file). The table was right about what it covered and silent
-- about real estate, because the self-registration check only ever checks contractor licences.
-- Real estate is added now: Florida HELD (agent_license_roster 496,407 / agent_license_status 493,556),
-- the other 50 not_held.
--
-- THREE STATES, NEVER TWO (717 §3): 'no_register_exists' is a permanent fact about a STATE (it does not
-- license that profession at state level); 'not_held' is a fact about US (a register exists and we have
-- not pulled it). Nothing is set to no_register_exists here - only the survey may, from a fetched source.
-- The check function is unchanged: any state other than 'held' still reads "Not verified. We don't yet
-- hold ...". Wording for no_register_exists is written when the first survey row sets it.

alter table public.register_coverage drop constraint if exists register_coverage_profession_check;
alter table public.register_coverage add constraint register_coverage_profession_check
  check (profession in ('construction', 'electrical', 'real_estate'));
alter table public.register_coverage drop constraint if exists register_coverage_coverage_state_check;
alter table public.register_coverage add constraint register_coverage_coverage_state_check
  check (coverage_state in ('held', 'not_held', 'no_register_exists'));

alter table public.register_coverage
  add column if not exists authority       text,
  add column if not exists access_type     text check (access_type in ('bulk_download', 'api', 'lookup_form_only', 'records_request', 'paid', 'none', 'not_established')),
  add column if not exists source_url      text,
  add column if not exists file_format     text,
  add column if not exists approx_rows     text,
  add column if not exists cadence         text,
  add column if not exists posted_date     date,
  add column if not exists fields_present  text[],
  add column if not exists code_list_url   text,
  add column if not exists terms           text,
  add column if not exists surveyed_at     date,
  add column if not exists survey_notes    text;

insert into public.register_coverage (state_geo_id, profession, coverage_state, source, retrieved_date, notes)
select g.geo_id, 'real_estate',
       case when g.geo_id = 'US-12' then 'held' else 'not_held' end,
       case when g.geo_id = 'US-12' then 'Florida DBPR real estate licence roster (Florida Real Estate Commission)' end,
       case when g.geo_id = 'US-12' then date '2026-07-23' end,
       case when g.geo_id = 'US-12' then 'Held as two halves of different vintage: identity (agent_license_roster, 496,407 rows, licences issued to 3 Sep 2026) and status (agent_license_status, 493,556 rows, file RE_20260723). retrieved_date is the STATUS vintage, because status is what a check reports.' end
  from public.geo_reference g
 where g.country_iso = 'US' and g.admin_level = 1
on conflict (state_geo_id, profession) do nothing;

do $a$
declare n int; fl text;
begin
  select count(*) into n from register_coverage;
  select coverage_state into fl from register_coverage where state_geo_id = 'US-12' and profession = 'real_estate';
  if n <> 153 or fl <> 'held' then raise exception '146a: rows % (153) FL real estate %', n, fl; end if;
end $a$;
