-- =============================================================================
-- handoff 42: the three formerly-unserved contamination concepts are now surfaced
-- through resolve_layer (source_water in get_parcel_restrictions; drycleaning + stcm in
-- get_parcel_contamination_facilities via _contam_points_resolved). Because serving is
-- resolver-driven, the table names never appear literally in any function source, so the
-- old source-grep detection can never read clean. Replace it with a SERVED-PATH check
-- that exercises the actual output on known parcels — the strong form of detection.
-- =============================================================================
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT
     (EXISTS (SELECT 1 FROM jsonb_array_elements(get_parcel_restrictions(74,'320500000021')) e WHERE e->>'field'='source_water_protection'))
 AND (COALESCE((get_parcel_contamination_facilities(16,'494330012860')->'area_context'->>'drycleaning_sites_within_1mi')::int,0) > 0)
 AND (COALESCE((get_parcel_contamination_facilities(16,'473825000000')->'area_context'->>'stcm_points_within_500m')::int,0) > 0) AS ok$det$,
  false_positive_notes = 'Served-path check: exercises get_parcel_restrictions (source_water) and get_parcel_contamination_facilities (drycleaning, stcm) on known parcels that have each. ok=true means all three are actually surfaced. Superseded the source-grep form, which cannot see resolver-driven serving (the table names are resolved at runtime via resolve_layer, not named in source).',
  attribution_evidence = attribution_evidence || ' RESOLVED 2026-08-08 (handoff 42): all three surfaced via resolve_layer — source_water as a Ch. 62-524 restriction (contains), drycleaning (1mi) + stcm (500m) as contamination-facility proximity. Volusia 28-section baseline unchanged.'
WHERE defect_id = 'contamination-concepts-registered-but-unserved';
