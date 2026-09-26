-- 137d — The golden-parcel check measures every report against the PRODUCTION timeout.
-- Ruling row 676 item 4: "the automated check runs with NO TIME LIMIT, so it passes a parcel the
-- live page fails - give the check the production timeout. THAT is the real defect."
--
-- The production limit is not 25 s, as the backlog note assumed: the site calls get_pir_report
-- through PostgREST, which connects as `authenticator` (statement_timeout=8s; service_role sets
-- none of its own). Measured 2026-09-26 after 137c: Santa Rosa's report is 200 at 7.3-8.5 s on the
-- page and 7.87 s by direct RPC, i.e. just under the limit. The 500 was this 8 s limit.
--
-- DESIGN: the hash comparison still runs with no limit (a slow parcel's sections stay checked;
-- enforcing the limit on the call would turn every section into 'error' and lose them). Each call
-- is TIMED, and a '<latency>' row records over_production_timeout / near_production_timeout (>75%)
-- / match. The limit is READ from authenticator's role config at run time, never hardcoded; if it
-- cannot be read the row says limit_unknown rather than passing.

do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.check_golden_parcels()'::regprocedure);
  new_def := replace(def,
    'DECLARE v_run uuid := gen_random_uuid(); v_at timestamptz := now(); gp record; v_report jsonb; sec record;',
    'DECLARE v_run uuid := gen_random_uuid(); v_at timestamptz := now(); gp record; v_report jsonb; sec record;
  v_t0 timestamptz; v_ms numeric; v_limit_ms numeric; v_lim text;');
  new_def := replace(new_def,
    '  PERFORM set_config(''statement_timeout'',''0'', true);',
    '  PERFORM set_config(''statement_timeout'',''0'', true);
  -- 137d: the production limit, read from the role PostgREST connects as.
  SELECT substring(c from ''^statement_timeout=(.*)$'') INTO v_lim
    FROM pg_roles r, unnest(r.rolconfig) c WHERE r.rolname = ''authenticator'' AND c LIKE ''statement_timeout=%'';
  v_limit_ms := CASE
    WHEN v_lim ~ ''^[0-9.]+ms$''  THEN substring(v_lim from ''^[0-9.]+'')::numeric
    WHEN v_lim ~ ''^[0-9.]+s$''   THEN substring(v_lim from ''^[0-9.]+'')::numeric * 1000
    WHEN v_lim ~ ''^[0-9.]+min$'' THEN substring(v_lim from ''^[0-9.]+'')::numeric * 60000
    WHEN v_lim ~ ''^[0-9.]+$''    THEN v_lim::numeric
    ELSE NULL END;');
  new_def := replace(new_def,
    '    BEGIN v_report := public.get_pir_report(gp.co_no, gp.parcel_id); EXCEPTION WHEN others THEN v_report := NULL; END;',
    '    v_t0 := clock_timestamp();
    BEGIN v_report := public.get_pir_report(gp.co_no, gp.parcel_id); EXCEPTION WHEN others THEN v_report := NULL; END;
    v_ms := extract(epoch from clock_timestamp() - v_t0) * 1000;
    INSERT INTO golden_parcel_run(run_id,run_at,co_no,parcel_id,section,structural_status,value_status,current_value)
    VALUES (v_run, v_at, gp.co_no, gp.parcel_id, ''<latency>'',
      CASE WHEN v_limit_ms IS NULL THEN ''limit_unknown''
           WHEN v_ms > v_limit_ms THEN ''over_production_timeout''
           WHEN v_ms > 0.75 * v_limit_ms THEN ''near_production_timeout''
           ELSE ''match'' END,
      ''n/a'', round(v_ms)::text || '' ms of '' || coalesce(v_limit_ms::text, ''?'') || '' ms'');');
  if new_def = def or position('<latency>' in new_def) = 0 or position('v_limit_ms numeric' in new_def) = 0
     or position('rolname = ''authenticator''' in new_def) = 0 then
    raise exception '137d: anchors did not apply cleanly - nothing changed';
  end if;
  execute new_def;
end $f$;

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('golden-report-within-production-timeout',
 'Every golden parcel''s report must build inside the production statement timeout (the latest golden run, within 8 days)',
 date '2026-09-26', 'backlog 258 / ruling row 676 item 4', 'completeness', 'blocking',
 $d$with last as (select run_id from public.golden_parcel_run where section = '<latency>'
                   and run_at > now() - interval '8 days' order by run_at desc limit 1)
  select (exists (select 1 from last)
          and not exists (select 1 from public.golden_parcel_run g, last
                           where g.run_id = last.run_id and g.section = '<latency>'
                             and g.structural_status in ('over_production_timeout','limit_unknown'))) as ok$d$,
 'the <latency> rows of the most recent golden run in the last 8 days',
 'SERVED-PATH TIMING, measured inside the database: it times get_pir_report as the golden check calls it (usually warm cache) and cannot see page overhead or cold starts, so a pass here is necessary, not sufficient - the Santa Rosa page took 7.3-8.5 s while the RPC took 7.9 s. near_production_timeout does NOT fail this check; it is the early warning. No golden run in 8 days is red: an unrun check is not a passing one.',
 'active', 'ours', 'clean',
 'Find the slow sub-function (time each get_parcel_* call for the parcel) and fix that path; do not raise the timeout.')
on conflict (defect_id) do nothing;

grant execute on function public.check_golden_parcels() to service_role;
