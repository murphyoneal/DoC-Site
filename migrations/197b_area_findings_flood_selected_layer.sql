-- 197b - Roz's area tool counts flood zones from the selected county layer, not fema_flood_zones (follows 197a).
--
-- get_area_findings (Volusia-only, co_no 74; Roz tool area_findings) counted each parcel's flood zone from
-- fema_flood_zones - the regional table the flood rebuild ruled NEVER a fallback - by the parcel CENTROID, and labelled a
-- parcel with no polygon 'X/none', folding "no polygon held" into "zone X". Measured 2026-10-01: fema_flood_zones'
-- Volusia rows are 15,400 (a round number) covering 8,321 km2 against a 3,710 km2 county, i.e. duplicated/overlapping,
-- while the SELECTED Volusia layer (resolve_layer -> volusia_flood_zones, 11,061 rows, 126% coverage) is what every
-- single-parcel answer uses. The area count and the parcel answer must come from the same layer and the same test.
-- Now: volusia_flood_zones, ST_Intersects with the parcel (any part, as get_parcel_flood_zone's in_sfha), a parcel with
-- no polygon counted as 'no_polygon' (never as X), and the whole flood count not_available if that layer is ever marked
-- incomplete (197a). Roz's prompt does not name 'X/none' (checked).

do $$
declare d text; a1 text; a2 text; old_from text; new_from text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_area_findings'::regproc;
  d := pg_get_functiondef('public.get_area_findings'::regproc);
  old_from := E'           filter (where z.fld_zone is not null))[1], ''X/none'') zone\n        from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid\n        left join fema_flood_zones z on st_contains(z.geom, st_centroid(p.geom))';
  new_from := E'           filter (where z.fld_zone is not null))[1], ''no_polygon'') zone\n        from unnest(pset) pid join parcels_staging p on p.co_no=74 and p.parcel_id=pid\n        left join volusia_flood_zones z on st_intersects(z.geom, p.geom)  -- 197b: the selected layer, the parcel test';
  if position(old_from in d) = 0 then raise exception '197b: flood join anchor missing'; end if;
  d := replace(d, old_from, new_from);
  if position(E'res := res || jsonb_build_object(''flood'', (\n    select coalesce(jsonb_object_agg(zone, cnt),''{}''::jsonb) from (' in d) = 0 then raise exception '197b: flood head anchor missing'; end if;
  d := replace(d, E'res := res || jsonb_build_object(''flood'', (\n    select coalesce(jsonb_object_agg(zone, cnt),''{}''::jsonb) from (',
                  E'res := res || jsonb_build_object(''flood'', (\n    select case when exists (select 1 from layer_resolution lr where lr.concept = ''flood'' and lr.table_name = ''volusia_flood_zones'' and lr.incomplete_reason is not null)\n      then jsonb_build_object(''field_status'',''not_available'',''reason'',''the county flood layer we hold is marked incomplete'')\n      else (\n    select coalesce(jsonb_object_agg(zone, cnt),''{}''::jsonb) from (');
  if position(E'      group by zone) fz));\n  res := res || jsonb_build_object(''encumbrances''' in d) = 0 then raise exception '197b: flood tail anchor missing'; end if;
  d := replace(d, E'      group by zone) fz));\n  res := res || jsonb_build_object(''encumbrances''',
                  E'      group by zone) fz) end));\n  res := res || jsonb_build_object(''encumbrances''');
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_area_findings'::regproc;
  if a2 is distinct from a1 then raise exception '197b: grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'area_findings_flood_selected_layer', 'get_area_findings', array['get_area_findings'],
  jsonb_build_object('source', 'fema_flood_zones by centroid, no polygon = X/none'),
  jsonb_build_object('source', 'volusia_flood_zones (selected) by parcel intersect, no polygon = no_polygon'),
  'The area tool counted flood zones from a table ruled never-a-fallback (duplicated in Volusia) and labelled missing polygons as zone X; it now uses the same layer and test as the single-parcel flood answer.', null);
