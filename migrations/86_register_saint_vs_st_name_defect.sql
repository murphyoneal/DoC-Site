-- =============================================================================
-- handoff 27b: register the county-name mismatch surfaced by the sinkhole migration.
-- Exactly two rows in county_registry spell a county "Saint X" where geo_reference
-- and the layer registries spell it "St. X":
--   dor_co_no 65  county_registry "Saint Johns"  vs geo_reference "St. Johns"
--   dor_co_no 66  county_registry "Saint Lucie"  vs geo_reference "St. Lucie"
-- Any resolver that matched a layer by comparing a name against
-- county_registry.county_name served a FALSE not_available for these two counties
-- over layers that exist (get_parcel_sinkhole_facts did, now repointed to co_no).
--
-- DO NOT repair by editing the names yet (handoff 27): a name edit could break other
-- joins not yet enumerated. Register; decide the repair separately. The permanent fix
-- for resolvers is keying on co_no/geo_id, not names (see the standing rule).
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'county-name-saint-vs-st',
 'county_registry.county_name spells two counties "Saint Johns"/"Saint Lucie" while geo_reference.name and the layer registries spell them "St. Johns"/"St. Lucie". Any layer resolution that matches by name against county_registry silently returns not_available for these two counties over data that exists.',
 CURRENT_DATE, 'handoff 25/27 — surfaced by the sinkhole resolver migration',
 'entity_confusion','material',
 $det$SELECT NOT EXISTS (SELECT 1 FROM county_registry cr JOIN geo_reference g ON g.dor_co_no = cr.dor_county_no::int AND g.admin_level=2 WHERE cr.dor_county_no ~ '^[0-9]+$' AND lower(cr.county_name) <> lower(g.name)) AS ok$det$,
 'All 67 counties: county_registry.county_name compared to geo_reference.name on dor_co_no.',
 'Reads ok=false while any county name disagrees (2 today: 65, 66). Not a false positive; it is the standing monitor for the mismatch and flips clean when the names are reconciled OR every consumer keys on co_no/geo_id.',
 'active','ours','repair',
 E'Blast radius (measured, handoff 27): the mismatch is EXACTLY two counties (65, 66). Three functions reference a registry and a county name: get_parcel_sinkhole_facts (fixed 2026-08-08, keys by co_no), discover_county_layers (matched by name but discovery was NOT skipped — St. Johns 28 registry rows, St. Lucie 31, both above the 24.2 average), and daily_ops_report. Damage was bounded to resolution/lookup, not ingest. Do not edit county_registry names yet — unenumerated joins may depend on the current spelling.',
 NULL,
 'county-registry-names-match-geo-reference', ARRAY[65,66]::numeric[])
ON CONFLICT (defect_id) DO UPDATE SET
  detection_sql=EXCLUDED.detection_sql,
  attribution_evidence=EXCLUDED.attribution_evidence;
