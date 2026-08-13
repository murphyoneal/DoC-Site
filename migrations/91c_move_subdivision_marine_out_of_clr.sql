-- =============================================================================
-- handoff 36 Phase 2: after wiring subdivisions + marine to layer_resolution (91a/91b),
-- remove their now-redundant rows from the shared county_layer_registry (single source
-- of truth), as sinkhole did. county_layer_registry is a base table serving many
-- concepts (41 distinct concepts / 1584 rows remain after this), so it does NOT become
-- a compatibility view yet — it will only when its last concept leaves.
-- =============================================================================
DELETE FROM county_layer_registry WHERE concept IN ('subdivisions','marine');
