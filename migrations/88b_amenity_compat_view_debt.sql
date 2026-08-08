-- =============================================================================
-- Completes migration 88a: extend the compat-views-pending-retirement debt to list
-- the new view amenity_registry and its reader get_nearby_amenities, so the detection
-- keeps failing until this bridge is dismantled too.
-- =============================================================================
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT NOT EXISTS (SELECT 1 FROM pg_views WHERE schemaname='public' AND viewname = ANY(ARRAY['flood_layer_selection','flood_layer_column_map','zoning_layer_selection','amenity_registry'])) AS ok$det$,
  attribution_evidence = E'Compatibility views pending retirement:\n  flood_layer_selection  (migration 83a) -> readers: get_parcel_flood_zone, get_county_coverage, detect_flood_layer_wrong_county, detect_invalid_served_flood_geometry, detect_unwired_firm_layers\n  flood_layer_column_map (migration 83a) -> reader: flood_col\n  zoning_layer_selection (migration 87a) -> reader: _zoning_lookup\n  amenity_registry       (migration 88a) -> reader: get_nearby_amenities\nCondition for dropping each: its reader(s) repointed to concept_registry / layer_resolution / layer_column_map, one pass per reader so each is touched once. county_layer_registry is NOT in this set: it is a base table serving many concepts and becomes a view only when its last concept leaves; migrated concepts (sinkhole) repoint their reader and delete their rows from it instead.'
WHERE defect_id = 'compat-views-pending-retirement';
