-- 199b - Roz's area tool: the flood count names its test and carries three numbers (ruling 922); it returns inside Roz's
-- 8 s limit.
--
-- 1. FLOOD (922 item 4: "any part of the parcel, above the measured floor, and the statement names its test").
--    Per zone, independently (a parcel touching AE and X counts in both):
--      some_part_within = wholly_within + partly_within      <- the headline, with `statement` naming the test
--      boundary_disagreement_under_3ft                       <- overlap strip < 3 ft (the floor measured for 195b)
--      centroid_in_zone                                      <- kept for planners who want the other test
--    plus parcels_with_no_flood_polygon and the denominator. Parcels are unioned by parcel_id first (fragments aggregate).
-- 2. SPEED. Measured 2026-10-01: get_area_findings('block','800 OAK ST') 21.7 s cold / 6.7 s warm, Spruce Creek 28 s;
--    the Roz route runs on a REST role with an 8 s statement_timeout, so the tool could not return. Causes: street
--    matching evaluated street_norm() on all 306,889 Volusia parcels per pass (~2 s each; fixed by the partial
--    indexes in 199a), and the tank / discharge / vat counts scanned every statewide record with a per-row subquery
--    (934 ms + 476 ms for 19 parcels). Those are rewritten parcel-driven through the existing gist indexes, counting
--    the same distinct records - asserted equal to the old form below.

do $$
declare d text; a1 text; a2 text; old_flood text; v_old jsonb; v_new jsonb; q text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_area_findings'::regproc;
  d := pg_get_functiondef('public.get_area_findings'::regproc);

  -- 1. flood block (the 197b text) -> three numbers, named test
  old_flood := substring(d from E'  res := res \\|\\| jsonb_build_object\\(''flood'', \\(.*?group by zone\\) fz\\) end\\)\\);\n');
  if old_flood is null then raise exception '199b: flood block not found'; end if;
  d := replace(d, old_flood, $f$  res := res || jsonb_build_object('flood', (
    select case when exists (select 1 from layer_resolution lr where lr.concept = 'flood' and lr.table_name = 'volusia_flood_zones' and lr.incomplete_reason is not null)
      then jsonb_build_object('field_status','not_available','reason','the county flood layer we hold is marked incomplete')
      else (
    with pp as (select p.parcel_id, st_union(p.geom) g from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid group by p.parcel_id),
    pz as (select pp.parcel_id, upper(trim(z.fld_zone)) zone, st_union(st_intersection(z.geom, pp.g)) ov, (array_agg(pp.g))[1] g
             from pp join volusia_flood_zones z on z.geom && pp.g and st_intersects(z.geom, pp.g)
            where nullif(trim(z.fld_zone),'') is not null group by 1, 2),
    cls as (select zone, parcel_id,
              case when st_area(ov::geography) / nullif(st_perimeter(ov::geography) / 2, 0) * 3.28084 < 3 then 'bd'
                   when st_isempty(st_difference(g, ov))
                     or st_area(st_difference(g, ov)::geography) / nullif(st_perimeter(st_difference(g, ov)::geography) / 2, 0) * 3.28084 < 3 then 'w'
                   else 'p' end c
              from pz where st_area(ov::geography) > 0),
    byz as (select zone, count(*) filter (where c = 'w') w, count(*) filter (where c = 'p') pw, count(*) filter (where c = 'bd') bd from cls group by 1),
    cen as (select upper(trim(z.fld_zone)) zone, count(distinct pp.parcel_id) n
              from pp join volusia_flood_zones z on st_contains(z.geom, st_centroid(pp.g))
             where nullif(trim(z.fld_zone),'') is not null group by 1)
    select jsonb_build_object(
      'test', 'Any part of the parcel within the zone, above a 3 ft boundary floor (overlap strip width); a parcel touching several zones is counted in each. The same test as the single-parcel flood answer.',
      'layer', 'volusia_flood_zones (FEMA NFHL, county extract)',
      'denominator', nrows,
      'parcels_with_no_flood_polygon', (select count(*) from pp where not exists (select 1 from pz where pz.parcel_id = pp.parcel_id)),
      'by_zone', coalesce((select jsonb_object_agg(b.zone, jsonb_build_object(
          'some_part_within', b.w + b.pw, 'wholly_within', b.w, 'partly_within', b.pw,
          'boundary_disagreement_under_3ft', b.bd,
          'centroid_in_zone', coalesce((select n from cen where cen.zone = b.zone), 0),
          'statement', format('%s of %s parcels have some part within zone %s (any part, above a 3 ft boundary floor)', b.w + b.pw, nrows, b.zone)))
        from byz b), '{}'::jsonb))
    ) end));
$f$);

  -- 2. contamination counts, parcel-driven (same distinct records)
  q := E'(select count(*) from fdep_stcm_tanks t\n       where exists(select 1 from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid where st_dwithin(t.geom, p.geom, 0.0055)))';
  if position(q in d) = 0 then raise exception '199b: tanks anchor'; end if;
  d := replace(d, q, '(select count(distinct t.oid) from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid join fdep_stcm_tanks t on st_dwithin(t.geom, p.geom, 0.0055))');
  q := E'(select count(*) from fdep_pcts_discharges d\n       where exists(select 1 from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid where st_dwithin(d.geom, p.geom, 0.0055)))';
  if position(q in d) = 0 then raise exception '199b: discharges anchor'; end if;
  d := replace(d, q, '(select count(distinct d.oid) from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid join fdep_pcts_discharges d on st_dwithin(d.geom, p.geom, 0.0055))');
  q := E'(select count(*) from fdep_clm x where x.business_name ~* ''(CATTLE\\s*DIP|DIP\\s*VAT|DIPPING)''\n       and exists(select 1 from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid where st_dwithin(x.geom, p.geom, 0.011)))';
  if position(q in d) = 0 then raise exception '199b: vats anchor'; end if;
  d := replace(d, q, E'(select count(distinct x.dep_cleanup_site_key) from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid join fdep_clm x on st_dwithin(x.geom, p.geom, 0.011)\n       where x.business_name ~* ''(CATTLE\\s*DIP|DIP\\s*VAT|DIPPING)'')');

  -- identity: the old contamination object vs the new, on a real block, before installing
  v_old := public.get_area_findings('block', '800 OAK ST', null) -> 'contamination';
  execute d;
  v_new := public.get_area_findings('block', '800 OAK ST', null) -> 'contamination';
  if v_new is distinct from v_old then raise exception '199b: contamination changed % -> %', v_old, v_new; end if;

  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_area_findings'::regproc;
  if a2 is distinct from a1 then raise exception '199b: grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'area_findings_flood_test_named_and_fast', 'get_area_findings', array['get_area_findings'],
  jsonb_build_object('flood', '{zone: count} by most severe zone', 'block_800_oak_cold_ms', 21690, 'spruce_creek_ms', 27997),
  jsonb_build_object('flood', 'per zone: some_part_within (headline) / wholly / partly / boundary_disagreement_under_3ft / centroid_in_zone + named test'),
  'Ruling 922: the area flood count names its test and carries three numbers; the tool now returns inside the 8 s REST limit.', null);
