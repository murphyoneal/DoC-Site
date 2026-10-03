-- 208a - the /map finder names the register it covers and the one it does not, in its payload, and its trade facet
-- no longer offers the electrical board's trades (ruling 955).
--
-- /map is the construction register only: contractor_finder never reads reg_us_fl. The page already carries a static
-- line ("Electrical contractors are licensed separately and are not in it", live 2026-10-03). It names no board and
-- links nowhere, and it is page text that no check can see. Now the coverage is DATA:
--   register_coverage.covered      the Construction Industry Licensing Board file, with its date
--   register_coverage.not_covered  the Electrical Contractors' Licensing Board, and where to search it (/c, both boards)
-- in both modes (counties and results). FinderShell renders it, and detection finder-names-its-register-coverage
-- asserts it.
-- Trade facet: doc_category 'electrical' holds exactly one construction row: CALKINS ELECTRIC CONSTRUCTION CO INC, a QB
-- business registration with no licence number. So /map in Volusia offered "Electrical (1)": a trade that looks covered
-- and is not. The facet now excludes the electrical board's categories (electrical, alarm_system). The business still
-- appears in results.
-- contractor_finder is SECURITY DEFINER, service_role only. Its ACL is captured and compared.

do $$
declare d text; a1 text; a2 text; cov text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.contractor_finder'::regproc;
  d := pg_get_functiondef('public.contractor_finder'::regproc);
  cov := $c$'register_coverage', jsonb_build_object(
        'covered', jsonb_build_array(jsonb_build_object('register', 'construction', 'label', 'Construction Industry Licensing Board',
          'file', 'Florida DBPR construction licence file',
          'file_date', (select to_char(capture_date, 'YYYY-MM-DD') from dbpr_snapshot_log where is_register_source limit 1))),
        'not_covered', jsonb_build_array(jsonb_build_object('register', 'electrical', 'label', 'Electrical Contractors'' Licensing Board',
          'trades', jsonb_build_array('Electrical', 'Alarm System'),
          'search_href', '/c',
          'note', 'Electrical and alarm-system contractors are licensed by a separate board. Its file has no map locations, so they are not on this map; the register search covers both boards.'))),$c$;
  if position($a$RETURN jsonb_build_object('mode', 'counties', 'counties', v_rows,$a$ in d) = 0
     or position($a$'mode', 'results', 'query', v_q, 'county', v_county, 'trade', v_trade,$a$ in d) = 0
     or position($a$AND c2.doc_category NOT IN ('qualifier_business', 'education_provider')$a$ in d) = 0 then
    raise exception '208a: an anchor is missing';
  end if;
  d := replace(d, $a$RETURN jsonb_build_object('mode', 'counties', 'counties', v_rows,$a$,
                  $a$RETURN jsonb_build_object('mode', 'counties', 'counties', v_rows, $a$ || cov);
  d := replace(d, $a$'mode', 'results', 'query', v_q, 'county', v_county, 'trade', v_trade,$a$,
                  $a$'mode', 'results', 'query', v_q, 'county', v_county, 'trade', v_trade, $a$ || cov);
  -- 208a: the electrical board's trades are not offered as a facet on a construction-only map
  d := replace(d, $a$AND c2.doc_category NOT IN ('qualifier_business', 'education_provider')$a$,
                  $a$AND c2.doc_category NOT IN ('qualifier_business', 'education_provider', 'electrical', 'alarm_system')$a$);
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.contractor_finder to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.contractor_finder to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.contractor_finder'::regproc;
  if a2 is distinct from a1 then raise exception '208a: contractor_finder grants % -> %', a1, a2; end if;
end $$;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('finder-names-its-register-coverage',
  'The /map finder does not state, in its served payload, which licence board it covers and which it does not - or offers a facet for a trade it does not hold',
  current_date, 'ruling 955 (an electrician is not findable on /map; "not found" reads as "not licensed")', 'completeness', 'blocking',
$q$with probes as (
      select public.contractor_finder(null, null, null, 1, 0) j
      union all select public.contractor_finder('roofing', null, null, 5, 0)
      union all select public.contractor_finder(null, 'volusia', null, 5, 0)),
    chk as (
      select (j->'register_coverage'->'covered'->0->>'label') = 'Construction Industry Licensing Board'
         and (j->'register_coverage'->'not_covered'->0->>'label') = 'Electrical Contractors'' Licensing Board'
         and (j->'register_coverage'->'not_covered'->0->>'search_href') is not null
         and not exists (select 1 from jsonb_array_elements(coalesce(j->'trades', '[]'::jsonb)) t where t->>'trade' in ('electrical','alarm_system')) as ok
        from probes)
select bool_and(ok) and count(*) = 3 as ok, count(*) filter (where not ok) as row_count, count(*) as population from chk$q$,
  'clean', '3 finder probes: the counties view, a statewide query, a county view (Volusia holds the one construction row categorised electrical)',
  'Reads the served payload (contractor_finder), not the page. The page renders register_coverage; whether it does is visible to the gate, not to SQL.',
  'active', 'ours', 'Keep register_coverage in both finder modes and keep the electrical board''s trades out of the construction-only facet.',
  'contractors_public', 'blocking');

do $$
declare j jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'finder-names-its-register-coverage')) into j;
  if (j->>'ok')::boolean is distinct from true or (j->>'population')::int <> 3 then raise exception '208a: detection %', j; end if;
end $$;

select public._log_action('cc', 'finder_names_its_register_coverage', 'contractor_finder', array['contractor_finder','finder-names-its-register-coverage'],
  jsonb_build_object('coverage', 'static page text only', 'facet', 'offered electrical (1, a QB registration)'),
  jsonb_build_object('coverage', 'register_coverage in payload, both modes', 'facet', 'electrical board trades excluded'),
  'Ruling 955: a construction-only map must say which board it covers and name the one it does not.', null);
