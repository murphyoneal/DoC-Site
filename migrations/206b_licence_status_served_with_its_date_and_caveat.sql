-- 206b - the licence "contradiction" detection is retired for its framing and replaced by the check that protects the
-- reader (ruling 937 section 3b).
--
-- licence-status-and-expiry-date-contradict-each-other flagged active licences with a past expiry date (4 today:
-- CGC061905, CGC1516933, CRC1331383, CBC057738, all 08/31/2026). It presumes license_status means "today". The served
-- copy denies that. contractor_register_search serves, in one payload:
--   - license_status and expiry_date on each result;
--   - source_retrieved (2026-09-07);
--   - a coverage note: a record dated before today "is not evidence the licence has lapsed".
-- register_search serves file_date on each row, and its note says the file is shown as of its date. So the served claim
-- is the state register as retrieved on that date. That is disclosed, and the material rating stands.
-- The real guard: a status is never served without its expiry date, its retrieval date AND the caveat. Drop any one of
-- the three and the status becomes a false statement.
-- The replacement probes both public search functions with the four licences plus three common words, and checks every
-- result row that carries a license_status. Population = result rows examined.
-- The retired row keeps its knowledge. Its two stale numbers are corrected, measured today: "the 74 contradictions" -> 4,
-- and "114,097 rows marked active" -> 95,405 (contractor_name_index; 95,404 in contractors_public).

update public.data_defect_registry set
  status = 'retired',
  remediation = replace(remediation, 'disclose the 74 contradictions', 'disclose the contradictions (4 measured 2026-10-02; 74 when written)'),
  expected_denominator = '95,405 rows marked active in contractor_name_index (measured 2026-10-02; was recorded as 114,097 before gating)',
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 206b RETIRED (ruling 937): the framing presumes license_status means today; the served copy says it is the register as retrieved, with the date and a caveat that a past expiry is not evidence of lapse. Replaced by licence-status-served-without-date-and-caveat, which guards the three things that make the status true.'
 where defect_id = 'licence-status-and-expiry-date-contradict-each-other';

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation)
values ('licence-status-served-without-date-and-caveat',
  'A public search result serves license_status without its expiry date, its retrieval date, or the caveat that a past-dated record is not evidence of lapse',
  current_date, 'ruling 937 section 3b: replaces licence-status-and-expiry-date-contradict-each-other', 'temporal', 'blocking',
$q$with probes(q) as (values ('CGC061905'), ('CGC1516933'), ('CRC1331383'), ('CBC057738'), ('roofing'), ('construction'), ('electric')),
    crs as (select p.q, public.contractor_register_search(p.q, 25)::jsonb j from probes p),
    rs  as (select p.q, public.register_search(p.q, 25) j from probes p),
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
  'clean', 'result rows carrying license_status across both public search functions, for 7 probes',
  'Population = result rows carrying a status. A probe set that returns no status rows errors the run (zero population), it does not pass. The caveat test is a phrase match against the served note: rewording the note turns this red on purpose, so the new wording gets read before it ships.',
  'active', 'ours',
  'Keep license_status, expiry_date, a retrieval date and the not-evidence-of-lapse caveat in the same payload on every public surface that serves a licence status.');

do $$
declare j jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'licence-status-served-without-date-and-caveat')) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) <= 0 then
    raise exception '206b: replacement not green with a population: %', j; end if;
  raise notice '206b: %', j;
end $$;

select public._log_action('cc', 'licence_contradiction_retired_for_coverage_check', 'data_defect_registry',
  array['licence-status-and-expiry-date-contradict-each-other','licence-status-served-without-date-and-caveat'],
  jsonb_build_object('contradictions_recorded', 74, 'denominator_recorded', 114097),
  jsonb_build_object('contradictions_measured', 4, 'denominator_measured', 95405),
  'Ruling 937 section 3b: the served status is the register as retrieved, disclosed; guard the three fields that keep it true.', null);
