-- =============================================================================
-- handoff id 17 (ruling #3): register naming debt, do NOT fix.
-- county_layer_registry becomes misnamed once the hierarchy walk adds admin_level
-- 0/1 rows (contamination step). Rename now = churn: get_parcel_sinkhole_facts and
-- resolve_layer reference it by name. Placeholder detection until a rename is scheduled.
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  status, attribution, disposition, false_positive_notes, disclosure_text, harness_predicate)
VALUES (
 'county-layer-registry-misnamed-for-multilevel',
 'county_layer_registry becomes misnamed once it holds admin_level 0 (country) and 1 (state) rows for the hierarchy walk — no longer county-only. Rename deferred (churn): get_parcel_sinkhole_facts and resolve_layer reference it by name. Eventual target e.g. layer_registry.',
 CURRENT_DATE, 'handoff id 17 ruling — hierarchy walk',
 'entity_confusion','cosmetic',
 $det$SELECT true AS ok$det$,
 'active','ours','disclose',
 'Tech-debt marker, not a data error; detection is a placeholder true until a rename is scheduled. Referencing objects: get_parcel_sinkhole_facts, resolve_layer.',
 'Once admin_level 0/1 rows are added, the name county_layer_registry describes only a subset of its contents.',
 'registry-name-matches-its-scope')
ON CONFLICT (defect_id) DO NOTHING;
