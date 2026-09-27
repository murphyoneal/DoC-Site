-- 144b — towns and townships join the city dropdown (ruling on row 710). In CT, MA, RI, VT, NH, ME
-- and the township states NY, NJ, PA, MI, MN, WI the town or township is the unit of local government,
-- and the Census files it as a COUNTY SUBDIVISION, not a place. Without them a contractor in Bristol,
-- Rhode Island found no town and had to pick "Rural / unincorporated" - recording something untrue.
--
-- WHAT IS LOADED: 11,788 subdivisions in those 12 states - T1/T5/T9 (active towns and townships) and C5
-- (a subdivision coextensive with a city or borough we already hold as a place). NOT loaded: the Z
-- classes - unorganized territory (Maine, Minnesota), "county subdivisions not defined", reservations -
-- where no town exists and "rural / unincorporated" is the true answer.
--
-- KEYS: geo_id US-{state}{county}-{cousub}, national_code = the 10-digit Census GEOID. Distinct from
-- places (US-{state}-{place}, 7-digit code) and counties (5-digit), so nothing collides. Parent is the
-- county: a county subdivision never crosses one. level_type minor_civil_division.
--
-- SHOWN ONCE: many towns are both a subdivision and a place of the same name (a New England town and its
-- village CDP, a Pennsylvania borough that is also its own subdivision, a New York town and the village
-- inside it). places_for_county now lists each NAME once per county, preferring the incorporated place,
-- then the town/township, then the census-designated place.
--
-- READERS: audited again. The only reader matching admin_level 3 by name, resolve_scope_co, requires
-- dor_co_no, which no new row has; the parcels view joins 5-digit county codes. Snapshot compared below.

insert into public.geo_reference (geo_id, name, admin1_code, admin1_abbr, parent_geo_id, active, notes,
                                  country_iso, national_code, admin_level, level_type, code_scheme)
select 'US-' || c.statefp || c.countyfp || '-' || c.cousubfp,
       regexp_replace(c.cousubname, ' (charter township|township|town|city|borough|village|plantation|grant|purchase|gore|location|municipality)$', ''),
       c.statefp, c.state, 'US-' || c.statefp || c.countyfp, true,
       'Census 2020 county subdivision (national_cousub2020.txt, legal name "' || c.cousubname || '", COUSUBNS ' || c.cousubns
         || ', CLASSFP ' || c.classfp || ', FUNCSTAT ' || c.funcstat || '), retrieved 2026-09-27. Town/township for the registration dropdown.',
       'US', c.statefp || c.countyfp || c.cousubfp, 3, 'minor_civil_division', 'Census county subdivision FIPS'
  from public.census_cousub_2020 c
 where c.state in ('CT', 'MA', 'RI', 'VT', 'NH', 'ME', 'NY', 'NJ', 'PA', 'MI', 'MN', 'WI')
   and c.classfp in ('T1', 'T5', 'T9', 'C5')
on conflict (geo_id) do nothing;

insert into public.geo_place_county (place_geo_id, county_geo_id)
select 'US-' || c.statefp || c.countyfp || '-' || c.cousubfp, 'US-' || c.statefp || c.countyfp
  from public.census_cousub_2020 c
 where c.state in ('CT', 'MA', 'RI', 'VT', 'NH', 'ME', 'NY', 'NJ', 'PA', 'MI', 'MN', 'WI')
   and c.classfp in ('T1', 'T5', 'T9', 'C5')
on conflict do nothing;

comment on table public.geo_place_county is
  'Every Census 2020 place x county pair (142b) plus every town/township county subdivision in the 12 MCD states (144b), for the 50 states + DC. A place spanning several counties has one row per county.';

create or replace function public.places_for_county(p_county text)
returns jsonb language sql stable security definer set search_path = public as $$
  with p as (
    select g.geo_id, _place_display(g.geo_id) as name, g.level_type,
           case g.level_type when 'municipality' then 1 when 'minor_civil_division' then 2 else 3 end as pri
      from geo_place_county x join geo_reference g on g.geo_id = x.place_geo_id
     where x.county_geo_id = p_county),
  r as (select p.*, row_number() over (partition by lower(name) order by pri, geo_id) as rn from p)
  select coalesce(jsonb_agg(jsonb_build_object('geo_id', geo_id, 'name', name, 'kind', level_type) order by name), '[]'::jsonb)
    from r where rn = 1
$$;
revoke all on function public.places_for_county(text) from public, anon, authenticated;
grant execute on function public.places_for_county(text) to service_role;

do $a$
declare n int; bristol jsonb; dupnames int; codedup int; tot int;
begin
  select count(*) into n from geo_reference where level_type = 'minor_civil_division';
  select count(*) - count(distinct national_code) into codedup from geo_reference where country_iso = 'US' and admin_level = 3;
  bristol := public.places_for_county('US-44001');
  -- no county list may show a name twice
  select count(*) into dupnames from (
    select c.geo_id from geo_reference c
      cross join lateral jsonb_array_elements(public.places_for_county(c.geo_id)) e
     where c.admin1_abbr in ('RI', 'CT', 'NY') and c.admin_level = 2
     group by c.geo_id, lower(e->>'name') having count(*) > 1) d;
  select count(*) into tot from geo_reference where country_iso = 'US' and admin_level = 3;
  if n <> 11788 or codedup <> 0 or dupnames <> 0
     or not (bristol @> '[{"name":"Bristol"}]' and bristol @> '[{"name":"Barrington"}]' and bristol @> '[{"name":"Warren"}]') then
    raise exception '144b: MCDs % (11788) code-dups % repeated names % Bristol RI list %', n, codedup, dupnames, bristol;
  end if;
  raise notice '144b: admin_level 3 now %', tot;
end $a$;
