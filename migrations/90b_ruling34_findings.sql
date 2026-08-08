-- =============================================================================
-- handoff 34 findings.
-- (1) The registry row_count stamp is unreliable as a PRESENCE signal in BOTH
--     directions. It is a single 2026-07-24 build date, not per-layer freshness, and
--     it both overcounts (stale rows since emptied) and — the dangerous direction —
--     UNDERCOUNTS: school_zones read as 7-with-data from the stamp but is 25 live,
--     so trusting the stamp silently withholds coverage we actually hold. Register as
--     a defect; the permanent fix is refreshing row_count from live tables at wire time.
-- (2) CAMA is a relational table-set keyed to parcels with no geometry; it does NOT
--     fit (geo_id, concept) -> one layer and needs its OWN resolution mechanism. Logged
--     to build_backlog (design work), not forced into layer_resolution.
-- =============================================================================

INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'registry-rowcount-stamp-unreliable',
 'county_layer_registry.row_count / verified_at is a single build-date stamp (2026-07-24), not per-layer freshness. It is unreliable as a presence signal in BOTH directions: it overcounts (rows emptied since) and undercounts (layers that gained rows since). The undercount is the dangerous one — it silently withholds held coverage (school_zones stamped 7-with-data, actually 25 live).',
 CURRENT_DATE, 'handoff 34 — Phase 1 content verification vs the stamp',
 'temporal','material',
 $det$SELECT (SELECT count(DISTINCT verified_at) FROM county_layer_registry) > 1 AS ok$det$,
 'county_layer_registry: distinct verified_at values.',
 'Reads ok=false while every registry row shares one verified_at (proving it is a single build stamp, not per-layer freshness). Not a false positive; it flips clean only when row_count/verified_at are refreshed per layer from live tables. Resolver migrations already refresh row_count from the live table at wire time (flood 83b, zoning 87b, phase-1 89a), which is the fix moving forward.',
 'active','ours','repair',
 'Measured 2026-08-08: school_zones stamped 7 counties-with-data, live 25 (22 usable + 3 district-junk). The stamp undercounted by 18. Any presence/coverage decision made from county_layer_registry.row_count without a live re-count is unsafe.',
 NULL, 'registry-rowcount-refreshed-per-layer', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence;

INSERT INTO build_backlog (item_no, title, priority, status, spec_ref, evidence)
SELECT COALESCE(max(item_no),0)+1,
 'CAMA relational-set resolution mechanism (distinct from layer_resolution)',
 'medium','open','handoff 34',
 E'CAMA is a relational table-set keyed to parcels with NO geometry — it does not fit (geo_id,concept)->one spatial layer and must not be forced into layer_resolution (same category error as amenity_registry). Needs its own registry: which counties have a CAMA export, which sub-tables it contains, and the parcel key. Phase-1 recorded 20 verdict rows (kind=relational) as a record but de-scoped cama from the get_pir_report resolver wiring; the Volusia CAMA scalar reads stay inline for now. The CAMA probe already measured Lee 111 cols, Duval 24, Pasco 17 (all relational, none iasWorld) — this is where that lands.'
FROM build_backlog;