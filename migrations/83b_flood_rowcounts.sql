-- =============================================================================
-- Completes migration 83a: populate layer_resolution.row_count for the flood rows.
-- The compatibility-view path (get_parcel_flood_zone) does NOT read row_count, so
-- this changes no served output. It exists so the flood rows are VALID resolver
-- rows: when resolve_layer is later pointed at layer_resolution, a present layer
-- must have row_count>0 (else it would classify none_recorded). Counts are read
-- from the actual layer (content, not names). De-selected rows (table_name NULL)
-- keep row_count NULL. Idempotent: re-running recomputes.
-- =============================================================================
SET statement_timeout = 0;
DO $$
DECLARE r record; n bigint;
BEGIN
  FOR r IN SELECT id, table_name FROM layer_resolution
           WHERE concept='flood' AND table_name IS NOT NULL LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', r.table_name) INTO n;
    UPDATE layer_resolution SET row_count = n WHERE id = r.id;
  END LOOP;
END $$;
