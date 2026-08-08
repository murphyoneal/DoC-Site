-- =============================================================================
-- Item 80, step 4 companion: register two flood data defects.
--   1) flood-lake-county-name-trap — "lake*" flood tables belong elsewhere
--      (lakeland_city = Polk; lake_mack = a 25-row fragment). Guard so a future
--      name-match can't mis-assign either to Lake County.
--   2) fema-flood-zones-page-truncated — county_name holds pull-batch labels and
--      every batch is an exact 200-multiple (page truncation). Not served; must
--      never be used as a statewide fallback.
-- (Step 4 verification itself changed no data: Calhoun/Citrus/Sumter were confirmed
--  spatially complete — the 200-multiple counts are coincidental; Citrus's low lng
--  coverage was a Gulf-offshore bbox artifact, all parcels fall within the layer.)
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition, attribution_evidence,
  disclosure_text, harness_predicate, applies_to_counties)
VALUES
(
 'flood-lake-county-name-trap',
 'Lake County holds no FIRM; "lake*" flood tables belong elsewhere — lakeland_city_flood_zones is the CITY of Lakeland (Polk County), lake_flood_zones_lake_mack is a 25-row "Lake Mack" fragment. A name-based selector would mis-assign either to Lake County (co_no 45).',
 CURRENT_DATE, 'Item 80 flood layer audit',
 'entity_confusion','material',
 $det$SELECT NOT EXISTS (SELECT 1 FROM flood_layer_selection WHERE co_no=45 AND table_name IN ('lakeland_city_flood_zones','lake_flood_zones_lake_mack')) AS ok$det$,
 'flood_layer_selection row for Lake County (co_no 45)',
 'ok=true means Lake is not mis-pointed at a trap table. Lake currently has no selection row (honest not_available); the guard fires if a future name-match selects lakeland_city_ or lake_mack for Lake.',
 'active','ours','disclose',
 'lakeland_city_flood_zones ~8137 rows are Lakeland (Polk); lake_flood_zones_lake_mack is 25 rows. Neither is Lake County''s FIRM. Verified 2026-08-08.',
 'Lake County flood data is not held; select by content (interior-point in the county), never by table name.',
 'flood-lake-not-mis-selected-by-name', ARRAY[45]::numeric[]
),
(
 'fema-flood-zones-page-truncated',
 'fema_flood_zones is page-truncated: county_name holds pull-BATCH labels (swcoast/spacecoast/central1/...), not counties, and every batch is an exact multiple of 200 — the page-size truncation signature. NOT in the served path, but sits there looking like a statewide fallback and is systematically incomplete.',
 CURRENT_DATE, 'Item 80 flood layer audit',
 'completeness','material',
 $det$SELECT NOT EXISTS (SELECT 1 FROM (SELECT county_name, count(*) n FROM fema_flood_zones GROUP BY county_name) s WHERE s.n % 200 = 0) AS ok$det$,
 'the 10 pull batches in fema_flood_zones',
 'A single real count could coincidentally be a 200-multiple; ALL 10 batches being exact 200-multiples is conclusive of page truncation. ok=true only when re-pulled complete.',
 'active','ours','repair',
 'Batches 2026-08-08: swcoast 17800, spacecoast 15600, Volusia 15400, southcentral 13600, ncrural 12000, panhandleeast 7600, necentral 6400, tampabayadj 6000, panhandlewest 5600, central1 1200 — all multiples of 200; total 101,200; coverage stops ~27N.',
 'Do NOT use fema_flood_zones as a statewide flood fallback — it is an incomplete, page-truncated pull. Per-county NFHL layers (flood_layer_selection) are the served path.',
 'fema-flood-zones-not-page-truncated', NULL
)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence;
