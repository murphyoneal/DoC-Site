-- =============================================================================
-- Ruling 122 step 1 — strip the per-call ST_MakeValid from resolve_parcel_geometry. The July ruling
-- (PIR_REPORT_SPEC_v5 Part I) settled "validate geometry AT INGEST, never per call" but it was applied
-- only to the data layer; the serving path kept the guard. This function is called ONCE PER SPATIAL
-- CONCEPT PER REPORT, so its ST_MakeValid is a per-report tax multiplied by the number of spatial
-- sections. Measured on the St Johns 1,215-fragment parcel (65/0251700001): 654.9 ms with the guard.
--
-- GATE (ruling 122, measured full-scan, not sampled): parcels_staging = 10,739,881 rows, 0 NULL,
-- 0 INVALID. parcel_geometry_supplement = 5,778 rows, 0 invalid (verified here before touching that
-- branch — ruling 122's gate covered parcels_staging only). Both sources are provably valid, so the
-- repair was pure overhead with zero protective value. Removing it cannot change an answer.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.resolve_parcel_geometry(p_co_no numeric, p_parcel_id text)
 RETURNS TABLE(geom geometry, geom_source text, attr_source text, is_supplement boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT ST_Union(p.geom), 'DOR statewide cadastral (parcels_staging)'::text, 'DOR NAL'::text, false
  FROM parcels_staging p
  WHERE p.co_no = p_co_no AND p.parcel_id = p_parcel_id AND p.geom IS NOT NULL
  HAVING count(*) > 0
  UNION ALL
  SELECT ST_Union(s.geom), max(s.geom_source), max(s.attr_source), true
  FROM parcel_geometry_supplement s
  WHERE s.co_no = p_co_no AND (s.parcel_id = p_parcel_id OR s.alt_key = p_parcel_id)
    AND NOT EXISTS (SELECT 1 FROM parcels_staging p2
                    WHERE p2.co_no = p_co_no AND p2.parcel_id = p_parcel_id AND p2.geom IS NOT NULL)
  HAVING count(*) > 0
  LIMIT 1
$function$;
