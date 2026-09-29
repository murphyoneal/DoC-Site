-- 158b: evidence, append-only, and the operator inside the trail (ruling 765, applied to parts 2-3).
--
-- 1. scan_result is EVIDENCE: add the model/version, the policy (thresholds and whether hash matching was
--    required) IN FORCE AT THAT MOMENT, and the decision it led to. A later retune must not make an old
--    decision unreadable. Classified 'derived' in column_writer (our computation about someone's
--    photograph; never rendered - the table has no public grant).
-- 2. submission_event and scan_result become APPEND-ONLY, enforced by trigger. A correction is a new
--    row, never an UPDATE or DELETE over the top. Strict: no test-row escape hatch.
-- 3. moderation_action: every action on a moderation record, by anyone - the operator, and the build
--    agents (CC, claude) - to the same standard. No 'system' actor. Append-only. `basis` (why we were
--    entitled to act) is required. `recorded_late` marks a row written after the action happened. A
--    late row carries the exact time only where the system can prove it; otherwise occurred_at is NULL
--    and the proven bounds go in occurred_not_before / occurred_not_after. No time is ever estimated.
-- 4. Three actions CC took on 2026-09-29 BEFORE this log existed are recorded here, late and labelled
--    as late: the 158a visibility backfill, moving two public copies to the private bucket, and deleting
--    one synthetic row from submission_event (a test, before that table was append-only).

alter table public.scan_result add column if not exists model_version text;
alter table public.scan_result add column if not exists policy jsonb;
alter table public.scan_result add column if not exists decision text check (decision in ('publish', 'hold', 'pending'));

create or replace function public.append_only_strict() returns trigger language plpgsql as $f$
begin
  raise exception 'append-only: % on % is not permitted. A correction is a new row that supersedes.', TG_OP, TG_TABLE_NAME;
end $f$;
revoke all on function public.append_only_strict() from public, anon, authenticated;

create trigger append_only_submission_event before update or delete on public.submission_event
  for each row execute function public.append_only_strict();
create trigger append_only_scan_result before update or delete on public.scan_result
  for each row execute function public.append_only_strict();

create table public.moderation_action (
  id             bigserial primary key,
  occurred_at    timestamptz,
  occurred_not_before timestamptz,
  occurred_not_after  timestamptz,
  recorded_at    timestamptz not null default now(),
  recorded_late  boolean not null default false,
  actor          text not null check (length(btrim(actor)) > 0),
  actor_kind     text not null check (actor_kind in ('operator', 'build_agent')),
  action         text not null,
  target_table   text not null,
  target_ids     text[] not null,
  before_state   jsonb,
  after_state    jsonb,
  basis          text not null check (length(btrim(basis)) > 0),
  via            text not null,
  ip             inet,
  constraint moderation_action_time_known check (occurred_at is not null or (recorded_late and occurred_not_before is not null))
);
create index moderation_action_target_idx on public.moderation_action (target_table, occurred_at desc);
alter table public.moderation_action enable row level security;
revoke all on public.moderation_action from anon, authenticated;
create trigger append_only_moderation_action before update or delete on public.moderation_action
  for each row execute function public.append_only_strict();
comment on table public.moderation_action is
  'Every action on a moderation record, by the operator or a build agent, to the same standard (ruling 765.7). No system actor. basis is required. recorded_late marks rows written after the fact. Append-only. Internal.';

insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by) values
('moderation_action', 'recorded_late', 'ours', 'ours: false = this row was written when the action happened; a late entry must set it true explicitly (158b)', 'cc')
on conflict (table_name, column_name) do nothing;

insert into public.column_writer (table_name, column_name, writer_class, derived_inputs, derived_rule, reason, classified_by) values
('scan_result','id','ours',null,null,'key','cc'),
('scan_result','image_id','ours',null,null,'key','cc'),
('scan_result','slot','ours',null,null,'which check','cc'),
('scan_result','provider','ours',null,null,'which service ran it','cc'),
('scan_result','model_version','ours',null,null,'the provider model/version that ran','cc'),
('scan_result','state','derived','{image bytes,provider,model_version,policy}','the provider''s labels/scores compared against policy thresholds in force; not_available when no provider is configured','OUR computation about someone''s photograph - never rendered, never a score or badge (765.2)','cc'),
('scan_result','detail','derived','{image bytes,provider,model_version}','the provider''s raw labels and scores, stored as returned','the provider''s opinion, kept as evidence; never rendered','cc'),
('scan_result','policy','ours',null,null,'thresholds and hash-match requirement in force at scan time','cc'),
('scan_result','decision','derived','{state,policy}','lib/moderation.ts decide(): publish only on a pass in every required slot; hold on flag or match; else pending','the gate outcome, readable later against the policy that applied','cc'),
('scan_result','scanned_at','ours',null,null,'when','cc');

insert into public.column_writer (table_name, column_name, writer_class, reason, classified_by)
select 'moderation_action', a.attname, 'ours', 'moderation action log (158b)', 'cc'
  from pg_attribute a where a.attrelid = 'public.moderation_action'::regclass and a.attnum > 0 and not a.attisdropped;

-- The three actions taken before this log existed. Recorded late, and saying so. Times are only what
-- the system proves: 158a's applied version (20260929120200) for the backfill; the 157a/158a versions
-- bound the test-row deletion; the storage move ran after 158a and before this entry.
insert into public.moderation_action (occurred_at, occurred_not_before, occurred_not_after, recorded_late, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via) values
('2026-09-29 12:02:00+00', null, null, true, 'cc', 'build_agent', 'visibility_backfill', 'work_contribution',
 array['8899238a-b9e4-4641-8a7b-10606feacc45','a9a97b79-089f-4b68-8f1b-366c4314569c'],
 '{"visibility":"public"}', '{"visibility":"pending_scan"}',
 'Ruling 762 part 3 (claude, reversing the public default): an unscanned image must not be publicly reachable for any interval. Neither row had ever been scanned.',
 'migration 158a_scan_before_publish (applied version 20260929120200)'),
(null, '2026-09-29 12:02:00+00', now(), true, 'cc', 'build_agent', 'move_public_copy_to_private', 'work_contribution_image',
 array['0df08b65-aae1-4f46-a0cd-e0fdad678637','d19bc834-7e67-47b0-9a3f-bdf6c1fef0e4'],
 '{"public_path":"set (work-public bucket)","held_path":null}', '{"public_path":null,"held_path":"same object path in work-private"}',
 'Ruling 762 part 3: an unscanned image must not be publicly reachable. Both public URLs verified failing (HTTP 400) after the move. Nothing deleted: the stripped copies are retained privately with the originals.',
 'script scratchpad/move_public_to_private.mjs (service key, run by cc)'),
(null, '2026-09-29 11:56:58+00', '2026-09-29 12:02:00+00', true, 'cc', 'build_agent', 'delete_test_row', 'submission_event',
 array['1'],
 '{"kind":"self_registration","actor_email":"zz-custody-test@example.com","ip":"203.0.113.7","outcome":"invalid:state"}', null,
 'A synthetic row CC wrote to verify the custody logger (documentation-range IP, example.com address). Deleted before the table was made append-only. Recorded because ruling 765.7 puts the build agents inside the trail; after 158b this deletion is impossible.',
 'execute_sql by cc');

do $m$ begin
  begin
    insert into public.moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, basis, via)
      values (now(), 'cc', 'build_agent', 'probe', 'x', array['x'], 'probe', 'probe');
    delete from public.moderation_action where action = 'probe';
    raise exception 'GUARD_NOT_ENFORCED';
  exception when others then
    if sqlerrm = 'GUARD_NOT_ENFORCED' then raise exception '158b: moderation_action accepted a DELETE'; end if;
  end;
  if (select count(*) from public.moderation_action where action = 'probe') > 0 then
    raise exception '158b: probe row survived'; end if;
end $m$;
