-- 214a - fold 41 stub business pages into the business that already holds the same licence (ruling 978 item 1).
--
-- Audit 971 C: 56 licences sit in two (or more) businesses, so one licence has two public pages (Kass:
-- /c/kass-air-conditioning-refrigeration-corp-fl and ...-weston-fl, one saying first issued 2001, the other 1987).
-- Measured 2026-10-03, by shape:
--   41  the SAME contractor row is (i) the canonical, only licence of a 'singleton_blank_key' business - a stub made
--       because the row's own address fields were blank - and (ii) a member of exactly one proper business
--       (name + zip + street key). The stub is a duplicate page of a licence the proper business already shows.
--   15  several rows and/or several proper businesses share a licence. One qualifier's licence can legitimately
--       qualify more than one company, so these are NOT merged by rule; they are listed for a ruling.
-- For the 41: the stub's slug becomes a permanent redirect to the proper business (business_slug_redirects, served as
-- a 308 by resolve_business_slug, already deployed), and the stub business is removed with its single licence link.
-- The contractor row itself is untouched - it stays a member of the proper business.
-- Safety, measured and re-asserted inside: 0 claims, 0 profiles, 0 redirects into the stubs, 0 rows in the other four
-- business_id tables. The stubs' 4 historical scan_events are slug-keyed logs and the redirect keeps them meaningful.
-- Before-state kept (businesses_before_214a, business_licences_before_214a). Recounted inside the migration before the
-- delete (memory recount-before-destructive-ddl).

set statement_timeout = 0;

create temp table _stub on commit drop as
with d as (select c.license_number from public.business_licences bl join public.contractors c on c.id = bl.contractor_id
            where c.license_number is not null and c.active is not false group by c.license_number having count(distinct bl.business_id) > 1),
pairs as (select d.license_number, b.id bid, b.slug, b.key_basis, (b.canonical_contractor_id = c.id) is_canon, c.id cid,
                 (select count(*) from public.business_licences x where x.business_id = b.id) n_lic
            from d join public.contractors c on c.license_number = d.license_number and c.active is not false
            join public.business_licences bl on bl.contractor_id = c.id join public.businesses b on b.id = bl.business_id),
simple as (select license_number from pairs group by 1
            having count(distinct cid) = 1 and count(distinct bid) = 2
               and bool_or(key_basis = 'singleton_blank_key' and is_canon and n_lic = 1)
               and count(*) filter (where key_basis <> 'singleton_blank_key') = 1)
select s.license_number,
       (select p.bid  from pairs p where p.license_number = s.license_number and p.key_basis = 'singleton_blank_key' and p.is_canon) stub_id,
       (select p.slug from pairs p where p.license_number = s.license_number and p.key_basis = 'singleton_blank_key' and p.is_canon) stub_slug,
       (select p.bid  from pairs p where p.license_number = s.license_number and p.key_basis <> 'singleton_blank_key') target_id,
       (select p.slug from pairs p where p.license_number = s.license_number and p.key_basis <> 'singleton_blank_key') target_slug
  from simple s;

do $$
declare n int;
begin
  select count(*) into n from _stub;
  if n <> 41 then raise exception '214a: expected 41 stub businesses, found %', n; end if;
  if exists (select 1 from _stub where stub_id is null or target_id is null or stub_id = target_id) then raise exception '214a: an unresolved pair'; end if;
  if exists (select 1 from public.business_profile p join _stub s on s.stub_id = p.business_id)
     or exists (select 1 from public.business_slug_redirects r join _stub s on s.stub_id = r.business_id)
     or exists (select 1 from public.claim_requests cr join public.businesses b on b.canonical_contractor_id = cr.contractor_id join _stub s on s.stub_id = b.id)
     or exists (select 1 from public.registered_credential x join _stub s on s.stub_id = x.business_id)
     or exists (select 1 from public.registration_review_check x join _stub s on s.stub_id = x.business_id)
     or exists (select 1 from public.business_declared_insurance x join _stub s on s.stub_id = x.business_id)
     or exists (select 1 from public.business_appeal x join _stub s on s.stub_id = x.business_id) then
    raise exception '214a: a stub carries a claim, profile, redirect or declaration - stop';
  end if;
  if exists (select 1 from public.business_slug_redirects r join _stub s on r.old_slug = s.stub_slug) then raise exception '214a: a stub slug is already a redirect'; end if;
end $$;

create table if not exists public.businesses_before_214a as select b.* from public.businesses b where false;
create table if not exists public.business_licences_before_214a as select bl.* from public.business_licences bl where false;
insert into public.businesses_before_214a select b.* from public.businesses b join _stub s on s.stub_id = b.id;
insert into public.business_licences_before_214a select bl.* from public.business_licences bl join _stub s on s.stub_id = bl.business_id;
alter table public.businesses_before_214a enable row level security;
alter table public.business_licences_before_214a enable row level security;
revoke all on public.businesses_before_214a, public.business_licences_before_214a from public, anon, authenticated;
comment on table public.businesses_before_214a is '214a: the 41 stub businesses folded into the business that already held their licence. Never update.';

insert into public.business_slug_redirects (business_id, old_slug) select target_id, stub_slug from _stub;
delete from public.business_licences bl using _stub s where bl.business_id = s.stub_id;
delete from public.businesses b using _stub s where b.id = s.stub_id;

do $$
declare r record; j jsonb; n int;
begin
  for r in select * from _stub loop
    j := public.resolve_business_slug(r.stub_slug);
    if (j->>'redirect')::boolean is distinct from true or j->>'slug' is distinct from r.target_slug then
      raise exception '214a: % does not redirect to %: %', r.stub_slug, r.target_slug, j; end if;
  end loop;
  select count(*) into n from (select c.license_number from public.business_licences bl join public.contractors c on c.id = bl.contractor_id
                                 where c.license_number is not null and c.active is not false group by 1 having count(distinct bl.business_id) > 1) x;
  if n <> 15 then raise exception '214a: % licences still in two businesses, expected the 15 left for a ruling', n; end if;
  if (select count(*) from public.businesses_before_214a) <> 41 then raise exception '214a: before-state incomplete'; end if;
  raise notice '214a: 41 stubs folded with 308s; % licences in more than one business remain for a ruling', n;
end $$;

select public._log_action('cc', 'singleton_stub_businesses_folded', 'businesses',
  (select array_agg(stub_slug) from _stub), (select jsonb_agg(jsonb_build_object('stub', stub_slug, 'target', target_slug)) from _stub), null,
  'Ruling 978: 41 blank-key stub pages duplicated a licence the proper business already shows; folded with permanent redirects.', null);
