-- =============================================================================
-- Stage 1 migration #2 (handoff 25): sinkhole -> layer_resolution.
-- Registry-to-registry: get_parcel_sinkhole_facts ALREADY resolved from
-- county_layer_registry, so this moves the 59 sinkhole rows into the superset
-- registry and repoints the one lookup. Unlike flood, county_layer_registry is a
-- BASE TABLE serving ~44 concepts, so it is NOT swapped to a view — only the
-- sinkhole rows leave; the table becomes a view when its last concept leaves.
--
-- Proof (handoff 25, scaled to the concept): 67-county before/after resolution diff
-- (sinkhole_before_snapshot captured pre-migration) = 0 changed; plus an end-to-end
-- call on Volusia (volusia_sinkhole_incidents, 110 rows), Marion (with a layer), and
-- Baker (no layer -> not_established, the honest third state, never a false negative).
-- =============================================================================
SET statement_timeout = 0;

-- 1. concept catalogue
INSERT INTO concept_registry (concept, expected_level, coverage_mode, display_name, icon_name, category, sort_order, who_can_answer, notes)
VALUES ('sinkhole', 2, 'per_county', 'Sinkhole Incidents', 'alert-triangle', 'hazards', 40,
        'Florida Geological Survey / FDEP subsidence-incident database.',
        'Per-county recorded subsidence incidents (area context, not a per-parcel prediction). absent -> not_established with the statewide-karst caveat; Florida karst risk is statewide.')
ON CONFLICT (concept) DO NOTHING;

-- 2. copy the 59 sinkhole rows (idempotent: skip if already migrated)
INSERT INTO layer_resolution
  (geo_id, concept, kind, table_name, precedence, jurisdiction_level, jurisdiction_name,
   geom_column, key_column, bridge_key, key_transform, srid, row_count, verified, verified_at,
   selected_by, notes)
SELECT g.geo_id, 'sinkhole', 'point', clr.table_name, 2, 'county', clr.county,
       'geom', clr.key_column, clr.bridge_key, clr.key_transform, clr.srid, clr.row_count,
       (COALESCE(clr.row_count,0) > 0), clr.verified_at,
       'migrated from county_layer_registry 2026-08-08 (handoff 25)', clr.notes
FROM county_layer_registry clr
JOIN geo_reference g ON lower(g.name) = lower(clr.county) AND g.admin_level = 2
WHERE clr.concept = 'sinkhole'
  AND NOT EXISTS (SELECT 1 FROM layer_resolution lr WHERE lr.concept='sinkhole');

-- 3. ASSERT the copy is complete before deleting the source
DO $$
DECLARE v_dst int;
BEGIN
  SELECT count(*) INTO v_dst FROM layer_resolution WHERE concept='sinkhole';
  IF v_dst <> 59 THEN
    RAISE EXCEPTION 'sinkhole copy incomplete: layer_resolution holds % rows, expected 59', v_dst;
  END IF;
END $$;

-- 4. remove sinkhole from the shared base table (leave every other concept)
DELETE FROM county_layer_registry WHERE concept='sinkhole';

DO $$
DECLARE v_src int;
BEGIN
  SELECT count(*) INTO v_src FROM county_layer_registry WHERE concept='sinkhole';
  IF v_src <> 0 THEN RAISE EXCEPTION 'sinkhole rows still in county_layer_registry: %', v_src; END IF;
END $$;

-- 5. repoint the ONE lookup in get_parcel_sinkhole_facts (keyed by co_no via
--    geo_reference); everything else byte-identical to the deployed function.
CREATE OR REPLACE FUNCTION public.get_parcel_sinkhole_facts(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_pt geometry; v_parcel text := p_co_no::text||'/'||p_parcel_id;
  v_county text; v_tbl text; v_out jsonb;
BEGIN
  SELECT ST_PointOnSurface(geom) INTO v_pt FROM public.parcels_staging WHERE co_no=p_co_no AND parcel_id=p_parcel_id LIMIT 1;
  IF v_pt IS NULL THEN
    RETURN jsonb_build_object('field_status','not_established','coverage_note',
      'Parcel geometry could not be resolved; sinkhole proximity was not evaluated — a gap in our data, not a statement about the parcel.');
  END IF;
  SELECT county_name INTO v_county FROM public.county_registry WHERE dor_county_no = p_co_no::text LIMIT 1;
  -- resolver: sinkhole layer now lives in layer_resolution (migration 85a)
  SELECT lr.table_name INTO v_tbl
    FROM public.layer_resolution lr
    JOIN public.geo_reference g ON g.geo_id = lr.geo_id
   WHERE lr.concept='sinkhole' AND g.dor_co_no = p_co_no::int AND g.admin_level=2
     AND lr.table_name IS NOT NULL AND lr.row_count > 0 LIMIT 1;
  IF v_tbl IS NULL THEN
    RETURN jsonb_build_object('field_status','not_established','county', v_county,
      'coverage_note','No sinkhole-incident layer is held for this county — a gap in our coverage, NOT a statement that the parcel has no sinkhole risk. Florida''s karst risk is statewide; check the Florida Geological Survey subsidence database.');
  END IF;
  BEGIN
    EXECUTE format($q$
      WITH d AS (SELECT
            CASE WHEN COALESCE(event_date,0) > 0 THEN to_timestamp(event_date/1000)::date::text ELSE NULL END AS event_date,
            nullif(trim(true_sink::text),'') AS true_sink,
            nullif(trim(sindepth::text),'') AS depth,
            ST_Distance(geom::geography, $1::geography) AS dm
          FROM public.%I WHERE geom IS NOT NULL)
      SELECT CASE WHEN (SELECT count(*) FROM d) = 0 THEN NULL ELSE jsonb_build_object(
        'field_status','present',
        'nearest', (SELECT jsonb_build_object('distance_ft', round(dm*3.28084), 'event_date', event_date,
            'verified', true_sink, 'depth', depth) FROM d ORDER BY dm ASC LIMIT 1),
        'incidents_within_1mi', (SELECT count(*) FROM d WHERE dm <= 1609.344),
        'incidents_within_quarter_mi', (SELECT count(*) FROM d WHERE dm <= 402.336),
        'verified_within_1mi', (SELECT count(*) FROM d WHERE dm <= 1609.344 AND upper(true_sink)='Y'),
        'source','Florida Geological Survey / FDEP subsidence-incident database','source_tier','government_derived',
        'note','Documented, reported sinkhole incidents near the parcel — area context (karst activity), not a prediction the parcel will subside. verified: Y = confirmed sinkhole, N = investigated and not a sinkhole, U = unverified report. A nearby count means a recorded subsidence history worth a closer look; zero nearby is not a guarantee of stability.')
      END $q$, v_tbl) INTO v_out USING v_pt;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('field_status','not_established','county', v_county,
      'coverage_note','The county''s sinkhole layer could not be read in the expected schema — a gap in our wiring, flagged for review.');
  END;
  IF v_out IS NULL THEN
    RETURN jsonb_build_object('field_status','not_established','county', v_county, 'layer_used', v_tbl,
      'coverage_note','The county''s sinkhole-incident layer is held but contains no mappable incidents — a gap in the data, not a statement about the parcel.');
  END IF;
  RETURN v_out || jsonb_build_object('county', v_county, 'layer_used', v_tbl);
END $function$;
