-- 217a - a licence that gets no page fails a check (ruling 998), and the licences in the held file that the register
-- never loaded are on the board instead of in a note.
--
-- 998: "nothing assigns slugs to NEW rows arriving in a register file. A licence that lands tomorrow gets no page and
-- nothing fails." Measured 2026-10-03:
--   served register rows with no slug                 0
--   served register rows with no business page        0
--   licences in the register-source file (snapshot 3, 130,474 distinct) with NO register row at all   38,012
--     of which ACTIVE in that file                    2,323   (e.g. CGC001072 - register_search returns none_found)
--     by trade: FRO 19,178, CGC 5,214, CRS1 4,944, CBC 2,230, CAC 1,171, CRC 1,107, CCC 1,079, CFC 845, ...
--   138a recorded "37,765 licences not in the register ... a separate step, reported for a ruling" - never done.
--   The June baseline appears to have loaded a subset; nothing has loaded the rest since.
-- Two detections:
--   register-row-without-a-page (blocking, contractors_public): a served row with no slug or no business page. Clean.
--   held-file-licence-not-in-register (material, register_search): a licence in the file we hold that the register does
--     not serve - red, expected defect, ACKNOWLEDGED with the measured counts and a review date. It clears when a loader
--     brings them in (that loader must assign slugs under the 216a/216b shapes and never touch an existing one). The
--     search's no-result sentence is corrected in the same change so it does not claim the file holds nothing.

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('register-row-without-a-page',
  'A served register row has no slug or belongs to no business page - a licence nobody can open',
  current_date, 'ruling 998 (nothing assigns slugs to new register rows)', 'completeness', 'blocking',
$q$select count(*) filter (where c.slug is null or c.slug = '' or not exists (select 1 from public.business_licences bl where bl.contractor_id = c.id)) = 0 as ok,
       count(*) filter (where c.slug is null or c.slug = '' or not exists (select 1 from public.business_licences bl where bl.contractor_id = c.id)) as row_count,
       count(*) as population
  from public.contractors_public c where c.active$q$,
  'clean', 'served register rows (contractors_public, active)',
  'Fires the day a loader inserts rows without slugs or without running the business register. A loader must assign slugs (216a/216b shapes for out-of-state addresses) and never rewrite an existing one.',
  'active', 'ours', 'Assign a slug and a business to every new register row in the same load.', 'contractors_public', 'blocking'),
('held-file-licence-not-in-register',
  'A licence in the register-source state file we hold has no row in the register we serve - search says nothing matched',
  current_date, 'cc 2026-10-03 while building register-row-without-a-page (138a''s deferred step, never done)', 'completeness', 'material',
$q$with snap as (select snapshot_id from public.dbpr_snapshot_log where is_register_source limit 1),
    f as (select distinct on (license_number) license_number, status_code from public.dbpr_construction_snapshot
           where snapshot_id = (select snapshot_id from snap) and license_number <> '' order by license_number, row_no),
    missing as (select * from f where not exists (select 1 from public.contractors c where c.license_number = f.license_number))
select not exists (select 1 from missing) as ok,
       (select count(*) from missing) as row_count,
       (select count(*) from missing where status_code = 'A') as active_missing,
       (select count(*) from f) as population$q$,
  'defect', 'distinct licence numbers in the register-source snapshot',
  'Licences only (registrations carry no number and are matched by name+zip+date elsewhere). Red until a loader brings the missing licences in.',
  'active', 'ours', 'Load the missing licences with slugs, categories and business grouping; then this clears.', 'register_search', 'material');

update public.data_defect_registry
   set acknowledgement = 'Measured 2026-10-03: 38,012 licences in the 7 Sep 2026 file have no register row (2,323 of them active in the file, e.g. CGC001072). 138a deferred loading them "for a ruling" and it was never done. Search no longer says the file holds nothing; it says the register we publish has no match. Clears when a loader brings them in. Review 2026-10-17.',
       expires_at = timestamptz '2026-10-17 23:59:59-04'
 where defect_id = 'held-file-licence-not-in-register';

do $$
declare a jsonb; b jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'register-row-without-a-page')) into a;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'held-file-licence-not-in-register')) into b;
  if (a->>'ok')::boolean is distinct from true or coalesce((a->>'population')::int,0) = 0 then raise exception '217a: page detection %', a; end if;
  if (b->>'ok')::boolean is distinct from false or coalesce((b->>'population')::int,0) = 0 then raise exception '217a: coverage detection should be red: %', b; end if;
  raise notice '217a: pages %; held-file coverage %', a, b;
end $$;
