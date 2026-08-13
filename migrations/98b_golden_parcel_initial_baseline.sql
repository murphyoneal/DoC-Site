-- =============================================================================
-- handoff 62: capture the reviewed initial baseline (version 1) and schedule the daily
-- output check. Guarded so re-applying does not mint a spurious new version.
-- Reviewed before storing: all 10 golden parcels' coverage states verified correct
-- (Volusia flood true/schools assigned/DEF-019; Sarasota flood not_available; Lee zoning
-- null; Santa Rosa R3 not a petition; St Johns DEF-003 fragmentation; Miami-Dade
-- recovered flood present); no known-bad sections found.
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM golden_parcel_baseline) THEN
    PERFORM public.rebaseline_golden_parcels('initial baseline 2026-08-09 (handoff 62) — reviewed: 10 coverage states verified correct; no known-bad sections');
  END IF;
END $$;

-- standing daily output check (results-only to golden_parcel_run; no blocking)
SELECT cron.schedule('golden-parcel-check-daily', '30 7 * * *', $q$SELECT public.check_golden_parcels();$q$);
