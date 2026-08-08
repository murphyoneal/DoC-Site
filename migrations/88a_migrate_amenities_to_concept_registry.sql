-- =============================================================================
-- Stage 1 migration #4 (handoff 30): amenities -> concept_registry.
-- Amenities is a CONCEPT CATALOGUE, not a layer selector. amenity_registry (8 rows)
-- describes what each amenity concept is (display/icon/category/coverage_mode); it
-- belongs in concept_registry. The FEATURES live in one shared statewide table
-- (amenity_features) resolved SPATIALLY by get_nearby_amenities, so layer_resolution
-- gets NOTHING for amenities (there are no per-county layer tables to select).
--
-- Audit findings reported to handoff 30 (NOT fixed here):
--  * amenity_features.co_no is NULL for exactly the four statewide types (school,
--    hospital, fire_station, police_station). get_nearby_amenities bypasses the co_no
--    filter when coverage_mode='statewide' (OR short-circuit), so the null co_no is
--    NOT a live consequence for the served path — those four are resolved spatially.
--    The four per_county types (hydrant/bus_stop/sunrail/library) carry non-null co_no.
--  * "hospitals row_count 0" is county_layer_registry concept=hospitals (69 rows, all
--    0) — a SEPARATE, unwired county-partitioned path, NOT amenity_features (381
--    hospitals, served spatially). Untouched here.
--
-- Shape: merge the 8 catalogue rows into concept_registry with an additive is_amenity
-- flag, then replace amenity_registry with a compatibility view over concept_registry
-- WHERE is_amenity. get_nearby_amenities (the only reader) is byte-unchanged.
-- Proof: exact-fidelity view==snapshot assert (rolls back the DROP on any diff).
-- =============================================================================
SET statement_timeout = 0;

-- 1. additive marker: which concepts are get_nearby_amenities' point-feature amenities
ALTER TABLE concept_registry ADD COLUMN IF NOT EXISTS is_amenity boolean NOT NULL DEFAULT false;

-- 2. merge the 8 catalogue rows (expected_level from coverage_mode: statewide=1, county=2)
INSERT INTO concept_registry
  (concept, expected_level, coverage_mode, display_name, icon_name, category, sort_order, who_can_answer, is_amenity)
SELECT ar.amenity_type,
       CASE WHEN ar.coverage_mode='statewide' THEN 1 ELSE 2 END,
       ar.coverage_mode, ar.display_name, ar.icon_name, ar.category, ar.sort_order,
       CASE ar.category
         WHEN 'health' THEN 'Hospitals are licensed by AHCA (Florida Agency for Health Care Administration).'
         WHEN 'safety' THEN 'The local fire/law-enforcement agency or water utility with jurisdiction.'
         WHEN 'transit' THEN 'The regional transit authority / FDOT.'
         WHEN 'civic'  THEN 'The county school district / library system / Florida DOE.'
         ELSE 'Local or regional government (see the feature source).' END,
       true
FROM amenity_registry ar
ON CONFLICT (concept) DO NOTHING;

-- 3. assert the merge is complete before dropping the source
DO $$
DECLARE v int;
BEGIN
  SELECT count(*) INTO v FROM concept_registry WHERE is_amenity;
  IF v <> 8 THEN RAISE EXCEPTION 'amenity catalogue merge incomplete: % is_amenity rows (expected 8)', v; END IF;
END $$;

-- 4. replace the table with a compatibility view (exact columns, same order)
DROP TABLE amenity_registry;
CREATE VIEW amenity_registry AS
SELECT concept AS amenity_type, display_name, icon_name, category, coverage_mode, sort_order
FROM concept_registry WHERE is_amenity;
COMMENT ON VIEW amenity_registry IS
  'COMPATIBILITY VIEW over concept_registry (is_amenity) - physical table migrated 2026-08-08 (migration 88a). get_nearby_amenities reads it unchanged. Amenity FEATURES remain in amenity_features (shared statewide, resolved spatially); layer_resolution holds nothing for amenities.';
GRANT SELECT ON amenity_registry TO anon, authenticated, service_role;

-- 5. ASSERT the view reproduces the pre-migration catalogue EXACTLY, both directions
DO $$
DECLARE d1 int; d2 int;
BEGIN
  SELECT count(*) INTO d1 FROM (
    SELECT amenity_type,display_name,icon_name,category,coverage_mode,sort_order FROM amenity_registry
    EXCEPT
    SELECT amenity_type,display_name,icon_name,category,coverage_mode,sort_order FROM amenity_registry_before_snapshot) a;
  SELECT count(*) INTO d2 FROM (
    SELECT amenity_type,display_name,icon_name,category,coverage_mode,sort_order FROM amenity_registry_before_snapshot
    EXCEPT
    SELECT amenity_type,display_name,icon_name,category,coverage_mode,sort_order FROM amenity_registry) b;
  IF d1 <> 0 OR d2 <> 0 THEN RAISE EXCEPTION 'amenity_registry view != pre-migration snapshot (view-only=%, snapshot-only=%)', d1, d2; END IF;
END $$;
