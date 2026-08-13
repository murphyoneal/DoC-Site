-- =============================================================================
-- Item 80, step 3: recovery (E + C). Select real, content-verified county FIRMs
-- that were never wired because the selector only matched the standard column
-- names. Each verified by content (interior-point in-county 400/400, zone-code
-- distribution, AE present) before selecting.
--
-- Recovered (7): Collier, Columbia, Escambia, Miami-Dade, Nassau, Walton (E) and
--   Pasco (C: was serving pasco_fema_floodways — the floodways layer, wrong data —
--   re-pointed at pasco_fema_flood_zones).
-- Deferred to the flood-pull backlog (content NOT clean enough to serve):
--   Charlotte (fzone is BFE-encoded "10AE"; sfha is IN/OUT), Duval (flood_zone is
--   comma-concatenated multi-zone per row), Clay (numeric junk zone codes + blank
--   sfha). These stay not_available (honest) until a clean per-polygon NFHL pull.
--
-- Column maps for variant schemas (zone code not in fld_zone). BFE left unmapped
-- where the BFE column is ambiguous (Miami-Dade elev, Columbia ah_bfe, Pasco
-- bfelev 0-sentinel) — better null than a possibly-wrong number. Escambia uses its
-- authoritative sfha_tf, so its compound zone_id labels don't affect the SFHA bit.
-- =============================================================================
INSERT INTO flood_layer_column_map (table_name, col_role, column_name, note) VALUES
 ('columbia_flood_zones','zone','zone','variant: zone code lives in "zone"'),
 ('miamidade_flood_zones','zone','fzone','variant: zone code in "fzone"'),
 ('miamidade_flood_zones','subty','zonesubty','variant: subtype in "zonesubty"'),
 ('escambia_flood_zones','zone','zone_id','compound local codes (AE-V BY LiMWA ...); in_sfha comes from authoritative sfha_tf, not the code'),
 ('escambia_flood_zones','datum','v_datum_id','variant datum column'),
 ('pasco_fema_flood_zones','zone','fzone','variant: zone in "fzone"; BFE (bfelev) left unmapped due to 0-sentinel ambiguity')
ON CONFLICT (table_name, col_role) DO UPDATE SET column_name=EXCLUDED.column_name, note=EXCLUDED.note;

-- Pasco: re-point from the floodways layer to the real flood-zone layer.
UPDATE flood_layer_selection
   SET table_name='pasco_fema_flood_zones',
       selected_by='content_recovery_2026-08-08',
       needs_curation=false,
       notes='Re-pointed off pasco_fema_floodways (floodways, wrong layer) to pasco_fema_flood_zones (2073 rows, in-county). zone=fzone; in_sfha derived (no sfha flag); BFE unmapped (bfelev 0-ambiguous).'
 WHERE co_no=61;

-- The 6 recovered absent counties (idempotent: only insert where no row exists).
INSERT INTO flood_layer_selection (co_no, county_name, table_name, selected_by, candidates, needs_curation, notes)
SELECT v.co_no, v.cname, v.tbl, 'content_recovery_2026-08-08', 1, false, v.note
FROM (VALUES
 (21::numeric,'Collier','collier_flood_zones','56k rows, 400/400 in-county, zones A/AE/AH/VE/X; sfha derived (no sfha_tf); static_bfe standard'),
 (22::numeric,'Columbia','columbia_flood_zones','5304 rows, 400/400; zone in "zone" col (mapped); sfha derived'),
 (27::numeric,'Escambia','escambia_flood_zones','400/400; zone in "zone_id" (compound, mapped); in_sfha from authoritative sfha_tf; static_bfe standard'),
 (23::numeric,'Miami-Dade','miamidade_flood_zones','3560 rows, 400/400; zone in "fzone", subtype "zonesubty" (mapped); sfha derived; BFE unmapped'),
 (55::numeric,'Nassau','nassau_flood_zones','1446 rows, 399/400; standard fld_zone/zone_subty/static_bfe; sfha derived (no sfha_tf)'),
 (76::numeric,'Walton','walton_flood_zones','8890 rows, 400/400; standard fld_zone/zone_subty/static_bfe; sfha derived')
) v(co_no,cname,tbl,note)
WHERE NOT EXISTS (SELECT 1 FROM flood_layer_selection s WHERE s.co_no=v.co_no);
