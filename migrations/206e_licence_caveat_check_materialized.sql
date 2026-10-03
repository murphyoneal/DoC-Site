-- 206e - licence-status-served-without-date-and-caveat took 267 s inside 206b. The planner inlined the two search CTEs
-- and re-called each search function once per reference per result row (about 7 probes x 25 rows x 3 references).
-- MATERIALIZED calls each function once per probe. The predicate is unchanged; the migration times it and asserts it
-- still returns a population.

update public.data_defect_registry set detection_sql = $q$with probes(q) as (values ('CGC061905'), ('CGC1516933'), ('CRC1331383'), ('CBC057738'), ('roofing'), ('construction'), ('electric')),
    crs as materialized (select p.q, public.contractor_register_search(p.q, 25)::jsonb j from probes p),
    rs  as materialized (select p.q, public.register_search(p.q, 25) j from probes p),
    rows_ as (
      select 'contractor_register_search' fn, r,
             (c.j->>'source_retrieved') is not null as has_retrieved,
             coalesce(c.j->>'coverage_note', '') ~* 'not evidence the licen[cs]e has lapsed' as has_caveat
        from crs c, jsonb_array_elements(c.j->'results') r
      union all
      select 'register_search', r,
             coalesce(r->>'file_date', r->>'record_dated') is not null,
             coalesce(s.j->>'coverage_note', '') ~* '(as of its date|on the date shown)' and coalesce(s.j->>'coverage_note', '') ~* 'renewed or changed since'
        from rs s, jsonb_array_elements(s.j->'results') r),
    checked as (select * from rows_ where r ? 'license_status' and r->>'license_status' is not null),
    bad as (select * from checked where not (r ? 'expiry_date') or not has_retrieved or not has_caveat)
select not exists (select 1 from bad) as ok,
       (select count(*) from bad) as row_count,
       (select count(*) from checked) as population$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 206e: CTEs materialized (267 s inline -> once per probe).'
 where defect_id = 'licence-status-served-without-date-and-caveat';

do $$
declare j jsonb; t timestamptz := clock_timestamp(); ms numeric;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'licence-status-served-without-date-and-caveat')) into j;
  ms := extract(epoch from clock_timestamp() - t) * 1000;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) <= 0 then raise exception '206e: %', j; end if;
  if ms > 60000 then raise exception '206e: still % ms', ms; end if;
  raise notice '206e: % in % ms', j, round(ms);
end $$;
