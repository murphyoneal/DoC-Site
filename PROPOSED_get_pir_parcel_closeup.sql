-- =============================================================================
-- get_pir_parcel_closeup(p_co_no, p_parcel_id, p_radius_m)  →  jsonb  (SECURITY DEFINER)
--
-- Tight boundary view for Page 1: the subject parcel plus neighbouring parcels
-- within ~p_radius_m metres (default 46 m ≈ 150 ft), all from real
-- parcels_staging geometry. Uses an index-accelerated bbox pre-filter (&& on an
-- expanded envelope) before the metric ST_DWithin refine, so it stays fast
-- against the 10.7M-row parcel table.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_pir_parcel_closeup(p_co_no numeric, p_parcel_id text, p_radius_m numeric DEFAULT 46)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout = '15s'
AS $$
DECLARE v_geom geometry; v_pt geometry; v_env geometry; v_subject jsonb; v_neighbors jsonb;
BEGIN
  SELECT geom INTO v_geom FROM parcels_staging WHERE co_no = p_co_no AND parcel_id = p_parcel_id LIMIT 1;
  IF v_geom IS NULL THEN RETURN NULL; END IF;
  v_pt := ST_PointOnSurface(v_geom);
  v_env := ST_Expand(v_geom, p_radius_m / 80000.0);   -- ~metres → degrees bbox pad
  v_subject := ST_AsGeoJSON(ST_Simplify(v_geom, 0.000004))::jsonb;
  SELECT jsonb_build_object('type','FeatureCollection','features', COALESCE(jsonb_agg(
           jsonb_build_object('type','Feature',
             'properties', jsonb_build_object('parcelId', p.parcel_id, 'address', p.phy_addr1),
             'geometry', ST_AsGeoJSON(ST_Simplify(p.geom, 0.000004))::jsonb)), '[]'::jsonb))
    INTO v_neighbors
    FROM parcels_staging p
   WHERE p.co_no = p_co_no
     AND p.parcel_id <> p_parcel_id
     AND p.geom && v_env                                   -- GIST-indexed bbox pre-filter
     AND ST_DWithin(p.geom::geography, v_geom::geography, p_radius_m);
  RETURN jsonb_build_object(
    'center', jsonb_build_object('lat', ST_Y(v_pt), 'lng', ST_X(v_pt)),
    'radiusM', p_radius_m, 'subject', v_subject, 'neighbors', v_neighbors);
END;
$$;

GRANT EXECUTE ON FUNCTION get_pir_parcel_closeup(numeric, text, numeric) TO anon, authenticated, service_role;
