-- 141a — the Census Bureau's 2020 state and county FIPS lists, held verbatim (work order 699,
-- ruling 701 §4). Source: www2.census.gov/geo/docs/reference/codes2020/national_state2020.txt and
-- national_county2020.txt, retrieved 2026-09-27. These are the raw rows as published (pipe-delimited,
-- every column kept) so the geo_reference seed in 141b can always be re-derived and checked against
-- the source bytes. A public federal reference list: no addresses, no licence data. Loaded by POST
-- from the client (service_role); nobody else reads it.

create table if not exists public.census_state_2020 (
  statefp    text primary key,
  state      text not null,
  statens    text not null,
  state_name text not null
);

create table if not exists public.census_county_2020 (
  statefp    text not null,
  countyfp   text not null,
  state      text not null,
  countyns   text not null,
  countyname text not null,
  classfp    text not null,
  funcstat   text not null,
  primary key (statefp, countyfp)
);

alter table public.census_state_2020 enable row level security;
alter table public.census_county_2020 enable row level security;
revoke all on public.census_state_2020, public.census_county_2020 from anon, authenticated;
grant select, insert, update on public.census_state_2020, public.census_county_2020 to service_role;

comment on table public.census_county_2020 is
  'PROVENANCE: US Census Bureau national_county2020.txt (codes2020), retrieved 2026-09-27, all 3,235 rows verbatim incl. territories. Source for the geo_reference county seed (141b). WO 699 / ruling 701.';
comment on table public.census_state_2020 is
  'PROVENANCE: US Census Bureau national_state2020.txt (codes2020), retrieved 2026-09-27, all 57 rows verbatim. Source for the geo_reference state seed (141b). WO 699 / ruling 701.';
