
=========================================================
## VOLUSIA OFFICIAL RECORDS PIPELINE - BUILT & RUNNING (2026-07-20)
Scope (owner-specified): RESTRICTIONS, LIEN, JUDGMENT/ORDER, LIS PENDENS; 2015-01-01 -> present;
one week per search, throttled. Tables: volusia_official_records_private + volusia_or_scrape_progress.
Collector: ~/volusia_or_collect.py   log: ~/or_crawl.log

### GOVERNANCE (mirrors volusia_arrest_booking_records)
RLS enabled, ZERO policies => service-role only. Table comment states: personal research use only,
NOT for PIR / B2B / customer-facing output, no redistribution or resale. Collection deliberately
throttled + weekly-windowed to match the app's own 7-day granularity (county has no paid bulk product).

### THE BUG THAT NEARLY POISONED THE WHOLE DATASET  *** most important finding ***
Reusing one ASP.NET session across searches CORRUPTS the grid: once the MaxRows postback is fired,
every LATER search in that session returns exactly 25 rows under the label "Records found 25".
The label is SELF-CONSISTENT (rows==25==N), so a page-level assertion CANNOT detect it.
First validation run reported a clean "ok=12 failed=0" while silently discarding ~93% of the data
(438 rows). Same 12 jobs with a fresh session per week -> 6,628 rows. 15x.
CAUGHT ONLY BY: looking at the count DISTRIBUTION (a wall of exactly-25s across unrelated
doctypes/weeks is not what real data looks like), not by the success line or the assertions.
FIX 1: Site.week() calls self.new() -- brand-new session+disclaimer per week-job. Mandatory, not hygiene.
FIX 2: any week landing on exactly 25 rows / 1 page is re-run in a second clean session and must agree.
LESSON: a self-consistent integrity check validates the parser, not the source. Distribution sanity
(does this look like real-world data?) is the check that actually catches a lying upstream.

### SOURCE CONTRACT (verified empirically)
- site's own JS clamps the window: dtToDate = dtFromDate + 7. A 1-month range returns the same rows
  as its first week -> weekly stepping is REQUIRED, not just polite.
- default page size 25; MaxRows select offers 25/50/100/200/500 (fired as its own postback).
- pager = ctl00$ContentPlaceHolder1$Grid$ctl01$LinkButton3 ("Next").
- label contract: "More than X records found. Viewing A To B" = more pages; "Records found N" = final
  page, N = rows ON THAT PAGE (not the grand total).
- exportButton (OfficialRecords.xls, actually an HTML table) exports the CURRENT PAGE ONLY, not the
  full result set -- tested and rejected; cross-check: export=25 vs paged truth=760 for the same week.
- grid columns are FIXED 9: View|Instrument|Date|Book/Page|Document Type|Name|Legal|Status|Direction.
  Parse by index and require len(tds)==9 -- filtering empty cells shifts columns when Legal is blank.

### DATA SHAPE
One row per PARTY per instrument (direction D=direct/grantor, R=reverse/grantee), so COUNT(*) is a
party count; use count(distinct instrument_number) for documents. Volume is dominated by
JUDGMENT/ORDER (~1,400-2,000 party-rows/week, code JDO1), then LIEN (~220-760), LIS PENDENS (~120),
RESTRICTIONS (~4-13). Full run projects to roughly 1.3M party-rows over ~601 weeks x 4 doctypes.
Integrity checks on the validated slice: 0 null dates, 0 directions outside D/R, 0 rows falling
outside their own week window.

### RUN CHARACTERISTICS
2,412 week-jobs at --delay 3 => observed ~1.2 jobs/min => ~30-33 hours wall clock. Resumable:
the ledger is authoritative, so re-running skips completed weeks and only fetches what is missing.
This makes incremental top-up FREE -- a later run picks up only the new weeks, no special code.
NOT added to data_source_registry: it is not a REST source and the monthly driver would try to
re-crawl 33 hours of history; incremental top-up via re-running the collector is the right pattern.
A week absent from / non-'ok' in the ledger must be read as NOT COLLECTED, never as zero records.
