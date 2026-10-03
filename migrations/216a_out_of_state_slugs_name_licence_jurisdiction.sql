-- 216a - out-of-state business pages take the slug name + licence number + jurisdiction (Murphy's ruling, relayed
-- 2026-10-03: "/c/123restore-llc-cac044860-fl ... Where there's no truthful place to name, name the thing that
-- identifies the licence.").
--
-- Slugs are <name>-<city>-fl. "fl" is the jurisdiction (every contractors row is a Florida licence - CHECK
-- contractors_is_florida_dbpr_only); the city is the MAILING address. Since 212a restored the file's state, 8,320 served
-- rows carry an address outside Florida, so their URLs name places that do not exist: canton-fl (Georgia),
-- longview-fl (Texas), calabasas-fl (California) - on the URLs a search engine reads as local intent.
-- Murphy rejected the alternatives, measured: dropping the city collides 2,005 of 8,322 rows into counters (-7) that
-- mean nothing; a real state suffix (-ga) asserts a jurisdiction the business holds no licence in. The licence number is
-- unique by construction, the government key, what a visitor verifies with, and no reload can reshuffle it.
-- SCOPE, measured:
--   6,826 business pages whose page record is an out-of-state licence (slug = that row's slug) -> renamed, old slug 308s.
--   Out-of-state rows that are NOT a page's record already resolve only as redirects - left alone.
--   798 out-of-state rows are business registrations: they hold no licence number and the state file carries no
--   identifier for them (licence_serial blank on all 127,447 registrations) - HELD for a ruling, not guessed.
--   The registered test fixture is excluded (the gate and robots.txt name its slug).
--   Florida-address slugs do not change.
-- Slugs are STORED, never regenerated (rebuild_business_register reuses contractors.slug; no loader assigns it), so these
-- stay put across reloads. Before-state kept; every old slug asserted to resolve to its new one; 0 clashes measured.

set statement_timeout = 0;

create temp table _rs on commit drop as
select c.id cid, b.id bid, c.slug old_slug,
       trim(both '-' from regexp_replace(lower(coalesce(nullif(c.display_name,''), c.business_name)), '[^a-z0-9]+', '-', 'g'))
         || '-' || lower(c.license_number) || '-fl' as new_slug
  from public.contractors c
  join public.businesses b on b.canonical_contractor_id = c.id and b.slug = c.slug
 where c.active is not false and c.state is distinct from 'FL' and c.license_number is not null
   and not public.is_test_fixture('contractors', c.license_number);

do $$
declare n int;
begin
  select count(*) into n from _rs;
  if n < 6000 or n > 7000 then raise exception '216a: % targets, expected ~6,825', n; end if;
  if (select count(distinct new_slug) from _rs) <> n then raise exception '216a: new slugs collide among themselves'; end if;
  if exists (select 1 from _rs t where exists (select 1 from public.contractors x where x.slug = t.new_slug and x.id <> t.cid))
     or exists (select 1 from _rs t where exists (select 1 from public.businesses x where x.slug = t.new_slug and x.id <> t.bid))
     or exists (select 1 from _rs t join public.business_slug_redirects r on r.old_slug = t.new_slug) then
    raise exception '216a: a new slug clashes with a live slug or a redirect'; end if;
end $$;

create table if not exists public.slugs_before_216a (contractor_id uuid primary key, business_id uuid, old_slug text, new_slug text, captured_at timestamptz not null default now());
alter table public.slugs_before_216a enable row level security;
revoke all on public.slugs_before_216a from public, anon, authenticated;
insert into public.slugs_before_216a (contractor_id, business_id, old_slug, new_slug) select cid, bid, old_slug, new_slug from _rs on conflict do nothing;

insert into public.business_slug_redirects (business_id, old_slug) select bid, old_slug from _rs;
update public.businesses b set slug = t.new_slug, updated_at = now() from _rs t where b.id = t.bid;
update public.contractors c set slug = t.new_slug, updated_at = now() from _rs t where c.id = t.cid;

do $$
declare r record; j jsonb; bad int := 0;
begin
  for r in select * from _rs loop
    j := public.resolve_business_slug(r.old_slug);
    if (j->>'redirect')::boolean is distinct from true or j->>'slug' is distinct from r.new_slug then bad := bad + 1; end if;
    j := public.resolve_business_slug(r.new_slug);
    if (j->>'redirect')::boolean is distinct from false then bad := bad + 1; end if;
  end loop;
  if bad > 0 then raise exception '216a: % slugs do not resolve as expected', bad; end if;
  if exists (select 1 from public.businesses b join public.contractors c on c.id = b.canonical_contractor_id
              where c.active is not false and c.state is distinct from 'FL' and c.license_number is not null
                and not public.is_test_fixture('contractors', c.license_number)
                and b.slug !~ ('-' || lower(c.license_number) || '-fl$') and b.slug = c.slug) then
    raise exception '216a: an out-of-state licence page kept its city slug'; end if;
  raise notice '216a: % business pages renamed to name-licence-fl; old slugs 308', (select count(*) from _rs);
end $$;

select public._log_action('cc', 'out_of_state_slugs_name_licence_jurisdiction', 'businesses',
  array['businesses.slug','contractors.slug','business_slug_redirects'], jsonb_build_object('before_table', 'slugs_before_216a'),
  (select jsonb_build_object('renamed', count(*)) from _rs),
  'Murphy 2026-10-03: out-of-state addresses named a city with the wrong state in the URL; renamed to name + licence number + jurisdiction.', null);
