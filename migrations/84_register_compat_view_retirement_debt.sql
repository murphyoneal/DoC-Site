-- =============================================================================
-- handoff 25: register the debt that the compatibility-view technique creates.
-- A compatibility view is a BRIDGE, not a destination. After migration 83a the
-- count of moving parts went UP: three registry tables + two views standing in for
-- the old flood tables, with six readers still addressing the OLD names. Fragmentation
-- is not removed until the readers address layer_resolution/layer_column_map directly
-- and the views are dropped. This defect makes the bridge impossible to forget: its
-- detection FAILS (ok=false) for as long as any view in the set still exists.
--
-- Deliberately not fixed now. The views stay until ALL concepts are migrated and the
-- readers are repointed in ONE pass — repointing piecemeal would touch
-- get_parcel_flood_zone twice. Note also (handoff 25): county_layer_registry is a
-- BASE TABLE serving many concepts, so it cannot be swapped to a view after one
-- concept leaves; it becomes a view only when its LAST concept leaves. Concepts that
-- migrate registry-to-registry (sinkhole, zoning) repoint their reader instead.
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'compat-views-pending-retirement',
 'Resolver migration leaves compatibility views standing in for migrated bespoke tables (flood_layer_selection, flood_layer_column_map over layer_resolution/layer_column_map). Fragmentation is not removed until every reader addresses the registry directly and the views are dropped. The bridge must not become permanent.',
 CURRENT_DATE, 'handoff 25 — flood migration review',
 'entity_confusion','material',
 $det$SELECT NOT EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname = ANY(ARRAY['flood_layer_selection','flood_layer_column_map'])) AS ok$det$,
 'The set of compatibility views created by resolver migrations (currently the two flood views).',
 'By design this reads ok=false (defect present) TODAY — the views exist on purpose as the bridge. It is not a false positive; it is a standing reminder that flips to clean only when the bridge is dismantled. Add each new compatibility view to the ARRAY as concepts migrate.',
 'active','ours','repair',
 E'Compatibility views pending retirement (2026-08-08, migration 83a):\n  flood_layer_selection  -> readers still addressing old name: get_parcel_flood_zone, get_county_coverage, detect_flood_layer_wrong_county, detect_invalid_served_flood_geometry, detect_unwired_firm_layers\n  flood_layer_column_map -> readers still addressing old name: flood_col\nCondition for dropping BOTH: all listed readers repointed to layer_resolution / layer_column_map (done in one pass, so get_parcel_flood_zone is touched once). county_layer_registry is NOT in this set: it is a base table serving many concepts and becomes a view only when its last concept leaves; migrated concepts (sinkhole, zoning) repoint their reader and delete their rows from it instead.',
 NULL,
 'compat-views-all-readers-repointed', NULL)
ON CONFLICT (defect_id) DO UPDATE SET
  detection_sql=EXCLUDED.detection_sql,
  attribution_evidence=EXCLUDED.attribution_evidence,
  false_positive_notes=EXCLUDED.false_positive_notes;
