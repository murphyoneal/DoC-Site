-- =============================================================================
-- get_pir_map_geojson(p_co_no, p_parcel_id, p_radius_m)  →  jsonb  (SECURITY DEFINER)
--
-- Map payload for the PIR's 5-mi radius renders (Page 3 flood, Page 4 zoning).
-- Everything is clipped to a real p_radius_m circle (default 5 mi = 8047 m) and
-- dissolved to keep the payload small:
--   • flood  → fema_flood_zones grouped by FEMA zone (fld_zone)
--   • zoning → volusia_zoning grouped into industry colour categories
--   • parcel → the real parcel boundary polygon
-- Perf: simplify each geometry, then the fast ST_ClipByBox2D, then ST_Collect
-- (NOT ST_Union) so it stays under the PostgREST role statement timeout; a
-- generous per-function statement_timeout is set as a safety margin.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_pir_map_geojson(p_co_no numeric, p_parcel_id text, p_radius_m numeric DEFAULT 8047)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout = '25s'
AS $$
DECLARE
  v_pt geometry(Point,4326); v_buf geometry; v_box box2d;
  v_parcel jsonb; v_flood jsonb; v_zoning jsonb;
BEGIN
  SELECT c.geom INTO v_pt FROM volusia_parcel_centroids c WHERE c.fullpid = p_parcel_id LIMIT 1;
  IF v_pt IS NULL THEN
    SELECT ST_PointOnSurface(geom) INTO v_pt FROM parcels_staging WHERE co_no = p_co_no AND parcel_id = p_parcel_id LIMIT 1;
  END IF;
  IF v_pt IS NULL THEN RETURN NULL; END IF;

  v_buf := ST_Buffer(v_pt::geography, p_radius_m)::geometry;
  v_box := Box2D(v_buf);

  SELECT ST_AsGeoJSON(ST_Simplify(geom, 0.00002))::jsonb INTO v_parcel
    FROM parcels_staging WHERE co_no = p_co_no AND parcel_id = p_parcel_id LIMIT 1;

  SELECT jsonb_build_object('type','FeatureCollection','features', COALESCE(jsonb_agg(
           jsonb_build_object('type','Feature',
             'properties', jsonb_build_object('zone', fld_zone, 'sfha', sfha_tf),
             'geometry', ST_AsGeoJSON(geom)::jsonb)), '[]'::jsonb))
    INTO v_flood
    FROM (
      SELECT fld_zone, max(sfha_tf) AS sfha_tf, ST_CollectionExtract(ST_MakeValid(ST_Collect(g)), 3) AS geom
        FROM (
          SELECT f.fld_zone, f.sfha_tf, ST_ClipByBox2D(ST_SimplifyPreserveTopology(f.geom, 0.00012), v_box) AS g
            FROM fema_flood_zones f WHERE ST_Intersects(f.geom, v_buf)
        ) s WHERE g IS NOT NULL AND NOT ST_IsEmpty(g)
       GROUP BY fld_zone
    ) z WHERE geom IS NOT NULL AND NOT ST_IsEmpty(geom);

  SELECT jsonb_build_object('type','FeatureCollection','features', COALESCE(jsonb_agg(
           jsonb_build_object('type','Feature',
             'properties', jsonb_build_object('category', category, 'codes', codes),
             'geometry', ST_AsGeoJSON(geom)::jsonb)), '[]'::jsonb))
    INTO v_zoning
    FROM (
      SELECT category, string_agg(DISTINCT zoncode, ', ' ORDER BY zoncode) AS codes,
             ST_CollectionExtract(ST_MakeValid(ST_Collect(g)), 3) AS geom
        FROM (
          SELECT z.zoncode, ST_ClipByBox2D(ST_SimplifyPreserveTopology(z.geom, 0.00012), v_box) AS g,
                 CASE
                   WHEN z.zoncode ILIKE '%PUD%'                     THEN 'planned'
                   WHEN z.zoncode ~ '^R' OR z.zoncode ILIKE 'MH%'   THEN 'residential'
                   WHEN z.zoncode ~ '^B'                            THEN 'commercial'
                   WHEN z.zoncode ~ '^(I|M-)'                       THEN 'industrial'
                   WHEN z.zoncode ~ '^A'                            THEN 'rural'
                   WHEN z.zoncode ~ '^(RC|FR|EC|OSF|CONS)'          THEN 'conservation'
                   WHEN z.zoncode ~ '^(GOV|P-|CIV|OTC)'             THEN 'public'
                   ELSE 'other'
                 END AS category
            FROM volusia_zoning z WHERE ST_Intersects(z.geom, v_buf)
        ) s WHERE g IS NOT NULL AND NOT ST_IsEmpty(g)
       GROUP BY category
    ) zz WHERE geom IS NOT NULL AND NOT ST_IsEmpty(geom);

  RETURN jsonb_build_object(
    'center', jsonb_build_object('lat', ST_Y(v_pt), 'lng', ST_X(v_pt)),
    'radiusM', p_radius_m, 'parcel', v_parcel, 'flood', v_flood, 'zoning', v_zoning);
END;
$$;

GRANT EXECUTE ON FUNCTION get_pir_map_geojson(numeric, text, numeric) TO anon, authenticated, service_role;
