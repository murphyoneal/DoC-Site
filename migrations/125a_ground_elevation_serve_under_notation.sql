-- 125a — get_ground_elevation_fact: six faults, one repair. Ruling 505 Part 3, option (a).
--
-- HOLD THIS MIGRATION until the fact-render change ships. See DEPLOY ORDER at the bottom.
--
-- The deployed function had SIX faults, not the four ruling 505 named:
--   (i)   DANGLING ARGUMENT. get_pir_report passes (v_out->'land'->>'elevationFt')::numeric, but
--         land.elevationFt was deliberately deleted (types/pir.ts:167). Verified at the served path:
--         the land block for 60/50434234040000100 is {"gopherTortoiseCoverage":"not_available"} —
--         there is no elevationFt key. The third argument is ALWAYS NULL, so the 'value_withheld'
--         branch was unreachable for all 10.7M parcels.
--   (ii)  field_status must derive from the parcel_elevations row. Never assert not_recorded about a
--         row we hold. Three-state: present where we hold one, not_available where we do not.
--   (iii) vertical_datum was the hardcoded literal 'not recorded'. WO156 (2026-08-12) established
--         NAVD88: 38 parcels stratified -30 ft to 209 ft across ~13 counties vs USGS EPQS, median
--         signed difference about -0.15 ft, no constant offset — therefore NAVD88, not NGVD29. The
--         literal predates that measurement by two weeks and could not change no matter what we held.
--   (iv)  The note asserted "Ground elevation is on record" OUTSIDE the CASE — emitted on every
--         parcel, contradicting field_status='not_recorded' in the same object. That contradiction is
--         what Roz correctly refused to resolve on 1491 N Ocean Blvd. It moves inside the CASE.
--   (v)   'value', null WAS HARDCODED, outside the CASE, with no argument reaching it. Fixing (i)
--         alone would have deployed green and still served null on every parcel. FOUND BY CC.
--   (vi)  LANGUAGE sql IMMUTABLE on a function that now reads a table. STABLE is correct; IMMUTABLE
--         was only harmless while the body read nothing. FOUND BY CC.
--
-- NOTATION, NOT ALTERATION (ruling 505 Part 2). USGS 3DEP publishes in metres and NAVD88 is a metric
-- datum. The source figure is reported AS PUBLISHED and the US figure travels beside it as notation:
--   value 3.55 | units 'm' | value_us '12 ft' | vertical_datum 'NAVD88'
-- Sibling keys, NOT a getter-composed string. The renderer composes; the getter stays structural.
-- Every units failure so far happened inside composed prose.
--
-- RULING 212 IS UNTOUCHED. Serving a ground elevation and a base flood elevation is not differencing
-- them. This function must never compute ground-vs-BFE, and the caveat must not invite the reader to.
--
-- The third argument is now VESTIGIAL. It is kept so the get_pir_report call site does not have to
-- change in the same deploy. Dropping it is a follow-up, not part of this repair.

CREATE OR REPLACE FUNCTION public.get_ground_elevation_fact(
  p_co_no numeric, p_parcel_id text, p_elev_ft numeric DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE sql
 STABLE                                          -- (vi) was IMMUTABLE; this body reads a table
AS $function$
  WITH e AS (
    SELECT elevation_m
    FROM public.parcel_elevations
    WHERE co_no = p_co_no::numeric AND parcel_id = p_parcel_id
    LIMIT 1
  )
  SELECT jsonb_build_object(
    'subject',   jsonb_build_object('parcel', p_co_no::text||'/'||p_parcel_id),
    'predicate', 'ground_elevation',
    -- (v) the value is served, not hardcoded null. Metres, as USGS publishes it.
    'value',     (SELECT elevation_m FROM e),
    'units',     CASE WHEN EXISTS (SELECT 1 FROM e) THEN 'm' END,
    -- notation sibling: nearest foot. NEVER a decimal — a single-point 3DEP sample carries
    -- several-feet error on a fifth of parcels, so 0.1 ft would imply an inch we do not have.
    'value_us',  (SELECT round(elevation_m * 3.280839895)::int || ' ft' FROM e),
    -- (ii) three-state, derived from the row. not_available is a coverage state, never a finding.
    'field_status', CASE WHEN EXISTS (SELECT 1 FROM e) THEN 'present' ELSE 'not_available' END,
    'source',      'parcel_elevations',
    'source_tier', 'government_derived',
    'source_url',  'none',
    'as_of',       'USGS 3DEP 1m DEM, sampled at the parcel',
    -- (iii) established by measurement (WO156), not asserted.
    'vertical_datum', CASE WHEN EXISTS (SELECT 1 FROM e) THEN 'NAVD88' END,
    -- The two-clause representativeness caveat, in US units, carrying the MEASURED risk. Clause one
    -- says what the figure is; clause two says where it is known to be wrong. It routes to the
    -- surveyed certificate WITHOUT inviting a ground-vs-BFE subtraction (ruling 212).
    'caveat', CASE WHEN EXISTS (SELECT 1 FROM e) THEN
      'This is a single elevation point sampled at the parcel from the USGS 3DEP 1m elevation model — '
      'not a survey, and not an average across the lot. Tested against USGS EPQS on 38 parcels, 30 agreed '
      'within 3 ft and 21 within 1 ft, but 8 differed by up to about 39 ft — all of them coastal, '
      'water-adjacent, near-zero-elevation or landfill parcels, where ground varies sharply across the '
      'lot. A surveyed elevation certificate is the only authoritative figure for this parcel.'
    END,
    -- (iv) the note now describes only the state it is attached to.
    'note', CASE WHEN EXISTS (SELECT 1 FROM e)
      THEN NULL
      ELSE 'No sampled ground elevation is held for this parcel. COVERAGE GAP, NOT A FINDING: this is '
           'not a statement that the parcel has no recorded elevation. A surveyed elevation certificate, '
           'or the county building department, can establish it.'
    END,
    'corroborators', '[]'::jsonb,
    'contradictors', '[]'::jsonb,
    'open_questions','[]'::jsonb)
$function$;

COMMENT ON FUNCTION public.get_ground_elevation_fact(numeric, text, numeric) IS
  'Ground elevation from parcel_elevations (USGS 3DEP 1m, NAVD88 per WO156 2026-08-12). Serves the '
  'metric source figure with a US notation sibling (ruling 505 Part 2: notation, not alteration). '
  'Three-state: present / not_available. NEVER computes ground-vs-BFE (ruling 212). The third '
  'argument is vestigial — retained only so the get_pir_report call site need not change; it is '
  'always NULL because land.elevationFt was removed from the payload (types/pir.ts:167).';

-- ---------------------------------------------------------------------------------------------
-- DEPLOY ORDER — THIS MIGRATION MUST NOT GO FIRST.
--
-- lib/fact-render.mjs valueLabel() renders ground_elevation as `${value} ft` and its own comment says
-- "the resolver already rounds". Under notation, value becomes 3.55 (METRES). Applying this migration
-- against the currently deployed front-end would render "3.55 ft" on an oceanfront VE-zone parcel
-- whose ground is about 12 ft — a 3.4x understatement, shown as a fact.
--
-- That is the coupled-deploy rule exactly: never apply a payload-shape change to production ahead of
-- the consuming front-end. ORDER:
--   1. Ship the fact-render change (notation-aware valueLabel). It is a no-op against today's DB,
--      because today value is null and renderFact returns the NULL_STRINGS branch before reaching
--      valueLabel. Verify green in production.
--   2. THEN apply this migration.
--
-- VERIFY AFTER APPLYING (item 200 detection, served path — RED before, must be GREEN after):
--   SELECT (get_pir_report(60,'50434234040000100')->'groundElevation'->>'field_status') <> 'not_recorded' AS ok;
-- Measured BEFORE this migration: field_status 'not_recorded' while parcel_elevations holds 3.55. ok = false.
-- ---------------------------------------------------------------------------------------------
