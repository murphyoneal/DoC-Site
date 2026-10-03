-- 216b - out-of-state business REGISTRATIONS drop the city from their slug (ruling 998).
--
-- 216a gave out-of-state licence pages name + licence number + jurisdiction. 797 out-of-state rows are business
-- registrations (trade QB, record_kind business_registration): no licence number, and the state file carries no
-- identifier for them (licence_serial blank on all 127,447 registrations). Claude measured no qualifying-licence link
-- either (0 carry personnel_names, rmi_name or licensee_name). Leaving them keeps the defect: 149-edison-street-inc-
-- williamsville-fl labels a New York town as Florida.
-- Ruled shape: name + jurisdiction - /c/149-edison-street-inc-fl. 795 of 797 are unique on it with 0 clashes; a name
-- that collides takes a STORED counter (-2, -3...). Counters are safe because slugs are persisted and never regenerated
-- (rebuild_business_register reuses contractors.slug; nothing else assigns it - verified 2026-10-03).
-- Scope: rows that are their business page's record (business slug = row slug) - 598 of the 797; the other 199 are
-- members whose slugs already resolve only as redirects, as in 216a. Same redirect and snapshot treatment as
-- 216a; the registered fixture is excluded.

set statement_timeout = 0;

create temp table _rr on commit drop as
select c.id cid, b.id bid, c.slug old_slug,
       trim(both '-' from regexp_replace(lower(coalesce(nullif(c.display_name,''), c.business_name)), '[^a-z0-9]+', '-', 'g')) || '-fl' as base
  from public.contractors c
  join public.businesses b on b.canonical_contractor_id = c.id and b.slug = c.slug
 where c.active is not false and c.state is distinct from 'FL' and c.license_number is null
   and c.record_kind = 'business_registration'
   and not public.is_test_fixture('contractors', c.license_number);
alter table _rr add column new_slug text;

do $$
declare r record; cand text; k int; n int;
begin
  select count(*) into n from _rr;
  -- of the 797 out-of-state registrations, 598 are their business page's record (measured on the first, rolled-back
  -- attempt); the other 199 are member rows whose slugs already resolve only as redirects to their business page.
  if n <> 598 then raise exception '216b: % targets, expected 598', n; end if;
  for r in select * from _rr order by base, old_slug loop
    cand := r.base; k := 1;
    while exists (select 1 from public.businesses where slug = cand and id <> r.bid)
       or exists (select 1 from public.contractors where slug = cand and id <> r.cid)
       or exists (select 1 from public.business_slug_redirects where old_slug = cand)
       or exists (select 1 from _rr where new_slug = cand) loop
      k := k + 1; cand := r.base || '-' || k;
    end loop;
    update _rr set new_slug = cand where cid = r.cid;
  end loop;
  if exists (select 1 from _rr where new_slug is null) or (select count(distinct new_slug) from _rr) <> n then raise exception '216b: unresolved or duplicate slugs'; end if;
  raise notice '216b: % targets, % took a counter', n, (select count(*) from _rr where new_slug <> base);
end $$;

insert into public.slugs_before_216a (contractor_id, business_id, old_slug, new_slug) select cid, bid, old_slug, new_slug from _rr on conflict do nothing;
insert into public.business_slug_redirects (business_id, old_slug) select bid, old_slug from _rr;
update public.businesses b set slug = t.new_slug, updated_at = now() from _rr t where b.id = t.bid;
update public.contractors c set slug = t.new_slug, updated_at = now() from _rr t where c.id = t.cid;

do $$
declare r record; j jsonb; bad int := 0;
begin
  for r in select * from _rr loop
    j := public.resolve_business_slug(r.old_slug);
    if (j->>'redirect')::boolean is distinct from true or j->>'slug' is distinct from r.new_slug then bad := bad + 1; end if;
  end loop;
  if bad > 0 then raise exception '216b: % old slugs do not resolve to their new one', bad; end if;
  if (select count(*) from public.contractors) <> (select count(distinct slug) from public.contractors) then raise exception '216b: contractor slugs not unique'; end if;
  raise notice '216b: done; e.g. %', (select old_slug || ' -> ' || new_slug from _rr where old_slug like '149-edison%' limit 1);
end $$;

select public._log_action('cc', 'out_of_state_registration_slugs_drop_city', 'businesses',
  array['businesses.slug','contractors.slug','business_slug_redirects'], jsonb_build_object('before_table', 'slugs_before_216a'),
  (select jsonb_build_object('renamed', count(*), 'with_counter', count(*) filter (where new_slug <> base)) from _rr),
  'Ruling 998: out-of-state registrations have no licence number or state identifier; the city named a non-Florida town as Florida, so it is dropped.', null);
