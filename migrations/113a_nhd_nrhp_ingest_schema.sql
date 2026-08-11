-- =============================================================================
-- WO 106 / rulings 100-105,107: ingest SCHEMA for NHD (hydrography) + NRHP (historic). CC owns the
-- schema+rules; WSL owns the bulk transfer. Every ruled transform is expressed as SCHEMA — dropped
-- columns simply DO NOT EXIST (no loader can reintroduce them), sentinels are CHECKs, and the
-- synthetic/serve-side exclusions live in VIEWS, never the load (load every row — synthetic geometry
-- is needed for network tracing; ruling 107). Flood loads separately once all 14 counties reconcile.
-- =============================================================================

-- ── NHD AREA (waterbodies; ruling 100/102) ───────────────────────────────────
-- DROPPED (absent): ELEVATION (0/5,776 populated — the exact fabrication surface), VISIBILITYFILTER
-- (cartographic draw-scale, an attribute of the map not the water). RESOLUTION kept but not rendered
-- until a 0/2 crosswalk is sourced. shape_area/shape_len named correctly (dotted names do not survive).
CREATE TABLE IF NOT EXISTS nhd_area (
  objectid              bigint PRIMARY KEY,
  permanent_identifier  text,
  fdate                 timestamptz,               -- FDATE epoch-ms /1000 at load
  resolution            int,                       -- 0/2, no crosswalk in data — do not render yet
  gnis_id               text,
  gnis_name             text,                      -- 14.3% fill; sparse != empty; lets a report name the water
  areasqkm              double precision,          -- canonical metric; convert to US units at RENDER only
  ftype                 int,
  fcode                 int,
  shape_area            double precision,
  shape_len             double precision,
  geom                  geometry(MultiPolygon,4326)
);

-- ── NHD FLOWLINE (watercourses; ruling 101/103) ──────────────────────────────
-- DROPPED (absent): ENABLED / FLOWDIRECTION / MAINPATH (one distinct value across 480,792 rows),
-- VISIBILITYFILTER (cartographic). KEPT: FLOWDIR (2 values — a different field), WBAREA_PERMANENT_
-- IDENTIFIER (kept but NEVER used as the watercourse shortcut — it disagrees with FTYPE both ways),
-- PARENT_FEATURE (LakePond vs Reservoir — report distribution, do not build on yet).
CREATE TABLE IF NOT EXISTS nhd_flowline (
  objectid                     bigint PRIMARY KEY,
  permanent_identifier         text,
  fdate                        timestamptz,        -- epoch-ms /1000 at load
  resolution                   int,                -- 0/2, no crosswalk — do not render
  gnis_id                      text,
  gnis_name                    text,
  lengthkm                     double precision,   -- canonical metric; convert at RENDER only
  reachcode                    text,
  flowdir                      int,
  wbarea_permanent_identifier  text,
  ftype                        int NOT NULL,       -- the AUTHORITY on what the feature is (serve filters on this)
  fcode                        int,
  innetwork                    text CHECK (innetwork IS NULL OR innetwork <> 'None'),  -- 'None' is a text-null; coerce to NULL at load
  parent_feature               text,
  globalid                     text,
  shape_len                    double precision,
  geom                         geometry(MultiLineString,4326)
);

-- ── NRHP POINTS (historic resources; ruling 104/105) ─────────────────────────
-- NRIS_Refnum is NOT a primary key (1,440 features / 1,432 distinct; repeats are genuine dups AND
-- multiple contributing resources under one listing — dedup would DELETE real resources). objectid is
-- the PK. Provenance columns (map_method, bnd_type, src_accu, src_scale, source) are CARRIED per
-- feature — they are why this was catchable and they map to the fact-index derivation column.
CREATE TABLE IF NOT EXISTS nrhp_points (
  objectid    bigint PRIMARY KEY,
  nris_refnum text,                                -- NOT unique — do not constrain
  resname     text,
  restype     text,                                -- building|site|structure|object|district (serve filters)
  address text, city text, county text, state text, vicinity text, multiname text,
  numcbldg int, numcobj int, numcsite int, numcstru int,
  is_nhl      text,                                -- 'X' = National Historic Landmark (stronger designation); keep distinct
  bnd_type    text,                                -- 'Arbitrary point' etc — provenance of the geometry
  bnd_other   text,
  is_extant   text,                                -- 'Unknown' on most — must NEVER render as extant
  extant_oth  text,
  certdate    text,                                -- raw MM/DD/YY string (2-digit year is ambiguous — parse at serve, not load)
  createdate  timestamptz, edit_date timestamptz,  -- epoch-ms /1000 at load
  map_method  text,                                -- 'Derived by XY event point or centroid generation' — the catch
  map_mth_ot  text, source text, src_date timestamptz, src_scale text, src_accu text, src_coord text,
  originator text, constrant text, cr_id text, geom_id text, property_id text, status text, nara_url text,
  geom        geometry(Point,4326)
);

-- ── NRHP DISTRICT POLYGONS ───────────────────────────────────────────────────
-- 298 of 306 are DERIVED FROM AN XY POINT (map_method) and carry NO real district shape. Containment
-- resolves ONLY against the 5 genuinely-digitized districts (see nrhp_district_boundaries view). 76 of
-- 306 are not districts at all (restype building/site/structure) — filtered at serve. Load every row.
CREATE TABLE IF NOT EXISTS nrhp_district_polygons (
  objectid    bigint PRIMARY KEY,
  nris_refnum text,
  resname text, restype text,
  address text, city text, county text, state text, vicinity text, certdate text, multiname text,
  numcbldg int, numcobj int, numcsite int, numcstru int,
  is_nhl text, bnd_type text, bnd_other text, is_extant text, extant_oth text,
  createdate timestamptz, edit_date timestamptz,
  map_method text, map_mth_ot text, source text, src_date timestamptz, src_scale text, src_accu text, src_coord text,
  originator text, constrant text, cr_id text, geom_id text, property_id text, status text, nara_url text,
  shape_length double precision, shape_area double precision,
  geom        geometry(MultiPolygon,4326)
);

-- spatial indexes
CREATE INDEX IF NOT EXISTS nhd_area_geom_gix     ON nhd_area              USING gist (geom);
CREATE INDEX IF NOT EXISTS nhd_flowline_geom_gix ON nhd_flowline          USING gist (geom);
CREATE INDEX IF NOT EXISTS nhd_flowline_ftype_ix ON nhd_flowline (ftype);
CREATE INDEX IF NOT EXISTS nrhp_points_geom_gix  ON nrhp_points           USING gist (geom);
CREATE INDEX IF NOT EXISTS nrhp_poly_geom_gix    ON nrhp_district_polygons USING gist (geom);

-- geometry validated ONCE, post-load (never per call — ST_MakeValid per call took a Marion report
-- from 4.98s to a 27.7s timeout). The loader (and the small-layer load) calls this after each table.
CREATE OR REPLACE FUNCTION public.repair_geometry_once(p_table regclass)
 RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE n int;
BEGIN
  EXECUTE format('UPDATE %s SET geom = ST_MakeValid(geom) WHERE geom IS NOT NULL AND NOT ST_IsValid(geom)', p_table);
  GET DIAGNOSTICS n = ROW_COUNT; RETURN n;
END $fn$;

-- ── SERVE-SIDE VIEWS (the exclusions live HERE, never in the load) ────────────
-- watercourse-present must EXCLUDE synthetic centrelines (FTYPE 558 ArtificialPath, 334 Connector) —
-- 140,392 rows / 29.2%, no real water — and coastline (566), a separate concept.
CREATE OR REPLACE VIEW nhd_watercourse AS SELECT * FROM nhd_flowline WHERE ftype NOT IN (558,334,566);
CREATE OR REPLACE VIEW nhd_coastline   AS SELECT * FROM nhd_flowline WHERE ftype = 566;      -- "is this parcel on the coast"
-- district CONTAINMENT resolves only against the 5 genuinely-digitized boundaries; everything else is
-- not_available for membership (never "no"). restype must be a district; is_extant Unknown never = extant.
CREATE OR REPLACE VIEW nrhp_district_boundaries AS
  SELECT * FROM nrhp_district_polygons
   WHERE nris_refnum IN ('14001084','70000181','03000990','11000577','70000847')
     AND restype ILIKE 'district';

-- ── source registry (cadence_basis not_established — the nightly sweep observes it) ──
INSERT INTO data_source_registry (county_name, category, table_name, source_url, access_technique, active, pull_mode, refresh_owner, cadence_basis, notes)
VALUES
 ('Statewide','hydrography','nhd_flowline','https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer/6','arcgis_paged',true,'manual','Murphy','not_established','NHD Flowline (item 103). Load EVERY row; exclude synthetic FTYPE 558/334 + coastline 566 at SERVE via nhd_watercourse/nhd_coastline.'),
 ('Statewide','hydrography','nhd_area','https://hydro.nationalmap.gov/arcgis/rest/services/nhd/MapServer/5','arcgis_paged',true,'manual','Murphy','not_established','NHD Area waterbodies (item 103). ELEVATION dropped at ingest (0/5776 populated).'),
 ('Statewide','historic','nrhp_points','https://services1.arcgis.com/NRHP/points','arcgis_paged',true,'manual','Murphy','not_established','NRHP resources (item 118). NRIS_Refnum is NOT a PK. Provenance columns carried for the fact index.'),
 ('Statewide','historic','nrhp_district_polygons','https://services1.arcgis.com/NRHP/districts','arcgis_paged',true,'manual','Murphy','not_established','NRHP districts (item 118). 298/306 derived from a point; containment only vs 5 digitized (nrhp_district_boundaries).')
ON CONFLICT (table_name, county_name) DO NOTHING;
