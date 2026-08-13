-- =============================================================================
-- Item 80, step 2: schema-adaptive get_parcel_flood_zone.
--
-- The served dynamic SQL hardcoded fld_zone/zone_subty/sfha_tf/static_bfe. Any
-- layer missing one crashed the ENTIRE report (Baker/DeSoto/Hendry/Jefferson).
-- It also silently excluded every county whose FIRM names its columns differently.
--
-- New machinery:
--   flood_layer_column_map(table_name, col_role, column_name) — explicit per-layer
--     overrides for zone/sfha/bfe/subty/datum. Empty now; populated in step 3.
--   flood_col(tbl, role) — returns the mapped column, else the standard NFHL name
--     if it exists on the table, else NULL.
--   get_parcel_flood_zone — resolves columns via flood_col:
--     * ZONE column unresolvable  -> not_available (FAIL CLOSED — never a false
--       "not in SFHA" from a layer we cannot read).
--     * sfha flag absent          -> derive in_sfha from the zone CODE (FEMA SFHA
--       set A/AE/AH/AO/AR/A99/V/VE and A#/V#), never assume "not in SFHA".
--     * bfe absent / -9999        -> NULL. The nullif(bfe,-9999) sentinel guard is
--       preserved for whatever column holds the BFE (asserted by test).
--   Standard-schema layers (e.g. Volusia) produce byte-identical output.
-- =============================================================================
CREATE TABLE IF NOT EXISTS flood_layer_column_map (
  table_name  text NOT NULL,
  col_role    text NOT NULL CHECK (col_role IN ('zone','sfha','bfe','subty','datum')),
  column_name text NOT NULL,
  note        text,
  PRIMARY KEY (table_name, col_role)
);

CREATE OR REPLACE FUNCTION flood_col(p_tbl text, p_role text)
RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$
DECLARE v_col text; v_std text;
BEGIN
  SELECT column_name INTO v_col FROM flood_layer_column_map WHERE table_name=p_tbl AND col_role=p_role;
  IF v_col IS NOT NULL THEN RETURN v_col; END IF;
  v_std := CASE p_role WHEN 'zone' THEN 'fld_zone' WHEN 'sfha' THEN 'sfha_tf'
                       WHEN 'bfe' THEN 'static_bfe' WHEN 'subty' THEN 'zone_subty'
                       WHEN 'datum' THEN 'v_datum' END;
  IF v_std IS NOT NULL AND EXISTS (SELECT 1 FROM information_schema.columns
       WHERE table_schema='public' AND table_name=p_tbl AND column_name=v_std) THEN
    RETURN v_std;
  END IF;
  RETURN NULL;
END $$;
GRANT EXECUTE ON FUNCTION flood_col(text,text) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION get_parcel_flood_zone(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
 SET search_path TO 'public','pg_temp' SET statement_timeout TO '20s'
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
  v_geom := ST_MakeValid(v_geom);

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

  -- FAIL CLOSED: no readable zone column -> we cannot read the layer. Never emit a
  -- false "not in SFHA"; report a coverage gap instead.
  IF v_zone IS NULL THEN
    RETURN jsonb_build_object('field','flood_zone','field_status','not_available','in_sfha',NULL,'zones',NULL,
      'county_layer_status', format('The held layer %s has no recognisable flood-zone column; not evaluated.', r.table_name),
      'coverage_caveat','COVERAGE GAP, NOT A FINDING. The county layer could not be read; this is not a statement that the parcel is outside a Special Flood Hazard Area. Check msc.fema.gov.',
      'source','FEMA National Flood Hazard Layer','authority','FEMA');
  END IF;

  v_subty_expr := CASE WHEN v_subty_c IS NOT NULL THEN format('nullif(trim(f.%I),'''')', v_subty_c) ELSE 'NULL::text' END;
  v_bfe_expr   := CASE WHEN v_bfe_c   IS NOT NULL THEN format('nullif(f.%I::numeric, -9999)', v_bfe_c) ELSE 'NULL::numeric' END;
  v_datum_expr := CASE WHEN v_datum_c IS NOT NULL THEN format('nullif(trim(f.%I),'''')', v_datum_c) ELSE 'NULL::text' END;
  -- in_sfha: authoritative flag when present; else derive from the zone CODE.
  v_sfha_expr  := CASE WHEN v_sfha_c IS NOT NULL
      THEN format('(upper(trim(f.%I)) = ''T'')', v_sfha_c)
      ELSE format('(upper(trim(f.%I)) IN (''A'',''AE'',''AH'',''AO'',''AR'',''A99'',''V'',''VE'') OR upper(trim(f.%I)) ~ ''^(A|V)[0-9]{1,2}$'')', v_zone, v_zone)
      END;

  EXECUTE format($q$
    SELECT jsonb_agg(x ORDER BY (x->>'pct_of_parcel')::numeric DESC), bool_or(sf), max(bf), max(vd)
    FROM (SELECT jsonb_build_object(
            'zone', f.%1$I,
            'subtype', %2$s,
            'in_sfha', %3$s,
            'base_flood_elevation_ft', %4$s,
            'pct_of_parcel', round((100*ST_Area(ST_Intersection(CASE WHEN ST_IsValid(f.geom) THEN f.geom ELSE ST_MakeValid(f.geom) END,$1)::geography)
                                    /nullif(ST_Area($1::geography),0))::numeric,1)) AS x,
            %3$s AS sf, %4$s AS bf, %5$s AS vd
          FROM %6$I f
         WHERE f.geom && $1 AND ST_Intersects(CASE WHEN ST_IsValid(f.geom) THEN f.geom ELSE ST_MakeValid(f.geom) END,$1)) s
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

-- Durable regression guard: the -9999 BFE sentinel must never render as a number.
-- Test parcel 720700000010 (Volusia) sits 73.7% in a Zone A polygon whose raw static_bfe is -9999.
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition, attribution_evidence,
  disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'flood-bfe-9999-sentinel-served-null',
 'FEMA static_bfe = -9999 is a "no BFE" sentinel, not an elevation — the served flood path must render it as null, never as the number -9999 (Part J sentinel class)',
 CURRENT_DATE,
 'Item 80 step 2 — schema-adaptive get_parcel_flood_zone; regression guard so the nullif is not lost when BFE columns are remapped per layer',
 'null_as_value', 'material',
 $det$SELECT NOT EXISTS (SELECT 1 FROM jsonb_array_elements(get_parcel_flood_zone(74,'720700000010')->'zones') z WHERE (z->>'base_flood_elevation_ft') = '-9999') AS ok$det$,
 'flood zones returned by get_parcel_flood_zone for a parcel over a -9999 BFE polygon',
 'Test parcel 720700000010 (Volusia) sits 73.7% in a Zone A polygon whose raw static_bfe is -9999; if the served BFE for any zone ever equals -9999 the sentinel guard has regressed. ok=true means the served path nulls it.',
 'active', 'source', 'repair',
 'Verified 2026-08-08: raw layer has static_bfe=-9999 on the intersecting Zone A polygon; served base_flood_elevation_ft is null. Guard is nullif(<bfe_col>::numeric,-9999) in get_parcel_flood_zone, applied to whatever column flood_col() maps to BFE.',
 'BFE shown only where FEMA records one; -9999 (no BFE established) renders as null, not a number.',
 'flood-bfe-never-renders-9999-sentinel', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence, status=EXCLUDED.status;
