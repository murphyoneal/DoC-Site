-- =============================================================================
-- handoff 38 #2: register the single-county geometry-assumption class (not just the bug).
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'resolver-single-county-geometry-assumptions',
 'Resolver helpers derived from one county''s inline read carry that county''s geometry/SRID/column/value conventions and misfire on other counties. Instance: some county boat-ramp layers are MULTIPOINT where the Volusia inline read assumed POINT, so ST_Azimuth threw. General rule: a helper must coerce (ST_Centroid/ST_SetSRID/typed cast), not assume, because the origin county is not representative.',
 CURRENT_DATE, 'handoff 38 — Phase 2 marine wiring',
 'geometry','material',
 $det$SELECT count(*)=0 AS ok FROM layer_resolution lr JOIN geometry_columns gc ON gc.f_table_name=lr.table_name AND gc.f_geometry_column=COALESCE(lr.geom_column,'geom') WHERE lr.kind='point' AND lr.table_name IS NOT NULL AND gc.type <> 'POINT'$det$,
 'Point-kind layer_resolution rows whose PostGIS geometry_columns.type is not strictly POINT.',
 'Reads ok=false when a point-concept layer is stored as MULTIPOINT or generic GEOMETRY (needs coercion). Catches typed columns; generic GEOMETRY columns can still hold mixed types and must be coerced at read time regardless. get_parcel_boat_ramps_resolved already coerces via ST_Centroid; this monitors the class as more point concepts are wired.',
 'active','ours','transform_on_ingest',
 'Instance fixed 2026-08-08 in get_parcel_boat_ramps_resolved (ST_Centroid coercion). The rule generalises: every resolver helper coerces geometry type + SRID rather than trusting the origin county''s conventions. Same shape as SRID-0, EPSG:3087 mining layers, Hardee''s HTML-anchor parcel id.',
 NULL, 'resolver-helpers-coerce-geometry', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence;
