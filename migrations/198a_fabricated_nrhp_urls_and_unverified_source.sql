-- 198a - two fabricated source URLs removed; an active source never fetched reads RED as unverified (ruling 919).
--
-- data_source_registry 339 (nrhp_points) and 340 (nrhp_district_polygons) cite https://services1.arcgis.com/NRHP/points and
-- .../NRHP/districts. Fetched 2026-10-01: both answer HTTP 200 with {"error":{"code":400,"message":"Invalid URL"}} -
-- not an ArcGIS service shape at all (no org id, no /arcgis/rest/services/). Invented citations.
-- Both tables are SERVED (get_parcel_historic_facts via layer_resolution historic_resource_proximity /
-- historic_district_containment), so deleting the rows would leave served tables with no source. Their contents name
-- their source instead: every nris_refnum in nrhp_points (1,440) and nrhp_district_polygons (306) is present in the
-- tables ~/nrhp_load.py pulled from https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer
-- layers 0 and 1 (nrhp_points_fl, nrhp_boundaries_fl; registry 310, 309), and both carry NPS's NRHP schema (cr_id,
-- nara_url, map_method, src_accu). Geometry is not byte-equal (an earlier pull of the same service). So the fabricated
-- URL is replaced by the verified NPS layer, with that evidence recorded; the invented string survives only in
-- before_state.
--
-- DETECTION active-source-never-fetched: every active source must have at least one recorded fetch
-- (source_observation status 'ok'). Measured at creation: 1,239 of 1,978 active sources have NONE; 953 have a source_url
-- that is not a URL at all (prose such as "Citrus PA local shapefiles ... + citrus-open-data hub"). RED BY DESIGN - a
-- URL nobody has fetched is a claim, not a citation. Clearing it is work for the cadence sweep, not for this migration.

do $$
declare r record; n int;
begin
  select count(*) into n from public.data_source_registry
   where (id = 339 and source_url = 'https://services1.arcgis.com/NRHP/points')
      or (id = 340 and source_url = 'https://services1.arcgis.com/NRHP/districts');
  if n is distinct from 2 then raise exception '198a: the two fabricated rows are not as measured (%)', n; end if;
  select count(*) into n from public.nrhp_points a where not exists (select 1 from public.nrhp_points_fl b where b.nris_refnum = a.nris_refnum);
  if n is distinct from 0 then raise exception '198a: % nrhp_points refnums not in the NPS pull - provenance not established', n; end if;
  select count(*) into n from public.nrhp_district_polygons a where not exists (select 1 from public.nrhp_boundaries_fl b where b.nris_refnum = a.nris_refnum);
  if n is distinct from 0 then raise exception '198a: % district refnums not in the NPS pull', n; end if;

  for r in select * from public.data_source_registry where id in (339, 340) loop
    perform public._log_action('cc', 'remove_fabricated_source_url', 'data_source_registry', array[r.id::text],
      to_jsonb(r),
      jsonb_build_object('source_url', case r.id when 339 then 'https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer/0'
                                                 else 'https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer/1' end),
      'Ruling 919: fabricated citation (' || r.source_url || ' returns {"error":{"code":400,"message":"Invalid URL"}}). Replaced by the NPS layer the table contents match on every nris_refnum; the invented string is kept only here.', null);
  end loop;

  update public.data_source_registry
     set source_url = 'https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer/0',
         source_recovered_from = 'content match 2026-10-01 (198a): all 1,440 nris_refnum present in nrhp_points_fl (NPS layer 0, registry 310); NPS NRHP schema. Replaced a fabricated URL (services1.arcgis.com/NRHP/points).'
   where id = 339;
  update public.data_source_registry
     set source_url = 'https://mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer/1',
         source_recovered_from = 'content match 2026-10-01 (198a): all 306 nris_refnum present in nrhp_boundaries_fl (NPS layer 1, registry 309); NPS NRHP schema. Replaced a fabricated URL (services1.arcgis.com/NRHP/districts).'
   where id = 340;

  if exists (select 1 from public.data_source_registry where source_url ilike '%services1.arcgis.com/NRHP%') then
    raise exception '198a: a fabricated NRHP URL is still registered'; end if;
end $$;

insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('active-source-never-fetched',
  'An active data_source_registry row has no recorded successful fetch (source_observation status ok): its source is a claim, not a verified citation',
  'completeness', 'material',
  $q$select count(*) = 0 as ok, count(*) as row_count,
            count(*) filter (where r.source_url !~* '^https?://') as not_a_url
       from public.data_source_registry r
      where r.active
        and not exists (select 1 from public.source_observation o where o.source_id = r.id and o.status = 'ok')$q$,
  'Red by design at creation (2026-10-01): 1,239 of 1,978 active sources never fetched, 953 of them with a source_url that is not a URL. A table can be loaded (last_successful_pull_date set) without its fetch ever being recorded; this asks for the record. Ruling 919.');

select public._log_action('cc', 'add_unverified_source_detection', 'data_defect_registry', array['active-source-never-fetched'], null,
  jsonb_build_object('red_by_design', 1239, 'not_a_url', 953, 'active', 1978),
  'Ruling 919: a URL nobody has ever successfully fetched is a claim, not a citation.', null);
