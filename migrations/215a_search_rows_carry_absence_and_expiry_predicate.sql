-- 215a - search rows say when a licence is missing from the latest state file, and the expiry boolean gets a predicate
-- name (ruling 978 item 2; ruling 966). ADDITIVE: nothing is removed until the pages that read record_dated have shipped.
--
-- Audit 971 C: contractor_register_search (and so register_search's construction half, which the homepage renders)
-- computed record_dated from the expiry date only. 7,167 rows absent from the latest file (7,116 with no expiry, 51
-- with a future one) came back record_dated null/false and rendered "UNCLAIMED", under a group header naming the very
-- file they are missing from. The homepage footer promises the opposite: shown as last recorded, with the date last seen.
-- Ruling 966: "A BOOLEAN NAMED AS A NOUN PHRASE WILL BE RENDERED AS THAT NOUN PHRASE BY SOMEBODY" - record_dated was
-- rendered as "Record dated" on two surfaces meaning two things.
--   contractor_register_search rows gain: absent_from_latest_file, last_seen_file_date, expiry_has_passed
--   contractor_finder rows gain:          expiry_has_passed (absent_from_latest_file already exists)
--   record_dated stays, unchanged, until the homepage/finder code that reads it is deployed (coupled-deploy rule);
--   a follow-up migration removes it.
-- contractor_register_search is a browser RPC: re-granted and asserted. contractor_finder is service-role only.

do $$
declare d text; a1 text; a2 text; f regprocedure;
begin
  f := 'public.contractor_register_search(text,integer)'::regprocedure;
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
  d := pg_get_functiondef(f);
  if position($a$'record_dated',   ( to_date(nullif(c.expiry_date,''),'MM/DD/YYYY') < current_date )$a$ in d) = 0 then
    raise exception '215a: contractor_register_search anchor missing'; end if;
  d := replace(d, $a$'record_dated',   ( to_date(nullif(c.expiry_date,''),'MM/DD/YYYY') < current_date )$a$,
    $a$'record_dated',   ( to_date(nullif(c.expiry_date,''),'MM/DD/YYYY') < current_date ),
           -- 215a: the absence the page must state, and the expiry boolean under a predicate name (966)
           'absent_from_latest_file', (c.register_file_state = 'absent_from_latest_file'),
           'last_seen_file_date', to_char(c.register_file_date, 'YYYY-MM-DD'),
           'expiry_has_passed', ( to_date(nullif(c.expiry_date,''),'MM/DD/YYYY') < current_date )$a$);
  execute d;
  grant execute on function public.contractor_register_search(text,integer) to anon, authenticated;
  select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
  if a2 is distinct from a1 then raise exception '215a: contractor_register_search grants % -> %', a1, a2; end if;

  f := 'public.contractor_finder'::regproc::oid::regprocedure;
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
  d := pg_get_functiondef(f);
  if position($a$'absent_from_latest_file', (h.register_file_state = 'absent_from_latest_file')$a$ in d) = 0 then
    raise exception '215a: contractor_finder anchor missing'; end if;
  d := replace(d, $a$'absent_from_latest_file', (h.register_file_state = 'absent_from_latest_file')$a$,
    $a$'absent_from_latest_file', (h.register_file_state = 'absent_from_latest_file'),
           'expiry_has_passed', (h.expiry_date ~ '^\d{2}/\d{2}/\d{4}$' AND to_date(h.expiry_date,'MM/DD/YYYY') < current_date)  -- 215a (966)$a$);
  execute d;
  if a1 like '%anon=X%' then execute format('grant execute on function %s to anon', f); end if;
  if a1 like '%authenticated=X%' then execute format('grant execute on function %s to authenticated', f); end if;
  select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
  if a2 is distinct from a1 then raise exception '215a: contractor_finder grants % -> %', a1, a2; end if;
end $$;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('search-row-absence-not-served',
  'A public search row for a licence absent from the latest state file does not carry that absence in its payload',
  current_date, 'audit 971 C: 7,167 absent rows rendered UNCLAIMED in homepage search', 'temporal', 'blocking',
$q$with probes(q) as (values ('CAC058343'), ('county:volusia'), ('roofing'), ('construction')),
    rows_ as (select r from probes p, jsonb_array_elements(public.register_search(p.q, 50)->'results') r where r->>'register' = 'construction'),
    known as (select r, c.register_file_state from rows_ join public.contractors c on c.license_number = r->>'license_number' and c.slug = r->>'slug')
select count(*) filter (where (r->>'absent_from_latest_file') is null
                           or (r->>'absent_from_latest_file')::boolean is distinct from (register_file_state = 'absent_from_latest_file')) = 0 as ok,
       count(*) filter (where (r->>'absent_from_latest_file') is null
                           or (r->>'absent_from_latest_file')::boolean is distinct from (register_file_state = 'absent_from_latest_file')) as row_count,
       count(*) filter (where register_file_state = 'absent_from_latest_file') as absent_rows_seen,
       count(*) as population
  from known$q$,
  'clean', 'construction rows returned by register_search for 4 probes, joined back to their register row',
  'Served path: calls register_search (what the homepage renders) and compares each row''s absent_from_latest_file with the register''s own file state. The page rendering it is the gate''s concern.',
  'active', 'ours', 'Serve absent_from_latest_file and last_seen_file_date on every construction search row; pages render the absence instead of UNCLAIMED.',
  'register_search', 'blocking');

do $$
declare j jsonb; r jsonb;
begin
  r := (select x from jsonb_array_elements(public.register_search('CAC058343', 5)->'results') x where x->>'register' = 'construction' limit 1);
  if r is null or (r->>'absent_from_latest_file') is distinct from 'true' or r->>'last_seen_file_date' is null then
    raise exception '215a: CAC058343 (absent) does not carry its absence: %', r; end if;
  if not has_function_privilege('anon','public.contractor_register_search(text,integer)','EXECUTE') then raise exception '215a: lost anon'; end if;
  if (public.contractor_finder('roofing', null, null, 1, 0)->'results'->0) ? 'expiry_has_passed' is not true then raise exception '215a: finder lacks expiry_has_passed'; end if;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'search-row-absence-not-served')) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int,0) = 0 or coalesce((j->>'absent_rows_seen')::int,0) = 0 then
    raise exception '215a: detection %', j; end if;
  raise notice '215a: CAC058343 %; detection %', r->>'last_seen_file_date', j;
end $$;
