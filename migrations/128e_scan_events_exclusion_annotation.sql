-- 128e — A wrong analytics record is annotated, never erased (ruling 2026-09-24).
--
-- Verifying the retired-slug redirect locally (PR #18) fired ScanTracker and wrote a real row:
-- slug red-stag-contracting-inc-jacksonville-fl, ref=download, ip ::1. It reads as the first
-- QR-download scan ever recorded and is not one. It stays; counts exclude it.
--
-- excluded_reason: null = a real event that counts. Anything else = kept, excluded, and why.
-- Additive: /api/scan inserts named columns, so it is unaffected.

alter table public.scan_events add column if not exists excluded_reason text;

comment on column public.scan_events.excluded_reason is
  'null = a real event that counts. Non-null = kept for the record but excluded from every count, with the reason. Rows are annotated, never deleted.';

update public.scan_events
   set excluded_reason = 'local test: CC verifying the retired-slug 308 redirect on a dev server (PR #18), 2026-09-24. Not a QR scan.'
 where id = '48c12f01-f03c-4d22-b356-f7047a9694a2'
   and ip = '::1'
   and excluded_reason is null;
