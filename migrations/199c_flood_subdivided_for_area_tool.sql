-- 199c - the area tool intersects parcels with a subdivided copy of the Volusia flood layer: same geometry, a fraction
-- of the cost (follows 197b / 199b).
--
-- 197b moved Roz's area flood count onto volusia_flood_zones with a parcel intersect, and 199b added the strip-width
-- classification. On Spruce Creek (2,060 parcels) that took 59.9 s: each ST_Intersection / ST_Difference runs against a
-- very large FEMA polygon. The parcel-set resolution itself takes 122 ms. Same remedy as nhd_area_subdivided (137b):
-- volusia_flood_zones_subdivided = ST_Subdivide(geom, 256) per source polygon, built in WSL 2026-10-02:
-- 63,116 pieces from all 11,061 zoned source polygons; summed piece area equals source area on 11,061 of 11,061.
-- The union of a parcel's intersections with the pieces IS its intersection with the source, so the counts must not
-- change - asserted below on two areas before the function is replaced.
-- DERIVED TABLE: registered in derived_table_asof; detection derived-flood-subdivision-matches-source compares source
-- polygon count and per-zone area. A refresh of volusia_flood_zones must rebuild it (the 186a rule).

alter table if exists public.volusia_flood_zones_subdivided_new rename to volusia_flood_zones_subdivided;
comment on table public.volusia_flood_zones_subdivided is
  'DERIVED (199c): ST_Subdivide(geom, 256) of volusia_flood_zones, one row per piece, src_id = volusia_flood_zones.id, fld_zone upper-trimmed. Exists only to make area intersections cheap; rebuild whenever volusia_flood_zones is refreshed. Checked by detection derived-flood-subdivision-matches-source.';

insert into public.derived_table_asof (table_name, source_table, source_as_of, built_at, basis)
select 'volusia_flood_zones_subdivided', 'volusia_flood_zones', max(loaded_at)::date, now(),
  'ST_Subdivide(geom,256) of every zoned row (11,061 -> 63,116 pieces), built 2026-10-02; summed piece area equals source area per polygon (11,061/11,061). source_as_of = max(volusia_flood_zones.loaded_at), the date our copy of the source was loaded - not the FIRM effective date.'
from public.volusia_flood_zones
having max(loaded_at) is not null;
do $$ begin if not exists (select 1 from public.derived_table_asof where table_name = 'volusia_flood_zones_subdivided') then
  raise exception '199c: volusia_flood_zones has no loaded_at - source date not established'; end if; end $$;

insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('derived-flood-subdivision-matches-source',
  'volusia_flood_zones_subdivided no longer matches volusia_flood_zones (polygon count or per-zone area) - the source was refreshed without rebuilding the derived copy',
  'completeness', 'material',
  $q$with s as (select upper(trim(fld_zone)) z, count(*) n, sum(st_area(geom)) a from public.volusia_flood_zones where nullif(trim(fld_zone),'') is not null group by 1),
          d as (select fld_zone z, count(distinct src_id) n, sum(st_area(geom)) a from public.volusia_flood_zones_subdivided group by 1)
     select bool_and(s.n = d.n and abs(s.a - d.a) <= greatest(1e-9, s.a * 1e-6)) is true
            and (select count(*) from s) = (select count(*) from d) as ok,
            (select count(*) from s full join d using (z) where s.n is distinct from d.n) as row_count
       from s join d using (z)$q$,
  '199c. Same shape as the derived-vs-source detections of 187a: the subdivided copy must have exactly the source''s polygons per zone and the same area.');

do $$
declare d text; a1 text; a2 text; before_oak jsonb; before_sc jsonb; after_oak jsonb; after_sc jsonb;
begin
  before_oak := public.get_area_findings('block', '800 OAK ST', null) -> 'flood';
  before_sc  := public.get_area_findings('subdivision', 'Spruce Creek', null) -> 'flood';

  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_area_findings'::regproc;
  d := pg_get_functiondef('public.get_area_findings'::regproc);
  if position('from pp join volusia_flood_zones z on z.geom && pp.g and st_intersects(z.geom, pp.g)' in d) = 0
     or position('from pp join volusia_flood_zones z on st_contains(z.geom, st_centroid(pp.g))' in d) = 0 then
    raise exception '199c: flood anchors missing'; end if;
  d := replace(d, 'select pp.parcel_id, upper(trim(z.fld_zone)) zone, st_union(st_intersection(z.geom, pp.g)) ov, (array_agg(pp.g))[1] g
             from pp join volusia_flood_zones z on z.geom && pp.g and st_intersects(z.geom, pp.g)
            where nullif(trim(z.fld_zone),'''') is not null group by 1, 2',
                  'select pp.parcel_id, z.fld_zone zone, st_union(st_intersection(z.geom, pp.g)) ov, (array_agg(pp.g))[1] g
             from pp join volusia_flood_zones_subdivided z on z.geom && pp.g and st_intersects(z.geom, pp.g)  -- 199c: pieces
            group by 1, 2');
  d := replace(d, 'select upper(trim(z.fld_zone)) zone, count(distinct pp.parcel_id) n
              from pp join volusia_flood_zones z on st_contains(z.geom, st_centroid(pp.g))
             where nullif(trim(z.fld_zone),'''') is not null group by 1',
                  'select z.fld_zone zone, count(distinct pp.parcel_id) n
              from pp join volusia_flood_zones_subdivided z on st_intersects(z.geom, st_centroid(pp.g))  -- 199c: a centroid on a cut line touches both pieces
             group by 1');
  if position('volusia_flood_zones_subdivided z on z.geom && pp.g' in d) = 0 or position('volusia_flood_zones_subdivided z on st_intersects(z.geom, st_centroid' in d) = 0 then
    raise exception '199c: a replace did not apply'; end if;
  execute d;

  after_oak := public.get_area_findings('block', '800 OAK ST', null) -> 'flood';
  after_sc  := public.get_area_findings('subdivision', 'Spruce Creek', null) -> 'flood';
  if after_oak is distinct from before_oak then raise exception '199c: Oak flood changed % -> %', before_oak, after_oak; end if;
  if after_sc  is distinct from before_sc  then raise exception '199c: Spruce Creek flood changed % -> %', before_sc, after_sc; end if;

  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_area_findings'::regproc;
  if a2 is distinct from a1 then raise exception '199c: grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'area_findings_flood_subdivided', 'get_area_findings', array['get_area_findings','volusia_flood_zones_subdivided'],
  jsonb_build_object('spruce_creek_ms', 59881),
  jsonb_build_object('source', 'volusia_flood_zones_subdivided (63,116 pieces)', 'identity', 'flood output identical on 800 OAK ST and Spruce Creek'),
  'The area flood count intersected parcels with very large FEMA polygons (59.9 s on 2,060 parcels); a subdivided derived copy gives the same geometry, registered and checked against its source.', null);
