-- =============================================================================
-- Ruling 125 fix — dataset_content_audit was written in three partial batches (60/120/99 layers) and its
-- consumers must read the LATEST ROW PER TABLE, not the whole history (the 138/2,234 figure was a union
-- across runs; any single run showed fewer). Add a run_id to group a sweep, backfill it deterministically
-- per existing run_at, and expose dataset_content_audit_latest so no reader re-derives the wrong set.
-- The audit driver (audit_layer_content caller) should stamp a fresh run_id per sweep going forward.
-- =============================================================================
ALTER TABLE dataset_content_audit ADD COLUMN IF NOT EXISTS run_id uuid;
UPDATE dataset_content_audit SET run_id = md5(run_at::text)::uuid WHERE run_id IS NULL;

CREATE OR REPLACE VIEW dataset_content_audit_latest AS
  SELECT DISTINCT ON (table_name) *
  FROM dataset_content_audit
  ORDER BY table_name, run_at DESC;

COMMENT ON VIEW dataset_content_audit_latest IS
  'Latest audit row per table. ALWAYS read this, not dataset_content_audit directly — the base table accumulates partial/overlapping sweeps and the union over-counts (ruling 125).';
