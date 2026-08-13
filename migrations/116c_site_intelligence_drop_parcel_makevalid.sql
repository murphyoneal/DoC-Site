-- =============================================================================
-- Ruling 122 step 3 / 125 — remove get_site_intelligence's two ST_MakeValid calls, both parcel-side
-- (parcels_staging is 0-invalid, ruling 122 gate). The first repairs the parcel union; the second
-- re-repairs v_parcel_geom which is ALREADY the repaired union — pure redundancy. The fema_flood_zones
-- read here is point-based (ST_Intersects(f.geom, v_rep_point)) and already carries no guard, so this
-- change is gated solely on parcels_staging validity, which is cleared. Body otherwise unchanged.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_site_intelligence(p_co_no numeric, p_parcel_id text)
 RETURNS TABLE(parcel_id text, county_name text, owner_name text, phy_addr1 text, phy_city text, land_sqft numeric, building_sqft numeric, just_value numeric, land_use_code text, nearby_max_aadt numeric, nearby_road_desc text, census_block_group text, area_population numeric, area_median_income numeric, area_housing_units numeric, elevation_m numeric, nearest_water_m numeric, flood_zone_available boolean, flood_zone text, in_flood_hazard_area boolean, gis_acres numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '60s'
AS $function$
DECLARE
  v_county_name text;
  v_fips text;
  v_parcel_geom geometry;
  v_rep_point geometry;  -- point on the LARGEST part; containment lookups use this, not the whole multipolygon
BEGIN
  SELECT cr.county_name, cr.fips INTO v_county_name, v_fips
  FROM county_registry cr WHERE cr.dor_county_no = p_co_no::text;

  SELECT ST_Union(p.geom) INTO v_parcel_geom
  FROM parcels_staging p WHERE p.co_no = p_co_no AND p.parcel_id = p_parcel_id
  LIMIT 1;

  SELECT ST_PointOnSurface(parts.geom) INTO v_rep_point
  FROM (SELECT (ST_Dump(v_parcel_geom)).geom AS geom) parts ORDER BY ST_Area(parts.geom) DESC LIMIT 1;

  RETURN QUERY
  SELECT
    p.parcel_id,
    v_county_name,
    p.own_name,
    p.phy_addr1,
    p.phy_city,
    p.lnd_sqfoot,
    p.tot_lvg_ar,
    p.jv,
    p.dor_uc,
    (SELECT MAX(t.aadt) FROM traffic_aadt t WHERE t.county = v_county_name AND ST_DWithin(t.geom, v_parcel_geom, 0.003)),
    (SELECT t.roadway FROM traffic_aadt t WHERE t.county = v_county_name AND ST_DWithin(t.geom, v_parcel_geom, 0.003) ORDER BY t.aadt DESC LIMIT 1),
    cb.name,
    ca.total_population,
    ca.median_household_income,
    ca.total_housing_units,
    (SELECT pe.elevation_m FROM parcel_elevations pe WHERE pe.co_no = p_co_no AND pe.parcel_id = p_parcel_id LIMIT 1),
    (SELECT MIN(ST_Distance(v_parcel_geom::geography, c.geom::geography))::numeric
       FROM (SELECT w.geom FROM hydrology_waterbodies w WHERE w.geom IS NOT NULL ORDER BY v_parcel_geom <-> w.geom LIMIT 5) c),
    (SELECT EXISTS (SELECT 1 FROM fema_flood_zones f WHERE f.county_name = v_county_name)),
    (SELECT f.fld_zone FROM fema_flood_zones f WHERE f.county_name = v_county_name AND ST_Intersects(f.geom, v_rep_point) LIMIT 1),
    (SELECT f.sfha_tf = 'T' FROM fema_flood_zones f WHERE f.county_name = v_county_name AND ST_Intersects(f.geom, v_rep_point) LIMIT 1),
    round((ST_Area(v_parcel_geom::geography) / 4046.8564224)::numeric, 3)
  FROM parcels_staging p
  LEFT JOIN census_block_groups cb ON cb.county = v_fips AND ST_Intersects(v_rep_point, cb.geom)
  LEFT JOIN census_acs_data ca ON ca.county = v_fips AND ca.tract = cb.tract AND ca.block_group = cb.blkgrp
  WHERE p.co_no = p_co_no AND p.parcel_id = p_parcel_id
  LIMIT 1;
END;
$function$;
