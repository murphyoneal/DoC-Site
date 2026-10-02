-- 199a - partial indexes on street_norm(phy_addr1) for Volusia, so Roz's area tool can resolve a street inside 8 s.
-- APPLIED FROM WSL (CREATE INDEX CONCURRENTLY cannot run inside a migration transaction, and the pooler's 2-minute
-- statement_timeout would kill it). This file is the record.
--
-- get_area_findings matches streets with street_norm(phy_addr1) = ... and street_norm(phy_addr1) ~ '\m<word>\M' over
-- co_no = 74. street_norm is IMMUTABLE, so both are indexable; without an index each pass evaluated it on all 306,889
-- Volusia parcels (~2 s per pass, two passes per street query). The btree serves the exact match; the trigram GIN
-- serves the word regex.
--
-- INCIDENT ON THE FIRST ATTEMPT (2026-10-01/02): the concurrent build waited 14 h on a lock. The blocker was an orphaned
-- read-only query of mine through the management API (pinellas_cama_rp_permits, statement_timeout=0, running 1 day
-- 14 h) - a connector timeout does not cancel the server-side statement. It also held the database-wide vacuum horizon
-- back for that long. Both were cancelled, the INVALID index left by the interrupted build was dropped, and the build
-- was rerun. Standing check before any long-running DDL: no transaction older than 10 minutes in pg_stat_activity.

create index concurrently if not exists idx_parcels_staging_v74_street
  on public.parcels_staging (street_norm(phy_addr1)) where co_no = 74;
create index concurrently if not exists idx_parcels_staging_v74_street_trgm
  on public.parcels_staging using gin (street_norm(phy_addr1) gin_trgm_ops) where co_no = 74;
analyze public.parcels_staging;
