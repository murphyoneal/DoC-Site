-- 146b — the schema-separation rule, enforced; and the data behind the coverage map (ruling relayed
-- 2026-09-28, with work order 717).
--
-- ONE REGISTER, ONE TABLE. Each state's register keeps what its source said, as it said it: Florida
-- DBPR has its own 29 trade codes, status vocabulary and layout; California CSLB will have none of
-- them. Merging another state into contractors would force a lowest-common-denominator schema and
-- lose what each source publishes. So every other state's register lands in ITS OWN table in its own
-- schema (e.g. reg_us_ca.cslb_licence), with a thin common view over the top for search - the
-- box/plug pattern geo_reference's country_iso / iso_3166_2 keys exist for.
-- ENFORCED, not just written down: contractors refuses any row that is not the Florida DBPR file.
-- Measured before adding it: all 114,104 rows are source DBPR_FL, source_state FL.
alter table public.contractors drop constraint if exists contractors_is_florida_dbpr_only;
alter table public.contractors add constraint contractors_is_florida_dbpr_only
  check (source = 'DBPR_FL' and source_state = 'FL');
comment on constraint contractors_is_florida_dbpr_only on public.contractors is
  'contractors is the Florida DBPR construction register and nothing else. Another state''s register goes in its own table in its own schema (one register, one table), joined for search by a common view. 146b, 2026-09-28.';

-- where each HELD register lives, so the map can say what we hold
alter table public.register_coverage add column if not exists held_table text;
update public.register_coverage set held_table = 'public.contractors (Florida DBPR construction licence file)'
 where state_geo_id = 'US-12' and profession = 'construction' and held_table is null;
update public.register_coverage set held_table = 'public.agent_license_roster + public.agent_license_status (Florida DBPR real estate files)'
 where state_geo_id = 'US-12' and profession = 'real_estate' and held_table is null;

-- The coverage map: one row per state, each profession's coverage in three states, plus demand
-- (self-registrations received, as counts only - never names).
create or replace function public.coverage_map()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_agg(jsonb_build_object(
    'geo_id', s.geo_id, 'abbr', s.admin1_abbr, 'name', s.name,
    'coverage', (select jsonb_object_agg(rc.profession, jsonb_build_object(
        'state', case rc.coverage_state when 'held' then 'held' when 'no_register_exists' then 'no_register_exists' else 'not_yet_collected' end,
        'retrieved', rc.retrieved_date, 'source', rc.source, 'authority', rc.authority, 'access_type', rc.access_type,
        'source_url', rc.source_url, 'cadence', rc.cadence, 'posted_date', rc.posted_date, 'surveyed_at', rc.surveyed_at,
        'notes', coalesce(rc.survey_notes, rc.notes)))
      from register_coverage rc where rc.state_geo_id = s.geo_id),
    'registrations', (select count(*) from registered_business b where b.state_geo_id = s.geo_id and b.review_state <> 'withdrawn'))
    order by s.name)
  from geo_reference s
  where s.country_iso = 'US' and s.admin_level = 1
$$;
revoke all on function public.coverage_map() from public, anon, authenticated;
grant execute on function public.coverage_map() to service_role;

do $a$
declare n int; fl jsonb;
begin
  select jsonb_array_length(public.coverage_map()) into n;
  select e->'coverage' into fl from jsonb_array_elements(public.coverage_map()) e where e->>'abbr' = 'FL';
  if n <> 51 or fl->'construction'->>'state' <> 'held' or fl->'real_estate'->>'state' <> 'held' then
    raise exception '146b: coverage_map states % FL %', n, fl;
  end if;
end $a$;
