-- 158a: scan before publish (ruling 762, part 3). Upload -> private -> scan -> publish on pass.
-- Never publish-then-retract.
--
-- work_contribution.visibility defaulted to 'public', so an unscanned image was public the moment
-- it was stored. claude's reversal (762): an unscanned image must not be publicly reachable for any
-- interval. New states:
--   pending_scan - stored privately, not yet passed every required scan (the new default)
--   held         - a scan flagged it; kept privately for review, never published automatically
-- The two existing rows were 'public' without ever being scanned; they move to pending_scan (visibility
-- is OUR state, so this backfill is permitted), and their public copies are moved back to the private
-- bucket by the deploy step recorded in the commit.
--
-- work_contribution_image: public_path becomes nullable (there is no public copy until a pass) and
-- held_path records the metadata-stripped copy kept in the private bucket.
--
-- scan_result: one row per image per slot. Two slots, never collapsed:
--   classification - adult/explicit/violent, a commodity classifier; a flag holds it for Murphy
--   hash_match     - CSAM hash matching; a match never publishes and is preserved
-- state: pass / flag / match / error / not_available. not_available (no provider configured) is
-- NEVER a pass. Internal only: RLS on, no anon/authenticated grant.

alter table public.work_contribution drop constraint work_contribution_visibility_check;
alter table public.work_contribution add constraint work_contribution_visibility_check
  check (visibility in ('pending_scan', 'held', 'public', 'withdrawn_by_owner', 'withdrawn_by_contractor'));
alter table public.work_contribution alter column visibility set default 'pending_scan';

update public.work_contribution set visibility = 'pending_scan' where visibility = 'public';

update public.column_default_authorship
   set reason = 'ours: our publication state. DEFAULT pending_scan - nothing is public until every required scan passes (158a, ruling 762 reversal of the former default public).',
       classified_by = 'cc', classified_on = current_date
 where table_name = 'work_contribution' and column_name = 'visibility';

alter table public.work_contribution_image alter column public_path drop not null;
alter table public.work_contribution_image add column if not exists held_path text;

create table public.scan_result (
  id          bigserial primary key,
  image_id    uuid not null references public.work_contribution_image(id) on delete cascade,
  slot        text not null check (slot in ('classification', 'hash_match')),
  provider    text not null,
  state       text not null check (state in ('pass', 'flag', 'match', 'error', 'not_available')),
  detail      jsonb,
  scanned_at  timestamptz not null default now()
);
create index scan_result_image_idx on public.scan_result (image_id, slot, scanned_at desc);
alter table public.scan_result enable row level security;
revoke all on public.scan_result from anon, authenticated;
comment on table public.scan_result is
  'Scan before publish (158a): per image per slot (classification | hash_match): provider, state (pass/flag/match/error/not_available), provider detail. not_available is never a pass. Internal only.';

do $m$ begin
  if exists (select 1 from public.work_contribution where visibility = 'public') then
    raise exception '158a: a contribution is still public'; end if;
  if has_table_privilege('anon', 'public.scan_result', 'select') then raise exception '158a: scan_result readable by anon'; end if;
  if (select pg_get_expr(adbin, adrelid) from pg_attrdef d join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
       where d.adrelid = 'public.work_contribution'::regclass and a.attname = 'visibility') <> '''pending_scan''::text' then
    raise exception '158a: visibility default not pending_scan'; end if;
end $m$;
