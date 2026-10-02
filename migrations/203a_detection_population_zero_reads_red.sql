-- 203a - a detection whose population is zero reads RED, not green; every run records whether a population was declared
-- (ruling 932, item 1).
--
-- 932: "a detection whose population drops to zero reads RED, not green. 'Nothing to check' and 'nothing wrong' are
-- different states and we have been conflating them." The public-surface gate's red run (2026-10-02) went green after its
-- registry row was removed: it found nothing to check and reported nothing wrong.
-- The runner already errored examined=0 for the old examined+hit contract. The common contract returns only `ok`, so a
-- predicate over an empty population passed silently. Now, for every detection:
--   population  = the first numeric of population / examined / examined_count / denominator the detection returns
--   0           -> error_class 'errored', ok NULL: EMPTY POPULATION
--   absent      -> population_state 'undeclared' (recorded, not failed: the runner cannot tell an undeclared population
--                  from a silent one, so it says which it is). Declaring one is the second-source pass (932 item 2).
-- A meta-detection, detection-population-undeclared, counts active detections whose latest run declared no population:
-- red by design until that pass is done, so the gap is on the board instead of in a note.

alter table public.defect_detection_runs add column if not exists population bigint;
alter table public.defect_detection_runs add column if not exists population_state text
  check (population_state is null or population_state in ('declared','zero','undeclared'));
comment on column public.defect_detection_runs.population_state is
  '203a (ruling 932): declared = the detection returned a numeric population > 0; zero = it examined nothing and is recorded errored; undeclared = it returned no population, so an empty population cannot be told from a clean one.';

do $$
declare d text; a1 text; a2 text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.run_defect_detections'::regproc;
  d := pg_get_functiondef('public.run_defect_detections'::regproc);
  if position('v_state text; v_class text;' in d) = 0
     or position($a$IF (v_json ? 'hit') AND jsonb_typeof(v_json->'hit')='number' THEN v_rows := (v_json->>'hit')::numeric::bigint; END IF;$a$ in d) = 0
     or position($a$v_rows := (v_json->>'hit')::numeric::bigint;
          v_ok := (v_rows = 0);$a$ in d) = 0
     or position('INSERT INTO defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id, error_class)' in d) = 0
     or position('VALUES (v_run, v_at, r.defect_id, v_ok, v_err, v_ms, v_rows, NULL, v_class);' in d) = 0
     or position('v_ok := NULL; v_err := NULL; v_rows := NULL; v_class := NULL;' in d) = 0 then
    raise exception '203a: an anchor is missing';
  end if;

  d := replace(d, 'v_state text; v_class text;', 'v_state text; v_class text; v_pop jsonb; v_pop_n bigint; v_pop_state text;  -- 203a');
  d := replace(d, 'v_ok := NULL; v_err := NULL; v_rows := NULL; v_class := NULL;',
                  'v_ok := NULL; v_err := NULL; v_rows := NULL; v_class := NULL; v_pop := NULL; v_pop_n := NULL; v_pop_state := NULL;');
  d := replace(d, $a$IF (v_json ? 'hit') AND jsonb_typeof(v_json->'hit')='number' THEN v_rows := (v_json->>'hit')::numeric::bigint; END IF;$a$,
$a$IF (v_json ? 'hit') AND jsonb_typeof(v_json->'hit')='number' THEN v_rows := (v_json->>'hit')::numeric::bigint; END IF;
          -- 203a (ruling 932): nothing to check is not nothing wrong
          v_pop := coalesce(v_json->'population', v_json->'examined', v_json->'examined_count', v_json->'denominator');
          IF v_pop IS NULL OR jsonb_typeof(v_pop) <> 'number' THEN
            v_pop_state := 'undeclared';
          ELSE
            v_pop_n := (v_pop #>> '{}')::numeric::bigint;
            IF v_pop_n = 0 THEN
              v_pop_state := 'zero'; v_ok := NULL; v_class := 'errored';
              v_err := 'EMPTY POPULATION: the detection examined nothing - "nothing to check" is not "nothing wrong" (ruling 932)';
            ELSE
              v_pop_state := 'declared';
            END IF;
          END IF;$a$);
  d := replace(d, $a$v_rows := (v_json->>'hit')::numeric::bigint;
          v_ok := (v_rows = 0);$a$,
$a$v_rows := (v_json->>'hit')::numeric::bigint;
          v_ok := (v_rows = 0);
          v_pop_n := (v_json->>'examined')::numeric::bigint; v_pop_state := 'declared';$a$);
  d := replace(d, 'INSERT INTO defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id, error_class)',
                  'INSERT INTO defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id, error_class, population, population_state)');
  d := replace(d, 'VALUES (v_run, v_at, r.defect_id, v_ok, v_err, v_ms, v_rows, NULL, v_class);',
                  'VALUES (v_run, v_at, r.defect_id, v_ok, v_err, v_ms, v_rows, NULL, v_class, v_pop_n, v_pop_state);');
  -- the examined=0 branch of the old contract records its state too
  d := replace(d, $a$v_err := 'BLIND SPOT: examined=0 (predicate evaluated nothing)'; v_class := 'errored';$a$,
                  $a$v_err := 'BLIND SPOT: examined=0 (predicate evaluated nothing)'; v_class := 'errored'; v_pop_n := 0; v_pop_state := 'zero';$a$);
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.run_defect_detections'::regproc;
  if a2 is distinct from a1 then raise exception '203a: grants changed % -> %', a1, a2; end if;
end $$;

insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('detection-population-undeclared',
  'An active detection returned no population in its latest run, so an empty population cannot be told from a clean result (ruling 932)',
  'completeness', 'material',
  $q$with latest as (select distinct on (defect_id) defect_id, population_state, run_at
                       from public.defect_detection_runs order by defect_id, run_at desc),
          act as (select d.defect_id from public.data_defect_registry d where d.status = 'active' and d.defect_id <> 'detection-population-undeclared')
     select count(*) filter (where l.population_state is distinct from 'declared' and l.population_state is distinct from 'zero') = 0 as ok,
            count(*) filter (where l.population_state is distinct from 'declared' and l.population_state is distinct from 'zero') as row_count,
            count(*) as population
       from act a left join latest l using (defect_id)$q$,
  'Red by design at creation (2026-10-02): no detection declared a population before 203a. Each turns green as the second-source pass (932 item 2) adds a population. Its own population is the count of active detections, so it cannot pass on an empty registry.');

select public._log_action('cc', 'detection_population_zero_reads_red', 'run_defect_detections', array['run_defect_detections','defect_detection_runs','detection-population-undeclared'], null,
  jsonb_build_object('zero_population', 'errored, ok NULL', 'undeclared', 'recorded + meta-detection red by design'),
  'Ruling 932: "nothing to check" and "nothing wrong" are different states; the runner now says which it saw.', null);
