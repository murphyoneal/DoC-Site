-- =============================================================================
-- handoff 56: register the mis-mapped-column defect CLASS (distinct from a junk layer).
-- A mis-map passes every structural test — right county, right geometry, populated
-- column, plausible strings — and is caught only by asking whether the VALUES are the
-- kind of thing the concept means. Heuristic: cardinality vs expected vocabulary size.
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition, expected_state,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'resolver-column-mismapped-to-wrong-semantics',
 'A resolver column mapping (layer_column_map) can point at the WRONG column: right county, right geometry, populated, plausible strings — but the VALUES are not what the concept means. Santa Rosa zoning served petition numbers (rezone_, 1076 distinct) where the district code lives (district, 66). Detection heuristic: cardinality vs expected vocabulary size — a code column far above a plausible code list is likely a case/id column.',
 CURRENT_DATE, 'handoff 56 — Santa Rosa zoning verification',
 'resolution_mislabelling','material',
 $det$SELECT (get_parcel_zoning_facts(67,'14-1N-29-0075-00G00-0040')->'zoning'->>'value') !~ '^(PZ-|[0-9]{4}-[A-Z]-)' AS ok$det$,
 'Served-path canary: the Santa Rosa proof parcel must serve a real zoning district, not a petition/case number.',
 'Served-path canary on the fixed Santa Rosa case (now R3, not 2004-R-049). General heuristic: cardinality of a code column vs the concept vocabulary size (zoning ~<150; >300 likely a case/id/parcel column) — cheap to run when wiring any coded layer. Third semantic catch this week; structure catches none.',
 'active','ours','repair','clean',
 'Instance fixed 2026-08-09 (migration 96a). Class registered so the next mis-map is looked for.',
 NULL, 'resolver-columns-value-verified', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, expected_state=EXCLUDED.expected_state, attribution_evidence=EXCLUDED.attribution_evidence;
