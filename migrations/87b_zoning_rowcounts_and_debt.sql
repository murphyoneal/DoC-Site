-- =============================================================================
-- Completes migration 87a.
-- (1) Populate layer_resolution.row_count for the zoning/land_use rows (content, not
--     names). The compatibility view + _zoning_lookup do NOT read row_count, so this
--     changes no served output; it makes the rows valid resolver rows for the future
--     resolve_layer. De-selected rows keep NULL. Idempotent.
-- (2) Extend the compat-views-pending-retirement debt (handoff 25) to include the new
--     view zoning_layer_selection and its reader _zoning_lookup, so the detection keeps
--     failing until this bridge is dismantled too.
-- =============================================================================
SET statement_timeout = 0;

DO $$
DECLARE r record; n bigint;
BEGIN
  FOR r IN SELECT id, table_name FROM layer_resolution
           WHERE concept IN ('zoning','land_use') AND table_name IS NOT NULL AND row_count IS NULL LOOP
    BEGIN
      EXECUTE format('SELECT count(*) FROM public.%I', r.table_name) INTO n;
      UPDATE layer_resolution SET row_count = n WHERE id = r.id;
    EXCEPTION WHEN others THEN
      -- a missing/unreadable layer table: leave row_count NULL, do not fail the migration
      NULL;
    END;
  END LOOP;
END $$;

UPDATE data_defect_registry SET
  detection_sql = $det$SELECT NOT EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname = ANY(ARRAY['flood_layer_selection','flood_layer_column_map','zoning_layer_selection'])) AS ok$det$,
  attribution_evidence = E'Compatibility views pending retirement:\n  flood_layer_selection  (2026-08-08, migration 83a) -> readers: get_parcel_flood_zone, get_county_coverage, detect_flood_layer_wrong_county, detect_invalid_served_flood_geometry, detect_unwired_firm_layers\n  flood_layer_column_map (2026-08-08, migration 83a) -> reader: flood_col\n  zoning_layer_selection (2026-08-08, migration 87a) -> reader: _zoning_lookup\nCondition for dropping: all listed readers repointed to layer_resolution / layer_column_map, done in one pass per bespoke reader so each is touched once. county_layer_registry is NOT in this set: it is a base table serving many concepts and becomes a view only when its last concept leaves; migrated concepts (sinkhole) repoint their reader and delete their rows from it instead.'
WHERE defect_id = 'compat-views-pending-retirement';
