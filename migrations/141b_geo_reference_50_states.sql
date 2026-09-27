-- 141b — geo_reference gains the 50 states, DC and their 3,143 counties and county-equivalents
-- (work order 699, ruling 701 §2 and §4), derived from the Census 2020 rows held verbatim in 141a.
-- Territories are in the staging table but NOT seeded (ruling: 50 states plus DC, stop there).
--
-- FIRST, THREE NAME JOINS THAT THIS SEED WOULD HAVE BROKEN. Until today every admin_level=2 row was a
-- Florida county, so a join on county NAME alone happened to be unique. With 3,143 counties it is not:
-- "Washington" is a county in 30 states. Each is scoped to the counties we serve (dor_co_no is set):
--   * view key_candidates: a scalar subquery by name would raise "more than one row" on a washington_* table;
--   * detection county-parcel-layer-disagrees-with-the-statewide-spine-both-ways: a Washington County FL
--     parcel source would be compared with 30 other states' (empty) parcel counts and go falsely red;
--   * detection coastal-only-concept-on-inland-parcel: every new county has is_coastal NULL - honestly, we
--     have not measured coastline outside Florida - and the check asserts NOT NULL on every US county.
-- Everything else that reads geo_reference keys on geo_id or dor_co_no (audited 2026-09-27).
--
-- NAMES: " County" is dropped to match the existing rows ("Alachua", "Crittenden"). Every other
-- suffix is kept because it is part of the name and disambiguates: Virginia has both Fairfax County
-- ("Fairfax") and Fairfax city ("Fairfax city"). level_type records what the unit is.
-- is_coastal stays NULL (not measured), dor_co_no NULL (Florida DOR numbers only). ON CONFLICT DO
-- NOTHING: the 67 Florida counties and the Arkansas test rows already exist and are not touched.

create or replace view public.key_candidates as
 SELECT table_name,
    col AS candidate_col,
    key_role,
    null_frac,
    ( SELECT g.dor_co_no
           FROM geo_reference g
          WHERE ((g.admin_level = 2) AND (g.dor_co_no IS NOT NULL) AND (lower(replace(g.name, '.'::text, ''::text)) = lower(replace(split_part((k.table_name)::text, '_'::text, 1), '.'::text, ''::text))))) AS co_no
   FROM nr_keys k
  WHERE ((key_role = ANY (ARRAY['OWN_KEY_unique'::text, 'near_unique'::text, 'high_cardinality'::text])) AND (col <> ALL (ARRAY['ogc_fid'::name, 'objectid'::name, 'objectid_1'::name, 'globalid'::name, 'global_id'::name, 'fid'::name, 'oid'::name, 'id'::name, 'x_coord'::name, 'y_coord'::name, 'latitude'::name, 'longitude'::name, 'lat'::name, 'lng'::name, 'created_at'::name, 'updated_at'::name, 'loaded_at'::name])) AND (col !~* '(area|length|acres|sqft|date|_at$|value|price|score|geom|shape)'::text) AND (null_frac < (0.2)::double precision));

do $d$
declare n int;
begin
  update data_defect_registry
     set detection_sql = replace(detection_sql, 'join geo_reference g on g.admin_level=2 and g.name = d.county_name',
                                 'join geo_reference g on g.admin_level=2 and g.dor_co_no is not null and g.name = d.county_name')
   where defect_id = 'county-parcel-layer-disagrees-with-the-statewide-spine-both-ways'
     and detection_sql like '%g.admin_level=2 and g.name = d.county_name%';
  get diagnostics n = row_count;
  if n <> 1 then raise exception '141b: spine detection anchor missing'; end if;
  update data_defect_registry
     set detection_sql = 'select not exists (select 1 from geo_reference where admin_level=2 and country_iso=''US'' and dor_co_no is not null and is_coastal is null) as ok'
   where defect_id = 'coastal-only-concept-on-inland-parcel'
     and detection_sql = 'select not exists (select 1 from geo_reference where admin_level=2 and country_iso=''US'' and is_coastal is null) as ok';
  get diagnostics n = row_count;
  if n <> 1 then raise exception '141b: coastal detection anchor missing'; end if;
end $d$;

insert into public.geo_reference (geo_id, name, admin1_code, admin1_abbr, parent_geo_id, active, notes,
                                  country_iso, national_code, admin_level, level_type, code_scheme, iso_3166_2)
select 'US-' || s.statefp, s.state_name, s.statefp, s.state, 'US', true,
       'Census 2020 FIPS (national_state2020.txt, STATENS ' || s.statens || '), retrieved 2026-09-27. Seeded for self-registration, WO 699.',
       'US', s.statefp, 1, case when s.state = 'DC' then 'federal_district' else 'state' end, 'FIPS', 'US-' || s.state
  from public.census_state_2020 s
 where s.statefp::int <= 56
on conflict (geo_id) do nothing;

insert into public.geo_reference (geo_id, name, admin1_code, admin1_abbr, parent_geo_id, active, notes,
                                  country_iso, national_code, admin_level, level_type, code_scheme)
select 'US-' || c.statefp || c.countyfp,
       regexp_replace(c.countyname, ' County$', ''),
       c.statefp, c.state, 'US-' || c.statefp, true,
       'Census 2020 FIPS (national_county2020.txt, COUNTYNS ' || c.countyns || ', CLASSFP ' || c.classfp || ', FUNCSTAT ' || c.funcstat || '), retrieved 2026-09-27. Seeded for self-registration, WO 699.'
         || case when c.state = 'CT' then ' Connecticut abolished county government in 1960; since 2022 the Census Bureau uses nine planning regions (FIPS 09110-09190) as its county-equivalents. The 2020 list is seeded as ruled because these are the counties people still name.' else '' end,
       'US', c.statefp || c.countyfp, 2,
       case when c.state = 'DC'                        then 'federal_district'
            when c.countyname ~ ' Parish$'             then 'parish'
            when c.countyname ~ ' City and Borough$'   then 'city_and_borough'
            when c.countyname ~ ' Borough$'            then 'borough'
            when c.countyname ~ ' Census Area$'        then 'census_area'
            when c.countyname ~ ' Municipality$'       then 'municipality'
            when c.countyname ~ ' (city|City)$'        then 'independent_city'
            else 'county' end,
       'FIPS'
  from public.census_county_2020 c
 where c.statefp::int <= 56
on conflict (geo_id) do nothing;

do $a$
declare st int; co int; orphan int; dup int; flmis int;
begin
  select count(*) into st from geo_reference where country_iso='US' and admin_level=1;
  select count(*) into co from geo_reference where country_iso='US' and admin_level=2;
  select count(*) into orphan from geo_reference g where g.country_iso='US' and g.admin_level=2
     and not exists (select 1 from geo_reference p where p.geo_id=g.parent_geo_id and p.admin_level=1);
  select count(*) - count(distinct national_code) into dup from geo_reference where country_iso='US' and admin_level=2;
  -- every county-level row we had before (67 FL + the Arkansas control) is in the Census list
  select count(*) into flmis from geo_reference g where g.country_iso='US' and g.admin_level=2
     and not exists (select 1 from census_county_2020 c where c.statefp||c.countyfp = g.national_code);
  if st <> 51 or co <> 3143 or orphan <> 0 or dup <> 0 or flmis <> 0 then
    raise exception '141b: states % (51) counties % (3143) orphans % dup % not-in-census %', st, co, orphan, dup, flmis;
  end if;
end $a$;
