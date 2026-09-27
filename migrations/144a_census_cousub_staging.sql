-- 144a — the Census Bureau's 2020 county-subdivision list, held verbatim (ruling on row 710, relayed
-- 2026-09-27). Source: www2.census.gov/geo/docs/reference/codes2020/national_cousub2020.txt (36,640
-- rows), retrieved 2026-09-27. Names only, no address points. In New England and the township states
-- the TOWN or TOWNSHIP is the unit of local government, and the Census files it as a county
-- subdivision, not a place - so the place seed (142b) left most of those towns out of the dropdown.
create table if not exists public.census_cousub_2020 (
  statefp    text not null,
  countyfp   text not null,
  cousubfp   text not null,
  state      text not null,
  countyname text not null,
  cousubns   text not null,
  cousubname text not null,
  classfp    text not null,
  funcstat   text not null,
  primary key (statefp, countyfp, cousubfp)
);
alter table public.census_cousub_2020 enable row level security;
revoke all on public.census_cousub_2020 from anon, authenticated;
grant select, insert, update on public.census_cousub_2020 to service_role;
comment on table public.census_cousub_2020 is
  'PROVENANCE: US Census Bureau national_cousub2020.txt (codes2020), retrieved 2026-09-27, all 36,640 rows verbatim. Source for the town/township seed (144b).';
