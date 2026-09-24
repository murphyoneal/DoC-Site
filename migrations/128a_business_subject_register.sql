-- 128a — The subject of the register becomes a BUSINESS, not a licence (work order 615, section 1).
--
-- ADDITIVE ONLY. contractors keeps one row per DBPR licence record and every existing reader is
-- untouched. This adds a business layer on top of it:
--
--   businesses               the subject; owns the slug
--   business_licences        licence facts attached to a business (member | qualifier)
--   business_slug_redirects  every retired slug -> its business. Never deleted: a printed QR
--                            code we cannot know about must keep resolving.
--   business_name_rulings    names ruled on by hand (placeholder | real_business)
--
-- THE KEY (rulings 2026-09-24, after a dry run refuted name+city+zip):
--   1. name + zip5 + street, all normalised. Street, not city: 3,288 rows named INDIVIDUAL sit
--      at 3,075 distinct addresses — a city key fused them into fake businesses.
--   2. NEVER MERGE: a ruled placeholder name, a blank name/zip/street, or a malformed licence
--      number. Those rows are one business each. The loader defects stay logged, not fixed here.
--   3. QB (Construction Business Information) rows ATTACH their qualifier's licence to the
--      business; they never merge two businesses. A qualifier backing several businesses is
--      normal (CPC057264 backs four) — merging on it would fuse four companies into one.
--      DBPR publishes no QB licence number of its own (all 127,447 QB rows in snapshot 3 carry
--      none), so the qualifier's number is the only link there is.
--   4. department='none' (CRS1/PVDR, continuing-education providers) is not in the register.
--
-- SLUGS: a business keeps an EXISTING slug — its canonical member's, preferring an unsuffixed
-- slug — and never changes it on rebuild. Every other member slug becomes a redirect.
-- No new slug is minted for an existing business and no live URL stops resolving.

create table if not exists public.business_name_rulings (
  name_norm  text primary key,
  ruling     text not null check (ruling in ('placeholder', 'real_business')),
  evidence   text not null,
  ruled_by   text not null,
  ruled_at   timestamptz not null default now()
);

insert into public.business_name_rulings (name_norm, ruling, evidence, ruled_by) values
  ('INDIVIDUAL', 'placeholder',
   'Measured 2026-09-24: 3,288 register rows at 3,075 distinct addresses across 1,274 zips. A sole-trader stand-in, not a business name.',
   'claude ruling 2026-09-24'),
  ('PINCH A PENNY', 'real_business',
   'Measured 2026-09-24: 228 rows at 188 addresses. A franchise brand: two licences at one store address are one business. It is the case that showed a cardinality rule cannot decide alone.',
   'claude ruling 2026-09-24')
on conflict (name_norm) do nothing;

create table if not exists public.businesses (
  id                     uuid primary key default gen_random_uuid(),
  business_key           text not null unique,
  key_basis              text not null check (key_basis in
                           ('name_zip_street', 'singleton_placeholder_name',
                            'singleton_blank_key', 'singleton_malformed_licence')),
  slug                   text not null unique,
  canonical_contractor_id uuid not null references public.contractors(id),
  display_name           text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create table if not exists public.business_licences (
  business_id    uuid not null references public.businesses(id) on delete cascade,
  contractor_id  uuid not null references public.contractors(id),
  link_basis     text not null check (link_basis in ('member', 'qualifier')),
  primary key (business_id, contractor_id)
);
-- A licence record is a MEMBER of exactly one business; it may additionally be attached as a
-- QUALIFIER to others.
create unique index if not exists business_licences_one_home
  on public.business_licences (contractor_id) where link_basis = 'member';
create index if not exists business_licences_contractor on public.business_licences (contractor_id);

create table if not exists public.business_slug_redirects (
  old_slug     text primary key,
  business_id  uuid not null references public.businesses(id),
  created_at   timestamptz not null default now()
);

-- service_role (the app) bypasses RLS; nothing else reads these directly.
alter table public.business_name_rulings   enable row level security;
alter table public.businesses              enable row level security;
alter table public.business_licences       enable row level security;
alter table public.business_slug_redirects enable row level security;

create or replace function public.business_norm(p text)
returns text language sql immutable parallel safe as
$$ select btrim(upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]+', ' ', 'g'))) $$;

-- Rebuild is idempotent: businesses upsert on business_key and never change their slug;
-- redirects are only ever added or re-pointed, never removed; member/qualifier links are
-- recomputed. Safe to run twice (invariant 9).
create or replace function public.rebuild_business_register()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as
$$
declare
  v_rows int; v_businesses int; v_keys int; v_redirects int; v_qual int;
begin
  set local statement_timeout = 0;

  create temp table _reg on commit drop as
  select c.id, c.slug, c.trade_code, c.license_number, c.business_name, c.display_name,
         business_norm(c.business_name)  as nm,
         business_norm(c.address_line_1) as st,
         left(coalesce(c.zip_code, ''), 5) as z,
         (c.license_number is not null and c.license_number !~ '^[A-Z]{2,4}[0-9]{5,8}$') as bad_lic
    from contractors c
    join trade_code_registry r using (trade_code)
   where r.department <> 'none';

  alter table _reg add column key_basis text, add column business_key text;
  update _reg set
    key_basis = case
      when bad_lic then 'singleton_malformed_licence'
      when nm = '' or st = '' or z !~ '^[0-9]{5}$' then 'singleton_blank_key'
      when exists (select 1 from business_name_rulings b where b.name_norm = _reg.nm and b.ruling = 'placeholder')
        then 'singleton_placeholder_name'
      else 'name_zip_street' end;
  update _reg set business_key = case key_basis
      when 'name_zip_street' then 'nzs:' || nm || '|' || z || '|' || st
      else 'lic:' || id::text end;

  -- Canonical member per key: an unsuffixed slug first, then a licence row over a QB row.
  create temp table _canon on commit drop as
  select distinct on (business_key) business_key, key_basis, id, slug, coalesce(display_name, business_name) as dn
    from _reg
   order by business_key, (slug ~ '-[0-9]+$'), (trade_code = 'QB'), length(slug), slug;

  insert into businesses (business_key, key_basis, slug, canonical_contractor_id, display_name)
  select business_key, key_basis, slug, id, dn from _canon
  on conflict (business_key) do update
     set display_name = excluded.display_name, key_basis = excluded.key_basis, updated_at = now();

  delete from business_licences;
  insert into business_licences (business_id, contractor_id, link_basis)
  select b.id, r.id, 'member' from _reg r join businesses b using (business_key);

  -- QB rows attach their qualifier's licence to the QB's business. Never a merge.
  insert into business_licences (business_id, contractor_id, link_basis)
  select distinct bq.business_id, c.id, 'qualifier'
    from _reg q
    join business_licences bq on bq.contractor_id = q.id and bq.link_basis = 'member'
    join _reg c on c.license_number = q.license_number and c.trade_code <> 'QB' and not c.bad_lic
    join business_licences bc on bc.contractor_id = c.id and bc.link_basis = 'member'
   where q.trade_code = 'QB' and q.license_number is not null and not q.bad_lic
     and bc.business_id <> bq.business_id
  on conflict do nothing;

  insert into business_slug_redirects (old_slug, business_id)
  select r.slug, b.id
    from _reg r join businesses b using (business_key)
   where r.slug <> b.slug
  on conflict (old_slug) do update set business_id = excluded.business_id;

  select count(*) into v_rows from _reg;
  select count(*), count(distinct business_key) into v_businesses, v_keys from businesses;
  select count(*) into v_redirects from business_slug_redirects;
  select count(*) into v_qual from business_licences where link_basis = 'qualifier';

  -- empty != done: refuse to report success on an empty or inconsistent build.
  if v_rows = 0 or v_businesses = 0 then
    raise exception 'rebuild_business_register: empty build (rows %, businesses %)', v_rows, v_businesses;
  end if;
  if v_businesses <> v_keys then
    raise exception 'rebuild_business_register: % businesses but % distinct keys', v_businesses, v_keys;
  end if;

  return jsonb_build_object('register_rows', v_rows, 'businesses', v_businesses,
                            'redirects', v_redirects, 'qualifier_links', v_qual);
end
$$;

-- Served path. The app resolves every /c/{slug} through this, so a retired slug redirects.
-- Returns null when the slug is not in the register (the caller then 404s as before).
create or replace function public.resolve_business_slug(p_slug text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as
$$
  select coalesce(
    (select jsonb_build_object('slug', b.slug, 'business_id', b.id, 'redirect', false)
       from businesses b where b.slug = p_slug),
    (select jsonb_build_object('slug', b.slug, 'business_id', b.id, 'redirect', true)
       from business_slug_redirects r join businesses b on b.id = r.business_id
      where r.old_slug = p_slug))
$$;

-- Every licence attached to a business, for the profile. "member" = a licence record of this
-- business; "qualifier" = the licence DBPR names as qualifying it.
create or replace function public.get_business_licences(p_slug text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as
$$
  select coalesce(jsonb_agg(jsonb_build_object(
           'license_number', c.license_number, 'trade_code', c.trade_code,
           'trade_label', coalesce(t.official_label, c.trade_label),
           'license_status', c.license_status, 'expiry_date', c.expiry_date,
           'holder_name', coalesce(c.display_name, c.business_name),
           'link_basis', bl.link_basis)
         order by bl.link_basis, c.trade_code, c.license_number), '[]'::jsonb)
    from businesses b
    join business_licences bl on bl.business_id = b.id
    join contractors c on c.id = bl.contractor_id
    left join trade_code_registry t on t.trade_code = c.trade_code
   where b.slug = p_slug and c.trade_code <> 'QB'
$$;

revoke all on function public.rebuild_business_register()   from public, anon, authenticated;
revoke all on function public.resolve_business_slug(text)   from public, anon, authenticated;
revoke all on function public.get_business_licences(text)   from public, anon, authenticated;
grant execute on function public.resolve_business_slug(text) to service_role;
grant execute on function public.get_business_licences(text) to service_role;
grant execute on function public.rebuild_business_register() to service_role;

select public.rebuild_business_register();
