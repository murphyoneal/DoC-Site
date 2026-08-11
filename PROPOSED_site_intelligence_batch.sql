-- =============================================================================
-- PROPOSAL — review before applying via migration
-- Consumer-report property map: two helper functions.
--
--   1. parcels_in_view()          — bbox → pins (needed: parcels_staging has no
--                                    lat/lng column, only geom).
--   2. get_site_intelligence_batch() — array of (co_no, parcel_id) → one table,
--                                    fixing the N+1 in parcelSocket.forMapWithIntel.
--
-- Both wrap existing objects (parcels_staging.geom, get_site_intelligence()), so
-- there's no duplicated logic to drift.
--
-- ⚠️ BEFORE APPLYING — confirm:
--   (a) parcels_staging.geom SRID. This assumes 4326 (lng/lat). If parcels are
--       stored in a projected SRID (FL parcel data is often EPSG:2881 / state
--       plane), use the ST_Transform variant marked below, or the centroid X/Y
--       will not be lng/lat and the && bbox test will silently match nothing.
--   (b) there's a GiST index on parcels_staging.geom, else the bbox scan is slow:
--         create index concurrently if not exists parcels_staging_geom_gix
--           on parcels_staging using gist (geom);
-- =============================================================================


-- 1. parcels_in_view --------------------------------------------------------------
-- Returns the pins for a viewport. LIMIT keeps large/zoomed-out requests bounded;
-- the API layer also caps span (MAX_SPAN) and count.
create or replace function parcels_in_view(
  p_west  double precision,
  p_south double precision,
  p_east  double precision,
  p_north double precision,
  p_limit integer default 25
)
returns table (
  parcel_id text,
  co_no     numeric,
  lng       double precision,
  lat       double precision
)
language sql
stable
parallel safe
as $$
  select
    p.parcel_id,
    p.co_no,
    st_x(st_centroid(p.geom))::double precision as lng,
    st_y(st_centroid(p.geom))::double precision as lat
  from parcels_staging p
  where p.geom && st_makeenvelope(p_west, p_south, p_east, p_north, 4326)
  -- Projected-SRID variant (use instead of the line above if geom is not 4326):
  --   where p.geom && st_transform(
  --           st_makeenvelope(p_west, p_south, p_east, p_north, 4326),
  --           st_srid(p.geom))
  --   and centroid computed via st_transform(p.geom, 4326)
  limit greatest(1, least(p_limit, 200));
$$;


-- 2. get_site_intelligence_batch --------------------------------------------------
-- Composite key type for the array input.
do $$
begin
  if not exists (select 1 from pg_type where typname = 'parcel_key') then
    create type parcel_key as (co_no numeric, parcel_id text);
  end if;
end $$;

-- One call, many parcels. Reuses get_site_intelligence() via LATERAL so the
-- per-parcel logic stays in exactly one place. Output mirrors get_site_intelligence()
-- (co_no is echoed by the source function's parcel row set; if it is NOT, add
-- k.co_no to the select and the RETURNS TABLE list so the client can map rows back).
create or replace function get_site_intelligence_batch(p_keys parcel_key[])
returns table (
  parcel_id text, county_name text, owner_name text, phy_addr1 text, phy_city text,
  land_sqft numeric, building_sqft numeric, just_value numeric, land_use_code text,
  nearby_max_aadt numeric, nearby_road_desc text, census_block_group text,
  area_population numeric, area_median_income numeric, area_housing_units numeric,
  elevation_m numeric, nearest_water_m numeric, flood_zone_available boolean,
  flood_zone text, in_flood_hazard_area boolean,
  co_no numeric   -- echoed so (co_no, parcel_id) can be matched client-side
)
language sql
stable
parallel safe
as $$
  select gsi.*, k.co_no
  from unnest(p_keys) as k
  cross join lateral get_site_intelligence(k.co_no, k.parcel_id) as gsi;
$$;


-- 3. Grants -----------------------------------------------------------------------
-- The app uses the service role, but the planned consumer_report_readonly role
-- (see CLAUDE.md) will need EXECUTE. Safe to include now.
grant execute on function parcels_in_view(double precision, double precision, double precision, double precision, integer) to consumer_report_readonly;
grant execute on function get_site_intelligence_batch(parcel_key[]) to consumer_report_readonly;
