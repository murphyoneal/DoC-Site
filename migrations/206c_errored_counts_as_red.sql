-- 206c - an errored detection counts as RED on the board and in the diff (ruling 937 section 7).
--
-- 937: "AN ERRORED CHECK IS RED. A CHECK THAT CANNOT RUN IS A CHECK THAT CANNOT FAIL." In 204a 'errored' was its own
-- board state, read as neither red nor green, so a check could stop working and the board said nothing. Now:
--   board_state 'errored' -> 'errored_red'. It is still named, because the fix differs (repair the check, not the
--     data), but it is red.
--   detection_board.latest stays 'errored' (what happened). A new column `reads_red` is true for red OR errored.
--   detection_board_diff 'went_red' includes detections that went errored, marked "(errored)". 'went_green' only counts
--     a real green.
--   An errored detection that IS acknowledged (expected_state 'defect' with a reason and an expiry) still reads
--     errored_red. A known red has to run to stay known.

create or replace view public.detection_board as
with runs as (
  select distinct run_id, run_at from public.defect_detection_runs
), last2 as (
  select run_id, run_at, row_number() over (order by run_at desc) rn from runs
), latest as (
  select r.* from public.defect_detection_runs r join last2 l on l.run_id = r.run_id and l.rn = 1
), prev as (
  select r.* from public.defect_detection_runs r join last2 l on l.run_id = r.run_id and l.rn = 2
), st as (
  select d.defect_id, d.name, d.severity, d.expected_state, d.acknowledgement, d.expires_at,
         case when l.error_class is not null or l.ok is null then 'errored' when l.ok then 'green' else 'red' end as latest,
         case when p.defect_id is null then null when p.error_class is not null or p.ok is null then 'errored' when p.ok then 'green' else 'red' end as previous,
         l.population, l.population_state, l.run_at
    from public.data_defect_registry d
    left join latest l using (defect_id)
    left join prev p using (defect_id)
   where d.status = 'active'
)
select st.*,
  case
    when latest = 'errored' then 'errored_red'
    when latest = 'green' and expected_state = 'defect' then 'fixed'
    when latest = 'green' then 'ok'
    when expected_state = 'defect' and acknowledgement is not null and expires_at is not null and expires_at < now() then 'expired'
    when expected_state = 'defect' and acknowledgement is not null and expires_at is not null then 'known'
    else 'unacknowledged'
  end as board_state,
  (previous is not null and previous is distinct from latest) as changed,
  (latest in ('red','errored')) as reads_red
from st;
comment on view public.detection_board is
  '204a/206c (rulings 934, 937): one row per active detection - latest vs previous run, board_state (ok / known / expired / unacknowledged / fixed / errored_red) and whether it changed. reads_red is true for red OR errored: a check that cannot run is a check that cannot fail.';

create or replace function public.detection_board_diff()
returns jsonb language sql stable security definer set search_path to 'public', 'pg_temp' as $$
  select jsonb_build_object(
    'latest_run_at', (select max(run_at) from public.detection_board),
    -- 206c: errored is red - a detection that stopped running is reported as going red, marked so
    'went_red',   coalesce((select jsonb_agg(defect_id || case when latest = 'errored' then ' (errored)' else '' end order by defect_id)
                              from public.detection_board where changed and latest in ('red','errored')), '[]'::jsonb),
    'went_green', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where changed and latest = 'green'), '[]'::jsonb),
    'went_errored', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where changed and latest = 'errored'), '[]'::jsonb),
    'errored_red', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where board_state = 'errored_red'), '[]'::jsonb),
    'board', coalesce((select jsonb_object_agg(board_state, n) from (select board_state, count(*) n from public.detection_board group by 1) x), '{}'::jsonb),
    'reads_red', (select count(*) from public.detection_board where reads_red),
    'expired', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where board_state = 'expired'), '[]'::jsonb),
    'unacknowledged', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where board_state = 'unacknowledged'), '[]'::jsonb))
$$;
revoke all on function public.detection_board_diff() from public, anon, authenticated;
grant execute on function public.detection_board_diff() to service_role;

-- daily_ops_report: a standing RED line for every errored detection, not only the ones that changed today
do $$
declare d text; a1 text; a2 text;
  anchor text := $a$      md := md || format(E'- Board: %s. Unacknowledged reds are new work or a lie; known reds carry why and until when.\n', v->'board');$a$;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  d := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  if (length(d) - length(replace(d, anchor, ''))) / length(anchor) <> 1 then raise exception '206c: ops-report anchor missing or not unique'; end if;
  d := replace(d, anchor, $p$      -- 206c (ruling 937): a check that cannot run cannot fail - errored is red, every day it stays errored
      md := md || format(E'- %s Detections that cannot run (errored, counted red): %s %s\n',
        case when jsonb_array_length(v->'errored_red') = 0 then 'OK' else 'RED' end, jsonb_array_length(v->'errored_red'),
        case when jsonb_array_length(v->'errored_red') > 0 then '('||(select string_agg(x, ', ') from jsonb_array_elements_text(v->'errored_red') x)||')' else '' end);
$p$ || anchor);
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.daily_ops_report() to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.daily_ops_report() to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  if a2 is distinct from a1 then raise exception '206c: daily_ops_report grants changed % -> %', a1, a2; end if;
end $$;

do $$
declare v jsonb; r text;
begin
  v := public.detection_board_diff();
  if not (v ? 'errored_red') then raise exception '206c: diff lacks errored_red'; end if;
  if (select count(*) from public.detection_board where board_state = 'errored') > 0 then raise exception '206c: a bare errored state remains'; end if;
  r := public.daily_ops_report();
  if position('cannot run (errored, counted red)' in r) = 0 then raise exception '206c: ops report lacks the errored line'; end if;
end $$;

select public._log_action('cc', 'errored_counts_as_red', 'detection_board', array['detection_board','detection_board_diff','daily_ops_report'], null,
  jsonb_build_object('board_state', 'errored -> errored_red', 'diff', 'went_red includes errored', 'ops', 'standing RED line'),
  'Ruling 937 section 7: a check that cannot run is a check that cannot fail; errored reads red.', null);
