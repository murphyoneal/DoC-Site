-- 184a - stop and unwind the history table that manufactured history (ruling 892).
--
-- cron job 5 'volusia-permit-intake-snapshot' (06:00 daily) ran collect_volusia_permit_snapshot(), whose whole body copies
-- the LOCAL table volusia_current_permits into volusia_current_permits_history under snapshot_date = current_date. It
-- fetches nothing. volusia_current_permits was last pulled 2026-07-14 (newest indate 2026-05-12). MEASURED 2026-10-01:
-- 69 snapshot dates (2026-07-25..2026-10-01), 202,170 rows, exactly 2,930 distinct row versions = 69 x the live table.
-- Every date after the first asserts an observation of the county's permits on a day nothing was observed.
-- Reachability, checked before deleting: no function reads the history except the job itself; the view
-- funnel_volusia_current_permits_history reads it and is registered in funnel_polygon_registry (family_view), which
-- get_parcel_containment_findings reads dynamically - but nothing calls that function (no SQL caller, no app/lib
-- reference). So nothing served was false; it was registered to become so.
-- Removing fabrication is not destroying evidence, but only if the removal is itself recorded: moderation_action below
-- carries the dates, the counts and an md5 over the deleted rows' content. The first generation (2026-07-25) is kept and
-- labelled for what it is: a copy, not an observation of that day.

select cron.unschedule('volusia-permit-intake-snapshot');

do $$
declare v_dates int; v_rows bigint; v_md5 text; v_kept bigint; v_first date;
begin
  select min(snapshot_date) into v_first from public.volusia_current_permits_history;
  if v_first is distinct from date '2026-07-25' then raise exception '184a: first generation is %, expected 2026-07-25', v_first; end if;
  select count(distinct snapshot_date), count(*),
         md5(string_agg(md5(row(objectid, snapshot_date, folderrsn, statuscode, statusdesc, indate, folderdesc)::text), '' order by snapshot_date, objectid))
    into v_dates, v_rows, v_md5
    from public.volusia_current_permits_history where snapshot_date > v_first;
  -- the premise, re-asserted inside the migration: every deleted row duplicates a row of the kept generation
  if exists (select 1 from public.volusia_current_permits_history h where h.snapshot_date > v_first
              and not exists (select 1 from public.volusia_current_permits_history k where k.snapshot_date = v_first and k.objectid = h.objectid
                                and row(k.folderrsn, k.statuscode, k.statusdesc, k.indate, k.folderdesc) is not distinct from row(h.folderrsn, h.statuscode, h.statusdesc, h.indate, h.folderdesc))) then
    raise exception '184a: a later generation holds a row the first does not - this is not pure duplication, stop';
  end if;

  delete from public.volusia_current_permits_history where snapshot_date > v_first;
  select count(*) into v_kept from public.volusia_current_permits_history;
  if v_kept is distinct from 2930::bigint then raise exception '184a: kept % rows, expected 2930', v_kept; end if;

  insert into public.moderation_action (actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via, occurred_at)
  values ('cc', 'build_agent', 'remove_fabricated_rows', 'volusia_current_permits_history', array['snapshot_date > 2026-07-25'],
    jsonb_build_object('generations', v_dates + 1, 'rows', v_rows + 2930, 'distinct_row_versions', 2930,
                       'deleted_generations', v_dates, 'deleted_rows', v_rows, 'deleted_rows_md5', v_md5,
                       'source_table_last_pull', '2026-07-14'),
    jsonb_build_object('kept_generation', '2026-07-25', 'kept_rows', v_kept, 'cron_job_5', 'unscheduled'),
    'Ruling 892: collect_volusia_permit_snapshot copied a frozen local table daily, writing 68 generations each dated as an observation that never happened. Every deleted row duplicates the kept first generation (asserted in-migration). Removed with the content hash recorded.',
    'migration 184a', now());
end $$;

comment on table public.volusia_current_permits_history is
  'ONE generation (snapshot_date 2026-07-25), copied from volusia_current_permits as pulled 2026-07-14. It is NOT an observation of the county on 2026-07-25. 68 later generations were identical copies written by a job that fetched nothing; removed by 184a and recorded in moderation_action. No job writes here now.';
