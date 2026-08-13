-- =============================================================================
-- Stage 1, Step 2 (handoff id 13): the generalised resolver.
--
-- A served function must resolve which layer applies to a parcel, not name its
-- tables. resolve_layer(geo_id, concept) is the single mechanism, unifying the
-- pattern get_parcel_sinkhole_facts already uses (reads county_layer_registry)
-- with get_parcel_flood_zone's rigor.
--
--   layer_column_map(table_name, col_role, column_name) — generalises
--     flood_layer_column_map: per-layer semantic column names (zone/sfha/bfe/...),
--     because names lie and the flood selector skipped 9 counties by matching
--     standard names. Populated per concept AT WIRE TIME after content verification.
--
--   resolve_layer(p_geo_id, p_concept) -> jsonb, THREE states never two:
--     present       — a layer with row_count>0 resolved; returns table_name, the
--                     generic keys (key_column/bridge_key/key_transform/srid) and
--                     the column_map.
--     none_recorded — a layer IS registered for this (county,concept) but holds 0
--                     rows (e.g. hospitals: 67 rows, all row_count 0).
--     not_available — no layer held (or geo not resolvable at this admin level).
--   A not_available carries null, never false; callers add who-can-answer.
--
-- Design notes:
--  * Keyed on geo_id via geo_reference (admin_level 2 = county, name matches
--    county_layer_registry.county). State-level geo_ids (US-12) return
--    not_available here — statewide concepts (contamination) get their state-level
--    source when that concept is migrated; this function is the county spine.
--  * row_count>0 guard, mirroring get_parcel_sinkhole_facts.
--  * verified_at is NOT trusted for freshness — every registry row carries a single
--    2026-07-24 build stamp. Content is re-verified at WIRE TIME (interior-point
--    test per concept migration), which updates row_count and the column_map.
--    resolve_layer itself is a fast read; it does not scan the layer per request.
-- =============================================================================
CREATE TABLE IF NOT EXISTS layer_column_map (
  table_name  text NOT NULL,
  col_role    text NOT NULL,
  column_name text NOT NULL,
  note        text,
  verified_at timestamptz,
  PRIMARY KEY (table_name, col_role)
);

CREATE OR REPLACE FUNCTION resolve_layer(p_geo_id text, p_concept text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE v_name text; v_admin int; v_co int; r record; v_cmap jsonb;
BEGIN
  SELECT name, admin_level, dor_co_no INTO v_name, v_admin, v_co
    FROM geo_reference WHERE geo_id = p_geo_id LIMIT 1;
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'state','not_available',
      'table_name',NULL,'column_map',NULL,'note','Unknown geo_id.');
  END IF;

  SELECT table_name, key_column, bridge_key, key_transform, srid, row_count
    INTO r
    FROM county_layer_registry
   WHERE concept = p_concept AND lower(county) = lower(v_name)
   ORDER BY (COALESCE(row_count,0) > 0) DESC, row_count DESC NULLS LAST
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'geo_name',v_name,'admin_level',v_admin,
      'state','not_available','table_name',NULL,'column_map',NULL,
      'note', CASE WHEN v_admin < 2
        THEN 'Not resolvable at this admin level via county_layer_registry (county-keyed); statewide concepts need a state-level source.'
        ELSE 'No layer is held for this county and concept.' END);
  END IF;

  IF COALESCE(r.row_count,0) = 0 THEN
    RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'geo_name',v_name,'admin_level',v_admin,
      'state','none_recorded','table_name',r.table_name,'column_map',NULL,
      'note','A layer is registered for this county and concept but holds no rows (row_count=0).');
  END IF;

  SELECT jsonb_object_agg(col_role, column_name) INTO v_cmap FROM layer_column_map WHERE table_name = r.table_name;

  RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'geo_name',v_name,'admin_level',v_admin,'co_no',v_co,
    'state','present','table_name',r.table_name,'key_column',r.key_column,'bridge_key',r.bridge_key,
    'key_transform',r.key_transform,'srid',r.srid,'row_count',r.row_count,
    'column_map', COALESCE(v_cmap,'{}'::jsonb));
END $fn$;
GRANT EXECUTE ON FUNCTION resolve_layer(text,text) TO anon, authenticated, service_role;
