-- 146d — coverage_map() also returns register_scope, so the map can say what a state's contractor
-- register covers (licence / registration / home improvement / residential / trades only / none).
-- The 102 survey cells themselves were written by docs/register-survey-2026-09-28/load_survey.py
-- (PATCH over REST, service_role) from the five survey files beside it.
create or replace function public.coverage_map()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_agg(jsonb_build_object(
    'geo_id', s.geo_id, 'abbr', s.admin1_abbr, 'name', s.name,
    'coverage', (select jsonb_object_agg(rc.profession, jsonb_build_object(
        'state', case rc.coverage_state when 'held' then 'held' when 'no_register_exists' then 'no_register_exists' else 'not_yet_collected' end,
        'retrieved', rc.retrieved_date, 'source', rc.source, 'authority', rc.authority, 'access_type', rc.access_type,
        'source_url', rc.source_url, 'cadence', rc.cadence, 'posted_date', rc.posted_date, 'surveyed_at', rc.surveyed_at,
        'scope', rc.register_scope, 'notes', coalesce(rc.survey_notes, rc.notes)))
      from register_coverage rc where rc.state_geo_id = s.geo_id),
    'registrations', (select count(*) from registered_business b where b.state_geo_id = s.geo_id and b.review_state <> 'withdrawn'))
    order by s.name)
  from geo_reference s
  where s.country_iso = 'US' and s.admin_level = 1
$$;
revoke all on function public.coverage_map() from public, anon, authenticated;
grant execute on function public.coverage_map() to service_role;
