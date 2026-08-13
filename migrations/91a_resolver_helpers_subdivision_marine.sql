-- =============================================================================
-- handoff 36: resolver-backed helpers for the two cleanly-additive concepts.
-- Each resolves the county's usable layer from layer_resolution + layer_column_map
-- (content-verified in phase 1) and reads it spatially. Returns NULL/[] when no layer
-- is held (honest absence). get_pir_report calls these only for NON-Volusia parcels
-- (gated on volusia_parcel_centroids presence), so Volusia stays byte-identical.
-- Boat ramps: coerce each feature to a POINT via ST_Centroid (some county layers are
-- MULTIPOINT; ST_Azimuth requires POINT). SRID normalised to 4326 (all FL layers are
-- lat/long whether tagged 4326 or 0, confirmed by the phase-1 interior-point test).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_parcel_subdivision_resolved(p_co_no numeric, p_parcel_id text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_pt geometry; v_tbl text; v_geom text; v_namecol text; v_name text;
BEGIN
  SELECT ST_PointOnSurface(geom) INTO v_pt FROM public.resolve_parcel_geometry(p_co_no,p_parcel_id) LIMIT 1;
  IF v_pt IS NULL THEN RETURN NULL; END IF;
  SELECT lr.table_name, COALESCE(lr.geom_column,'geom'), cm.column_name
    INTO v_tbl, v_geom, v_namecol
    FROM public.layer_resolution lr
    JOIN public.geo_reference g ON g.geo_id=lr.geo_id
    LEFT JOIN public.layer_column_map cm ON cm.table_name=lr.table_name AND cm.col_role='name'
   WHERE lr.concept='subdivisions' AND g.dor_co_no=p_co_no::int AND g.admin_level=2
     AND lr.table_name IS NOT NULL AND COALESCE(lr.row_count,0)>0
   ORDER BY lr.row_count DESC LIMIT 1;
  IF v_tbl IS NULL OR v_namecol IS NULL THEN RETURN NULL; END IF;
  BEGIN
    EXECUTE format('SELECT (%I)::text FROM public.%I WHERE ST_Contains(ST_SetSRID(%I,4326), $1) AND %I IS NOT NULL LIMIT 1',
      v_namecol, v_tbl, v_geom, v_geom) INTO v_name USING v_pt;
  EXCEPTION WHEN others THEN RETURN NULL; END;
  RETURN nullif(trim(v_name),'');
END $fn$;
GRANT EXECUTE ON FUNCTION public.get_parcel_subdivision_resolved(numeric,text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_parcel_boat_ramps_resolved(p_co_no numeric, p_parcel_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_pt geometry; v_tbl text; v_geom text; v_namecol text; v_out jsonb;
BEGIN
  SELECT ST_PointOnSurface(geom) INTO v_pt FROM public.resolve_parcel_geometry(p_co_no,p_parcel_id) LIMIT 1;
  IF v_pt IS NULL THEN RETURN NULL; END IF;
  SELECT lr.table_name, COALESCE(lr.geom_column,'geom'), cm.column_name
    INTO v_tbl, v_geom, v_namecol
    FROM public.layer_resolution lr
    JOIN public.geo_reference g ON g.geo_id=lr.geo_id
    LEFT JOIN public.layer_column_map cm ON cm.table_name=lr.table_name AND cm.col_role='name'
   WHERE lr.concept='marine' AND g.dor_co_no=p_co_no::int AND g.admin_level=2
     AND lr.table_name IS NOT NULL AND COALESCE(lr.row_count,0)>0
   ORDER BY lr.row_count DESC LIMIT 1;
  IF v_tbl IS NULL THEN RETURN NULL; END IF;
  BEGIN
    EXECUTE format($q$
      SELECT jsonb_agg(x ORDER BY (x->>'distanceM')::numeric) FROM (
        SELECT jsonb_build_object('name', s.nm,
                 'distanceM', round(ST_Distance(s.p::geography, $1::geography)),
                 'bearingDegrees', round(degrees(ST_Azimuth($1, s.p))::numeric,1)) x
          FROM (SELECT %s AS nm, ST_Centroid(ST_SetSRID(%I,4326)) AS p
                  FROM public.%I WHERE %I IS NOT NULL) s
         WHERE ST_DWithin(s.p::geography, $1::geography, 8000) AND NOT ST_Equals(s.p, $1)
         ORDER BY ST_Distance(s.p::geography, $1::geography) LIMIT 4) q$q$,
      CASE WHEN v_namecol IS NULL THEN 'NULL::text' ELSE '('||quote_ident(v_namecol)||')::text' END,
      v_geom, v_tbl, v_geom)
    INTO v_out USING v_pt;
  EXCEPTION WHEN others THEN RETURN NULL; END;
  RETURN COALESCE(v_out, '[]'::jsonb);
END $fn$;
GRANT EXECUTE ON FUNCTION public.get_parcel_boat_ramps_resolved(numeric,text) TO anon, authenticated, service_role;
