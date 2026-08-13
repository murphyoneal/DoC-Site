-- =============================================================================
-- Ruling 122 step 3 (cont.) — remove get_parcel_flood_zone's TWO per-ROW layer guards now that every
-- WIRED flood layer is provably valid (all 53 flood_layer_selection tables measured 0 invalid after the
-- 116a estate repair). This is the Marion/DeSoto defect: ST_IsValid ran on every candidate row, and
-- DeSoto's 660k-vertex (was 1.8M pre-repair) polygon made nearly every parcel a candidate. Measured
-- DeSoto BEFORE = 19,545ms. The per-row CASE WHEN ST_IsValid(f.geom) ... ST_MakeValid(f.geom) guards are
-- replaced with f.geom directly. Precondition (ruling 122): repair FIRST, remove guard SECOND — done.
-- Body otherwise identical to 115b.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_parcel_flood_zone(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '20s'
AS $function$
DECLARE
  r record; v_geom geometry; v_items jsonb; v_sfha boolean; v_bfe numeric; v_datum text;
  v_zone text; v_sfha_c text; v_bfe_c text; v_subty_c text; v_datum_c text;
  v_sfha_expr text; v_bfe_expr text; v_subty_expr text; v_datum_expr text;
BEGIN
  SELECT geom INTO v_geom FROM resolve_parcel_geometry(p_co_no, p_parcel_id) LIMIT 1;
  IF v_geom IS NULL THEN
    RETURN jsonb_build_object('field','flood_zone','field_status','parcel_not_resolved','in_sfha',NULL,
      'coverage_caveat','Parcel geometry could not be resolved; flood zone was NOT evaluated. This is not a statement about flood hazard.');
  END IF;

  SELECT * INTO r FROM flood_layer_selection WHERE co_no = p_co_no;
  IF NOT FOUND OR r.table_name IS NULL THEN
    RETURN jsonb_build_object('field','flood_zone','field_status','not_available','in_sfha',NULL,'zones',NULL,
      'county_layer_status', CASE WHEN FOUND AND r.needs_curation
        THEN format('%s candidate flood layers are held for this county but none has been selected as the effective FIRM. Not evaluated.', r.candidates)
        ELSE 'No county FEMA NFHL layer is held for this county.' END,
      'coverage_caveat','COVERAGE GAP, NOT A FINDING. This is NOT a statement that the parcel is outside a Special Flood Hazard Area. Check the FEMA Flood Map Service Center (msc.fema.gov) before drawing any conclusion about flood insurance.',
      'source','FEMA National Flood Hazard Layer','authority','FEMA');
  END IF;

  v_zone    := flood_col(r.table_name,'zone');
  v_sfha_c  := flood_col(r.table_name,'sfha');
  v_bfe_c   := flood_col(r.table_name,'bfe');
  v_subty_c := flood_col(r.table_name,'subty');
  v_datum_c := flood_col(r.table_name,'datum');

  IF v_zone IS NULL THEN
    RETURN jsonb_build_object('field','flood_zone','field_status','not_available','in_sfha',NULL,'zones',NULL,
      'county_layer_status', format('The held layer %s has no recognisable flood-zone column; not evaluated.', r.table_name),
      'coverage_caveat','COVERAGE GAP, NOT A FINDING. The county layer could not be read; this is not a statement that the parcel is outside a Special Flood Hazard Area. Check msc.fema.gov.',
      'source','FEMA National Flood Hazard Layer','authority','FEMA');
  END IF;

  v_subty_expr := CASE WHEN v_subty_c IS NOT NULL THEN format('nullif(trim(f.%I),'''')', v_subty_c) ELSE 'NULL::text' END;
  v_bfe_expr   := CASE WHEN v_bfe_c   IS NOT NULL THEN format('nullif(f.%I::numeric, -9999)', v_bfe_c) ELSE 'NULL::numeric' END;
  v_datum_expr := CASE WHEN v_datum_c IS NOT NULL THEN format('nullif(trim(f.%I),'''')', v_datum_c) ELSE 'NULL::text' END;
  v_sfha_expr  := CASE WHEN v_sfha_c IS NOT NULL
      THEN format('(upper(trim(f.%I)) = ''T'')', v_sfha_c)
      ELSE format('(upper(trim(f.%I)) IN (''A'',''AE'',''AH'',''AO'',''AR'',''A99'',''V'',''VE'') OR upper(trim(f.%I)) ~ ''^(A|V)[0-9]'')', v_zone, v_zone)
      END;

  EXECUTE format($q$
    SELECT jsonb_agg(x ORDER BY (x->>'pct_of_parcel')::numeric DESC), bool_or(sf), max(bf), max(vd)
    FROM (SELECT jsonb_build_object(
            'zone', f.%1$I,
            'subtype', %2$s,
            'in_sfha', %3$s,
            'base_flood_elevation_ft', %4$s,
            'pct_of_parcel', round((100*ST_Area(ST_Intersection(f.geom,$1)::geography)
                                    /nullif(ST_Area($1::geography),0))::numeric,1)) AS x,
            %3$s AS sf, %4$s AS bf, %5$s AS vd
          FROM %6$I f
         WHERE f.geom && $1 AND ST_Intersects(f.geom,$1)) s
  $q$, v_zone, v_subty_expr, v_sfha_expr, v_bfe_expr, v_datum_expr, r.table_name)
  INTO v_items, v_sfha, v_bfe, v_datum USING v_geom;

  RETURN jsonb_build_object(
    'field','flood_zone',
    'field_status', CASE WHEN v_items IS NULL THEN 'none_intersecting' ELSE 'present' END,
    'zones', coalesce(v_items,'[]'::jsonb),
    'in_sfha', v_sfha,
    'base_flood_elevation_ft', v_bfe,
    'vertical_datum', v_datum,
    'layer_used', r.table_name,
    'coverage_caveat', CASE WHEN v_items IS NULL
      THEN 'The county NFHL layer was queried and no polygon intersects this parcel. For a complete NFHL extract that is unusual and may indicate a gap in the layer rather than absence of hazard. Verify at msc.fema.gov.'
      ELSE 'Percentages are share of parcel area. A parcel may span several zones; in_sfha is true if ANY part lies in one. Zone and BFE are from the county FEMA NFHL extract, not an elevation certificate.' END,
    'source','FEMA National Flood Hazard Layer, county extract','authority','FEMA',
    'resolution_level','parcel','relation','intersects');
END $function$;
