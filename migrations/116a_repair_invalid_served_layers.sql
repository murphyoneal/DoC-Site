-- =============================================================================
-- Ruling 122 step 3 / ruling 117 / item 99 — apply the once-at-ingest geometry repair to the EXISTING
-- served estate, not just the new NHD/flood loads. dataset_content_audit found 138 served spatial layers
-- (2,234 features) holding invalid geometry, every one flagged verified. An invalid polygon is what makes
-- the per-call ST_MakeValid fire in the serving path (the Marion 27.7s timeout, the DeSoto 19s). Repairing
-- each layer once is the precondition for removing the per-row serving guards.
--
-- repair_invalid_served_layers: resumable (skips a layer already logged invalid_after=0), COMMITs per
-- layer so a long run banks progress, light-layers-first, and fail-loud (repair_geometry_once raises if a
-- layer stays invalid — the sweep STOPS there, per ruling 119). It only handles layers whose geom column
-- has a resolvable dimension; the 4 generic-GEOMETRY layers are repaired separately (they can't tell
-- repair_geometry_once whether to keep polygons, lines or points).
-- =============================================================================
CREATE TABLE IF NOT EXISTS geometry_repair_log (
  table_name    text PRIMARY KEY,
  invalid_before int,
  invalid_after  int,
  repaired       int,
  max_vertices   int,
  repaired_at    timestamptz DEFAULT now(),
  note           text
);

CREATE OR REPLACE PROCEDURE public.repair_invalid_served_layers(p_max_vertices_cap int DEFAULT NULL)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $$
DECLARE r record; nb int; na int; nr int;
BEGIN
  FOR r IN
    WITH latest_per_table AS (
      SELECT DISTINCT ON (table_name) table_name, geom_invalid, max_vertices
      FROM dataset_content_audit ORDER BY table_name, run_at DESC)
    SELECT lp.table_name, lp.max_vertices
    FROM latest_per_table lp
    JOIN geometry_columns gc ON gc.f_table_schema='public' AND gc.f_table_name=lp.table_name
                            AND gc.f_geometry_column='geom'
    WHERE lp.geom_invalid > 0
      AND (gc.type ILIKE '%POLYGON%' OR gc.type ILIKE '%LINESTRING%' OR gc.type ILIKE '%POINT%')
      AND (p_max_vertices_cap IS NULL OR lp.max_vertices <= p_max_vertices_cap)
      AND NOT EXISTS (SELECT 1 FROM geometry_repair_log g WHERE g.table_name=lp.table_name AND g.invalid_after=0)
    ORDER BY lp.max_vertices ASC NULLS FIRST
  LOOP
    EXECUTE format('SELECT count(*) FROM %I WHERE geom IS NOT NULL AND NOT ST_IsValid(geom)', r.table_name) INTO nb;
    IF nb = 0 THEN
      INSERT INTO geometry_repair_log(table_name,invalid_before,invalid_after,repaired,max_vertices,note)
        VALUES (r.table_name,0,0,0,r.max_vertices,'already valid at repair time')
        ON CONFLICT (table_name) DO UPDATE SET invalid_before=0,invalid_after=0,repaired=0,note=EXCLUDED.note,repaired_at=now();
      COMMIT; CONTINUE;
    END IF;
    nr := public.repair_geometry_once(r.table_name::regclass);   -- raises if any row remains invalid
    EXECUTE format('SELECT count(*) FROM %I WHERE geom IS NOT NULL AND NOT ST_IsValid(geom)', r.table_name) INTO na;
    INSERT INTO geometry_repair_log(table_name,invalid_before,invalid_after,repaired,max_vertices)
      VALUES (r.table_name,nb,na,nr,r.max_vertices)
      ON CONFLICT (table_name) DO UPDATE SET invalid_before=nb,invalid_after=na,repaired=nr,repaired_at=now(),note=NULL;
    COMMIT;
  END LOOP;
END $$;
