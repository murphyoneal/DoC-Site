-- 142a — the Census Bureau's 2020 place lists, held verbatim (work order 705). Source:
-- www2.census.gov/geo/docs/reference/codes2020/national_place2020.txt (32,188 rows) and
-- national_place_by_county2020.txt (33,618 rows), retrieved 2026-09-27. A PLACE-NAME list:
-- incorporated places and census-designated places with their state and county. No address points.
-- The by-county file is what parents a place to its county: 1,294 places in the 50 states + DC span
-- two to five counties, so a place has a SET of counties, not one. Loaded by POST (service_role).

create table if not exists public.census_place_2020 (
  statefp   text not null,
  placefp   text not null,
  state     text not null,
  placens   text not null,
  placename text not null,
  type      text not null,
  classfp   text not null,
  funcstat  text not null,
  counties  text,
  primary key (statefp, placefp)
);

create table if not exists public.census_place_county_2020 (
  statefp    text not null,
  countyfp   text not null,
  placefp    text not null,
  state      text not null,
  countyname text not null,
  placens    text not null,
  placename  text not null,
  type       text not null,
  classfp    text not null,
  funcstat   text not null,
  primary key (statefp, countyfp, placefp)
);

alter table public.census_place_2020 enable row level security;
alter table public.census_place_county_2020 enable row level security;
revoke all on public.census_place_2020, public.census_place_county_2020 from anon, authenticated;
grant select, insert, update on public.census_place_2020, public.census_place_county_2020 to service_role;

comment on table public.census_place_2020 is
  'PROVENANCE: US Census Bureau national_place2020.txt (codes2020), retrieved 2026-09-27, all rows verbatim incl. territories. Source for the geo_reference place seed (142b). WO 705.';
comment on table public.census_place_county_2020 is
  'PROVENANCE: US Census Bureau national_place_by_county2020.txt (codes2020), retrieved 2026-09-27, all rows verbatim. One row per place x county; source for geo_place_county (142b). WO 705.';
