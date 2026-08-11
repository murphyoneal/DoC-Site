-- =============================================================================
-- STATUS (2026-07-06):
--   • KNN waterbody fix below → APPLIED via migration
--     optimize_get_site_intelligence_waterbody_knn. Verified: 25-parcel viewport
--     904 ms (was timing out); KNN top-5 == top-50 (behavior-preserving).
--   • Flood-zone generalization (bottom of file) → NOT applied. Blocked: the
--     statewide fema_flood_zones load is spatially MISLOCATED (region polygons
--     piled at lat ~27 SW-FL; Osceola/Seminole/Brevard uncovered — nearest polygon
--     to a test Osceola parcel is 32 km away). Neither `= v_county_name` nor
--     spatial-only will return correct flood zones until that data is re-loaded.
-- =============================================================================
--
-- WHY (waterbody fix): the function was 4–85 s PER PARCEL, which made the map viewport
-- unusable (5 parcels = ~19 s; a single large parcel timed at 85 s). Root cause,
-- confirmed by EXPLAIN ANALYZE:
--
--   nearest_water_m does
--     (SELECT MIN(ST_Distance(parcel::geography, w.geom::geography))
--      FROM hydrology_waterbodies w WHERE w.geom IS NOT NULL)
--   → a Seq Scan over all 41,087 waterbodies, casting every one to geography and
--     computing geodesic distance. The GiST index on hydrology_waterbodies.geom
--     is never used because there's no ST_DWithin bound and MIN() can't drive KNN.
--
-- FIX: use the KNN operator (<->) to let the GiST index return the few nearest
-- candidates by planar distance, then compute exact geodesic distance on just
-- those. 41,087-row seq scan → ~5-row index lookup. Milliseconds instead of
-- tens of seconds. Result is identical for all realistic geometries (top-5 guards
-- the rare case where the planar-nearest isn't the geodesic-nearest).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_site_intelligence(p_co_no numeric, p_parcel_id text)
 RETURNS TABLE(parcel_id text, county_name text, owner_name text, phy_addr1 text, phy_city text, land_sqft numeric, building_sqft numeric, just_value numeric, land_use_code text, nearby_max_aadt numeric, nearby_road_desc text, census_block_group text, area_population numeric, area_median_income numeric, area_housing_units numeric, elevation_m numeric, nearest_water_m numeric, flood_zone_available boolean, flood_zone text, in_flood_hazard_area boolean)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_county_name text;
  v_fips text;
  v_parcel_geom geometry;
BEGIN
  SELECT cr.county_name, cr.fips INTO v_county_name, v_fips
  FROM county_registry cr WHERE cr.dor_county_no = p_co_no::text;

  SELECT p.geom INTO v_parcel_geom
  FROM parcels_staging p WHERE p.co_no = p_co_no AND p.parcel_id = p_parcel_id
  LIMIT 1;

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
    -- ▼▼▼ THE FIX: KNN candidate lookup (index-assisted) + exact geodesic min ▼▼▼
    (SELECT MIN(ST_Distance(v_parcel_geom::geography, c.geom::geography))::numeric
       FROM (
         SELECT w.geom
         FROM hydrology_waterbodies w
         WHERE w.geom IS NOT NULL
         ORDER BY v_parcel_geom <-> w.geom   -- uses idx on hydrology_waterbodies.geom
         LIMIT 5
       ) c),
    -- ▲▲▲ end fix ▲▲▲
    (v_county_name = 'Volusia'),
    (SELECT f.fld_zone FROM fema_flood_zones f WHERE f.county_name = 'Volusia' AND ST_Intersects(f.geom, v_parcel_geom) LIMIT 1),
    (SELECT f.sfha_tf = 'T' FROM fema_flood_zones f WHERE f.county_name = 'Volusia' AND ST_Intersects(f.geom, v_parcel_geom) LIMIT 1)
  FROM parcels_staging p
  LEFT JOIN census_block_groups cb ON cb.county = v_fips AND ST_Intersects(v_parcel_geom, cb.geom)
  LEFT JOIN census_acs_data ca ON ca.county = v_fips AND ca.tract = cb.tract AND ca.block_group = cb.blkgrp
  WHERE p.co_no = p_co_no AND p.parcel_id = p_parcel_id
  LIMIT 1;
END;
$function$;


-- =============================================================================
-- SEPARATE ISSUE (not performance) — flood zone is hardcoded to Volusia.
-- Flood zone is the card's biggest conversion driver, but these three lines only
-- ever populate it for Volusia parcels:
--
--     (v_county_name = 'Volusia'),                                  -- flood_zone_available
--     ... WHERE f.county_name = 'Volusia' ...   (flood_zone)
--     ... WHERE f.county_name = 'Volusia' ...   (in_flood_hazard_area)
--
-- If fema_flood_zones now has data beyond Volusia, generalize by replacing the
-- three lines above with:
--
--     (EXISTS (SELECT 1 FROM fema_flood_zones f WHERE f.county_name = v_county_name)),
--     (SELECT f.fld_zone FROM fema_flood_zones f WHERE f.county_name = v_county_name AND ST_Intersects(f.geom, v_parcel_geom) LIMIT 1),
--     (SELECT f.sfha_tf = 'T' FROM fema_flood_zones f WHERE f.county_name = v_county_name AND ST_Intersects(f.geom, v_parcel_geom) LIMIT 1)
--
-- Left as-is above because I don't know your FEMA data coverage — your call.
-- (For our Lee County test parcels, flood_zone is null for this reason, not a bug.)
-- =============================================================================
