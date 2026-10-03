-- 208b - a register placeholder is never served as a company name (rulings 943, 944, 946, 947; Murphy 947).
--
-- Both state licence files put INDIVIDUAL (five spellings, name_placeholder_registry) in the business-name field when
-- the licence is held by a natural person. We served it as the name: a company called INDIVIDUAL holds the licence.
-- Measured 2026-10-03:
--   construction  3,288 rows, all served (contractors_public). business_name, display_name AND businesses.display_name
--                 all hold the placeholder; slugs are individual-<city>-fl[-n].
--                 2,766 are in the latest DBPR file, and dbpr_construction_snapshot.full_name holds the licensee (our
--                 loader dropped it). 522 are absent from the latest file, with no name in any file we hold.
--   electrical    335 rows; dba_name holds the placeholder, licensee_name is present on all 335.
-- Murphy (947): "Name on the page if the licence is held by a individual and name if held by a company. It is a state
-- record." / "Name in the URL." So:
--   1. contractors.licensee_name holds the name as the state publishes it ("TUBB, DENNIS G"), taken from the snapshot by
--      licence number. display_name (contractors and businesses) becomes that name.
--      business_name keeps the value as published - the record is not rewritten; only the display is.
--   2. The 522: display_name 'Licence held by an individual (name not in the file we hold)', display_name_basis
--      'no_name_in_file_held'. An absence statement, never an invented name, never INDIVIDUAL standing as a company.
--   3. Slugs for the 2,766 become <name>-<city>-fl[-n], built like the existing 114,000. The old slug goes into
--      business_slug_redirects, so every saved link 308s (resolve_business_slug, already deployed).
--      The 522 keep individual-<city>-fl: no name exists to put there, and "individual" is now what the page says.
--      Nothing else references these slugs: 0 scans, claims, registrations or duplicate lists (measured).
--   4. Electrical: register_search and get_eclb_entry treat a placeholder dba_name as no business name, so the licensee
--      is the name. The as-published value stays in get_eclb_entry as business_name_as_published.
-- register_search is a browser RPC: replacing it revokes its anon grant (secdef guard), so it is re-granted and asserted
-- against the browser_rpc allowlist.

alter table public.contractors add column if not exists licensee_name text;
alter table public.contractors add column if not exists display_name_basis text;
alter table public.contractors drop constraint if exists contractors_display_name_basis_ck;
alter table public.contractors add constraint contractors_display_name_basis_ck
  check (display_name_basis is null or display_name_basis in ('licensee_name_from_register','no_name_in_file_held'));
comment on column public.contractors.licensee_name is
  '208b: the licensee as the state file publishes it (DBPR full_name), carried where business_name is a register placeholder (name_placeholder_registry). NULL elsewhere - not measured, not asserted.';
comment on column public.contractors.display_name_basis is
  '208b: why display_name differs from business_name. licensee_name_from_register = the placeholder was replaced by the published licensee; no_name_in_file_held = absent from the latest file, no name in any file we hold, display states that.';

create temp table _ph on commit drop as
select c.id, c.license_number, c.slug as old_slug, c.city, b.id as bid,
       (select nullif(btrim(s.full_name), '') from public.dbpr_construction_snapshot s
         where s.license_number = c.license_number order by s.snapshot_id desc limit 1) as full_name
  from public.contractors c join public.businesses b on b.canonical_contractor_id = c.id
 where public.is_name_placeholder(c.business_name);

do $$
declare n_all int; n_named int; n_unnamed int;
begin
  select count(*), count(full_name), count(*) - count(full_name) into n_all, n_named, n_unnamed from _ph;
  if n_all <> 3288 or n_named <> 2766 or n_unnamed <> 522 then
    raise exception '208b: population moved: % rows, % named, % unnamed (expected 3288/2766/522)', n_all, n_named, n_unnamed; end if;
  if exists (select 1 from _ph p join public.contractors c on c.id = p.id where p.full_name is null and c.register_file_state is distinct from 'absent_from_latest_file') then
    raise exception '208b: an unnamed row is in the latest file - its name should exist'; end if;
end $$;

-- 1 + 2: names
update public.contractors c set licensee_name = p.full_name, display_name = p.full_name, display_name_basis = 'licensee_name_from_register'
  from _ph p where p.id = c.id and p.full_name is not null;
update public.contractors c set display_name = 'Licence held by an individual (name not in the file we hold)', display_name_basis = 'no_name_in_file_held'
  from _ph p where p.id = c.id and p.full_name is null;
update public.businesses b set display_name = c.display_name, updated_at = now()
  from _ph p join public.contractors c on c.id = p.id where b.id = p.bid;

-- 3: slugs for the named, unique against live slugs AND retired ones, old slug kept as a permanent redirect
do $$
declare r record; base text; cand text; k int; n int := 0;
begin
  for r in select * from _ph where full_name is not null order by license_number loop
    base := trim(both '-' from regexp_replace(lower(r.full_name || ' ' || coalesce(r.city, '') || ' fl'), '[^a-z0-9]+', '-', 'g'));
    cand := base; k := 1;
    while exists (select 1 from public.businesses where slug = cand and id <> r.bid)
       or exists (select 1 from public.contractors where slug = cand and id <> r.id)
       or exists (select 1 from public.business_slug_redirects where old_slug = cand) loop
      k := k + 1; cand := base || '-' || k;
    end loop;
    insert into public.business_slug_redirects (business_id, old_slug) values (r.bid, r.old_slug);
    update public.businesses set slug = cand where id = r.bid;
    update public.contractors set slug = cand where id = r.id;
    n := n + 1;
  end loop;
  if n <> 2766 then raise exception '208b: renamed % slugs, expected 2766', n; end if;
end $$;

-- 4: electrical - a placeholder dba_name is not a business name
do $$
declare d text; a1 text; a2 text; n int;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.register_search(text,integer)'::regprocedure;
  d := pg_get_functiondef('public.register_search(text,integer)'::regprocedure);
  n := (length(d) - length(replace(d, $a$coalesce(nullif(e.dba_name, ''), e.licensee_name) as nm$a$, ''))) / length($a$coalesce(nullif(e.dba_name, ''), e.licensee_name) as nm$a$);
  if n <> 1 then raise exception '208b: register_search nm anchor count %', n; end if;
  d := replace(d, $a$coalesce(nullif(e.dba_name, ''), e.licensee_name) as nm$a$,
    $a$coalesce(case when public.is_name_placeholder(e.dba_name) then null else nullif(e.dba_name, '') end, e.licensee_name) as nm$a$);
  n := (length(d) - length(replace(d, $a$'licensee', case when nullif(dba_name, '') is not null then licensee_name end,$a$, ''))) / length($a$'licensee', case when nullif(dba_name, '') is not null then licensee_name end,$a$);
  if n <> 1 then raise exception '208b: register_search licensee anchor count %', n; end if;
  d := replace(d, $a$'licensee', case when nullif(dba_name, '') is not null then licensee_name end,$a$,
    $a$'licensee', case when nullif(dba_name, '') is not null and not public.is_name_placeholder(dba_name) then licensee_name end,$a$);
  execute d;
  -- the secdef guard revokes anon on replace; the allowlist says register_search is browser-callable
  grant execute on function public.register_search(text,integer) to anon, authenticated;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.register_search(text,integer)'::regprocedure;
  if a2 is distinct from a1 then raise exception '208b: register_search grants % -> %', a1, a2; end if;

  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_eclb_entry(text)'::regprocedure;
  d := pg_get_functiondef('public.get_eclb_entry(text)'::regprocedure);
  if position($a$'business_name', nullif(l.dba_name, ''),$a$ in d) = 0 then raise exception '208b: get_eclb_entry anchor missing'; end if;
  d := replace(d, $a$'business_name', nullif(l.dba_name, ''),$a$,
    $a$'business_name', case when public.is_name_placeholder(l.dba_name) then null else nullif(l.dba_name, '') end,
      'business_name_as_published', nullif(l.dba_name, ''),
      'business_name_status', case when public.is_name_placeholder(l.dba_name) then 'none_recorded' when nullif(l.dba_name, '') is null then 'none_recorded' else 'present' end,$a$);
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.get_eclb_entry(text) to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.get_eclb_entry(text) to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_eclb_entry(text)'::regprocedure;
  if a2 is distinct from a1 then raise exception '208b: get_eclb_entry grants % -> %', a1, a2; end if;
end $$;

do $$
declare j jsonb; e jsonb; r record; nm text; lic text;
begin
  -- nothing served carries a placeholder as a name: the view, both businesses' display, the searches, the entry page
  if exists (select 1 from public.contractors_public where public.is_name_placeholder(display_name)) then raise exception '208b: contractors_public display_name still a placeholder'; end if;
  if exists (select 1 from public.businesses where public.is_name_placeholder(display_name)) then raise exception '208b: businesses.display_name still a placeholder'; end if;
  if exists (select 1 from jsonb_array_elements(public.register_search('individual', 50)->'results') x where public.is_name_placeholder(x->>'name')) then
    raise exception '208b: register_search still serves a placeholder name'; end if;
  if exists (select 1 from jsonb_array_elements(public.contractor_register_search('individual', 50)->'results') x where public.is_name_placeholder(x->>'name')) then
    raise exception '208b: contractor_register_search still serves a placeholder name'; end if;
  select license_number into lic from reg_us_fl.eclb_licence where public.is_name_placeholder(dba_name) and record_kind = 'licence' limit 1;
  e := public.get_eclb_entry(lic);
  if e->>'business_name' is not null or e->>'business_name_status' <> 'none_recorded' or e->>'licensee_name' is null then raise exception '208b: get_eclb_entry %: %', lic, e; end if;
  -- every old slug resolves to its business's new slug, and the restored name is findable by search
  for r in select p.old_slug, b.slug new_slug, p.full_name from _ph p join public.businesses b on b.id = p.bid where p.full_name is not null limit 25 loop
    j := public.resolve_business_slug(r.old_slug);
    if (j->>'redirect')::boolean is distinct from true or j->>'slug' <> r.new_slug then raise exception '208b: % does not redirect to %: %', r.old_slug, r.new_slug, j; end if;
  end loop;
  select full_name into nm from _ph where full_name is not null order by license_number limit 1;
  if not exists (select 1 from jsonb_array_elements(public.contractor_register_search(split_part(nm, ',', 1) || ' ' || split_part(btrim(split_part(nm, ',', 2)), ' ', 1), 50)->'results') x where x->>'name' = nm) then
    raise exception '208b: restored name % is not findable', nm; end if;
  if not has_function_privilege('anon', 'public.register_search(text,integer)', 'EXECUTE') then raise exception '208b: register_search lost anon'; end if;
end $$;

select public._log_action('cc', 'name_placeholder_served_as_licensee', 'contractors',
  array['contractors.display_name','businesses.display_name','businesses.slug','contractors.slug','business_slug_redirects','register_search','get_eclb_entry'],
  jsonb_build_object('construction_placeholder_display', 3288, 'electrical_placeholder_name', 335, 'individual_slugs', 3288),
  jsonb_build_object('licensee_named', 2766, 'stated_no_name', 522, 'slugs_renamed_with_308', 2766, 'electrical_licensee_shown', 335),
  'Murphy 947 / claude 946: the register placeholder INDIVIDUAL was served as a company name; the state-published licensee name is shown, in the page and the slug.', null);
