-- 204a - a readable detection board: mandatory expectation, acknowledged reds with an expiry, and the daily diff
-- (ruling 934 R1, R3, R4).
--
-- Measured 2026-10-02 (latest run, 201 active): expected clean 137 (89 green, 46 RED, 2 errored); expected defect 31
-- (27 red - 14 with an expiry - and 4 GREEN); expected state NULL 33 (23 green, 10 red). A board where 46 reds
-- contradict their own declaration and nobody can tell a new red from a known one is a board nobody reads.
--
-- R1 expected_state is mandatory for active detections. The 33 nulls are declared 'clean' - not to launder their
--    reds: a red against 'clean' with no acknowledgement reads UNACKNOWLEDGED (new work), which is the honest state for
--    a red nobody has explained. Four of the ten null reds are mine from this week and red by design; they are declared
--    'defect' WITH a reason and an expiry below, because I know why they are red.
-- R3 acknowledgement (new column) carries WHY a known red is red; expires_at carries UNTIL WHEN. Board state, computed:
--      ok             green and expected clean
--      known          red, expected defect, acknowledged, expiry in the future
--      expired        red, expected defect, expiry passed          -> ESCALATION
--      unacknowledged red with no acknowledgement or no expiry, or red against 'clean'  -> new work, or a lie
--      fixed          green but expected defect - a fix, or a blind check (population_state says which can be trusted)
--      errored        did not run
-- R4 detection_board_diff(): which detections changed state between the latest run and the one before, in BOTH
--    directions, and daily_ops_report leads with it.
-- R2 (population mandatory) is enforced by detection-population-undeclared (203a); declaring 186 populations is SQL work
--    per detection, done in the consequence-ordered pass that follows.

alter table public.data_defect_registry add column if not exists acknowledgement text;
comment on column public.data_defect_registry.acknowledgement is
  '204a (ruling 934): WHY a detection is expected red. Required with expires_at for a red to count as known; a red with no acknowledgement and no expiry is new work or a lie. An expiry passing while red is an escalation.';

-- my own red-by-design detections from this week: why, and until when (a review date, 2 weeks out)
update public.data_defect_registry set expected_state = 'defect', expires_at = timestamptz '2026-10-16 23:59:59-04',
  acknowledgement = '1,239 of 1,978 active sources have no recorded fetch; 953 have a source_url that is not a URL (198a). Clears only as the cadence sweep records fetches; review 2026-10-16.'
 where defect_id = 'active-source-never-fetched' and expected_state is null;
update public.data_defect_registry set expected_state = 'defect', expires_at = timestamptz '2026-10-16 23:59:59-04',
  acknowledgement = '186 of 201 active detections declare no population (203a); each turns as the consequence-ordered pass adds one (ruling 934 R2). Review 2026-10-16.'
 where defect_id = 'detection-population-undeclared' and expected_state is null;
update public.data_defect_registry set expected_state = 'defect', expires_at = timestamptz '2026-10-16 23:59:59-04',
  acknowledgement = 'parcel_deed_chain is built from deed parties as of 2019-01-09 (186b/187a); its source is not recovered. Known degradation, rendered as such on the report. Review 2026-10-16.'
 where defect_id = 'derived-deed-chain-behind-source' and expected_state is null;
update public.data_defect_registry set expected_state = 'defect', expires_at = timestamptz '2026-10-16 23:59:59-04',
  acknowledgement = 'property_permit_history is as of the 2026-06-21 CAMA export while volusia_cama_permits holds the 2026-09-28 capture (185a/187b); the rebuild (staging + diff) is queued. Review 2026-10-16.'
 where defect_id = 'derived-permit-history-behind-source' and expected_state is null;

-- every other active null declares 'clean' (a red among them reads unacknowledged)
update public.data_defect_registry set expected_state = 'clean' where status = 'active' and expected_state is null;

alter table public.data_defect_registry drop constraint if exists ddr_active_declares_expected_state;
alter table public.data_defect_registry add constraint ddr_active_declares_expected_state
  check (status <> 'active' or expected_state is not null);

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
    when latest = 'errored' then 'errored'
    when latest = 'green' and expected_state = 'defect' then 'fixed'
    when latest = 'green' then 'ok'
    when expected_state = 'defect' and acknowledgement is not null and expires_at is not null and expires_at < now() then 'expired'
    when expected_state = 'defect' and acknowledgement is not null and expires_at is not null then 'known'
    else 'unacknowledged'
  end as board_state,
  (previous is not null and previous is distinct from latest) as changed
from st;
comment on view public.detection_board is
  '204a (ruling 934): one row per active detection - latest vs previous run, board_state (ok / known / expired / unacknowledged / fixed / errored) and whether it changed. Read the diff, not the count.';

create or replace function public.detection_board_diff()
returns jsonb language sql stable security definer set search_path to 'public', 'pg_temp' as $$
  select jsonb_build_object(
    'latest_run_at', (select max(run_at) from public.detection_board),
    'went_red',   coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where changed and latest = 'red'), '[]'::jsonb),
    'went_green', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where changed and latest = 'green'), '[]'::jsonb),
    'went_errored', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where changed and latest = 'errored'), '[]'::jsonb),
    'board', coalesce((select jsonb_object_agg(board_state, n) from (select board_state, count(*) n from public.detection_board group by 1) x), '{}'::jsonb),
    'expired', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where board_state = 'expired'), '[]'::jsonb),
    'unacknowledged', coalesce((select jsonb_agg(defect_id order by defect_id) from public.detection_board where board_state = 'unacknowledged'), '[]'::jsonb))
$$;
revoke all on function public.detection_board_diff() from public, anon, authenticated;
grant execute on function public.detection_board_diff() to service_role;

-- daily_ops_report leads with the diff (after the header and morning briefing, before "1. System Health")
do $$
declare d text; a1 text; a2 text; anchor text := E'  md := md || E''\\n## 1. System Health\\n'';';
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  d := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  if (select count(*) from regexp_matches(d, '## 1\. System Health', 'g')) <> 1 or position(anchor in d) = 0 then
    raise exception '204a: ops-report anchor missing or not unique'; end if;
  d := replace(d, anchor, $p$  -- 204a (ruling 934): the detection board, read as a DIFF first - what changed since the previous run, both directions
  begin
    declare v jsonb := public.detection_board_diff();
    begin
      md := md || E'\n## 0. Detection board - what changed\n';
      md := md || format(E'- %s Went red since the previous run: %s %s\n',
        case when jsonb_array_length(v->'went_red') = 0 then 'OK' else 'RED' end, jsonb_array_length(v->'went_red'),
        case when jsonb_array_length(v->'went_red') > 0 then '('||(select string_agg(x, ', ') from jsonb_array_elements_text(v->'went_red') x)||')' else '' end);
      md := md || format(E'- %s Went green (a fix, or a check gone blind - see population): %s %s\n',
        case when jsonb_array_length(v->'went_green') = 0 then 'OK' else 'NOTE' end, jsonb_array_length(v->'went_green'),
        case when jsonb_array_length(v->'went_green') > 0 then '('||(select string_agg(x, ', ') from jsonb_array_elements_text(v->'went_green') x)||')' else '' end);
      md := md || format(E'- %s Stopped running: %s %s\n',
        case when jsonb_array_length(v->'went_errored') = 0 then 'OK' else 'RED' end, jsonb_array_length(v->'went_errored'),
        case when jsonb_array_length(v->'went_errored') > 0 then '('||(select string_agg(x, ', ') from jsonb_array_elements_text(v->'went_errored') x)||')' else '' end);
      md := md || format(E'- %s Known reds past their expiry: %s %s\n',
        case when jsonb_array_length(v->'expired') = 0 then 'OK' else 'RED' end, jsonb_array_length(v->'expired'),
        case when jsonb_array_length(v->'expired') > 0 then '('||(select string_agg(x, ', ') from jsonb_array_elements_text(v->'expired') x)||')' else '' end);
      md := md || format(E'- Board: %s. Unacknowledged reds are new work or a lie; known reds carry why and until when.\n', v->'board');
    end;
  exception when others then md := md || format(E'- ERROR (detection board): %s\n', sqlerrm); end;
$p$ || anchor);
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.daily_ops_report() to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.daily_ops_report() to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  if a2 is distinct from a1 then raise exception '204a: daily_ops_report grants changed % -> %', a1, a2; end if;
end $$;

do $$
declare n int;
begin
  select count(*) into n from public.data_defect_registry where status = 'active' and expected_state is null;
  if n is distinct from 0 then raise exception '204a: % active detections still declare no expectation', n; end if;
  select count(*) into n from public.detection_board;
  if n = 0 then raise exception '204a: the board is empty'; end if;
end $$;

select public._log_action('cc', 'readable_detection_board', 'data_defect_registry', array['expected_state','acknowledgement','detection_board','detection_board_diff','daily_ops_report'],
  jsonb_build_object('expected_null_active', 33, 'clean_but_red', 46, 'defect_red_without_expiry', 13, 'defect_but_green', 4),
  jsonb_build_object('expected_state', 'mandatory (CHECK)', 'board_states', 'ok/known/expired/unacknowledged/fixed/errored', 'daily', 'diff first'),
  'Ruling 934: a board of 83 reds where nobody can tell new from known is unread. Expectation mandatory, known reds carry why and until when, the daily report leads with what changed.', null);
