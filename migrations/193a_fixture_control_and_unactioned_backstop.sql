-- 193a - two hardenings from ruling 912 item 5.
--
-- 1. THE ZZ FIXTURE IS KEPT OFF PUBLIC SEARCH BY A CONTROL, NOT BY ITS OWN VALUES.
--    Measured 2026-10-01. The fixture (ZZC0000001, ruling 723) is excluded BY KEY - public.is_test_fixture() over
--    test_fixture - in contractor_register_search (the public register) and contractor_finder. Nine adversarial
--    queries against the public search (its name, licence, slug, 'zz', 'ZZC', 'do not use', 'dop system check', ...)
--    returned 0. Every OTHER reader misses it only because the fixture's own values were chosen to miss:
--      search_contractors (Roz)  - trade_code is NULL, and `trade_code not in (...)` is NULL, so the row drops.
--                                  A fixture given a trade code would surface in Roz. Not a control.
--      app list sockets over contractors_public - state 'ZZ', county/lat/lng NULL, in_volusia false.
--    Fixed here for Roz: the same key predicate. The list sockets are reported, not changed (see bus): the
--    view serves the fixture's profile URL on purpose (723), so a list exclusion is a view column + socket change.
--    Detection test-fixture-reachable-from-public-search calls the served functions with the fixture's own name and
--    licence, with a positive control so a search that returns nothing cannot pass.
--
-- 2. THE LIVE_FALSE_STATEMENT TAG NEEDS A BACKSTOP THAT NEEDS NO MEMORY. daily_ops_report gains an AMBER line: any
--    finding or question with actioned_at NULL after 7 days, regardless of tags, by recipient, with the oldest ids.
--    (A question blocks as surely as a finding misleads - 807 sat unread for a day.) Tag-driven stays RED at 24h.
--    AMBER lives in the report because the detection contract is boolean; there is no amber state to return.

do $$
declare d text; a1 text; a2 text; anchor text;
begin
  -- 1a. Roz's search excludes registered fixtures by key
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.search_contractors'::regproc;
  d := pg_get_functiondef('public.search_contractors'::regproc);
  if (select count(*) from regexp_matches(d, 'where active=''True''', 'g')) <> 1 then raise exception '193a: search anchor missing or not unique'; end if;
  d := replace(d, 'where active=''True''',
    'where active=''True''' || E'\n' || '      and not public.is_test_fixture(''contractors'', license_number)  -- 193a: a control, not the fixture''s values');
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.search_contractors(text, text, numeric, boolean, integer) to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.search_contractors(text, text, numeric, boolean, integer) to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.search_contractors'::regproc;
  if a2 is distinct from a1 then raise exception '193a: search_contractors grants changed % -> %', a1, a2; end if;

  -- 2. the 7-day backstop in the morning report
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  d := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  anchor := '  exception when others then md := md || format(E''- ERROR (live false statements): %s\n'', sqlerrm); end;';
  if position(anchor in d) = 0 then raise exception '193a: ops-report anchor (191b line) missing'; end if;
  d := replace(d, anchor, anchor || E'\n' ||
$p$  -- 193a (ruling 912): backstop that needs no tag - any finding or question unactioned after 7 days
  begin select string_agg(format('%s→%s %s', kind, to_agent, cnt), ', ' order by to_agent, kind) into s
      from (select to_agent, kind, count(*) cnt from agent_handoff
             where kind in ('finding','question') and actioned_at is null and created_at < now() - interval '7 days'
             group by 1, 2) g;
    select string_agg(id::text, ', ') into s2 from (select id from agent_handoff
             where kind in ('finding','question') and actioned_at is null and created_at < now() - interval '7 days'
             order by created_at limit 10) o;
    select coalesce(sum(cnt), 0) into n from (select count(*) cnt from agent_handoff
             where kind in ('finding','question') and actioned_at is null and created_at < now() - interval '7 days') t;
    md := md || format(E'- %s Bus findings/questions unactioned >7 days: %s%s\n',
      case when coalesce(n,0)=0 then 'OK' else 'AMBER' end, coalesce(n,0),
      case when coalesce(n,0)>0 then ' ('||s||'; oldest '||s2||')' else '' end);
  exception when others then md := md || format(E'- ERROR (unactioned backstop): %s\n', sqlerrm); end;$p$);
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.daily_ops_report() to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.daily_ops_report() to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  if a2 is distinct from a1 then raise exception '193a: daily_ops_report grants changed % -> %', a1, a2; end if;
end $$;

-- 1b. the detection: call what the public and Roz call, with the fixture's own identifiers
insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('test-fixture-reachable-from-public-search',
  'A registered test fixture (test_fixture, register contractors) is returned by the public register search or by Roz''s contractor search',
  'access_control', 'blocking',
  $q$with f as (select t.key, c.slug, c.business_name, c.trade_label from public.test_fixture t
                 join public.contractors c on c.license_number = t.key where t.register = 'contractors'),
         hits as (
           select count(*) n from f, jsonb_array_elements(public.contractor_register_search(f.key, 50)->'results') r where r->>'slug' = f.slug
           union all
           select count(*) from f, jsonb_array_elements(public.contractor_register_search(f.business_name, 50)->'results') r where r->>'slug' = f.slug
           union all
           select count(*) from f, jsonb_array_elements(public.search_contractors(f.trade_label, null, null, false, 200000)) e where e->>'license_number' = f.key),
         pos as (select jsonb_array_length(public.contractor_register_search('roofing', 5)->'results') r1,
                        jsonb_array_length(public.search_contractors('General Contractor', null, null, false, 5)) r2)
    select (select count(*) from f) > 0 and (select sum(n) from hits) = 0 and pos.r1 > 0 and pos.r2 > 0 as ok,
           (select sum(n) from hits) as row_count
      from pos$q$,
  '193a. Served path: calls the public register search with each fixture''s licence and name, and Roz''s search filtered to its trade; a positive control (real queries return rows) and a non-empty fixture list keep it from passing vacuously. Does NOT cover the app''s contractors_public list sockets (state/county/city/map), which miss the fixture by its values - reported on the bus.');

select public._log_action('cc', 'fixture_control_and_unactioned_backstop', 'search_contractors', array['search_contractors','daily_ops_report','test-fixture-reachable-from-public-search'], null,
  jsonb_build_object('roz_fixture_exclusion', 'by key (is_test_fixture)', 'ops_report', 'AMBER: findings/questions unactioned >7d'),
  'Ruling 912 item 5: the ZZ fixture was kept out of Roz''s search only by its NULL trade code; now by key, with a served-path detection. And a tag-free 7-day backstop for unactioned findings and questions.', null);
