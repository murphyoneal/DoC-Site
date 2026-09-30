-- 176a - the Florida Electrical Contractors' Licensing Board register, one register one table, verbatim (WO 862).
--
-- READ FROM THE FILE, NOT THE DOCUMENTATION (858). lic08el.csv captured 2026-09-30 22:02 UTC, posted (Last-Modified)
-- 2026-09-30 10:45:40 GMT, 3,998,040 bytes, sha256 b1bbbd8f...40754, 20,103 rows, all 22 fields. Measured on the file:
--   * 14 class prefixes, not the 3 in 862: EC 12,323 ES 1,785 CRS3 1,725 ER 1,656 EF 1,465 EG 545 PVDR 189 CRS1 114
--     ET 112 CRS2 99 EY 65 EZ 17 EI 6 EH 2.
--   * The board's own page (myfloridalicense.com/electrical-contractors) names them: EC electrical contractor, ER
--     registered electrical contractor, EF ALARM SYSTEM CONTRACTOR I ("all types of alarm systems for all purposes" -
--     fire alarm included), EG alarm II (other than fire), EY/EH registered alarm I, EZ/EI registered alarm II, ES
--     specialty, ET registered specialty. CRS1/2/3 and PVDR are continuing-education listings (training bodies,
--     no status) - the construction file carries the same class.
--   * The composed licence number COLLIDES (CRS3 serial 50 and CRS1 serial 350 both compose "CRS350"; 37 such). The
--     natural key is (class_code, licence_serial): 20,103 distinct on 20,103 rows.
--   * Field 3 (licensee_name, a person for licences) is populated on all 20,103 rows; field 4 (dba_name) on 16,826.
--     BOTH SURVIVE: separate columns, verbatim. This is the field the construction load dropped (858).
--   * Field 14 is DBPR primary status (C Current / P Probation / S Suspended), field 15 secondary (A Active /
--     I Inactive / blank) - the vocabulary already established on agent_license_status. The construction snapshot
--     names field 14 "licence_class"; that name is wrong and is not repeated here.
--   * Fields 19, 20 and 22 are blank on every row; kept verbatim so a future file that fills them is not dropped.
-- DBPR states the licensee download excludes null-and-void, delinquent and involuntarily inactive records: this is
-- the register MINUS the people in trouble, and every served statement must say "current licensees only".
--
-- Not served by anything yet. register_coverage stays not_held until the served search paths and the copy change
-- (#93/#95, FinderShell, Roz) ship in ONE deploy (862): flipping it now would move the false statement, not fix it.

create schema if not exists reg_us_fl;
revoke all on schema reg_us_fl from public, anon, authenticated;
grant usage on schema reg_us_fl to service_role;

-- one row per captured file; captured_at is ours, posted_at is DBPR's Last-Modified - never conflated
create table reg_us_fl.eclb_extract (
  extract_id    bigint generated always as identity primary key,
  source_url    text        not null,
  file_name     text        not null,
  sha256        text        not null,
  bytes         bigint      not null check (bytes > 0),
  posted_at     timestamptz not null,
  captured_at   timestamptz not null,
  archived_path text        not null,
  row_count     integer     not null check (row_count > 0),
  ingested_at   timestamptz
);

-- the archive: every row of every captured file, verbatim, 22 fields in file order
create table reg_us_fl.eclb_extract_row (
  extract_id            bigint  not null references reg_us_fl.eclb_extract(extract_id),
  row_no                integer not null,
  board_code            text, class_code text, licensee_name text, dba_name text, specialty_code text,
  addr1 text, addr2 text, addr3 text, city text, state text, zip text, county_code text,
  licence_serial        text, primary_status_code text, secondary_status_code text,
  original_date text, effective_date text, expiry_date text,
  field_19 text, field_20 text, license_number text, field_22 text,
  primary key (extract_id, row_no)
);

-- the current register: one row per (class_code, licence_serial) ever seen, carrying the latest file's values
create table reg_us_fl.eclb_licence (
  class_code            text not null,
  licence_serial        text not null,
  record_kind           text not null check (record_kind in ('licence', 'continuing_education_listing')),
  board_code text, licensee_name text, dba_name text, specialty_code text,
  addr1 text, addr2 text, addr3 text, city text, state text, zip text, county_code text,
  primary_status_code text, secondary_status_code text, original_date text, effective_date text, expiry_date text,
  field_19 text, field_20 text, license_number text, field_22 text,
  first_seen_extract_id bigint not null references reg_us_fl.eclb_extract(extract_id),
  last_seen_extract_id  bigint not null references reg_us_fl.eclb_extract(extract_id),
  register_file_state   text   not null check (register_file_state in ('in_latest_file', 'absent_from_latest_file')),
  primary key (class_code, licence_serial)
);
comment on column reg_us_fl.eclb_licence.record_kind is
  'licence = an EC/ER/EF/EG/EY/EH/EZ/EI/ES/ET licensee row; continuing_education_listing = CRS1/CRS2/CRS3/PVDR (training bodies, no status). Set explicitly by eclb_ingest_extract, no default (830).';
comment on column reg_us_fl.eclb_licence.register_file_state is
  'in_latest_file / absent_from_latest_file. Absent means the most recent captured file does not list it - which the download also does to null-and-void, delinquent and involuntarily inactive licences. Never serve an absent row as active.';
comment on table reg_us_fl.eclb_licence is
  'Florida ECLB (board 08) register, verbatim from lic08el.csv, keyed (class_code, licence_serial). Current licensees only: DBPR excludes null-and-void, delinquent and involuntarily inactive records. Loader: ~/dbpr/eclb/eclb_load.py -> reg_us_fl.eclb_ingest_extract().';

revoke all on all tables in schema reg_us_fl from public, anon, authenticated;
grant select on all tables in schema reg_us_fl to service_role;

-- the ONE ingest path: the first load and the weekly job both call this after COPYing an extract's rows
create or replace function reg_us_fl.eclb_ingest_extract(p_extract_id bigint) returns jsonb
language plpgsql security definer set search_path to 'reg_us_fl', 'public' as $$
declare e reg_us_fl.eclb_extract; n_rows int; n_up int; n_absent int; n_tab int; n_key int; latest bigint;
begin
  select * into e from eclb_extract where extract_id = p_extract_id;
  if not found then raise exception 'eclb: extract % not found', p_extract_id; end if;
  select count(*) into n_rows from eclb_extract_row where extract_id = p_extract_id;
  -- empty != done, and a short COPY is not a file
  if n_rows = 0 then raise exception 'eclb: extract % has 0 rows - touching nothing', p_extract_id; end if;
  if n_rows <> e.row_count then raise exception 'eclb: extract % archived % rows, file had %', p_extract_id, n_rows, e.row_count; end if;
  if exists (select 1 from eclb_extract_row where extract_id = p_extract_id group by class_code, licence_serial having count(*) > 1) then
    raise exception 'eclb: extract % repeats a (class_code, licence_serial) - natural key broken', p_extract_id;
  end if;
  -- only the newest posted file may set register_file_state
  select extract_id into latest from eclb_extract order by posted_at desc, captured_at desc limit 1;
  if latest <> p_extract_id then raise exception 'eclb: extract % is not the newest posted file (%)', p_extract_id, latest; end if;

  insert into eclb_licence (class_code, licence_serial, record_kind, board_code, licensee_name, dba_name, specialty_code,
      addr1, addr2, addr3, city, state, zip, county_code, primary_status_code, secondary_status_code,
      original_date, effective_date, expiry_date, field_19, field_20, license_number, field_22,
      first_seen_extract_id, last_seen_extract_id, register_file_state)
  select r.class_code, r.licence_serial,
         case when r.class_code ~ '^(CRS|PVDR)' then 'continuing_education_listing' else 'licence' end,
         r.board_code, r.licensee_name, r.dba_name, r.specialty_code, r.addr1, r.addr2, r.addr3, r.city, r.state, r.zip,
         r.county_code, r.primary_status_code, r.secondary_status_code, r.original_date, r.effective_date, r.expiry_date,
         r.field_19, r.field_20, r.license_number, r.field_22, p_extract_id, p_extract_id, 'in_latest_file'
    from eclb_extract_row r where r.extract_id = p_extract_id
  on conflict (class_code, licence_serial) do update set
      record_kind = excluded.record_kind, board_code = excluded.board_code, licensee_name = excluded.licensee_name,
      dba_name = excluded.dba_name, specialty_code = excluded.specialty_code, addr1 = excluded.addr1, addr2 = excluded.addr2,
      addr3 = excluded.addr3, city = excluded.city, state = excluded.state, zip = excluded.zip, county_code = excluded.county_code,
      primary_status_code = excluded.primary_status_code, secondary_status_code = excluded.secondary_status_code,
      original_date = excluded.original_date, effective_date = excluded.effective_date, expiry_date = excluded.expiry_date,
      field_19 = excluded.field_19, field_20 = excluded.field_20, license_number = excluded.license_number, field_22 = excluded.field_22,
      last_seen_extract_id = p_extract_id, register_file_state = 'in_latest_file';
  get diagnostics n_up = row_count;

  update eclb_licence set register_file_state = 'absent_from_latest_file'
   where last_seen_extract_id <> p_extract_id and register_file_state <> 'absent_from_latest_file';
  get diagnostics n_absent = row_count;

  select count(*), count(distinct (class_code, licence_serial)) into n_tab, n_key from eclb_licence;
  if n_tab <> n_key then raise exception 'eclb: register has % rows for % keys', n_tab, n_key; end if;
  if (select count(*) from eclb_licence where last_seen_extract_id = p_extract_id) <> n_rows then
    raise exception 'eclb: register does not carry every row of extract %', p_extract_id;
  end if;
  if (select count(*) from eclb_licence where last_seen_extract_id = p_extract_id and nullif(trim(licensee_name), '') is null) > 0 then
    raise exception 'eclb: licensee_name dropped on load (the 858 defect)';
  end if;

  update eclb_extract set ingested_at = now() where extract_id = p_extract_id;
  perform public._log_action('build_agent', 'ingest_eclb_extract', 'reg_us_fl.eclb_licence', array[p_extract_id::text], null,
    jsonb_build_object('extract_id', p_extract_id, 'rows', n_rows, 'upserted', n_up, 'newly_absent', n_absent, 'register_rows', n_tab),
    'WO 862: weekly ECLB register ingest from the archived lic08el.csv extract, upsert on (class_code, licence_serial).', null);
  return jsonb_build_object('extract_id', p_extract_id, 'rows', n_rows, 'upserted', n_up, 'newly_absent', n_absent, 'register_rows', n_tab);
end $$;
revoke all on function reg_us_fl.eclb_ingest_extract(bigint) from public, anon, authenticated;
grant execute on function reg_us_fl.eclb_ingest_extract(bigint) to service_role;

insert into public.data_source_registry (county_name, category, table_name, source_url, access_technique, active, pull_mode, notes, cadence_basis)
values ('Statewide', 'licence_register', 'reg_us_fl.eclb_licence',
  'https://www2.myfloridalicense.com/sto/file_download/extracts/lic08el.csv', 'bulk_csv', true, 'auto',
  'Florida ECLB (board 08) licensee extract, weekly per DBPR (maintenance may delay it). 22 fields; person (licensee_name) and business (dba_name) both loaded. Excludes null-and-void, delinquent and involuntarily inactive records. Archive: reg_us_fl.eclb_extract/_row. Loader ~/dbpr/eclb/eclb_load.py.',
  'publisher_stated');

select public._log_action('cc', 'build_eclb_register', 'reg_us_fl.eclb_licence', array['reg_us_fl.eclb_extract','reg_us_fl.eclb_extract_row','reg_us_fl.eclb_licence','reg_us_fl.eclb_ingest_extract'],
  null, jsonb_build_object('schema','reg_us_fl','natural_key','class_code+licence_serial'),
  'WO 862: electricians and alarm contractors added as their own register, verbatim, person and business names both kept.', null);
