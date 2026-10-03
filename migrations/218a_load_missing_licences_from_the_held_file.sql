-- 218a - load the licences the register never loaded from the file we already hold (ruling 1000).
--
-- 217a found 38,012 licences in the 7 Sep 2026 file (dbpr_construction_snapshot 3) with no register row; searching an
-- active one (CGC001072) returned "no match". Ruling 1000 split them:
--   status A, real trade codes      2,323   LOAD   (the live defect)
--   status I, real trade codes     11,256   LOAD   (an inactive licence is the fact most likely to stop a contract)
--   blank status, stray CBC/RC/RG       3   LOAD   rendered "not stated", never active
--   FRO business registrations     19,178   DEFERRED (no licence number, no government key - a separate ruling)
--   CRS1/PVDR education providers   5,252   NEVER (not contractors; excluded from every served path)
-- 1000 headlined "13,579"; its own parts sum to 13,582 (2,323 + 11,256 + 3), which is what this loads.
-- Every value comes from the file row (latest expiry wins, as 138a/212a):
--   name: the business name as published; where the file gives none, the licence is held by a person and the page shows
--         that person's name as the state publishes it (Murphy 947). trading_name only where the file has one.
--   trade_label / doc_category: trade_code_registry (official_label / display_category) - never a name-read guess.
--   status: A active, I inactive, blank not_stated; secondary_status = the file's code; primary_status = licence class.
--   address, county_code from the file; county_name from the register's own 67-code map (out-of-state codes: none).
--   country from the state code (US/CA) or NULL - a fact about the subject is never defaulted.
--   No map pin: lat/lng NULL, geocoded false, until geocoded - a missing pin, not a wrong one.
-- Slugs (stored, never regenerated): Florida address -> name-city-fl; out-of-state or no state -> name-licence-fl (216a);
-- a clash takes a stored counter. Existing slugs are never touched.
-- Business pages: each row is keyed exactly as rebuild_business_register keys rows (name+zip+street, else a singleton);
-- a key that already has a business makes the row a MEMBER of it (its slug redirects there); otherwise a new business
-- page. contractor_name_index is rebuilt so the new licences can be claimed.

set statement_timeout = 0;

create temp table _m on commit drop as
select distinct on (s.license_number) s.*
  from public.dbpr_construction_snapshot s
 where s.snapshot_id = 3 and s.license_number <> '' and s.trade_code not in ('FRO','CRS1','PVDR')
   and not exists (select 1 from public.contractors c where c.license_number = s.license_number)
 order by s.license_number, to_date(nullif(s.expiry_date,''),'MM/DD/YYYY') desc nulls last, s.row_no;

create temp table _cmap on commit drop as
select county_code, min(county_name) county_name from public.contractors
 where county_name_method = 'dbpr_county_code' and county_name is not null group by county_code;

do $$
declare n int; na int; ni int; nb int;
begin
  select count(*), count(*) filter (where status_code = 'A'), count(*) filter (where status_code = 'I'), count(*) filter (where coalesce(status_code,'') = '')
    into n, na, ni, nb from _m;
  if n <> 13582 or na <> 2323 or ni <> 11256 or nb <> 3 then raise exception '218a: population moved: % (A %, I %, blank %)', n, na, ni, nb; end if;
  if exists (select 1 from _m where not exists (select 1 from public.trade_code_registry r where r.trade_code = _m.trade_code)) then
    raise exception '218a: a trade code is not in the registry'; end if;
end $$;

create temp table _new on commit drop as
select gen_random_uuid() id, m.license_number, m.trade_code,
       coalesce(nullif(btrim(m.dba_name),''), nullif(btrim(m.full_name),'')) as name,
       nullif(btrim(m.dba_name),'') as trading_name,
       nullif(btrim(m.licence_class),'') as primary_status, nullif(btrim(m.status_code),'') as secondary_status,
       case m.status_code when 'A' then 'active' when 'I' then 'inactive' else 'not_stated' end as license_status,
       nullif(m.original_date,'') original_date, nullif(m.effective_date,'') effective_date, nullif(m.expiry_date,'') expiry_date,
       nullif(btrim(m.addr1),'') addr1, nullif(btrim(m.addr2),'') addr2, nullif(btrim(m.city),'') city,
       nullif(btrim(m.state),'') state, nullif(btrim(m.zip),'') zip, nullif(btrim(m.county_code),'') county_code,
       r.official_label trade_label, r.display_category doc_category
  from _m m join public.trade_code_registry r on r.trade_code = m.trade_code;
alter table _new add column slug text, add column bkey text, add column key_basis text;

-- slugs: Florida address -> name-city-fl; otherwise name-licence-fl; stored counter on a clash
do $$
declare r record; base text; cand text; k int;
begin
  for r in select * from _new order by license_number loop
    base := trim(both '-' from regexp_replace(lower(r.name || case when r.state = 'FL' and r.city is not null then ' ' || r.city else ' ' || r.license_number end || ' fl'), '[^a-z0-9]+', '-', 'g'));
    cand := base; k := 1;
    while exists (select 1 from public.contractors where slug = cand) or exists (select 1 from public.businesses where slug = cand)
       or exists (select 1 from public.business_slug_redirects where old_slug = cand) or exists (select 1 from _new where slug = cand) loop
      k := k + 1; cand := base || '-' || k;
    end loop;
    update _new set slug = cand where id = r.id;
  end loop;
end $$;

insert into public.contractors (id, slug, business_name, trading_name, display_name, licensee_name, trade_code, trade_label, doc_category,
  license_number, license_status, primary_status, secondary_status, original_date, effective_date, expiry_date,
  address_line_1, address_line_2, city, state, zip_code, county_code, county_name, county_name_method, in_volusia,
  country, country_code, source, source_state, active, record_kind, register_file_state, register_file_date, geocoded)
select n.id, n.slug, n.name, n.trading_name, n.name,
       case when n.trading_name is null then n.name end,
       n.trade_code, n.trade_label, n.doc_category, n.license_number, n.license_status, n.primary_status, n.secondary_status,
       n.original_date, n.effective_date, n.expiry_date, n.addr1, n.addr2, n.city, n.state, n.zip, n.county_code,
       m.county_name, case when m.county_name is not null then 'dbpr_county_code' else 'dbpr_county_code_out_of_state' end,
       coalesce(m.county_name = 'volusia', false),
       case when n.state in ('AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT') then 'CA' when n.state ~ '^[A-Z]{2}$' then 'US' end,
       case when n.state in ('AB','BC','MB','NB','NL','NS','NT','NU','ON','PE','QC','SK','YT') then 'CA' when n.state ~ '^[A-Z]{2}$' then 'US' end,
       'DBPR_FL', 'FL', true, 'licence', 'in_latest_file', date '2026-09-07', false
  from _new n left join _cmap m on m.county_code = n.county_code;

-- business pages, keyed as rebuild_business_register keys rows
update _new set key_basis = case
    when license_number !~ '^[A-Z]{2,4}[0-9]+$' then 'singleton_malformed_licence'
    when public.business_norm(name) = '' or public.business_norm(coalesce(addr1,'')) = '' or coalesce(left(zip,5),'') !~ '^[0-9]{5}$' then 'singleton_blank_key'
    when exists (select 1 from public.business_name_rulings b where b.name_norm = public.business_norm(_new.name) and b.ruling = 'placeholder') then 'singleton_placeholder_name'
    else 'name_zip_street' end;
update _new set bkey = case when key_basis = 'name_zip_street'
    then 'nzs:' || public.business_norm(name) || '|' || left(zip,5) || '|' || public.business_norm(addr1)
    else 'lic:' || id::text end;

-- (1) rows whose key already has a business: members of it; their own slug redirects to the business page
insert into public.business_licences (business_id, contractor_id, link_basis)
select b.id, n.id, 'member' from _new n join public.businesses b on b.business_key = n.bkey;
insert into public.business_slug_redirects (business_id, old_slug)
select b.id, n.slug from _new n join public.businesses b on b.business_key = n.bkey;

-- (2) new keys: one business per key, canonical = the row rebuild would pick (no counter, shorter slug)
insert into public.businesses (business_key, key_basis, slug, canonical_contractor_id, display_name)
select distinct on (n.bkey) n.bkey, n.key_basis, n.slug, n.id, n.name
  from _new n where not exists (select 1 from public.businesses b where b.business_key = n.bkey)
 order by n.bkey, (n.slug ~ '-[0-9]+$'), length(n.slug), n.slug;
insert into public.business_licences (business_id, contractor_id, link_basis)
select b.id, n.id, 'member' from _new n join public.businesses b on b.business_key = n.bkey
 where not exists (select 1 from public.business_licences x where x.contractor_id = n.id);
insert into public.business_slug_redirects (business_id, old_slug)
select b.id, n.slug from _new n join public.businesses b on b.business_key = n.bkey
 where b.slug <> n.slug and not exists (select 1 from public.business_slug_redirects r where r.old_slug = n.slug);

select public.rebuild_contractor_name_index();

-- the held-file detection now counts only the classes the register serves; FRO (deferred) and CRS1/PVDR (never) are
-- outside its population by ruling, and stated as such
update public.data_defect_registry set
  detection_sql = $q$with snap as (select snapshot_id from public.dbpr_snapshot_log where is_register_source limit 1),
    f as (select distinct on (license_number) license_number, status_code from public.dbpr_construction_snapshot
           where snapshot_id = (select snapshot_id from snap) and license_number <> '' and trade_code not in ('FRO','CRS1','PVDR')
           order by license_number, row_no),
    missing as (select * from f where not exists (select 1 from public.contractors c where c.license_number = f.license_number))
select not exists (select 1 from missing) as ok,
       (select count(*) from missing) as row_count,
       (select count(*) from missing where status_code = 'A') as active_missing,
       (select count(*) from f) as population$q$,
  expected_state = 'clean', acknowledgement = null, expires_at = null,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 218a (ruling 1000): loaded 13,582. Population is now the served classes only - FRO business registrations (19,178, deferred to their own ruling) and CRS1/PVDR education providers (5,252, never loaded) are excluded by ruling, not by accident.'
 where defect_id = 'held-file-licence-not-in-register';

do $$
declare a jsonb; b jsonb; s jsonb; n int;
begin
  select count(*) into n from public.contractors c join _new x on x.id = c.id;
  if n <> 13582 then raise exception '218a: inserted %', n; end if;
  if exists (select 1 from _new x where not exists (select 1 from public.business_licences bl where bl.contractor_id = x.id)) then raise exception '218a: a new licence has no business'; end if;
  if exists (select 1 from public.contractors c join _new x on x.id = c.id where c.license_status = 'active' and x.secondary_status is distinct from 'A') then raise exception '218a: a non-A row reads active'; end if;
  if (select count(*) from public.contractors) <> (select count(distinct slug) from public.contractors) then raise exception '218a: slugs not unique'; end if;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'register-row-without-a-page')) into a;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'held-file-licence-not-in-register')) into b;
  if (a->>'ok')::boolean is distinct from true then raise exception '218a: a served row has no page: %', a; end if;
  if (b->>'ok')::boolean is distinct from true then raise exception '218a: held-file licences still missing: %', b; end if;
  s := public.register_search('CGC001072', 5);
  if (s->>'count')::int < 1 then raise exception '218a: CGC001072 still not found'; end if;
  if not exists (select 1 from public.contractor_name_index where license_number = 'CGC001072') then raise exception '218a: not in the claim index'; end if;
  raise notice '218a: loaded 13,582; pages %; held-file %; CGC001072 found %; new businesses %, joined existing %',
    a->>'population', b, s->>'count',
    (select count(*) from public.businesses bz join _new x on x.id = bz.canonical_contractor_id),
    (select count(*) from _new x join public.business_licences bl on bl.contractor_id = x.id join public.businesses bz on bz.id = bl.business_id where bz.canonical_contractor_id <> x.id);
end $$;

select public._log_action('cc', 'load_missing_licences_from_held_file', 'contractors', array['contractors','businesses','business_licences','contractor_name_index'],
  jsonb_build_object('missing_served_class_licences', 13582), jsonb_build_object('loaded', 13582, 'active', 2323, 'inactive', 11256, 'not_stated', 3),
  'Ruling 1000: 13,582 licences in the held 7 Sep 2026 file were never loaded; search told visitors there was no match.', null);
