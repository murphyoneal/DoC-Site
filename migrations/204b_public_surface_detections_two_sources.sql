-- 204b - the four detections guarding the public contractor register declare a population and learn what is fabricated
-- from two independent sources (ruling 932/934, the 39 by consequence: public surface first).
--
-- The public-surface gate's red run showed the shape: remove the fixture's test_fixture row and a check that reads its
-- definition of "fake" from test_fixture goes quietly green. The independent definition is the reserved ZZ licence range
-- (ruling 723), read from the registers themselves.
--   test-fixture-reachable-from-public-search  fixture set = test_fixture UNION reserved ZZ range; also probes
--                                              register_search (the homepage's function, 201b); population = fixtures examined
--   reserved-test-fixture-in-public-search     same set; population = fixtures examined
--   reserved-prefix-row-not-a-registered-fixture  already compares range vs registry (the disagreement IS the alarm);
--                                              population = reserved-range rows examined. Retire it WITH the fixtures
--                                              (backlog 288), or its population goes to zero and it errors - by design.
--   contractor-status-vocabulary-and-shape     population = served rows examined. Its fixture exclusion reads test_fixture,
--                                              but that direction FAILS SAFE: remove the row and the fixture's
--                                              'Current'/'Active' statuses turn the check RED, not green. Noted, not changed.
-- Each rewrite is executed before it is stored and must return ok + a positive population.

update public.data_defect_registry set detection_sql =
$q$with f as (
      select c.license_number as key, c.slug, c.business_name, c.trade_label
        from public.contractors c
       where upper(c.license_number) like 'ZZ%'
          or exists (select 1 from public.test_fixture t where t.register = 'contractors' and t.key = c.license_number)),
    hits as (
      select count(*) n from f, jsonb_array_elements(public.register_search(f.key, 50)->'results') r where r->>'license_number' = f.key or r->>'slug' = f.slug
      union all
      select count(*) from f, jsonb_array_elements(public.register_search(f.business_name, 50)->'results') r where r->>'license_number' = f.key or r->>'slug' = f.slug
      union all
      select count(*) from f, jsonb_array_elements(public.contractor_register_search(f.key, 50)->'results') r where r->>'slug' = f.slug
      union all
      select count(*) from f, jsonb_array_elements(public.search_contractors(f.trade_label, null, null, false, 200000)) e where e->>'license_number' = f.key),
    pos as (select jsonb_array_length(public.register_search('roofing', 5)->'results') r1,
                   jsonb_array_length(public.search_contractors('General Contractor', null, null, false, 5)) r2)
select (select count(*) from f) > 0 and (select sum(n) from hits) = 0 and pos.r1 > 0 and pos.r2 > 0 as ok,
       (select sum(n) from hits) as row_count,
       (select count(*) from f) as population
  from pos$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204b: fixture set = test_fixture UNION the reserved ZZ range (independent of the registry); probes register_search too; population = fixtures examined (zero errors the run).'
 where defect_id = 'test-fixture-reachable-from-public-search';

update public.data_defect_registry set detection_sql =
$q$with f as (
      select 'contractors' as register, c.license_number as key, coalesce(t.label, c.business_name) as label
        from public.contractors c left join public.test_fixture t on t.register = 'contractors' and t.key = c.license_number
       where upper(c.license_number) like 'ZZ%' or t.key is not null
      union
      select 'agent_license_roster', r.license_number, coalesce(t.label, r.license_number)
        from public.agent_license_roster r left join public.test_fixture t on t.register = 'agent_license_roster' and t.key = r.license_number
       where upper(r.license_number) like 'ZZ%' or t.key is not null),
    leak as (
      select 1 from f
       where (f.register = 'agent_license_roster' and exists (select 1 from jsonb_array_elements(public.agent_register_search(f.label, 25)->'results') e where e->>'license_number' = f.key))
          or (f.register = 'contractors' and (
                exists (select 1 from jsonb_array_elements(public.register_search(f.label, 25)->'results') e where e->>'license_number' = f.key)
             or exists (select 1 from jsonb_array_elements(public.contractor_register_search(f.label, 25)->'results') e where e->>'license_number' = f.key)
             or exists (select 1 from jsonb_array_elements(public.contractor_finder(f.label, null, null, 60, 0)->'results') e
                         where e->>'slug' in (select b.slug from businesses b join contractors c on c.id = b.canonical_contractor_id where c.license_number = f.key)))))
select not exists (select 1 from leak) and (select count(*) from f) > 0 as ok,
       (select count(*) from leak) as row_count,
       (select count(*) from f) as population$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204b: fixture set = test_fixture UNION the reserved ZZ range; register_search added; population = fixtures examined.'
 where defect_id = 'reserved-test-fixture-in-public-search';

update public.data_defect_registry set detection_sql =
$q$with reserved as (
      select 'contractors' as register, c.license_number as key from contractors c where upper(c.license_number) like 'ZZ%'
      union all select 'agent_license_roster', r.license_number from agent_license_roster r where upper(r.license_number) like 'ZZ%'
      union all select 'reg_us_or.ccb_active_license', o.license_number from reg_us_or.ccb_active_license o where upper(o.license_number) like 'ZZ%'),
    bad as (select * from reserved r where r.register = 'reg_us_or.ccb_active_license' or not public.is_test_fixture(r.register, r.key))
select not exists (select 1 from bad) as ok,
       (select count(*) from bad) as row_count,
       (select count(*) from reserved) as population$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204b: population = reserved-range rows examined; two sources (the range and the registry) and their disagreement is the alarm. Retire with the fixtures (backlog 288) - after that its population is zero and it errors, by design.'
 where defect_id = 'reserved-prefix-row-not-a-registered-fixture';

update public.data_defect_registry set detection_sql =
$q$with served as (
      select c.* from public.contractors c
       where c.active is not false  -- 192a: served rows; a re-activated withdrawn row turns this red
         and not exists (select 1 from public.test_fixture f where f.register = 'contractors' and f.key = c.license_number)),
    bad as (
      select * from served c
       where c.primary_status ~ '^[0-9]+$' or c.secondary_status ~ '^[0-9]+$'
          or c.secondary_status is not null and c.secondary_status not in ('A','I')
          or c.license_status is null
          or c.license_status not in ('active','inactive','not_stated','not_in_latest_file')
          or (c.register_file_state = 'in_latest_file' and c.license_status is distinct from
                case c.secondary_status when 'A' then 'active' when 'I' then 'inactive' else 'not_stated' end)
          or (c.register_file_state = 'absent_from_latest_file' and c.license_status = 'active'))
select count(*) = 0 as ok, count(*) as row_count,
       count(*) filter (where primary_status ~ '^[0-9]+$' or secondary_status ~ '^[0-9]+$') as shape_failures,
       (select count(*) from served) as population
  from bad$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 204b: population = served rows examined. The fixture exclusion reads test_fixture but FAILS SAFE: without the registry row the fixture''s Current/Active statuses turn this red, not green. Single-source on the exclusion, documented.'
 where defect_id = 'contractor-status-vocabulary-and-shape';

do $$
declare r record; q text; res record;
begin
  for r in select defect_id, detection_sql from public.data_defect_registry
            where defect_id in ('test-fixture-reachable-from-public-search','reserved-test-fixture-in-public-search',
                                'reserved-prefix-row-not-a-registered-fixture','contractor-status-vocabulary-and-shape') loop
    execute r.detection_sql into res;
    if res.ok is distinct from true then raise exception '204b: % is not green after rewrite', r.defect_id; end if;
    if coalesce(res.population, 0) <= 0 then raise exception '204b: % has no population', r.defect_id; end if;
  end loop;
end $$;

select public._log_action('cc', 'public_surface_detections_two_sources', 'data_defect_registry',
  array['test-fixture-reachable-from-public-search','reserved-test-fixture-in-public-search','reserved-prefix-row-not-a-registered-fixture','contractor-status-vocabulary-and-shape'], null,
  jsonb_build_object('second_source', 'reserved ZZ licence range (723)', 'population', 'declared on all four'),
  'Ruling 932/934: the detections guarding the public register no longer learn what is fake only from the registry they guard.', null);
