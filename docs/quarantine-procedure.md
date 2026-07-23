
=========================================================
## TABLE QUARANTINE PROCEDURE (rename indexes WITH the table) (2026-07-22)
When parking a superseded staging/live table by RENAME (e.g. -> <t>_abandoned_YYYYMMDD),
Postgres renames the TABLE but NOT its indexes. The old index names stay attached to the
abandoned table and then COLLIDE with the next same-named staging table's index creation
(ogr2ogr CREATE INDEX <stg>_geom_geom_idx fails: "relation already exists"). This silently
broke the Orange re-pull for 3 launches.

PROCEDURE for quarantine-by-rename:
  1. ALTER TABLE <t> RENAME TO <t>_abandoned_YYYYMMDD;
  2. For EACH index on it, rename to match:
       ALTER INDEX <t>_geom_geom_idx RENAME TO <t>_abandoned_YYYYMMDD_geom_idx;
     (find them: select i.relname from pg_index x join pg_class i on i.oid=x.indexrelid
                 join pg_class t on t.oid=x.indrelid where t.relname='<abandoned name>')
  3. Verify no *_stg_geom_geom_idx (or other soon-to-be-reused index name) remains dangling.
Belt-and-suspenders in the puller: -lco SPATIAL_INDEX=NONE on staging loads (staging needs no
spatial index anyway; the live table keeps its own through TRUNCATE+INSERT).

DONE 2026-07-22:
  orange_parcels_govt_source_stg_geom_geom_idx  -> orange_parcels_abandoned_20260722_geom_idx
  pinellas_parcels_govt_source_stg_geom_geom_idx-> pinellas_parcels_abandoned_20260722_geom_idx
  (both were quarantine artifacts of the paging remediation)
REMAINING / FLAGGED (NOT a quarantine artifact, left for owner decision):
  baker_subdivisions_stg_geom_geom_idx on LIVE baker_subdivisions (212 rows, registered active).
  Cosmetic _stg leftover in the index name; no collision now (no baker_subdivisions_stg table),
  but a future baker re-pull WOULD collide. Recommended: rename to baker_subdivisions_geom_idx.
