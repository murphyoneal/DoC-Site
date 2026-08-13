-- =============================================================================
-- handoff 47 pass 2: (D) rehome the 5 bare-count measurements to statewide_metrics with
-- their method SQL, then retire the predicates; (E) retire 2 stale, preserving knowledge;
-- (F) DEF-014 -> build_backlog + retire. Retiring never deletes: knowledge moves to
-- statewide_metrics, build_backlog, or a replacement.
-- =============================================================================
INSERT INTO statewide_metrics (metric_key, value_numeric, unit, method_sql, inputs, caveat, computed_at, is_floor)
VALUES
 ('volusia_parcels_unpublished_vs_assessed',
  (SELECT count(*) FROM volusia_cama_parcel WHERE "ROLLTYPE"='REAL') - (SELECT count(*) FROM volusia_parcels_govt_source),
  'parcels','SELECT (SELECT count(*) FROM volusia_cama_parcel WHERE "ROLLTYPE"=''REAL'') - (SELECT count(*) FROM volusia_parcels_govt_source)',
  'volusia_cama_parcel (ROLLTYPE=REAL) vs volusia_parcels_govt_source',
  'REAL-rolltype CAMA parcels Volusia assesses but does not publish as GIS polygons. Coverage measurement, not a defect (ex DEF-019).', now(), false),
 ('counties_in_properties_table',
  (SELECT count(DISTINCT county_name) FROM properties),'counties','SELECT count(DISTINCT county_name) FROM properties','properties',
  'Distinct counties represented in the properties table (ex DEF-021).', now(), true),
 ('fuds_property_boundaries_count',
  (SELECT count(*) FROM fuds_property_boundaries),'boundaries','SELECT count(*) FROM fuds_property_boundaries','fuds_property_boundaries',
  'FUDS (formerly used defense sites) property boundaries held (ex DEF-022).', now(), false),
 ('volusia_marine_improvement_rows',
  (SELECT count(*) FROM volusia_cama_misc WHERE "MICODE" IN ('DOC','SEW','BHS','BL1','BSL')),'rows',
  'SELECT count(*) FROM volusia_cama_misc WHERE "MICODE" IN (''DOC'',''SEW'',''BHS'',''BL1'',''BSL'')','volusia_cama_misc',
  'Volusia CAMA misc rows coded as marine improvements (docks/seawalls/boathouses/boatlifts/boat slips) (ex DEF-023).', now(), false),
 ('fdep_clm_cattle_dip_vat_rows',
  (SELECT count(*) FROM fdep_clm WHERE business_name ILIKE '%vat%' OR business_name ILIKE '%dip%'),'sites',
  'SELECT count(*) FROM fdep_clm WHERE business_name ILIKE ''%vat%'' OR business_name ILIKE ''%dip%''','fdep_clm',
  'Arsenical cattle-dip vat sites discoverable in fdep_clm by name (FLOOR — most of the ~3,200 historic vats are in no spatial register) (ex cattle-dip-vats-non-spatial-historic).', now(), true)
ON CONFLICT (metric_key) DO UPDATE SET value_numeric=EXCLUDED.value_numeric, method_sql=EXCLUDED.method_sql, inputs=EXCLUDED.inputs, caveat=EXCLUDED.caveat, computed_at=now();

UPDATE data_defect_registry SET status='retired',
  false_positive_notes='RETIRED 2026-08-08 (handoff 47): a measurement, not a pass/fail defect. Knowledge preserved in statewide_metrics with its method SQL.'
WHERE defect_id IN ('DEF-019','DEF-021','DEF-022','DEF-023','cattle-dip-vats-non-spatial-historic');

UPDATE data_defect_registry SET status='retired',
  false_positive_notes='RETIRED 2026-08-08 (handoff 47): superseded. flood_layer_selection NULLs are now the 8 deliberate content-verified de-selections (reasons retained), so this would flag the CORRECT state as a defect. Covered by served-path flood-bfe-9999-sentinel-served-null + get_parcel_flood_zone.'
WHERE defect_id='DEF-020';
UPDATE data_defect_registry SET status='retired',
  false_positive_notes='RETIRED 2026-08-08 (handoff 47): references dropped column properties.assessed_value (now just_value/taxable_value_*/market_value_estimate). Values served via get_parcel_values; SOH-cap disclosure, if required, becomes a served-path check (build_backlog).'
WHERE defect_id='DEF-018';
UPDATE data_defect_registry SET status='retired',
  false_positive_notes='RETIRED 2026-08-08 (handoff 47): a reminder for an unbuilt feature (§3 resolution metadata), not a monitor. Moved to build_backlog.'
WHERE defect_id='DEF-014';

WITH base AS (SELECT COALESCE(max(item_no),0) AS m FROM build_backlog),
items(seq,title,spec_ref,evidence) AS (VALUES
 (1,'PIR §3 resolution metadata + served-path detection for resolution-mislabelling','handoff 47 (ex DEF-014)',
    'DEF-014 was a standing examined=0 reminder: resolution-mislabelling cannot be detected until the report emits §3 resolution metadata (what level each fact resolved at). Build that, then a served-path detection replacing the reminder.'),
 (2,'SOH-cap disclosure served-path check on get_parcel_values (ex DEF-018)','handoff 47 (ex DEF-018)',
    'DEF-018 checked properties.assessed_value>just_value (SOH cap) but that column was dropped. If disclosing the Save-Our-Homes cap matters, add a served-path check on get_parcel_values.'))
INSERT INTO build_backlog (item_no, title, priority, status, spec_ref, evidence)
SELECT base.m+items.seq, items.title, 'low','open', items.spec_ref, items.evidence FROM items CROSS JOIN base;
