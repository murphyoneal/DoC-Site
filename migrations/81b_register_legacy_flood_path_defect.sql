-- =============================================================================
-- handoff id 14: register (do NOT fix) the legacy flood path.
-- Flood is served two ways with different truthfulness — get_parcel_flood_zone
-- (authoritative, per-county FIRM) vs get_site_intelligence / get_parcel_env_findings
-- / get_area_findings / get_pir_map_geojson, which read the page-truncated
-- fema_flood_zones (registered defect fema-flood-zones-page-truncated). A parcel
-- that is authoritative-SFHA can read null/negative on the legacy path.
-- Served-path detection: no definite negative in a no-coverage county (Miami-Dade).
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition, attribution_evidence,
  disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'served-flood-legacy-fema-flood-zones',
 'Flood is served two ways with different truthfulness: get_parcel_flood_zone (authoritative, per-county FIRM via flood_layer_selection) vs the legacy path through get_site_intelligence, which reads the page-truncated fema_flood_zones. Same concept, divergent answers — a parcel authoritative-SFHA can read null/negative on the legacy path.',
 CURRENT_DATE, 'handoff id 14 — legacy flood-path audit',
 'entity_confusion','material',
 $det$SELECT (s.in_flood_hazard_area IS DISTINCT FROM false) AS ok FROM get_site_intelligence(23,'0141280040170') s$det$,
 'get_site_intelligence flood fields for a real parcel in a county with no fema_flood_zones coverage (Miami-Dade)',
 'Served-path guard: ok=false if the legacy path emits a DEFINITE negative (in_flood_hazard_area=false) in a no-coverage county. Reads clean today (Miami-Dade returns null, honest) but the root — a served function depending on a known-truncated table — persists; the guard fires on the harmful manifestation. Class entity_confusion (one concept, two served representations that disagree); root cause is the completeness defect fema-flood-zones-page-truncated.',
 'active','ours','repair',
 'Served functions reading fema_flood_zones (2026-08-08): get_site_intelligence, get_parcel_env_findings, get_area_findings, get_pir_map_geojson (the map — can render wrong/absent flood while the report is correct). Repair: repoint all four at get_parcel_flood_zone / the resolver. Miami-Dade has 0 fema_flood_zones coverage yet get_parcel_flood_zone serves it from miamidade_flood_zones.',
 'Where flood appears outside the authoritative flood block (site summary, area findings, map), it may be drawn from an incomplete legacy layer; the authoritative determination is get_parcel_flood_zone.',
 'served-flood-single-authoritative-source', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence, disclosure_text=EXCLUDED.disclosure_text;
