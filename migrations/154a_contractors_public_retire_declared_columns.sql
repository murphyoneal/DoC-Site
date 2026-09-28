-- 154a: contractors_public stops serving business-declared columns from the register copy (ruling 744, step 2).
--
-- contractors is the Florida DBPR register copy. It also carried ~40 columns only a BUSINESS could
-- state (description, photos, capability and emergency claims, service area, bond/insurance) or
-- that read as a claim about one (contact). None is a DBPR field; none has a writer; every one is
-- 0-filled on all 114,008 public rows - except work_photos, which carries DEFAULT '{}' on every
-- row: an empty array asserting "no photos of their work" about every licensee. The business's own
-- statements live in business_profile and render under "From the business". Step 1 (#80) removed
-- the only render paths. This rebuilds the view without the set; step 3 (154b) drops the columns.
--
-- NOT in scope (ruling 744): verified, tier, profile_tier_label - ours, parked for a render ruling.
-- Kept: trading_name (DBPR's DBA), rmi_name, lbp_* (register fields).
--
-- A view cannot lose columns via CREATE OR REPLACE, so DROP + CREATE. work_gallery_public depends on
-- it and is recreated verbatim. Both views' ACLs are captured before the drop and replayed after,
-- then asserted equal - anon SELECT on contractors_public is the public search. Search and finder
-- results are asserted against baselines measured on 2026-09-28 before this migration.

create temp table _acl on commit drop as
  select c.relname, a.grantee::regrole::text as grantee, a.privilege_type
    from pg_class c, aclexplode(c.relacl) a
   where c.relnamespace = 'public'::regnamespace and c.relname in ('contractors_public', 'work_gallery_public');

create temp table _cmt on commit drop as
  select relname, obj_description(oid) as cmt from pg_class
   where relnamespace = 'public'::regnamespace and relname in ('contractors_public', 'work_gallery_public');

do $m$ begin
  if (select count(*) from public.contractors_public) <> 114008 then
    raise exception '154a: contractors_public is not 114,008 rows before the rebuild; re-measure the baselines'; end if;
end $m$;

drop view public.work_gallery_public;
drop view public.contractors_public;

create view public.contractors_public as
 SELECT id,
    slug,
    business_name,
    trading_name,
    display_name,
    trade_code,
    trade_label,
    doc_category,
    classifications,
    license_number,
    license_status,
    primary_status,
    secondary_status,
    original_date,
    effective_date,
    expiry_date,
    NULL::text AS address_line_1,
    NULL::text AS address_line_2,
    city,
    state,
    zip_code,
    county_code,
    county_name,
    country,
    in_volusia,
    rmi_name,
    license_endorsement,
    tier,
    verified,
    verified_at,
    contractor_is_claimed(id) AS claimed,
    active,
    profile_tier_label,
    lbp_number,
    lbp_classes,
    lbp_status,
    lbp_expiry,
    source,
    source_url,
    source_state,
    created_at,
    updated_at,
    geocoded,
    round(lat, 2)::numeric(10,7) AS lat,
    round(lng, 2)::numeric(10,7) AS lng,
    country_code,
    geocode_quality,
    register_file_date,
    register_file_state
   FROM contractors
  WHERE active IS TRUE AND NOT (EXISTS ( SELECT 1
           FROM trade_code_registry tr
          WHERE tr.trade_code = contractors.trade_code AND tr.department = 'none'::text));

create view public.work_gallery_public as
 SELECT c.id,
    c.contractor_id,
    ct.slug AS contractor_slug,
    ct.display_name AS contractor_name,
    r.department,
    r.display_category,
    c.description,
    c.work_date,
    c.assertion_state,
    c.location_state,
    i.public_path,
    i.width,
    i.height,
    c.created_at
   FROM work_contribution c
     JOIN contractors_public ct ON ct.id = c.contractor_id
     LEFT JOIN trade_code_registry r ON r.trade_code = ct.trade_code
     JOIN work_contribution_image i ON i.contribution_id = c.id
  WHERE c.visibility = 'public'::text AND i.exif_stripped_at IS NOT NULL;

-- replay the captured ACLs exactly (revoke first so default privileges cannot widen them)
do $m$ declare r record; begin
  revoke all on public.contractors_public, public.work_gallery_public from anon, authenticated;
  for r in select * from _acl loop
    execute format('grant %s on public.%I to %s', r.privilege_type, r.relname,
                   case when r.grantee = '-' then 'public' else quote_ident(r.grantee) end);
  end loop;
end $m$;

comment on view public.contractors_public is
  'PII-reduced public projection of contractors - the Florida DBPR register copy: active rows only, register fields only, minus every row whose trade_code maps to department=none in trade_code_registry (today CRS1 and PVDR - 97 continuing-education providers). Business-declared columns (description, photos, capability/emergency claims, service area, bond/insurance, contact) are NOT served here: they are the business''s statements, not the register''s, and live in business_profile (154a, ruling 744). Public-facing consumers read THIS view, never the contractors table.';
do $m$ begin
  execute format('comment on view public.work_gallery_public is %L', (select cmt from _cmt where relname = 'work_gallery_public'));
end $m$;

-- assertions: nothing lost, nothing widened, search and finder unchanged
do $m$
declare v_diff int; f jsonb; s jsonb;
begin
  if (select count(*) from public.contractors_public) <> 114008 then
    raise exception '154a: contractors_public row count changed'; end if;
  select count(*) into v_diff from (
    (select relname, grantee, privilege_type from _acl
     except
     select c.relname, a.grantee::regrole::text, a.privilege_type from pg_class c, aclexplode(c.relacl) a
      where c.relnamespace = 'public'::regnamespace and c.relname in ('contractors_public', 'work_gallery_public'))
    union all
    (select c.relname, a.grantee::regrole::text, a.privilege_type from pg_class c, aclexplode(c.relacl) a
      where c.relnamespace = 'public'::regnamespace and c.relname in ('contractors_public', 'work_gallery_public')
     except
     select relname, grantee, privilege_type from _acl)) d;
  if v_diff <> 0 then raise exception '154a: view ACLs differ from before the rebuild (% entries)', v_diff; end if;
  if not has_table_privilege('anon', 'public.contractors_public', 'select') then
    raise exception '154a: anon lost SELECT on contractors_public'; end if;
  if has_table_privilege('anon', 'public.work_gallery_public', 'select') then
    raise exception '154a: anon gained SELECT on work_gallery_public'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'execute') then
    raise exception '154a: anon lost EXECUTE on contractor_register_search'; end if;
  f := public.contractor_finder(null, 'Volusia', null, 5, 0);
  if (f->>'count')::int <> 3288 then raise exception '154a: finder Volusia count % <> 3288', f->>'count'; end if;
  s := public.contractor_register_search('smith', 5);
  if (s->>'count')::int <> 277 then raise exception '154a: register search smith count % <> 277', s->>'count'; end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'contractors_public'
              and column_name in ('service_categories', 'description', 'phone', 'email', 'website', 'work_photos', 'emergency_available', 'insurance_company')) then
    raise exception '154a: a retired column is still served'; end if;
end $m$;
