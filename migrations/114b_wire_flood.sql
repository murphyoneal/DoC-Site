-- =============================================================================
-- WO 111 — wire the 14 NFHL counties into the flood resolver. RUN ONLY AFTER
-- scripts/wo111_load_flood.py --repair reports 14/14 reconciled + repaired. Wiring an empty or
-- partially-loaded table flips a county from an honest not_available to a false answer.
--
-- get_parcel_flood_zone gates on flood_layer_selection.table_name IS NULL (NOT on `verified`). So
-- table_name is the live switch: this script sets it ONLY where the loaded count == the target. A
-- county that did not reconcile keeps table_name NULL and stays not_available. `verified` is recorded
-- alongside as the audit flag. Idempotent: re-running re-derives counts and re-asserts.
--   8 existing rows (NULL table_name)  -> UPDATE   | 6 counties with no row -> INSERT
-- =============================================================================
BEGIN;

-- 8 existing flood rows: set table_name only if the county reconciles.
WITH tgt(geo_id, target) AS (VALUES
  ('US-12001',3391),('US-12005',10076),('US-12009',23480),('US-12043',3726),
  ('US-12077',2758),('US-12081',13820),('US-12105',21220),('US-12115',54526)),
cnt AS (SELECT g.geo_id, x.n
        FROM (SELECT co_no, count(*) n FROM nfhl_flood_zones GROUP BY co_no) x
        JOIN geo_reference g ON g.dor_co_no = x.co_no)
UPDATE layer_resolution lr
   SET table_name   = CASE WHEN cnt.n = tgt.target THEN 'nfhl_flood_zones' ELSE lr.table_name END,
       kind         = 'polygon',
       geom_column  = 'geom',
       srid         = 4326,
       selected_by  = 'wo111',
       needs_curation = (cnt.n <> tgt.target),
       row_count    = cnt.n,
       verified     = (cnt.n = tgt.target),
       verified_at  = CASE WHEN cnt.n = tgt.target THEN now() END,
       notes        = concat_ws(' | ', lr.notes, 'wo111 NFHL load '||cnt.n||'/'||tgt.target)
  FROM tgt JOIN cnt USING (geo_id)
 WHERE lr.geo_id = tgt.geo_id AND lr.concept = 'flood';

-- 6 counties with no flood row: insert one, wired only if reconciled.
WITH tgt(geo_id, target) AS (VALUES
  ('US-12015',8411),('US-12019',1704),('US-12031',10207),
  ('US-12053',12768),('US-12069',6791),('US-12097',2850)),
cnt AS (SELECT g.geo_id, g.name, x.n
        FROM (SELECT co_no, count(*) n FROM nfhl_flood_zones GROUP BY co_no) x
        JOIN geo_reference g ON g.dor_co_no = x.co_no)
INSERT INTO layer_resolution
  (geo_id, concept, kind, table_name, precedence, geom_column, srid,
   jurisdiction_level, jurisdiction_name, selected_by, needs_curation, row_count, verified, verified_at, notes)
SELECT tgt.geo_id, 'flood', 'polygon',
       CASE WHEN cnt.n = tgt.target THEN 'nfhl_flood_zones' END,
       2, 'geom', 4326, 'county', cnt.name, 'wo111',
       (cnt.n <> tgt.target), cnt.n, (cnt.n = tgt.target),
       CASE WHEN cnt.n = tgt.target THEN now() END,
       'wo111 NFHL load '||cnt.n||'/'||tgt.target
  FROM tgt JOIN cnt USING (geo_id)
 WHERE NOT EXISTS (SELECT 1 FROM layer_resolution lr WHERE lr.geo_id = tgt.geo_id AND lr.concept='flood');

-- proof: every one of the 14 must be wired (table_name set) and verified.
DO $$
DECLARE unwired int;
BEGIN
  SELECT count(*) INTO unwired
  FROM flood_layer_selection
  WHERE co_no IN (11,13,15,18,20,26,32,37,45,49,51,59,63,68)
    AND (table_name IS DISTINCT FROM 'nfhl_flood_zones');
  IF unwired > 0 THEN
    RAISE EXCEPTION '114b: % of the 14 flood counties are not wired to nfhl_flood_zones (reconcile failed?). Rolled back.', unwired;
  END IF;
END $$;

COMMIT;

SELECT co_no, county_name, table_name, needs_curation FROM flood_layer_selection
WHERE co_no IN (11,13,15,18,20,26,32,37,45,49,51,59,63,68) ORDER BY co_no;
