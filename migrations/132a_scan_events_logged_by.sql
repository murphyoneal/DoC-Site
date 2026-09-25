-- 132a — Record HOW each scan event was logged (work order 653 (b)).
--
-- Page views move from client-side (ScanTracker, after the page loads in a browser that runs
-- JavaScript) to server-side (on the /c/[slug] request itself). The two mechanisms count
-- different populations — the server sees every request, including visitors without JS, crawlers
-- and redirected visitors; the client saw only JS browsers that finished loading — so a count
-- that spans the switch is only interpretable if each row says which mechanism wrote it.
--
-- Existing rows were all written by /api/scan (client-side): backfilled 'client'. The default
-- stays 'client' because /api/scan still receives the click events (save_contact,
-- visit_website, view_profile), which are genuinely client-side. The server logger writes
-- 'server' explicitly. Additive; /api/scan inserts named columns and is unaffected.

alter table public.scan_events add column if not exists logged_by text not null default 'client';
alter table public.scan_events drop constraint if exists scan_events_logged_by_chk;
alter table public.scan_events add constraint scan_events_logged_by_chk check (logged_by in ('client', 'server'));

comment on column public.scan_events.logged_by is
  'client = posted by the browser to /api/scan (JS visitors only; click events). server = written by the page request itself (every request, including non-JS visitors, crawlers and redirects). Counts spanning 2026-09-25 must be split on this column.';
