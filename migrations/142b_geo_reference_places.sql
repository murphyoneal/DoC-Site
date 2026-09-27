-- 142b — geo_reference gains every Census 2020 place in the 50 states and DC (work order 705):
-- 19,519 incorporated places and 12,098 census-designated places (CDPs), derived from the rows
-- held verbatim in 142a. Territories are staged, not seeded (ruling 701: 50 states + DC).
--
-- WHAT IS REAL AND WILL LOOK WRONG:
--   * A place can span counties. 1,294 places sit in 2-5 counties. geo_reference has ONE parent, so
--     a single-county place is parented to its county and a multi-county place to its STATE, and
--     geo_place_county holds every place x county pair. The city dropdown reads geo_place_county, so
--     a multi-county place appears under each of its counties. Parenting it to an arbitrary one of
--     them would put it in the wrong county for everyone living in the others.
--   * CDPs are not incorporated: a statistical name for a settled area with no government of its
--     own. level_type census_designated_place, kept apart from municipality. Many rural contractors
--     live in one, so they belong in the dropdown.
--   * The same name repeats inside a state (191 base names; e.g. two "Mount Olive CDP" in Alabama)
--     - different places in different counties, told apart by geo_id and county.
--   * Eight "(balance)" rows are the part of a consolidated city outside its included towns
--     (Indianapolis, Nashville-Davidson, Louisville/Jefferson County...). They are where people in
--     those cities live, so they stay, under the name people use.
--
-- NAMES drop the legal descriptor ("Abbeville city" -> "Abbeville", as the 412 Florida rows already
-- read) and keep the full legal name in notes. The existing 412 Florida municipalities are NOT
-- touched (ON CONFLICT DO NOTHING); their geo_ids already follow this convention (US-12-00375).
--
-- READERS AUDITED BEFORE SEEDING (2026-09-27): the only reader that matches admin_level 3 by name
-- is resolve_scope_co, and it requires dor_co_no IS NOT NULL, which no new row has. parcels joins on
-- national_code (5-digit county codes; places are 7 digits). Every other reader keys on geo_id or
-- dor_co_no, or filters admin_level 2.

create table if not exists public.geo_place_county (
  place_geo_id  text not null references public.geo_reference(geo_id),
  county_geo_id text not null references public.geo_reference(geo_id),
  primary key (place_geo_id, county_geo_id)
);
create index if not exists geo_place_county_county_idx on public.geo_place_county(county_geo_id);
alter table public.geo_place_county enable row level security;
revoke all on public.geo_place_county from anon, authenticated;
grant select, insert, update, delete on public.geo_place_county to service_role;
comment on table public.geo_place_county is
  'Every Census 2020 place x county pair for the 50 states + DC (from census_place_county_2020). A place spanning several counties has one row per county. WO 705, migration 142b.';

create or replace function public._census_place_base(p text) returns text
language sql immutable set search_path = public as $$
  select regexp_replace(regexp_replace(p, ' \(balance\)$', ''),
    ' (city and borough|unified government|consolidated government|metropolitan government|metro government|urban county|city|town|village|CDP|borough|municipality|township|corporation|plantation)$', '')
$$;

with pc as (
  select statefp, placefp, count(*) as n_counties, min(countyfp) as only_county
    from public.census_place_county_2020 where statefp::int <= 56 group by 1, 2)
insert into public.geo_reference (geo_id, name, admin1_code, admin1_abbr, parent_geo_id, active, notes,
                                  country_iso, national_code, admin_level, level_type, code_scheme)
select 'US-' || p.statefp || '-' || p.placefp,
       public._census_place_base(p.placename),
       p.statefp, p.state,
       case when pc.n_counties = 1 then 'US-' || p.statefp || pc.only_county else 'US-' || p.statefp end,
       true,
       'Census 2020 place (national_place2020.txt, legal name "' || p.placename || '", PLACENS ' || p.placens
         || ', CLASSFP ' || p.classfp || ', FUNCSTAT ' || p.funcstat || '), retrieved 2026-09-27. Seeded for self-registration, WO 705.'
         || case when pc.n_counties > 1 then ' Spans ' || pc.n_counties || ' counties (' || p.counties || '), so it is parented to the state; see geo_place_county.' else '' end,
       'US', p.statefp || p.placefp, 3,
       case when p.type = 'CENSUS DESIGNATED PLACE' then 'census_designated_place' else 'municipality' end,
       'Census ANSI place FIPS'
  from public.census_place_2020 p
  join pc using (statefp, placefp)
 where p.statefp::int <= 56
on conflict (geo_id) do nothing;

insert into public.geo_place_county (place_geo_id, county_geo_id)
select 'US-' || statefp || '-' || placefp, 'US-' || statefp || countyfp
  from public.census_place_county_2020
 where statefp::int <= 56
on conflict do nothing;

-- TWO FLORIDA ROWS WE ALREADY HELD CARRY PRE-2020 PLACE CODES. Both places were renamed and
-- re-coded; Census 2020 lists them under new codes, which the insert above adds:
--   US-12-50900 OCEAN BREEZE (old "Ocean Breeze Park" code)  -> Census 2020 1250875 "Ocean Breeze town"
--   US-12-39075 LAKE WORTH (renamed Lake Worth Beach, 2019)  -> Census 2020 1239081 "Lake Worth Beach city"
-- The old rows are NOT changed or removed: they carry dor_co_no and our Florida data keys on them.
-- They are annotated, and they have no geo_place_county rows, so the city dropdown (which lists
-- only Census 2020 places) shows the current name once.
update public.geo_reference set notes = coalesce(notes || ' ', '') ||
  'SUPERSEDED CODE: not in the Census 2020 place list. The place is Census 2020 1250875 "Ocean Breeze town" (geo_id US-12-50875); this row keeps the older code our Florida data keys on (142b, 2026-09-27).'
 where geo_id = 'US-12-50900' and coalesce(notes, '') not like '%SUPERSEDED CODE%';
update public.geo_reference set notes = coalesce(notes || ' ', '') ||
  'SUPERSEDED CODE: renamed Lake Worth Beach in 2019. The place is Census 2020 1239081 "Lake Worth Beach city" (geo_id US-12-39081); this row keeps the older code our Florida data keys on (142b, 2026-09-27).'
 where geo_id = 'US-12-39075' and coalesce(notes, '') not like '%SUPERSEDED CODE%';

do $a$
declare pl int; fl int; flmis text; pairs int; nocounty text; dupcode int; badparent int;
begin
  select count(*) into pl from geo_reference where country_iso = 'US' and admin_level = 3;
  select count(*) into fl from geo_reference where admin1_abbr = 'FL' and admin_level = 3;
  -- the Florida municipalities we held that are not Census 2020 places: exactly the two re-coded ones
  select coalesce(string_agg(g.geo_id, ',' order by g.geo_id), '') into flmis from geo_reference g
   where g.admin1_abbr = 'FL' and g.admin_level = 3 and g.level_type = 'municipality'
     and not exists (select 1 from census_place_2020 c where c.statefp || c.placefp = g.national_code);
  select count(*) into pairs from geo_place_county;
  select coalesce(string_agg(g.geo_id, ',' order by g.geo_id), '') into nocounty from geo_reference g
   where g.country_iso = 'US' and g.admin_level = 3
     and not exists (select 1 from geo_place_county x where x.place_geo_id = g.geo_id);
  select count(*) - count(distinct national_code) into dupcode from geo_reference where country_iso = 'US' and admin_level = 3;
  select count(*) into badparent from geo_reference g where g.country_iso = 'US' and g.admin_level = 3
     and not exists (select 1 from geo_reference p where p.geo_id = g.parent_geo_id and p.admin_level in (1, 2));
  -- 31,617 Census places + the 2 superseded Florida rows; Florida 412 held + 543 CDPs + 2 re-coded
  if pl <> 31619 or fl <> 957 or flmis <> 'US-12-39075,US-12-50900' or pairs <> 33037
     or nocounty <> 'US-12-39075,US-12-50900' or dupcode <> 0 or badparent <> 0 then
    raise exception '142b: places % (31619) FL % (957) FL-not-in-census [%] pairs % (33037) no-county [%] dup % bad-parent %',
      pl, fl, flmis, pairs, nocounty, dupcode, badparent;
  end if;
end $a$;
