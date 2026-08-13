-- =============================================================================
-- handoff 58 (URGENT): data_defect_registry.status carried TWO meanings — whether a
-- DETECTION RUNS (run_defect_detections) and whether a DISCLOSURE RENDERS
-- (get_parcel_disclosures). Retiring measurement/stale predicates under ruling 51
-- silently switched off their user-facing disclosures: DEF-019 (the Volusia
-- source-limit disclosure, applies_to_counties [74]) and DEF-003 (per-parcel
-- fragmentation notice) went dark. A maintenance action on an internal registry
-- silently changed what a user sees. The detection suite did not catch it (it watches
-- data, not outputs); the 28-section baseline diff did, only because it was run.
--
-- FIX: separate the lifecycles. Add disclosure_status (additive — NOT renaming status,
-- which the runner + expected_state + every status reader depend on). A defect can be
-- detection-retired but disclosure-active (an untestable source limit) and vice versa.
-- =============================================================================
ALTER TABLE data_defect_registry ADD COLUMN IF NOT EXISTS disclosure_status text
  CHECK (disclosure_status IN ('active','retired'));
COMMENT ON COLUMN data_defect_registry.disclosure_status IS
  'Disclosure lifecycle, INDEPENDENT of status (the detection lifecycle). active = disclosure_text renders to users via get_parcel_disclosures; retired = it does not.';

-- anything with a disclosure to make renders it, regardless of detection status
UPDATE data_defect_registry
   SET disclosure_status = CASE WHEN disposition='disclose' AND disclosure_text IS NOT NULL THEN 'active' ELSE 'retired' END;
-- pure measurements rehomed to statewide_metrics are not disclosures (DEF-022 discloses via env_findings, keep active)
UPDATE data_defect_registry SET disclosure_status='retired'
 WHERE defect_id IN ('cattle-dip-vats-non-spatial-historic','DEF-023');

-- get_parcel_disclosures keys on the DISCLOSURE lifecycle, never on whether a predicate runs
CREATE OR REPLACE FUNCTION public.get_parcel_disclosures(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb LANGUAGE sql STABLE
AS $function$
  WITH applicable AS (
    SELECT d.defect_id, d.disclosure_text
    FROM public.data_defect_registry d
    WHERE d.disclosure_status='active' AND d.disposition='disclose' AND d.disclosure_text IS NOT NULL
      AND d.defect_id <> 'DEF-022'
      AND (
        (d.applies_to_counties IS NOT NULL AND p_co_no = ANY(d.applies_to_counties))
        OR (d.defect_id = 'DEF-003' AND
            (SELECT count(*) FROM public.parcels_staging p WHERE p.co_no = p_co_no AND p.parcel_id = p_parcel_id) > 1)
      )
  )
  SELECT COALESCE(jsonb_agg(jsonb_build_object('defect_id',defect_id,'kind','source_limit','disclosure',disclosure_text) ORDER BY defect_id), '[]'::jsonb)
  FROM applicable
$function$;
