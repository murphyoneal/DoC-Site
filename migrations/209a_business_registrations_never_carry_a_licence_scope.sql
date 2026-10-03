-- 209a - a business registration (QB / FRO) is never categorised as a licence scope or a trade it does not hold
-- (ruling 957; cc's lead in 956, wrongly set aside as "only a filter").
--
-- Measured 2026-10-03: 10,125 served QB rows carry doc_category 'general_contractor'; 5,983 of them hold no licence
-- number at all. The profile page renders CATEGORY_LABELS[doc_category] ahead of trade_label ("Construction Business
-- Information"), so 10,125 pages said "General Contractor" under the business name and in the meta description.
-- Under s.489.105 that phrase is a statutory scope, unlimited as to type of work; trade_display_category says "ONLY
-- CGC and RG". trade_display_category's qualifier_business note recorded this defect as 407 rows. The population was
-- never re-measured after that fix.
-- The rest of the QB scatter was measured before moving it, as 957 asked. 283 rows carry a trade (roofing 77,
-- plumbing 60, hvac 48, pool_spa 39, windows_doors 26, then a tail including the one 'electrical'). 280 of the 283
-- belong to businesses holding no other licence; none matches a real licence of that trade except 3. They are trade
-- words read from the business name, not from a licence, so they move too.
-- No other licence-scope mislabel exists on served rows. The only other row whose category disagrees with its trade
-- code is the ZZ test fixture, which is never served.
--   1. trade_code_registry: QB maps to qualifier_business (FRO already does). The registry was the gap: QB had no
--      display_category, so whatever categorised these rows guessed.
--   2. All QB/FRO rows take doc_category 'qualifier_business'. The before-state is kept in a table, so this is
--      reversible.
--   3. A trigger holds it: a row whose trade code the registry maps to qualifier_business can never carry another
--      category. A reload or a re-categoriser cannot bring the scope back.
--   4. Detection licence-scope-category-without-a-granting-licence (blocking, contractors_public). Two sources: the
--      row's category against the registry's category for the row's OWN trade code. Population = served rows carrying
--      a licence-scope category. It was red-run against the before-state inside this migration and found 10,125.
-- Known and not fixed here: 757 businesses whose page record (canonical_contractor_id) is a QB row but which also
-- hold a real licence. After this they read "Business Registration" - understated, not false, and the page lists
-- their licences. Choosing a real licence as the page record changes slugs; it is a separate change.

create table if not exists public.contractors_doc_category_before_209a (
  contractor_id uuid primary key, doc_category text, trade_code text, captured_at timestamptz not null default now());
alter table public.contractors_doc_category_before_209a enable row level security;
revoke all on public.contractors_doc_category_before_209a from public, anon, authenticated;
comment on table public.contractors_doc_category_before_209a is
  '209a: doc_category of every QB/FRO row before it was set to qualifier_business (10,125 general_contractor + 283 trades). Kept so the change is reversible and the red run can replay it.';

insert into public.contractors_doc_category_before_209a (contractor_id, doc_category, trade_code)
select id, doc_category, trade_code from public.contractors
 where trade_code in ('QB','FRO') and doc_category is distinct from 'qualifier_business'
on conflict (contractor_id) do nothing;

do $$
declare n_gc int; n_other int;
begin
  select count(*) filter (where doc_category = 'general_contractor'), count(*) filter (where doc_category <> 'general_contractor')
    into n_gc, n_other from public.contractors_doc_category_before_209a;
  if n_gc <> 10125 then raise exception '209a: expected 10,125 general_contractor QB rows, found %', n_gc; end if;
  raise notice '209a: moving % general_contractor + % other QB/FRO rows', n_gc, n_other;
end $$;

update public.trade_code_registry set display_category = 'qualifier_business' where trade_code = 'QB' and display_category is null;

update public.contractors c set doc_category = 'qualifier_business'
  from public.contractors_doc_category_before_209a b where b.contractor_id = c.id;

create or replace function public.contractors_registration_category()
returns trigger language plpgsql set search_path to 'public', 'pg_temp' as $$
begin
  -- 209a (ruling 957): a business registration is not a licence; its category is fixed by its trade code
  if NEW.trade_code is not null and exists (
       select 1 from public.trade_code_registry tr where tr.trade_code = NEW.trade_code and tr.display_category = 'qualifier_business') then
    NEW.doc_category := 'qualifier_business';
  end if;
  return NEW;
end $$;
comment on function public.contractors_registration_category() is
  '209a (ruling 957): a row whose trade code the registry maps to qualifier_business (QB, FRO) always carries doc_category qualifier_business - never a licence scope (s.489.105) or a trade read from its name.';
drop trigger if exists contractors_registration_category on public.contractors;
create trigger contractors_registration_category before insert or update of trade_code, doc_category on public.contractors
  for each row execute function public.contractors_registration_category();

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('licence-scope-category-without-a-granting-licence',
  'A served row carries a licence-scope category (General Contractor, Building, Residential, Underground Utility, Pollutant Storage, Tank Testing) that its own trade code does not grant - a statutory scope asserted about a named business',
  current_date, 'ruling 957 (10,125 QB business registrations rendered "General Contractor" on their profile pages and meta descriptions)',
  'entity_confusion', 'blocking',
$q$with scoped as (
      select c.id, c.trade_code, c.doc_category, tr.display_category as granted
        from public.contractors_public c
        left join public.trade_code_registry tr on tr.trade_code = c.trade_code
       where c.doc_category in (select category from public.trade_display_category where grouping = 'licence_scope')),
    bad as (select * from scoped where granted is distinct from doc_category)
select not exists (select 1 from bad) as ok,
       (select count(*) from bad) as row_count,
       (select count(*) from scoped) as population$q$,
  'clean', 'served rows carrying a licence-scope category (about 63,000 on 2026-10-03)',
  'Two sources: the row''s category vs the registry''s category for its own trade code. Red-run inside 209a by replaying the before-state: 10,125. The trigger contractors_registration_category should keep this green; dropping it, or a loader writing scope categories by name, turns it red.',
  'active', 'ours',
  'Categorise from the trade code via trade_code_registry; a business registration is qualifier_business; never derive a scope from a name.',
  'contractors_public', 'blocking');

do $$
declare j jsonb; red jsonb; q text;
begin
  select detection_sql into q from public.data_defect_registry where defect_id = 'licence-scope-category-without-a-granting-licence';
  execute format('select to_jsonb(x) from (%s) x', q) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) <= 0 then raise exception '209a: detection not green: %', j; end if;
  -- red run: replay the before-state with the trigger off, measure, and undo it inside a subtransaction
  begin
    alter table public.contractors disable trigger contractors_registration_category;
    update public.contractors c set doc_category = b.doc_category from public.contractors_doc_category_before_209a b where b.contractor_id = c.id;
    execute format('select to_jsonb(x) from (%s) x', q) into red;
    raise exception 'redrun_done';
  exception when raise_exception then
    if sqlerrm <> 'redrun_done' then raise; end if;
  end;
  if (red->>'ok')::boolean is distinct from false or (red->>'row_count')::int <> 10125 then raise exception '209a: red run did not find 10,125: %', red; end if;
  -- the trigger refuses the scope on a registration row
  begin
    update public.contractors set doc_category = 'general_contractor'
     where id = (select contractor_id from public.contractors_doc_category_before_209a limit 1);
    if (select doc_category from public.contractors where id = (select contractor_id from public.contractors_doc_category_before_209a limit 1)) <> 'qualifier_business' then
      raise exception '209a: trigger did not hold the category'; end if;
    raise exception 'trigger_ok';
  exception when raise_exception then
    if sqlerrm <> 'trigger_ok' then raise; end if;
  end;
  if exists (select 1 from public.contractors where trade_code in ('QB','FRO') and doc_category is distinct from 'qualifier_business') then
    raise exception '209a: a registration row still carries another category'; end if;
  raise notice '209a: green %; red run %', j, red;
end $$;

select public._log_action('cc', 'business_registrations_never_carry_a_licence_scope', 'contractors',
  array['contractors.doc_category','trade_code_registry.QB','contractors_registration_category','licence-scope-category-without-a-granting-licence'],
  (select jsonb_object_agg(doc_category, n) from (select doc_category, count(*) n from public.contractors_doc_category_before_209a group by 1) x),
  jsonb_build_object('qualifier_business', (select count(*) from public.contractors_doc_category_before_209a)),
  'Ruling 957: 10,125 business registrations were served as "General Contractor", a statutory scope, on their own pages and meta descriptions.', null);
