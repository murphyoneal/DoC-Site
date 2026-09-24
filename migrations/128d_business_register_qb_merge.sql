-- 128d — Business register v2: merge on DBPR's one-to-one QB link, and correct the licence shape.
--
-- 1. QB MERGE (ruling 2026-09-24). A QB (Construction Business Information) row and its
--    qualifier's licence row are ONE business when the link is one-to-one on both sides AND the
--    normalised names match. DBPR's own link is better evidence than an address string:
--    JACK JOYNER was two businesses over "1860 N. HERCULES AVENUE" vs "1860 HERCULES AVENUE".
--    One-to-many links never merge — CPC057264 qualifies four separate PINCH A PENNY stores.
--    Rows that must never merge (placeholder name, blank key, malformed licence) still don't.
--
-- 2. LICENCE SHAPE CORRECTED. 128a treated '^[A-Z]{2,4}[0-9]{5,8}$' as well-formed and flagged
--    4,757 rows malformed. 4,311 of those numbers appear verbatim in DBPR's own published file
--    (dbpr_construction_snapshot, snapshot 3): 9-digit specialty (SCC131149543), 9-digit
--    registered (RG/RP/RR) and short historical (CGC4809, FRO103) numbers are DBPR's formats.
--    Genuinely malformed: 8 rows ('74' x7, column-shifted; 'CGC0B7622' x1).
--
-- 3. KEY CHANGES ARE NOW SAFE. A merge makes a business key vanish. The rebuild re-points that
--    business's redirects to the business now holding its canonical licence record, turns its
--    slug into a redirect, and deletes it. No slug stops resolving.

create or replace function public.rebuild_business_register()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as
$$
declare
  v_rows int; v_businesses int; v_keys int; v_redirects int; v_qual int;
  v_edges int; v_stale int; v_changed int;
begin
  set local statement_timeout = 0;

  create temp table _reg on commit drop as
  select c.id, c.slug, c.trade_code, c.license_number, c.business_name, c.display_name,
         business_norm(c.business_name)  as nm,
         business_norm(c.address_line_1) as st,
         left(coalesce(c.zip_code, ''), 5) as z,
         (c.license_number is not null and c.license_number !~ '^[A-Z]{2,4}[0-9]+$') as bad_lic
    from contractors c
    join trade_code_registry r using (trade_code)
   where r.department <> 'none';

  alter table _reg add column key_basis text, add column base_key text, add column business_key text;
  update _reg set
    key_basis = case
      when bad_lic then 'singleton_malformed_licence'
      when nm = '' or st = '' or z !~ '^[0-9]{5}$' then 'singleton_blank_key'
      when exists (select 1 from business_name_rulings b where b.name_norm = _reg.nm and b.ruling = 'placeholder')
        then 'singleton_placeholder_name'
      else 'name_zip_street' end;
  update _reg set base_key = case key_basis
      when 'name_zip_street' then 'nzs:' || nm || '|' || z || '|' || st
      else 'lic:' || id::text end;

  -- Temp tables carry no statistics; without these the QB self-join plans as a nested loop over
  -- 114k rows and never finishes.
  create index on _reg (license_number);
  create index on _reg (base_key);
  analyze _reg;

  -- QB merge edges: one QB and one licence record share the number, names match, both mergeable.
  create temp table _lc on commit drop as
  select license_number,
         count(*) filter (where trade_code = 'QB')  as nqb,
         count(*) filter (where trade_code <> 'QB') as nlic
    from _reg where license_number is not null and not bad_lic group by 1;
  analyze _lc;

  create temp table _edge on commit drop as
  select q.base_key as a, c.base_key as b
    from _reg q
    join _lc l on l.license_number = q.license_number and l.nqb = 1 and l.nlic = 1
    join _reg c on c.license_number = q.license_number and c.trade_code <> 'QB'
   where q.trade_code = 'QB'
     and q.key_basis = 'name_zip_street' and c.key_basis = 'name_zip_street'
     and q.nm = c.nm and q.base_key <> c.base_key;
  get diagnostics v_edges = row_count;

  -- Connected components over the edges (label propagation to the least key).
  create temp table _comp on commit drop as select distinct base_key as k, base_key as comp from _reg;
  create index on _comp (k);
  analyze _comp;
  analyze _edge;
  loop
    update _comp t set comp = s.m
      from (select e.k, min(x.comp) as m
              from (select a as k, b as o from _edge union all select b, a from _edge) e
              join _comp x on x.k = e.o
             group by e.k) s
     where t.k = s.k and s.m < t.comp;
    get diagnostics v_changed = row_count;
    exit when v_changed = 0;
  end loop;

  -- A component takes the key of the group holding its best canonical row, so the business that
  -- already owns the preferred (unsuffixed) slug survives and the other becomes a redirect.
  update _reg r set business_key = x.base_key
    from _comp c
    join (select distinct on (c2.comp) c2.comp, r2.base_key
            from _reg r2 join _comp c2 on c2.k = r2.base_key
           order by c2.comp, (r2.slug ~ '-[0-9]+$'), (r2.trade_code = 'QB'), length(r2.slug), r2.slug) x
      on x.comp = c.comp
   where c.k = r.base_key;

  create temp table _canon on commit drop as
  select distinct on (business_key) business_key, key_basis, id, slug, coalesce(display_name, business_name) as dn
    from _reg
   order by business_key, (slug ~ '-[0-9]+$'), (trade_code = 'QB'), length(slug), slug;
  create index on _canon (business_key);
  create index on _canon (slug);
  analyze _reg;
  analyze _canon;

  -- A business whose key changed but whose slug is still its canonical's keeps its id.
  update businesses b set business_key = c.business_key, updated_at = now()
    from _canon c
   where b.slug = c.slug and b.business_key <> c.business_key
     and not exists (select 1 from _canon c2 where c2.business_key = b.business_key)
     and not exists (select 1 from businesses b2 where b2.business_key = c.business_key);

  insert into businesses (business_key, key_basis, slug, canonical_contractor_id, display_name)
  select business_key, key_basis, slug, id, dn from _canon
  on conflict (business_key) do update
     set display_name = excluded.display_name, key_basis = excluded.key_basis,
         canonical_contractor_id = excluded.canonical_contractor_id, updated_at = now();

  delete from business_licences;
  insert into business_licences (business_id, contractor_id, link_basis)
  select b.id, r.id, 'member' from _reg r join businesses b using (business_key);

  insert into business_licences (business_id, contractor_id, link_basis)
  select distinct bq.business_id, c.id, 'qualifier'
    from _reg q
    join business_licences bq on bq.contractor_id = q.id and bq.link_basis = 'member'
    join _reg c on c.license_number = q.license_number and c.trade_code <> 'QB' and not c.bad_lic
    join business_licences bc on bc.contractor_id = c.id and bc.link_basis = 'member'
   where q.trade_code = 'QB' and q.license_number is not null and not q.bad_lic
     and bc.business_id <> bq.business_id
  on conflict do nothing;

  -- Every register slug that is not its business's slug redirects to it. Upsert re-points
  -- existing redirects, including a merged-away business's own slug.
  insert into business_slug_redirects (old_slug, business_id)
  select r.slug, b.id
    from _reg r join businesses b using (business_key)
   where r.slug <> b.slug
  on conflict (old_slug) do update set business_id = excluded.business_id;

  -- Stale businesses (key vanished): re-point anything still aimed at them, then delete.
  create temp table _stale on commit drop as
  select b.id, b.canonical_contractor_id from businesses b
   where not exists (select 1 from _canon c where c.business_key = b.business_key);
  update business_slug_redirects r set business_id = bl.business_id
    from _stale s join business_licences bl on bl.contractor_id = s.canonical_contractor_id and bl.link_basis = 'member'
   where r.business_id = s.id;
  delete from businesses b using _stale s
   where b.id = s.id and not exists (select 1 from business_slug_redirects r where r.business_id = s.id);
  get diagnostics v_stale = row_count;
  if exists (select 1 from businesses b join _stale s on s.id = b.id) then
    raise exception 'rebuild_business_register: a stale business is still referenced and has no home to re-point to';
  end if;

  select count(*) into v_rows from _reg;
  select count(*), count(distinct business_key) into v_businesses, v_keys from businesses;
  select count(*) into v_redirects from business_slug_redirects;
  select count(*) into v_qual from business_licences where link_basis = 'qualifier';

  if v_rows = 0 or v_businesses = 0 then
    raise exception 'rebuild_business_register: empty build (rows %, businesses %)', v_rows, v_businesses;
  end if;
  if v_businesses <> v_keys then
    raise exception 'rebuild_business_register: % businesses but % distinct keys', v_businesses, v_keys;
  end if;

  return jsonb_build_object('register_rows', v_rows, 'businesses', v_businesses,
                            'redirects', v_redirects, 'qualifier_links', v_qual,
                            'qb_merge_edges', v_edges, 'stale_businesses_retired', v_stale);
end
$$;

revoke all on function public.rebuild_business_register() from public, anon, authenticated;
grant execute on function public.rebuild_business_register() to service_role;

select public.rebuild_business_register();

-- The integrity detection gains the QB-merge founding case and its negative: JACK JOYNER's QB
-- slug now redirects to the licence slug, and two PINCH A PENNY stores sharing CPC057264 stay
-- two businesses.
update public.data_defect_registry
   set detection_sql = replace(detection_sql,
         $o$    and jsonb_array_length(public.get_business_licences('red-stag-contracting-inc-jacksonville-fl')) = 2
  ) as ok$o$,
         $n$    and jsonb_array_length(public.get_business_licences('red-stag-contracting-inc-jacksonville-fl')) = 2
    and (public.resolve_business_slug('jack-joyner-heating-ac-company-clearwater-fl-2')->>'slug') = 'jack-joyner-heating-ac-company-clearwater-fl'
    and (select count(distinct bl.business_id) from public.business_licences bl
           join public.contractors c on c.id = bl.contractor_id
          where c.license_number = 'CPC057264' and c.trade_code = 'QB' and bl.link_basis = 'member') = 4
  ) as ok$n$)
 where defect_id = 'business-register-integrity'
   and detection_sql like '%get_business_licences(''red-stag-contracting-inc-jacksonville-fl'')) = 2%';
