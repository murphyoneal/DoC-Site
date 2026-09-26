-- 138a — Refresh the contractor register from the 7 Sep 2026 state file. Ruling 2026-09-26.
--
-- The register was built from the 27 Jun 2026 file, before DBPR's 31 Aug renewal deadline, so
-- 71,998 licence records (63,933 businesses) showed "Active" beside an expiry that had passed. The
-- 7 Sep file is already held (dbpr_construction_snapshot 3): Red Stag CBC1255193 is there at
-- 08/31/2028.
--
-- CONDITIONS OF THE RULING, and how they are met:
--  * "Append the new snapshot, don't overwrite the June baseline." The June register exists only as
--    the contents of `contractors` (snapshot 2 was never kept row-by-row), so it is FROZEN first,
--    whole, into contractors_register_2026_06_27. Snapshot 3 is already appended in
--    dbpr_construction_snapshot; nothing there is touched.
--  * "Re-run the business keys afterwards; slugs must stay stable." This migration changes ONLY the
--    licence's state-file fields (status, expiry, effective date) and adds two columns. Name, city,
--    zip and street - the business-key inputs - are NOT touched, so every key and slug is unchanged
--    by construction (asserted below). The 971 name / 6,073 city / 7,473 zip changes in the Sep file
--    and the 37,765 licences not in the register are a separate step, reported for a ruling.
--
-- WHAT CHANGES, per licence:
--  * found in the Sep file (96,116): status, expiry and effective date from that file;
--    register_file_date = 2026-09-07, register_file_state = in_latest_file.
--    Status: A -> active, I -> inactive, blank -> not_stated (never guessed).
--  * NOT in the Sep file (17,988): nothing overwritten; register_file_date = 2026-06-27 (last seen),
--    register_file_state = absent_from_latest_file. The page says so instead of showing the June
--    status as current (DoC-Site #46, deployed first).
--  * 127,447 Sep rows have a BLANK licence number (all trade QB) and cannot be matched; excluded.
--  * Where a licence has several Sep rows (141), the one with the latest expiry is used.

set statement_timeout = 0;

-- 1. Freeze the June baseline, whole. It holds the street address, so it is closed to the REST roles.
create table public.contractors_register_2026_06_27 as select * from public.contractors;
revoke all on public.contractors_register_2026_06_27 from anon, authenticated;
alter table public.contractors_register_2026_06_27 enable row level security;
comment on table public.contractors_register_2026_06_27 is
  'FROZEN copy of contractors as built from the 27 Jun 2026 DBPR file, taken by 138a immediately before the '
  'register was refreshed from the 7 Sep 2026 file. The only row-level record of what the register said then. '
  'Never update. Not served.';

-- 2. Per-licence file provenance.
alter table public.contractors
  add column register_file_date date,
  add column register_file_state text
    check (register_file_state in ('in_latest_file','absent_from_latest_file'));
comment on column public.contractors.register_file_date is
  'Date of the DBPR state file this licence''s status/expiry come from: the latest file it appears in. 138a.';
comment on column public.contractors.register_file_state is
  'in_latest_file, or absent_from_latest_file (status/expiry are as last recorded; absence is not a lapse). 138a.';

-- 3. The Sep file, one row per licence.
create temp table _sep on commit drop as
select distinct on (license_number) license_number, status_code, expiry_date, effective_date
  from public.dbpr_construction_snapshot
 where snapshot_id = 3 and license_number <> ''
 order by license_number, to_date(nullif(expiry_date,''),'MM/DD/YYYY') desc nulls last, row_no;

-- 4. Licences in the Sep file.
update public.contractors c
   set expiry_date         = s.expiry_date,
       effective_date      = s.effective_date,
       secondary_status    = nullif(s.status_code,''),
       license_status      = case s.status_code when 'A' then 'active' when 'I' then 'inactive' else 'not_stated' end,
       register_file_date  = date '2026-09-07',
       register_file_state = 'in_latest_file',
       updated_at          = now()
  from _sep s
 where s.license_number = c.license_number;

-- 5. Licences not in it: nothing overwritten, marked.
update public.contractors
   set register_file_date = date '2026-06-27', register_file_state = 'absent_from_latest_file'
 where register_file_state is null;

-- 6. The register's source file is now snapshot 3 (one-source index: off before on).
update public.dbpr_snapshot_log set is_register_source = false where snapshot_id = 2;
update public.dbpr_snapshot_log set is_register_source = true  where snapshot_id = 3;

-- 7. Serve the two columns (additive, appended to the end of the view).
do $v$
declare def text; new_def text;
begin
  def := pg_get_viewdef('public.contractors_public'::regclass);
  new_def := replace(def, E'    geocode_quality\n   FROM contractors',
                          E'    geocode_quality,\n    register_file_date,\n    register_file_state\n   FROM contractors');
  if new_def = def then raise exception '138a: view anchor not found'; end if;
  execute 'create or replace view public.contractors_public as ' || new_def;
end $v$;

-- 8. Assertions.
do $a$
declare n_arch bigint; n_now bigint; n_in bigint; n_abs bigint; n_past bigint; n_null bigint; biz_before bigint;
begin
  select count(*) into n_arch from public.contractors_register_2026_06_27;
  select count(*) into n_now  from public.contractors;
  if n_arch <> n_now or n_arch = 0 then raise exception '138a: archive % rows vs register %', n_arch, n_now; end if;

  select count(*) filter (where register_file_state = 'in_latest_file'),
         count(*) filter (where register_file_state = 'absent_from_latest_file'),
         count(*) filter (where register_file_state is null)
    into n_in, n_abs, n_null from public.contractors;
  if n_null <> 0 then raise exception '138a: % rows have no file state', n_null; end if;
  if n_in < 90000 then raise exception '138a: only % licences matched the Sep file', n_in; end if;

  select count(*) into n_past from public.contractors
   where register_file_state = 'in_latest_file' and license_status = 'active'
     and expiry_date ~ '^\d{2}/\d{2}/\d{4}$' and to_date(expiry_date,'MM/DD/YYYY') < current_date;
  if n_past > 50 then raise exception '138a: % in-file active licences still show a past expiry', n_past; end if;

  -- business-key inputs untouched: identical to the frozen copy on every row
  if exists (select 1 from public.contractors c join public.contractors_register_2026_06_27 j on j.id = c.id
              where c.business_name is distinct from j.business_name or c.city is distinct from j.city
                 or c.zip_code is distinct from j.zip_code or c.address_line_1 is distinct from j.address_line_1
                 or c.slug is distinct from j.slug) then
    raise exception '138a: a business-key input or slug changed';
  end if;

  if has_table_privilege('anon', 'public.contractors_register_2026_06_27', 'SELECT') then
    raise exception '138a: the June archive (with street addresses) is readable by anon';
  end if;
  if not has_table_privilege('anon', 'public.contractors_public', 'SELECT') then
    raise exception '138a: contractors_public lost its anon grant';
  end if;
  raise notice '138a: % in the Sep file, % absent, % in-file active with a past expiry', n_in, n_abs, n_past;
end $a$;
