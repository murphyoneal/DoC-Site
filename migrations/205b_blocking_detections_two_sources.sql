-- 205b - the two BLOCKING detections that read red were detection defects, not exposures. Both are fixed to read what
-- they guard (ruling 936 / the 932 two-source rule).
--
-- anon-callable-secdef-functions has been red since 2026-09-30. Its SQL had no allowlist, so it alarmed on the
-- browser-called RPCs that are SUPPOSED to be anon-callable. Measured 2026-10-02, the anon/authenticated-executable
-- SECURITY DEFINER functions in public (supabase_admin's excluded) are exactly:
--   contractor_register_search, agent_register_search, register_search (201b).
-- These are the three the browser calls; there is no exposure. The fix compares TWO lists:
--   (1) browser_rpc - a DECLARED table, one row per function a browser may call, each with its reason;
--   (2) the catalogue - what pg_proc actually grants.
-- Disagreement in EITHER direction is the alarm: an undeclared grant is an exposure, and a declared function that lost
-- its grant is an outage. Population = declared rows (an emptied declaration errors the run, it does not pass).
-- register_search also gets the grant-and-payload check the other two have (register-search-anon-execute-missing
-- covered only contractor_register_search).
--
-- register-row-field-shifted read all of contractors. Its 3 red rows are the withdrawn 807 rows (active=false since
-- 192a, 0 in contractors_public). It now reads served rows (active is not false), with the served count as population.
-- The 3 withdrawn rows stay a named gap in the note: they are not served and are kept as the record of what was withdrawn.

create table if not exists public.browser_rpc (
  function_sig regprocedure primary key,
  reason text not null,
  declared_on date not null default current_date
);
comment on table public.browser_rpc is
  '205b (ruling 932/936): the SECURITY DEFINER functions a browser may call as anon. anon-callable-secdef-functions compares this list with the catalogue and alarms on disagreement in either direction. Adding a row is a decision to expose a function - say why.';
alter table public.browser_rpc enable row level security;
revoke all on public.browser_rpc from public, anon, authenticated;

insert into public.browser_rpc (function_sig, reason) values
  ('public.contractor_register_search(text,integer)'::regprocedure, 'Public contractor register search on departmentofconstruction.com (browser fetch to /rest/v1/rpc).'),
  ('public.agent_register_search(text,integer)'::regprocedure,      'Public agent register search (browser fetch to /rest/v1/rpc).'),
  ('public.register_search(text,integer)'::regprocedure,            'Two-board homepage search, construction + ECLB (201b; browser fetch to /rest/v1/rpc).')
on conflict (function_sig) do update set reason = excluded.reason;

update public.data_defect_registry set detection_sql =
$q$with granted as (
      select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.prosecdef and pg_get_userbyid(p.proowner) <> 'supabase_admin'
         and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE'))),
    declared as (select function_sig::oid as oid from public.browser_rpc),
    undeclared_grant as (select oid from granted except select oid from declared),
    declared_without_grant as (select d.oid from declared d where not has_function_privilege('anon', d.oid, 'EXECUTE'))
select not exists (select 1 from undeclared_grant) and not exists (select 1 from declared_without_grant) as ok,
       (select count(*) from undeclared_grant) + (select count(*) from declared_without_grant) as row_count,
       (select string_agg(oid::regprocedure::text, ', ') from undeclared_grant) as undeclared_grants,
       (select string_agg(oid::regprocedure::text, ', ') from declared_without_grant) as declared_but_ungranted,
       (select count(*) from declared) as population$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 205b: was red since 2026-09-30 with no allowlist - it alarmed on the three browser RPCs that must be anon-callable. Now compares the declared list (browser_rpc) with the catalogue; either direction of disagreement is the alarm; population = declared rows.'
 where defect_id = 'anon-callable-secdef-functions';

update public.data_defect_registry set detection_sql =
$q$select (has_function_privilege('anon','public.contractor_register_search(text,integer)','EXECUTE')
         and (public.contractor_register_search('CONSTRUCTION',1)::jsonb->>'field_status') = 'present'
         and has_function_privilege('anon','public.register_search(text,integer)','EXECUTE')
         and (public.register_search('roofing',1)->>'field_status') = 'present'
         and jsonb_array_length(public.register_search('roofing',1)->'results') > 0) as ok,
       2 as population$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 205b: also asserts register_search (201b, the homepage search): grant AND a non-empty present payload.'
 where defect_id = 'register-search-anon-execute-missing';

update public.data_defect_registry set detection_sql =
$q$select count(*) filter (where zip_code = 'FL' or state ~ ' ') = 0 as ok,
       count(*) filter (where zip_code = 'FL' or state ~ ' ') as row_count,
       count(*) as population
  from public.contractors where active is not false$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 205b: reads SERVED rows only (active is not false). The 3 withdrawn shifted rows (192a, active=false, 0 in contractors_public) are the named gap: kept as the record of the withdrawal, never served. Re-activating one turns this red.'
 where defect_id = 'register-row-field-shifted';

do $$
declare r record; j jsonb;
begin
  for r in select defect_id, detection_sql from public.data_defect_registry
            where defect_id in ('anon-callable-secdef-functions','register-search-anon-execute-missing','register-row-field-shifted') loop
    execute format('select to_jsonb(x) from (%s) x', r.detection_sql) into j;
    if (j->>'ok')::boolean is distinct from true then raise exception '205b: % is not green after rewrite: %', r.defect_id, j; end if;
    if coalesce((j->>'population')::bigint, 0) <= 0 then raise exception '205b: % has no population', r.defect_id; end if;
  end loop;
end $$;

select public._log_action('cc', 'blocking_detections_two_sources', 'data_defect_registry',
  array['anon-callable-secdef-functions','register-search-anon-execute-missing','register-row-field-shifted','browser_rpc'], null,
  jsonb_build_object('browser_rpc', 3, 'anon_secdef', 'declared list vs catalogue, both directions', 'field_shifted', 'served rows only'),
  'Ruling 936: the two firing blocking detections were detection defects (no allowlist; withdrawn rows read as served).', null);
