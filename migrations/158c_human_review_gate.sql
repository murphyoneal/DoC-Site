-- 158c: a human is the publication gate (ruling 768, ruling 2).
--
-- upload -> private -> classifier as PRE-FILTER -> review page -> Murphy approves -> public.
-- At this volume a person can look at every image, which is a stronger control than any classifier.
-- New visibility state pending_review (passed the pre-filter, awaiting a person). scan_result.decision
-- gains 'review'. There is NO automatic publish path until hash matching (PhotoDNA) is live AND auto-
-- publish is deliberately switched on; lib/moderation.ts enforces it.
--
-- operating_threshold records the volume at which this design stops working, decided now while it is
-- cheap: about 50 photo uploads a day is more than one person can review. The upload route counts
-- against it and tells Murphy at the warning level and at the limit, rather than it failing silently.

alter table public.work_contribution drop constraint work_contribution_visibility_check;
alter table public.work_contribution add constraint work_contribution_visibility_check
  check (visibility in ('pending_scan', 'pending_review', 'held', 'public', 'withdrawn_by_owner', 'withdrawn_by_contractor'));

alter table public.scan_result drop constraint if exists scan_result_decision_check;
alter table public.scan_result add constraint scan_result_decision_check check (decision in ('publish', 'review', 'hold', 'pending'));

create table public.operating_threshold (
  name        text primary key,
  limit_value numeric not null,
  warn_at     numeric not null,
  unit        text not null,
  reason      text not null,
  set_by      text not null,
  set_on      date not null default current_date
);
alter table public.operating_threshold enable row level security;
revoke all on public.operating_threshold from anon, authenticated;
insert into public.operating_threshold (name, limit_value, warn_at, unit, reason, set_by) values
('photo_uploads_per_day', 50, 40, 'uploads in the last 24 hours',
 'Every photo is approved by a person before it is public (ruling 768). Past about 50 a day one person cannot review them and the design fails silently. Reaching it is a trigger to reassess, not a cap on contractors.',
 'claude ruling 768, recorded by cc');

insert into public.column_writer (table_name, column_name, writer_class, reason, classified_by)
select 'operating_threshold', a.attname, 'ours', 'operating limits we set for ourselves (158c)', 'cc'
  from pg_attribute a where a.attrelid = 'public.operating_threshold'::regclass and a.attnum > 0 and not a.attisdropped;
