-- =============================================================================
-- Rulings 116/117/131 — split layer_resolution.verified (one flag asserting THREE claims, true on all 316
-- rows while false for half of them on two of the three) into three checkable flags. ADDITIVE: verified is
-- read by resolve_layer (the core resolver), get_parcel_sinkhole_facts, zoning_layer_selection and
-- dataset_audit, so it is KEPT and only its MEANING is narrowed by comment — renaming a column the resolver
-- depends on ahead of its consumers is the payload-shape rule applied to a column (ruling 131 Q1).
--
-- Ruling 131's load-bearing half: the PRODUCERS are the deliverable, not the columns. A flag written once
-- and read forever becomes a lie the moment the world moves — which is exactly how verified drifted. So
-- refresh_layer_trust_flags() recomputes both from live truth, is scheduled (110a-style pg_cron), and a
-- detection fires if either column goes STALE. NULL = NOT YET COMPUTED (never false); a layer inserted
-- tomorrow reads NULL until a producer runs. source_known is for VISIBILITY, NOT a serving gate.
-- =============================================================================
ALTER TABLE layer_resolution ADD COLUMN IF NOT EXISTS source_known   boolean;
ALTER TABLE layer_resolution ADD COLUMN IF NOT EXISTS geometry_valid boolean;

COMMENT ON COLUMN layer_resolution.verified IS
  'RESOLVES ONLY: the layer resolved and its contents were read. NOT a source or geometry assurance — see source_known / geometry_valid. (Historically this one flag conflated all three; rulings 116/117/131.)';
COMMENT ON COLUMN layer_resolution.source_known IS
  'Has a registered, reachable, refreshable source in data_source_registry (derived_from counts — ruling 123). NULL = not yet computed. VISIBILITY FLAG, NOT A SERVING GATE: ~94/303 served tables read false and serve correctly; resolve_layer must never gate on this. Producer: refresh_layer_trust_flags().';
COMMENT ON COLUMN layer_resolution.geometry_valid IS
  'Three-state: true = 0 invalid geometry (latest audit / repair log), false = holds invalid geometry, NULL = non-spatial OR not yet computed. Never render NULL as false. Producer: refresh_layer_trust_flags() over dataset_content_audit_latest + geometry_repair_log.';

-- PRODUCER. source_known from the registry (kept in sync by the daily 06:15 provenance sync); geometry_valid
-- three-state from geometry_columns (is it spatial at all) + geometry_repair_log (repaired => valid) +
-- dataset_content_audit_latest (measured). A spatial layer never audited and never repaired reads NULL —
-- honestly not-established, not a false assurance.
CREATE OR REPLACE FUNCTION public.refresh_layer_trust_flags()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_src int; v_geom int;
BEGIN
  UPDATE layer_resolution lr
     SET source_known = EXISTS (SELECT 1 FROM data_source_registry r WHERE r.table_name = lr.table_name)
   WHERE lr.table_name IS NOT NULL;
  GET DIAGNOSTICS v_src = ROW_COUNT;

  UPDATE layer_resolution lr
     SET geometry_valid = CASE
        WHEN NOT EXISTS (SELECT 1 FROM geometry_columns gc
                         WHERE gc.f_table_schema='public' AND gc.f_table_name=lr.table_name) THEN NULL
        WHEN EXISTS (SELECT 1 FROM geometry_repair_log g
                     WHERE g.table_name=lr.table_name AND g.invalid_after=0) THEN true
        WHEN EXISTS (SELECT 1 FROM dataset_content_audit_latest a
                     WHERE a.table_name=lr.table_name AND a.geom_invalid=0) THEN true
        WHEN EXISTS (SELECT 1 FROM dataset_content_audit_latest a
                     WHERE a.table_name=lr.table_name AND a.geom_invalid>0) THEN false
        ELSE NULL
      END
   WHERE lr.table_name IS NOT NULL;
  GET DIAGNOSTICS v_geom = ROW_COUNT;

  RETURN jsonb_build_object('source_known_updated', v_src, 'geometry_valid_updated', v_geom, 'refreshed_at', now());
END $fn$;

-- backfill now
SELECT public.refresh_layer_trust_flags();
