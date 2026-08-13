-- =============================================================================
-- Stage 1 migration #3 (handoff 27): zoning + future-land-use -> layer_resolution.
-- zoning_layer_selection is ONE bespoke table serving TWO concepts via a `kind`
-- discriminator (kind='zoning' 44 rows, kind='flu' 52 rows), read by ONE helper
-- (_zoning_lookup). So this migrates BOTH concepts in one move; they are inseparable
-- in the source. Flood-style: copy -> compatibility view, _zoning_lookup byte-unchanged.
--
-- Mapping (architecture has separate concepts zoning and land_use):
--   kind='zoning' -> concept='zoning'      kind='flu' -> concept='land_use'
--   layer_resolution.kind stays the GEOMETRY kind ('polygon'), as for flood/sinkhole;
--   the zoning/flu discriminator is carried by concept and reconstructed in the view.
--   precedence: municipal->3, county->2 (the single primitive; _zoning_lookup keeps
--   its own ORDER BY for now, so behaviour is identical - precedence is for the future
--   resolve_layer). Keyed by co_no via geo_reference (NOT name - no Saint/St. risk).
--   Per-row code/name/url/municipality columns pivot into layer_column_map roles
--   (table_name is unique across all 96 rows, so no PK collision).
--
-- Proof: the compatibility view must reproduce zoning_before_snapshot EXACTLY (all 14
-- content columns; id excluded - _zoning_lookup does not use it). The DO block asserts
-- set-equality both directions and ROLLS BACK the whole migration on any difference.
-- =============================================================================
SET statement_timeout = 0;

-- 1. concept catalogue
INSERT INTO concept_registry (concept, expected_level, coverage_mode, display_name, icon_name, category, sort_order, who_can_answer, notes) VALUES
 ('zoning',   2, 'per_county', 'Zoning',          'map', 'land', 10, 'The county or municipal planning/zoning department with jurisdiction over the parcel.', 'Zoning district. Municipal layer overrides county where a parcel sits inside an incorporated place.'),
 ('land_use', 2, 'per_county', 'Future Land Use', 'map', 'land', 11, 'The county or municipal planning department (comprehensive plan / FLUM).', 'Future Land Use (FLU) from the comprehensive plan. Distinct from zoning.')
ON CONFLICT (concept) DO NOTHING;

-- 2. copy the 96 rows (idempotent). kind->concept; geometry kind='polygon';
--    precedence from jurisdiction_level.
INSERT INTO layer_resolution
  (geo_id, concept, kind, table_name, precedence, jurisdiction_level, jurisdiction_name,
   geom_column, not_mine_values, flagged_values, verified, verified_at, selected_by, notes)
SELECT g.geo_id,
       CASE WHEN z.kind='flu' THEN 'land_use' ELSE 'zoning' END,
       'polygon', z.table_name,
       CASE WHEN z.jurisdiction_level='municipal' THEN 3 ELSE 2 END,
       z.jurisdiction_level, z.jurisdiction_name,
       COALESCE(z.geom_column,'geom'), z.not_mine_values, z.flagged_values,
       z.verified, CASE WHEN z.verified THEN TIMESTAMPTZ '2026-08-08 00:00:00+00' ELSE NULL END,
       'migrated from zoning_layer_selection 2026-08-08 (handoff 27)', z.notes
FROM zoning_layer_selection z
JOIN geo_reference g ON g.dor_co_no = z.co_no::int AND g.admin_level = 2
WHERE NOT EXISTS (SELECT 1 FROM layer_resolution lr WHERE lr.concept IN ('zoning','land_use'));

-- 3. pivot the per-layer columns into layer_column_map roles (table_name unique -> safe)
INSERT INTO layer_column_map (table_name, col_role, column_name, verified_at)
SELECT table_name, role, col, TIMESTAMPTZ '2026-08-08 00:00:00+00' FROM (
  SELECT table_name, 'code'         AS role, code_column         AS col FROM zoning_layer_selection
  UNION ALL SELECT table_name, 'name',         name_column         FROM zoning_layer_selection
  UNION ALL SELECT table_name, 'url',          url_column          FROM zoning_layer_selection
  UNION ALL SELECT table_name, 'municipality', municipality_column FROM zoning_layer_selection
) s WHERE col IS NOT NULL
ON CONFLICT (table_name, col_role) DO NOTHING;

-- 4. assert the copy is complete before dropping the source
DO $$
DECLARE v_lr int; v_code int;
BEGIN
  SELECT count(*) INTO v_lr FROM layer_resolution WHERE concept IN ('zoning','land_use');
  IF v_lr <> 96 THEN RAISE EXCEPTION 'zoning/flu copy incomplete: layer_resolution holds % (expected 96)', v_lr; END IF;
  SELECT count(*) INTO v_code FROM layer_column_map cm
    WHERE cm.col_role='code' AND cm.table_name IN (SELECT table_name FROM layer_resolution WHERE concept IN ('zoning','land_use'));
  IF v_code <> 96 THEN RAISE EXCEPTION 'zoning/flu code-column copy incomplete: % (expected 96)', v_code; END IF;
END $$;

-- 5. swap the physical table for a compatibility view reconstructing the exact columns
DROP TABLE zoning_layer_selection;
CREATE VIEW zoning_layer_selection AS
SELECT lr.id,
       g.dor_co_no::numeric AS co_no,
       lr.jurisdiction_level, lr.jurisdiction_name,
       CASE WHEN lr.concept='land_use' THEN 'flu' ELSE 'zoning' END AS kind,
       lr.table_name,
       cm.code_col AS code_column, cm.name_col AS name_column, cm.url_col AS url_column,
       lr.geom_column, lr.verified, lr.notes, lr.not_mine_values,
       cm.muni_col AS municipality_column, lr.flagged_values
FROM layer_resolution lr
JOIN geo_reference g ON g.geo_id = lr.geo_id
LEFT JOIN LATERAL (
  SELECT max(column_name) FILTER (WHERE col_role='code')         AS code_col,
         max(column_name) FILTER (WHERE col_role='name')         AS name_col,
         max(column_name) FILTER (WHERE col_role='url')          AS url_col,
         max(column_name) FILTER (WHERE col_role='municipality') AS muni_col
  FROM layer_column_map WHERE table_name = lr.table_name) cm ON true
WHERE lr.concept IN ('zoning','land_use');
COMMENT ON VIEW zoning_layer_selection IS
  'COMPATIBILITY VIEW over layer_resolution (concept zoning|land_use) + layer_column_map - physical table migrated 2026-08-08 (migration 87a). kind reconstructed from concept. _zoning_lookup reads it unchanged. Source of truth: layer_resolution.';
GRANT SELECT ON zoning_layer_selection TO anon, authenticated, service_role;

-- 6. ASSERT the view reproduces the pre-migration table EXACTLY (id excluded), both directions
DO $$
DECLARE d1 int; d2 int;
BEGIN
  SELECT count(*) INTO d1 FROM (
    SELECT co_no,jurisdiction_level,jurisdiction_name,kind,table_name,code_column,name_column,url_column,geom_column,verified,notes,not_mine_values,municipality_column,flagged_values FROM zoning_layer_selection
    EXCEPT
    SELECT co_no,jurisdiction_level,jurisdiction_name,kind,table_name,code_column,name_column,url_column,geom_column,verified,notes,not_mine_values,municipality_column,flagged_values FROM zoning_before_snapshot) a;
  SELECT count(*) INTO d2 FROM (
    SELECT co_no,jurisdiction_level,jurisdiction_name,kind,table_name,code_column,name_column,url_column,geom_column,verified,notes,not_mine_values,municipality_column,flagged_values FROM zoning_before_snapshot
    EXCEPT
    SELECT co_no,jurisdiction_level,jurisdiction_name,kind,table_name,code_column,name_column,url_column,geom_column,verified,notes,not_mine_values,municipality_column,flagged_values FROM zoning_layer_selection) b;
  IF d1 <> 0 OR d2 <> 0 THEN RAISE EXCEPTION 'zoning view != pre-migration snapshot (view-only=%, snapshot-only=%)', d1, d2; END IF;
END $$;
