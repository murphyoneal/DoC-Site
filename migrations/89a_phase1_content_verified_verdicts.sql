-- =============================================================================
-- handoff 32 PHASE 1: content-verified verdicts into layer_resolution. NO function
-- edit, NO get_pir_report change, NO county_layer_registry delete (Phase 2 wires the
-- verified-usable layers into get_pir_report and moves rows out then).
--
-- 94 candidate rows across six concepts (subdivisions, school_zones,
-- environmental_overlay, marine, plat_index, cama) were verified by CONTENT, not by
-- the stale 2026-07-24 registry stamp:
--   * live row_count (registry stamp was wrong — e.g. school_zones is 25 populated,
--     not the 7 the stamp implied)
--   * interior-point ratio: ST_Contains(county boundary, ST_PointOnSurface(feature)),
--     sampled 500/layer, SRID-normalised. No geographic junk found (all >=0.5).
--   * value distribution on the identifying column, confirming each layer is what its
--     concept claims.
--
-- Verdicts (the flood de-selection pattern: usable -> table_name kept + verified;
-- junk/empty -> table_name NULL + reason retained in notes):
--   USABLE 87 · EMPTY 3 (Pasco elem/middle/high school zones, 0 live rows)
--   JUNK  4: three *_school_board_districts (hold board members / district numbers,
--            NOT attendance zones — wrong layer for assigned-school) + one
--            volusia_cama_snapshot_log (a 3-row log/metadata table, not CAMA data).
--
-- Open design questions REPORTED for the Phase-2 ruling (not resolved here):
--   1. school_zones split by LEVEL (elementary/middle/high) — 3 layers per county;
--      recorded per-row, level noted; wiring must combine them.
--   2. cama is RELATIONAL (parcel-keyed sub-tables, 19 for Volusia) not a spatial
--      layer; it does not fit (geo_id,concept)->one-table and likely stays inline
--      Volusia-only. Recorded as verdicts (kind=relational) for completeness.
-- =============================================================================
SET statement_timeout = 0;

INSERT INTO concept_registry (concept, expected_level, coverage_mode, display_name, icon_name, category, sort_order, who_can_answer, notes) VALUES
 ('subdivisions',          2, 'per_county', 'Subdivision',          'grid',     'land',   12, 'The county property appraiser / clerk plat records.', 'Recorded subdivision the parcel sits in.'),
 ('school_zones',          2, 'per_county', 'Assigned Schools',     'school',   'civic',  72, 'The county school district (attendance boundaries change; confirm with the district).', 'Public-school attendance zones, split by level (elementary/middle/high).'),
 ('environmental_overlay', 2, 'per_county', 'Environmental Overlay','leaf',     'hazards',35, 'The county environmental/planning department and FWC.', 'County conservation / preserve / protected-species overlays.'),
 ('marine',                2, 'per_county', 'Boat Ramps & Marinas', 'anchor',   'transit',34, 'The county / municipal parks or a marina operator.', 'Public boat ramps and marinas.'),
 ('plat_index',            2, 'per_county', 'Plat Index',           'file',     'land',   13, 'The county clerk of court / property appraiser plat records.', 'Recorded plat index.'),
 ('cama',                  2, 'per_county', 'CAMA (assessor detail)','database','land',   90, 'The county property appraiser (CAMA export).', 'Relational assessor detail (parcel-keyed sub-tables); Volusia-deep. Not a spatial layer.')
ON CONFLICT (concept) DO NOTHING;

-- verdict rows (idempotent: skip if these concepts already populated)
INSERT INTO layer_resolution
  (geo_id, concept, kind, table_name, precedence, jurisdiction_level, jurisdiction_name,
   geom_column, row_count, verified, verified_at, selected_by, notes)
SELECT g.geo_id, s.concept,
       CASE WHEN s.concept='marine' THEN 'point'
            WHEN s.concept='cama' OR s.geom_col IS NULL THEN 'relational'
            ELSE 'polygon' END,
       -- usable keeps its table_name; junk/empty go NULL (de-selection pattern)
       CASE WHEN v.verdict='usable' THEN s.table_name ELSE NULL END,
       2, 'county', s.county,
       CASE WHEN v.verdict='usable' THEN s.geom_col ELSE NULL END,
       CASE WHEN v.verdict='usable' THEN s.live_rc ELSE NULL END,
       CASE WHEN v.verdict='usable' THEN true WHEN v.verdict='junk' THEN false ELSE NULL END,
       CASE WHEN v.verdict='usable' THEN TIMESTAMPTZ '2026-08-08 00:00:00+00' ELSE NULL END,
       'content-verified 2026-08-08 phase 1 (handoff 32)',
       CASE v.verdict
         WHEN 'usable' THEN 'usable: interior-point ratio='||COALESCE(s.ratio::text,'n/a (relational)')
                            ||CASE WHEN s.id_col IS NOT NULL THEN '; '||s.id_col||' e.g. '||COALESCE(s.id_samples,'') ELSE '' END
                            ||CASE WHEN s.table_name ~* 'element' THEN ' [level=elementary]'
                                   WHEN s.table_name ~* 'middle'  THEN ' [level=middle]'
                                   WHEN s.table_name ~* 'high'    THEN ' [level=high]' ELSE '' END
         WHEN 'empty'  THEN 'DE-SELECTED empty: 0 live rows. original table '||s.table_name
         WHEN 'junk'   THEN 'DE-SELECTED junk: '||v.reason||' original table '||s.table_name
                            ||CASE WHEN s.id_col IS NOT NULL THEN ' ('||s.id_col||' e.g. '||COALESCE(s.id_samples,'')||')' ELSE '' END
       END
FROM layer_verify_staging s
JOIN geo_reference g ON lower(g.name)=lower(s.county) AND g.admin_level=2
CROSS JOIN LATERAL (SELECT
   CASE WHEN COALESCE(s.live_rc,0)=0 THEN 'empty'
        WHEN s.table_name ~* 'board_district' OR s.table_name='volusia_cama_snapshot_log' THEN 'junk'
        ELSE 'usable' END AS verdict,
   CASE WHEN s.table_name ~* 'board_district' THEN 'school board electoral districts, NOT attendance zones — wrong layer for assigned-school.'
        WHEN s.table_name='volusia_cama_snapshot_log' THEN 'log/metadata table, not CAMA data.'
        ELSE NULL END AS reason) v
WHERE NOT EXISTS (SELECT 1 FROM layer_resolution lr
                  WHERE lr.concept IN ('subdivisions','school_zones','environmental_overlay','marine','plat_index','cama'));

-- identifying column -> layer_column_map role 'name' (usable rows with an id column)
INSERT INTO layer_column_map (table_name, col_role, column_name, note, verified_at)
SELECT s.table_name, 'name', s.id_col, 'phase-1 content-verified identifying column', TIMESTAMPTZ '2026-08-08 00:00:00+00'
FROM layer_verify_staging s
WHERE COALESCE(s.live_rc,0)>0 AND s.id_col IS NOT NULL
  AND NOT (s.table_name ~* 'board_district' OR s.table_name='volusia_cama_snapshot_log')
ON CONFLICT (table_name, col_role) DO NOTHING;

-- assert the verdict counts landed as measured
DO $$
DECLARE v_tot int; v_usable int; v_deselected int;
BEGIN
  SELECT count(*) INTO v_tot FROM layer_resolution
    WHERE concept IN ('subdivisions','school_zones','environmental_overlay','marine','plat_index','cama');
  SELECT count(*) INTO v_usable FROM layer_resolution
    WHERE concept IN ('subdivisions','school_zones','environmental_overlay','marine','plat_index','cama') AND table_name IS NOT NULL;
  SELECT count(*) INTO v_deselected FROM layer_resolution
    WHERE concept IN ('subdivisions','school_zones','environmental_overlay','marine','plat_index','cama') AND table_name IS NULL;
  IF v_tot <> 94 THEN RAISE EXCEPTION 'verdict rows: % (expected 94)', v_tot; END IF;
  IF v_usable <> 87 THEN RAISE EXCEPTION 'usable rows: % (expected 87)', v_usable; END IF;
  IF v_deselected <> 7 THEN RAISE EXCEPTION 'de-selected rows: % (expected 7 = 3 empty + 4 junk)', v_deselected; END IF;
END $$;
