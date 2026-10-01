-- 185a - the capture log records which capture is loaded (rulings 889 O2, 890 "the manifest is the fix, not the folder").
--
-- volusia_cama_snapshot_log recorded six captures (2026-07-20 .. 2026-09-28 county as-of) and nothing recorded which one
-- the served tables held - which is how six captures sat unloaded for ten weeks. Two columns:
--   loaded_at        when this capture's contents became the served volusia_cama_* tables
--   loaded_evidence  the proof (a count match, a loader log)
-- 2026-07-20: loaded by ~/cama_load.py; proven by every table's row count equalling this capture's table_counts (182a,
--             measured 18/18 on 2026-10-01). Its exact load time is not recorded, so loaded_at = the capture date
--             (2026-07-23) with that stated as the basis.
-- 2026-09-28: loaded 2026-10-01 by ~/volusia_cama_refresh.py through the collapse guard: 18/18 OK, each table replaced in
--             one transaction (TRUNCATE + INSERT from staging), counts asserted equal to the export; then
--             refresh_permit_contractor_match() added 5,830 candidate matches for the new permits.
-- The four captures in between were never loaded and now never need to be; they stay on disk as evidence per 890.

alter table public.volusia_cama_snapshot_log add column if not exists loaded_at timestamptz;
alter table public.volusia_cama_snapshot_log add column if not exists loaded_evidence text;
comment on column public.volusia_cama_snapshot_log.loaded_at is
  'When this capture became the served volusia_cama_* tables (185a). NULL = captured, never loaded. At most one capture is the current load: the latest loaded_at.';

update public.volusia_cama_snapshot_log
   set loaded_at = timestamptz '2026-07-23 00:00:00+00',
       loaded_evidence = 'loaded by ~/cama_load.py; every volusia_cama_* table row count equalled this capture''s table_counts (measured 18/18, 2026-10-01). Exact load time not recorded; capture date used.'
 where data_current_as_of = date '2026-07-20';

update public.volusia_cama_snapshot_log
   set loaded_at = now(),
       loaded_evidence = 'loaded 2026-10-01 by ~/volusia_cama_refresh.py (sha256 a8bf8b7d92df verified against this row): 18/18 OK through the collapse guard, each table replaced in one transaction with staged = exported = live asserted; refresh_permit_contractor_match() then added 5,830 raw matches (resolved 191,536 -> 193,677).'
 where data_current_as_of = date '2026-09-28';

select public._log_action('cc', 'load_volusia_cama_capture', 'volusia_cama_*', array['18 tables','permit_contractor_match','permit_contractor_match_resolved'],
  jsonb_build_object('county_as_of', '2026-07-20', 'permits', 992313, 'newest_permit', '2026-08-29', 'sales', 1613504, 'newest_sale', '2026-07-15', 'parcels', 346517, 'licence_linked', 99181),
  jsonb_build_object('county_as_of', '2026-09-28', 'permits', 1000048, 'newest_permit', '2026-09-25', 'permits_after_0720', 4604, 'sales', 1620903, 'newest_sale', '2026-09-10', 'sales_after_0720', 4266, 'parcels', 347528, 'licence_linked', 100069),
  'Ruling 889 O2: the weekly Volusia CAMA captures were downloaded and never loaded; the latest (as of 2026-09-28) loaded from disk through the collapse guard. Derived property_permit_history and parcel_deed_chain NOT rebuilt (no recovered builder).', null);

do $$
declare n int;
begin
  select count(*) into n from public.volusia_cama_snapshot_log where loaded_at is not null;
  if n is distinct from 2 then raise exception '185a: % captures marked loaded, expected 2', n; end if;
  if (select count(*) from public.volusia_cama_permits) is distinct from 1000048::bigint then raise exception '185a: permits table is not the 2026-09-28 load'; end if;
end $$;
