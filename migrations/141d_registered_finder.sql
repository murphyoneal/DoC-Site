-- 141d — self-registered businesses are findable in the finder, alongside register entries and
-- clearly labelled (ruling 699). A separate function and a separate block on the page, never a
-- union into contractor_finder: the two lists have different provenance and the page says which is
-- which. Only approved registrations whose business chose to be listed are returned, and only the
-- fields they switched on.
--
-- The finder's county filter is a Florida county KEY ('volusia', 'dade', 'st_johns'). It is mapped
-- to a geo_id here, inside Florida only (parent US-12), and the mapping is asserted below to be
-- 1:1 over all 67 keys - a name match that is checked, not assumed.

create or replace function public._fl_county_geo(p_key text) returns text
language sql stable set search_path = public as $$
  select geo_id from geo_reference
   where parent_geo_id = 'US-12' and admin_level = 2
     and (case when name = 'Miami-Dade' then 'dade' else replace(replace(lower(name), '.', ''), ' ', '_') end) = p_key
$$;

create or replace function public.registered_finder(q text default null, county text default null, lim integer default 30)
returns jsonb language sql stable security definer set search_path = public as $$
  with hits as (
    select b.slug, b.business_name, b.trades, s.name as state, s.admin1_abbr as state_abbr,
           co.name as county, co.level_type as county_level,
           case when b.publish_city then b.city end as city
      from registered_business b
      join geo_reference s on s.geo_id = b.state_geo_id
      left join geo_reference co on co.geo_id = b.county_geo_id
     where b.review_state = 'approved' and b.publish_listing
       and (county is null or b.county_geo_id = _fl_county_geo(county))
       and (q is null or btrim(q) = '' or b.business_name ilike '%' || btrim(q) || '%'
            or exists (select 1 from unnest(b.trades) t where t ilike '%' || btrim(q) || '%'))
     order by b.business_name
     limit greatest(1, least(coalesce(lim, 30), 100)))
  select jsonb_build_object('count', (select count(*) from hits),
                            'results', coalesce((select jsonb_agg(to_jsonb(h)) from hits h), '[]'::jsonb))
$$;

revoke all on function public.registered_finder(text, text, integer) from public, anon, authenticated;
grant execute on function public.registered_finder(text, text, integer) to service_role;

do $a$
declare n int; keys text[] := array['alachua','baker','bay','bradford','brevard','broward','calhoun','charlotte','citrus','clay','collier',
  'columbia','dade','desoto','dixie','duval','escambia','flagler','franklin','gadsden','gilchrist','glades',
  'gulf','hamilton','hardee','hendry','hernando','highlands','hillsborough','holmes','indian_river','jackson',
  'jefferson','lafayette','lake','lee','leon','levy','liberty','madison','manatee','marion','martin','monroe',
  'nassau','okaloosa','okeechobee','orange','osceola','palm_beach','pasco','pinellas','polk','putnam',
  'santa_rosa','sarasota','seminole','st_johns','st_lucie','sumter','suwannee','taylor','union','volusia',
  'wakulla','walton','washington'];
begin
  select count(distinct _fl_county_geo(k)) into n from unnest(keys) k where _fl_county_geo(k) is not null;
  if n <> 67 or cardinality(keys) <> 67 then raise exception '141d: county keys map to % geo_ids, expected 67', n; end if;
  if (public.registered_finder(null, null, 10)->>'count') is null then raise exception '141d: registered_finder returned no payload'; end if;
end $a$;
