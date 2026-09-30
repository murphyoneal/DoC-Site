-- 163a - a work photo has no route to publication until the owner-approval store exists (ruling 795).
--
-- 795: a photo is tagged to the parcel and held private; it becomes public ONLY when the owner/occupant
-- has claimed the property (utility-bill verification) and approved that specific item. Neither the
-- claim nor the approval log exists yet, so today EVERY parcel is unclaimed and no photo may publish.
--
-- Measured 2026-09-30 before this migration: 0 public rows, 0 objects in work-public, 0 scans - no photo
-- has ever been public. But two routes to publication existed, both blind to the owner:
--   1. LIVE   /review "Approve - make public" -> operator_photo_decision(p_approve => true)
--   2. DORMANT /api/work/upload auto-publish when classifier + PhotoDNA pass and MODERATION_AUTO_PUBLISH=true
-- The code for both is closed in the same commit. This trigger is the lock that does not depend on the
-- code: it refuses the transition for every writer, service_role included. It is lifted by the migration
-- that builds the owner-approval log, and only by a check against that log - never by deleting it.

create or replace function public.work_contribution_publication_gate() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  if new.visibility = 'public' and (tg_op = 'INSERT' or old.visibility is distinct from 'public') then
    raise exception 'not published: a work photo is held against the property until the homeowner claims it and approves this photo (ruling 795)';
  end if;
  return new;
end $$;

drop trigger if exists work_contribution_publication_gate on public.work_contribution;
create trigger work_contribution_publication_gate before insert or update of visibility on public.work_contribution
  for each row execute function public.work_contribution_publication_gate();

insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('work-photo-public-without-owner-approval',
        'A work photo is public (row or public-bucket file) while no owner-approval route exists',
        'access_control', 'blocking',
        $d$select ((select count(*) from work_contribution where visibility = 'public') = 0
                  and (select count(*) from storage.objects where bucket_id = 'work-public') = 0) as ok$d$,
        'Ruling 795: no photo publishes until the owner claims the property and approves the item. Guarded by trigger work_contribution_publication_gate (163a). Checks BOTH the row and the bucket, because both routes wrote the file before the row. When the owner-approval log is built, rewrite this to require a matching approval row per public item - do not delete it.');

do $$
declare id uuid;
begin
  -- the lock refuses an operator approve through the real function
  select c.id into id from work_contribution c where c.visibility = 'pending_scan' limit 1;
  begin
    perform operator_photo_decision(id, true, 'zz-control.jpg', (select email from operator_account limit 1), 'control: must be refused by the gate', null);
    raise exception '163a: CONTROL_FAILED - approve went through';
  exception when others then
    if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
    if sqlerrm not like '%ruling 795%' then raise exception '163a: unexpected refusal: %', sqlerrm; end if;
  end;
  -- Hold (-> 'held') is untouched by the gate; it is Murphy's pending verification click and is not exercised here
  if (select count(*) from pg_trigger where tgname = 'work_contribution_publication_gate') <> 1 then raise exception '163a: trigger missing'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then
    raise exception '163a: a public register lost its anon grant';
  end if;
end $$;
