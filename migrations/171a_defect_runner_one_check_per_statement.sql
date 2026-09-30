-- 171a - the defect runner runs one check per top-level statement (ruling 823 R1 a-c).
--
-- MEASURED 2026-09-30: cron defect-detections-daily failed 45/45 runs since 2026-08-20, every run at EXACTLY
-- 120 s. Cause, from the code, not the symptom:
--   * run_defect_detections() executes all 188 checks inside ONE top-level statement. statement_timeout is armed
--     once, at statement start; its set_config('statement_timeout','20000') re-arms nothing, so the whole suite
--     shares the session's 120 s budget.
--   * a timeout is SQLSTATE 57014 (query_canceled), which EXCEPTION WHEN OTHERS deliberately does not catch. The
--     cancel escapes the per-check handler and aborts the transaction, ROLLING BACK EVERY RESULT ALREADY WRITTEN.
--   * the suite needs tens of minutes: on the last manual run (08-26) one check took 467 s, one 135 s, one 94 s.
-- So the Palm Beach check was merely where the shared clock ran out, and 45 runs left zero rows.
--
-- NEW SHAPE:
--   enqueue_defect_detections()   daily (job 'defect-detections-daily', 07:00): one queue row per active check.
--   run_next_defect_detection()   every 15 s (job 'defect-detections-worker'): runs ONE pending check. Each check
--                                 is its own top-level statement with its own budget; its result commits alone.
--   A check that overruns is killed by the statement timeout and its tick rolls back. The next tick sees that
--   the previous worker run FAILED on a statement timeout and records the first pending check (the one that
--   was running - one check per tick makes the attribution exact) as timed_out, with a result row.
--   defect_detection_status: per active check, its last EXECUTION; unrun in 48 h = red (823 b).
--   Detection defect-detection-suite-not-completing + the morning brief watch the suite itself (823 c).

create table if not exists public.defect_detection_queue (
  run_id      uuid        not null,
  defect_id   text        not null,
  queued_at   timestamptz not null default now(),
  state       text        not null check (state in ('pending','done','timed_out')),
  finished_at timestamptz,
  primary key (run_id, defect_id)
);
comment on table public.defect_detection_queue is
  'One row per check per daily run (171a). pending until a worker tick runs it; done when its result row is written; timed_out when a worker tick died on the statement timeout while running it. A pending row older than a day is a check the suite never reached.';
revoke all on public.defect_detection_queue from anon, authenticated;
alter table public.defect_detection_queue enable row level security;

alter table public.defect_detection_runs add column if not exists executed_at timestamptz;
comment on column public.defect_detection_runs.executed_at is
  'When THIS check actually executed (171a). run_at is the run''s enqueue time, shared by every check in the run.';

create or replace function public.enqueue_defect_detections() returns uuid
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare v_run uuid := gen_random_uuid();
begin
  -- a run still pending from yesterday is not silently discarded: its unreached checks stay visible as pending
  insert into defect_detection_queue (run_id, defect_id, state)
  select v_run, defect_id, 'pending' from data_defect_registry where status = 'active';
  return v_run;
end $$;

-- The body of one check: identical contract logic to run_defect_detections(), for ONE defect.
create or replace function public._execute_one_detection(p_run uuid, p_run_at timestamptz, p_defect text) returns void
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare r record; v_json jsonb; v_ok boolean; v_err text; v_rows bigint; v_ms int; t0 timestamptz; v_state text; v_class text;
begin
  select defect_id, detection_sql into r from data_defect_registry where defect_id = p_defect;
  t0 := clock_timestamp();
  begin
    execute 'SELECT to_jsonb(t) FROM (' || E'\n' || rtrim(btrim(r.detection_sql), ';') || E'\n) t LIMIT 1' into v_json;
    if v_json is null then
      v_err := 'NON-CONFORMING: detection returned no rows'; v_class := 'errored';
    elsif v_json ? 'ok' then
      if jsonb_typeof(v_json->'ok') = 'boolean' then
        v_ok := (v_json->>'ok')::boolean;
        if (v_json ? 'hit') and jsonb_typeof(v_json->'hit') = 'number' then v_rows := (v_json->>'hit')::numeric::bigint; end if;
      else
        v_err := 'NON-CONFORMING: ok is not boolean (' || coalesce(jsonb_typeof(v_json->'ok'),'absent') || ')'; v_class := 'errored';
      end if;
    elsif (v_json ? 'examined') and (v_json ? 'hit') then
      if (v_json->>'examined') is null or (v_json->>'examined')::numeric = 0 then
        v_err := 'BLIND SPOT: examined=0 (predicate evaluated nothing)'; v_class := 'errored';
      else
        v_rows := (v_json->>'hit')::numeric::bigint; v_ok := (v_rows = 0);
      end if;
    else
      v_err := 'NON-CONFORMING: no ok / examined+hit contract; keys=[' || coalesce((select string_agg(k, ',') from jsonb_object_keys(v_json) k),'') || ']'; v_class := 'errored';
    end if;
  exception when others then
    get stacked diagnostics v_err = message_text, v_state = returned_sqlstate;
    v_ok := null; v_rows := null;
    if v_state in ('42P01','42703') then
      v_class := 'not_applicable'; v_err := 'NOT_APPLICABLE (' || v_state || '): ' || v_err;
    elsif v_state = '42501' then
      v_class := 'errored'; v_err := 'PERMISSION DENIED (' || v_state || '): ' || v_err;
    else
      v_class := 'errored'; v_err := 'EXEC ERROR (' || v_state || '): ' || v_err;
    end if;
  end;
  v_ms := round(extract(epoch from clock_timestamp() - t0) * 1000);
  insert into defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id, error_class, executed_at)
  values (p_run, p_run_at, p_defect, v_ok, v_err, v_ms, v_rows, null, v_class, t0);
end $$;

create or replace function public.run_next_defect_detection() returns text
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare q record; last_run record; v_run_at timestamptz;
begin
  -- 1. Did the previous worker tick die on a statement timeout? Then the check it was running is the first
  --    pending one (one check per tick, fixed order) - record it, so a slow check is a result, not a silence.
  select d.status, d.return_message, d.end_time into last_run
    from cron.job j join cron.job_run_details d using (jobid)
   where j.jobname = 'defect-detections-worker' and d.end_time is not null
   order by d.start_time desc limit 1;
  select * into q from defect_detection_queue where state = 'pending' order by queued_at, defect_id limit 1;
  if q is null then return 'idle'; end if;
  select min(queued_at) into v_run_at from defect_detection_queue where run_id = q.run_id;
  if last_run.status = 'failed' and last_run.return_message ilike '%statement timeout%' and last_run.end_time > q.queued_at then
    update defect_detection_queue set state = 'timed_out', finished_at = now() where run_id = q.run_id and defect_id = q.defect_id;
    insert into defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id, error_class, executed_at)
    values (q.run_id, v_run_at, q.defect_id, null,
            'TIMEOUT: exceeded the per-check statement budget and was cancelled. An unfinished check is not a pass (823 b); find out why it is slow before optimising it (823 e).',
            null, null, null, 'errored', last_run.end_time);
    return 'recorded_timeout:' || q.defect_id;
  end if;
  -- 2. Run exactly one check. If it overruns, this whole tick rolls back and step 1 records it next tick.
  perform _execute_one_detection(q.run_id, v_run_at, q.defect_id);
  update defect_detection_queue set state = 'done', finished_at = now() where run_id = q.run_id and defect_id = q.defect_id;
  return 'ran:' || q.defect_id;
end $$;

revoke all on function public.enqueue_defect_detections() from public, anon, authenticated;
revoke all on function public._execute_one_detection(uuid, timestamptz, text) from public, anon, authenticated;
revoke all on function public.run_next_defect_detection() from public, anon, authenticated;
grant execute on function public.enqueue_defect_detections() to service_role;
grant execute on function public.run_next_defect_detection() to service_role;

-- 823 b: an unrun check is not a passing check.
create or replace view public.defect_detection_status as
select r.defect_id, r.severity, x.executed_at as last_executed, x.ok as last_ok, x.error_class as last_error_class,
       case when x.executed_at is null or x.executed_at < now() - interval '48 hours' then 'unrun_48h'
            when x.error_class = 'errored' then 'errored'
            when x.error_class = 'not_applicable' then 'not_applicable'
            when x.ok then 'ok' else 'red' end as state
  from data_defect_registry r
  left join lateral (select coalesce(d.executed_at, d.run_at) executed_at, d.ok, d.error_class
                       from defect_detection_runs d where d.defect_id = r.defect_id
                      order by coalesce(d.executed_at, d.run_at) desc limit 1) x on true
 where r.status = 'active';
comment on view public.defect_detection_status is
  'Per active check, its last EXECUTION and a state. unrun_48h means the check has not executed in 48 hours and counts as RED, never as a pass (ruling 823 b). 171a.';
revoke all on public.defect_detection_status from anon, authenticated;

-- 823 c: the suite's own health, as a check (and in the morning brief, which already reads defect_detection_runs).
insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('defect-detection-suite-not-completing',
  'The defect-detection suite has checks that have not executed in 48 hours, or a daily run with checks still pending after 24 hours',
  'completeness', 'blocking',
  $d$select (not exists (select 1 from defect_detection_status where state = 'unrun_48h')
            and not exists (select 1 from defect_detection_queue where state = 'pending' and queued_at < now() - interval '24 hours')) as ok$d$,
  'Ruling 823 c: the suite watches itself. Cannot go red if the WHOLE suite is dead (it would not run) - that case is covered by the morning brief''s "DETECTIONS NOT CURRENT" line, which reads defect_detection_runs directly. 171a.');

-- Schedule: the enqueue keeps the old job name (the morning brief looks it up by name); the worker ticks every 15 s.
select cron.unschedule('defect-detections-daily');
select cron.schedule('defect-detections-daily', '0 7 * * *', 'SELECT public.enqueue_defect_detections();');
select cron.schedule('defect-detections-worker', '15 seconds', 'SELECT public.run_next_defect_detection();');

comment on function public.run_defect_detections() is
  'Legacy all-in-one runner: runs every check in ONE statement, so it only completes with statement_timeout=0 (manual use). The scheduled path is enqueue_defect_detections() + run_next_defect_detection() (171a).';
