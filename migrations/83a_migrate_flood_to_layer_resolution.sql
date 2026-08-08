-- =============================================================================
-- Stage 1 first migration (handoff 23): flood -> layer_resolution / layer_column_map.
-- HIGHEST-STAKES migration in the system. A full day took flood from 8 false
-- negatives to zero; this move must not change ONE county's resolution.
--
-- Approach: table-to-table, then COMPATIBILITY VIEWS. The 61 flood_layer_selection
-- rows and 6 flood_layer_column_map rows are copied into the superset registry,
-- then flood_layer_selection and flood_layer_column_map are REPLACED BY VIEWS that
-- reconstruct their exact columns from layer_resolution / layer_column_map. Every
-- reader (get_parcel_flood_zone, get_county_coverage, flood_col, the three flood
-- detections) is BYTE-UNCHANGED and now reads the registry through the view. Zero
-- function edits, zero payload-shape change, zero front-end coupling.
--
-- Proof is a 67-county before/after resolution diff (flood_before_snapshot captured
-- pre-migration), not a Volusia diff — Volusia is 1 of 53 correct; the value is the
-- other 66. Every assert below fails the whole transaction rather than half-migrate.
-- Additive to the registry; the old table NAMES survive as views (nothing that
-- referenced them breaks).
-- =============================================================================
SET statement_timeout = 0;

-- 1. concept catalogue
INSERT INTO concept_registry (concept, expected_level, coverage_mode, display_name, icon_name, category, sort_order, who_can_answer, notes)
VALUES ('flood', 2, 'per_county', 'Flood Zone', 'wave', 'hazards', 30,
        'FEMA — the authoritative FIRM is at msc.fema.gov (Map Service Center).',
        'Per-county FIRM. present=layer held & content-verified; de-selected (table_name NULL) = a candidate existed but was junk; absent (no row) = no FIRM held -> not_available, msc.fema.gov.')
ON CONFLICT (concept) DO NOTHING;

-- 2. copy the 61 selection rows (53 present + 8 de-selected). Absent counties have
--    no row and stay absent. precedence=2 (county), the single ordering primitive.
INSERT INTO layer_resolution
  (geo_id, concept, kind, table_name, precedence, jurisdiction_level, jurisdiction_name,
   geom_column, selected_by, candidates, needs_curation, notes, verified, verified_at)
SELECT g.geo_id, 'flood', 'polygon', s.table_name, 2, 'county', s.county_name,
       'geom', s.selected_by, s.candidates, s.needs_curation, s.notes,
       CASE WHEN s.table_name IS NULL THEN NULL
            WHEN COALESCE(s.needs_curation,false) THEN false ELSE true END,
       CASE WHEN s.table_name IS NULL THEN NULL ELSE TIMESTAMPTZ '2026-08-08 00:00:00+00' END
FROM flood_layer_selection s
JOIN geo_reference g ON g.dor_co_no = s.co_no::int AND g.admin_level = 2;

-- 3. copy the 6 column maps (recovery counties whose FIRM fields are non-standard)
INSERT INTO layer_column_map (table_name, col_role, column_name, note, verified_at)
SELECT table_name, col_role, column_name, note, TIMESTAMPTZ '2026-08-08 00:00:00+00'
FROM flood_layer_column_map
ON CONFLICT (table_name, col_role) DO NOTHING;

-- 4. ASSERT lossless BEFORE dropping anything (rolls back the whole migration if not)
DO $$
DECLARE v_src int; v_dst int; v_cm_src int; v_cm_dst int;
BEGIN
  SELECT count(*) INTO v_src FROM flood_layer_selection;
  SELECT count(*) INTO v_dst FROM layer_resolution WHERE concept='flood';
  IF v_src <> v_dst THEN
    RAISE EXCEPTION 'flood row copy lossy: % selection rows -> % layer_resolution rows (geo join dropped/multiplied rows)', v_src, v_dst;
  END IF;
  SELECT count(*) INTO v_cm_src FROM flood_layer_column_map;
  SELECT count(*) INTO v_cm_dst FROM layer_column_map
    WHERE table_name IN (SELECT table_name FROM layer_resolution WHERE concept='flood' AND table_name IS NOT NULL);
  IF v_cm_src <> v_cm_dst THEN
    RAISE EXCEPTION 'flood column-map copy lossy: % -> %', v_cm_src, v_cm_dst;
  END IF;
END $$;

-- 5. swap the physical tables for compatibility views reconstructing the exact columns
DROP TABLE flood_layer_selection;
CREATE VIEW flood_layer_selection AS
SELECT g.dor_co_no::numeric AS co_no,
       lr.jurisdiction_name  AS county_name,
       lr.table_name,
       lr.selected_by,
       lr.candidates,
       lr.needs_curation,
       lr.notes
FROM layer_resolution lr
JOIN geo_reference g ON g.geo_id = lr.geo_id
WHERE lr.concept = 'flood';
COMMENT ON VIEW flood_layer_selection IS
  'COMPATIBILITY VIEW over layer_resolution (concept=flood) — the physical table was migrated 2026-08-08 (migration 83a). Same columns; readers unchanged. New source of truth: layer_resolution.';

DROP TABLE flood_layer_column_map;
CREATE VIEW flood_layer_column_map AS
SELECT cm.table_name, cm.col_role, cm.column_name, cm.note
FROM layer_column_map cm
WHERE cm.table_name IN (SELECT table_name FROM layer_resolution WHERE concept='flood' AND table_name IS NOT NULL);
COMMENT ON VIEW flood_layer_column_map IS
  'COMPATIBILITY VIEW over layer_column_map (flood tables) — physical table migrated 2026-08-08 (migration 83a). flood_col() reads it unchanged.';

GRANT SELECT ON flood_layer_selection, flood_layer_column_map TO anon, authenticated, service_role;

-- 6. ASSERT the views reproduce the original row counts
DO $$
DECLARE v_fls int; v_flcm int;
BEGIN
  SELECT count(*) INTO v_fls  FROM flood_layer_selection;
  SELECT count(*) INTO v_flcm FROM flood_layer_column_map;
  IF v_fls <> 61 THEN RAISE EXCEPTION 'flood_layer_selection view has % rows, expected 61', v_fls; END IF;
  IF v_flcm <> 6 THEN RAISE EXCEPTION 'flood_layer_column_map view has % rows, expected 6', v_flcm; END IF;
END $$;
