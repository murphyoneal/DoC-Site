-- 182a - reconcile data_source_registry against evidence before any pull engine reads it (rulings 883, 885 S1).
--
-- MEASURED 2026-10-01: all 81 active sources with last_successful_pull_date NULL resolve to an existing table WITH
-- ROWS (0 missing, 0 empty). True never-pulled = 0. The data was loaded; the date was never written. A pull engine
-- seeded from the NULLs would re-fetch ~38M rows we already hold.
--
-- Dates are written back ONLY where a dated artefact proves them, and the artefact is named:
--   cama_load_manifest      Pinellas / Collier / Pasco - one row per loaded file, loaded_at + file_as_of + count_ok
--   volusia_cama_snapshot_log  Volusia CAMA - all 18 tables' current exact row counts equal the 2026-07-20 extract's
--                           table_counts (measured 18/18), captured 2026-07-23
--   reg_us_fl.eclb_extract  the ECLB register - extract 1, ingested 2026-09-30
-- Everything else stays NULL with basis 'present_undated': present in a table, no artefact dates it. An honest NULL
-- beats an invented date (cf. moderation_action 25, my own estimated timestamp, corrected 2026-10-01).

alter table public.data_source_registry add column if not exists last_pull_basis text;
alter table public.data_source_registry add column if not exists last_pull_evidence text;
comment on column public.data_source_registry.last_pull_basis is
  'How last_successful_pull_date is known (182a): fetcher (written by the pull engine / master_refresh), cama_load_manifest, volusia_cama_snapshot_log, eclb_extract, present_undated (data present, no artefact dates it - date stays NULL). NULL basis on an old row = written before 182a by master_refresh.';
comment on column public.data_source_registry.last_pull_evidence is
  'The artefact behind last_successful_pull_date: manifest ids, snapshot date, extract id. Never a guess.';

-- Pinellas / Collier / Pasco: from the load manifest, only where every file for the table was count_ok
update public.data_source_registry r
   set last_successful_pull_date = m.loaded::date,
       last_pull_basis = 'cama_load_manifest',
       last_pull_evidence = 'cama_load_manifest ids ' || m.ids || '; file_as_of ' || m.as_of || '; loaded_at ' || m.loaded || '; rows ' || m.rows
  from (select table_name, string_agg(id::text, ',' order by id) ids, max(loaded_at) loaded, max(file_as_of)::date::text as_of,
               sum(row_count) rows, bool_and(count_ok) all_ok
          from public.cama_load_manifest group by table_name) m
 where r.table_name = m.table_name and m.all_ok and r.active and r.last_successful_pull_date is null;

-- Volusia CAMA: the 2026-07-20 extract (captured 2026-07-23), proven by exact per-table count match below
update public.data_source_registry r
   set last_successful_pull_date = date '2026-07-23',
       last_pull_basis = 'volusia_cama_snapshot_log',
       last_pull_evidence = 'exact row count equals volusia_cama_snapshot_log data_current_as_of 2026-07-20 (captured 2026-07-23, sha256 4aee87ca...) table_counts; measured 18/18 tables 2026-10-01'
 where r.active and r.last_successful_pull_date is null and r.county_name = 'Volusia' and r.category = 'cama';

-- ECLB
update public.data_source_registry r
   set last_successful_pull_date = (select ingested_at::date from reg_us_fl.eclb_extract where extract_id = 1),
       last_pull_basis = 'eclb_extract',
       last_pull_evidence = 'reg_us_fl.eclb_extract id 1, posted 2026-09-30 10:45:40 GMT, 20,103 rows'
 where r.table_name = 'reg_us_fl.eclb_licence' and r.last_successful_pull_date is null;

-- the rest: present, undated
update public.data_source_registry r
   set last_pull_basis = 'present_undated',
       last_pull_evidence = 'table holds rows (pg_class reltuples > 0 on 2026-10-01); no artefact dates the load'
 where r.active and r.last_successful_pull_date is null and r.last_pull_basis is null;

select public._log_action('cc', 'reconcile_registry_pull_dates', 'data_source_registry', array['last_successful_pull_date','last_pull_basis','last_pull_evidence'],
  jsonb_build_object('active_never_pulled', 81),
  (select jsonb_object_agg(coalesce(last_pull_basis,'(null)'), n) from (select last_pull_basis, count(*) n from public.data_source_registry where active and last_pull_basis is not null group by 1) x),
  'Ruling 883/885 S1: 81 "never pulled" sources all hold data; dates written back only from named artefacts, the rest marked present_undated with a NULL date.', null);

do $$
declare bad int;
begin
  -- every active source now has either a date or a stated basis for having none
  select count(*) into bad from public.data_source_registry where active and last_successful_pull_date is null and last_pull_basis is distinct from 'present_undated';
  if bad <> 0 then raise exception '182a: % active sources with no date and no basis', bad; end if;
  -- no date was written without evidence
  select count(*) into bad from public.data_source_registry where last_pull_basis in ('cama_load_manifest','volusia_cama_snapshot_log','eclb_extract') and (last_successful_pull_date is null or last_pull_evidence is null);
  if bad <> 0 then raise exception '182a: % evidence rows missing date or evidence', bad; end if;
end $$;
