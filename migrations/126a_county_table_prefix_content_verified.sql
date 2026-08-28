-- 126a — county_table_prefix: which table-name prefixes belong to which county, VERIFIED BY GEOMETRY.
-- Ruling 511 resolver re-aim, step 1 of 2. Step 2 rewrites discover_county_layers to enumerate from
-- information_schema using this map.
--
-- WHY THIS TABLE EXISTS. The deployed discover_county_layers resolved a county by joining
-- county_registry.county_name = county_layer_registry.county. That name join drops "Saint Johns" and
-- "Saint Lucie", and BOTH COUNTIES RETURN ZERO LAYERS while holding 61 tables between them. A naive
-- prefix derivation (lowercase, strip non-letters) fails on exactly the same two: there is no
-- saintjohns_ or saintlucie_. Two different name mechanisms, the same two casualties.
--
-- Three spellings of one county exist across three tables:
--   county_registry.county_name    'Saint Johns'
--   fl_county_boundaries.name      'St. Johns County'
--   table prefixes                 sjc_  AND  stjohns_        <- TWO live prefixes for one county
-- Names cannot be the key. This map is keyed on co_no and established by CONTENT (CLAUDE.md invariant 8:
-- verify a sampled feature falls inside the target county by point-in-polygon, never by a name match).
--
-- THE CROSSWALK IS NUMERIC END TO END, with no name comparison at any step:
--   sampled geometry -> ST_Contains(fl_county_boundaries) -> geoid -> '12'||county_registry.fips
--                    -> county_registry.dor_county_no
--
-- A STATEWIDE PREFIX MUST NOT BE ATTRIBUTED TO ONE COUNTY. fl_*, census_*, nhd_* and similar hold
-- features across many counties; a single sampled point would land in one and mislabel the whole prefix.
-- The rule below is therefore UNANIMITY: a prefix is attributed only if every sampled point across
-- several tables lands in the SAME county. Anything that scatters is recorded with co_no NULL and
-- classified 'multi_county_or_statewide' — recorded, not deleted, so the next reader sees it was
-- examined and why it was rejected.

CREATE TABLE IF NOT EXISTS public.county_table_prefix (
  prefix              text PRIMARY KEY,
  co_no               smallint,
  verified_geoid      char(5),
  samples_taken       int      NOT NULL DEFAULT 0,
  distinct_counties   int      NOT NULL DEFAULT 0,
  sample_tables       text[],
  classification      text     NOT NULL,
  verified_at         timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.county_table_prefix IS
  'Table-name prefix -> DOR county number, established by point-in-polygon against fl_county_boundaries '
  'and crosswalked numerically via FIPS. Never by name: three spellings of St. Johns exist across three '
  'tables, and it carries two live prefixes (sjc_, stjohns_). Rebuilt by rebuild_county_table_prefix(). '
  'classification: county_verified | multi_county_or_statewide | no_geometry | unattributable.';

-- Idempotent rebuild (CLAUDE.md invariant 9: upsert on the natural key, never a blind insert; the
-- natural key is the prefix). Safe to re-run after any load.
CREATE OR REPLACE FUNCTION public.rebuild_county_table_prefix()
RETURNS TABLE(classification text, prefixes int, counties int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  p            record;
  t            record;
  g            geometry;
  hit_geoid    char(5);
  geoids       text[];
  tbls         text[];
  n_samples    int;
BEGIN
  FOR p IN
    SELECT split_part(f_table_name,'_',1) AS pfx
    FROM geometry_columns
    WHERE f_table_schema = 'public' AND strpos(f_table_name,'_') > 0
    GROUP BY 1
  LOOP
    geoids := '{}'; tbls := '{}'; n_samples := 0;

    -- Sample up to 4 geometry tables per prefix. Unanimity across tables is what separates a county
    -- prefix from a statewide one, so more than one table must be consulted wherever one exists.
    FOR t IN
      SELECT f_table_name AS tn, f_geometry_column AS gc, srid
      FROM geometry_columns
      WHERE f_table_schema='public' AND split_part(f_table_name,'_',1) = p.pfx
      ORDER BY f_table_name
      LIMIT 4
    LOOP
      -- SRID 0 cannot be located on the earth. Skip the sample rather than guess a projection —
      -- fl_cadastral lost its SRID at load and that is a known, separate defect.
      CONTINUE WHEN t.srid = 0 OR t.srid IS NULL;
      g := NULL;
      BEGIN
        EXECUTE format(
          'SELECT ST_PointOnSurface(ST_Transform(%I::geometry, 4326)) FROM public.%I WHERE %I IS NOT NULL LIMIT 1',
          t.gc, t.tn, t.gc) INTO g;
      EXCEPTION WHEN OTHERS THEN
        BEGIN
          EXECUTE format(
            'SELECT ST_Centroid(ST_Transform(%I::geometry, 4326)) FROM public.%I WHERE %I IS NOT NULL LIMIT 1',
            t.gc, t.tn, t.gc) INTO g;
        EXCEPTION WHEN OTHERS THEN g := NULL;
        END;
      END;
      CONTINUE WHEN g IS NULL;

      SELECT b.geoid INTO hit_geoid FROM fl_county_boundaries b WHERE ST_Contains(b.geom, g) LIMIT 1;
      n_samples := n_samples + 1;
      tbls := tbls || t.tn;
      IF hit_geoid IS NOT NULL THEN geoids := geoids || hit_geoid::text; END IF;
    END LOOP;

    INSERT INTO public.county_table_prefix AS c
      (prefix, co_no, verified_geoid, samples_taken, distinct_counties, sample_tables, classification, verified_at)
    SELECT
      p.pfx,
      CASE WHEN d.n = 1 THEN (SELECT cr.dor_county_no::smallint FROM county_registry cr
                              WHERE '12'||cr.fips = d.only_geoid) END,
      CASE WHEN d.n = 1 THEN d.only_geoid::char(5) END,
      n_samples,
      d.n,
      tbls,
      CASE WHEN n_samples = 0            THEN 'no_geometry'
           WHEN d.n = 0                  THEN 'unattributable'      -- sampled, but outside every FL county
           WHEN d.n = 1                  THEN 'county_verified'
           ELSE                               'multi_county_or_statewide'
      END,
      now()
    FROM (SELECT count(DISTINCT x) AS n, min(x) AS only_geoid FROM unnest(geoids) AS x) d
    ON CONFLICT (prefix) DO UPDATE SET
      co_no = EXCLUDED.co_no, verified_geoid = EXCLUDED.verified_geoid,
      samples_taken = EXCLUDED.samples_taken, distinct_counties = EXCLUDED.distinct_counties,
      sample_tables = EXCLUDED.sample_tables, classification = EXCLUDED.classification,
      verified_at = EXCLUDED.verified_at;
  END LOOP;

  RETURN QUERY
    SELECT c.classification, count(*)::int, count(DISTINCT c.co_no)::int
    FROM public.county_table_prefix c GROUP BY c.classification ORDER BY 2 DESC;
END
$fn$;

COMMENT ON FUNCTION public.rebuild_county_table_prefix() IS
  'Rebuilds county_table_prefix by sampling up to 4 geometry tables per prefix and requiring UNANIMOUS '
  'point-in-polygon agreement against fl_county_boundaries. Unanimity is what distinguishes a county '
  'prefix from a statewide one. Upserts on prefix; safe to re-run after any load.';
