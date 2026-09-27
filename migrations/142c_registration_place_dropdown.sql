-- 142c — the registration's city becomes a choice from the Census places in the chosen county, with a
-- fixed "Rural / unincorporated" value (work order 705, Murphy's ruling). Free text goes: the city
-- column is dropped (registered_business had 0 rows) so there is no path left for typing a town.
--
-- THREE STATES, never two:
--   place_state = 'place'          + place_geo_id  - a Census 2020 place in that county
--   place_state = 'unincorporated'                 - STATED, and the answer is: no incorporated place
--   place_state IS NULL                            - not stated
-- 'unincorporated' is a value we control: it cannot carry typed text, it is filterable, and it is
-- visible at review as an ordinary answer rather than a blank.
--
-- This raises the effort for someone typing nonsense; it does not stop a determined faker, who picks
-- a real town. The control against fakes is Murphy reading every registration before it publishes.
--
-- Payload shapes are unchanged: registered_business_page and registered_finder still return "city"
-- (now derived from the place), and self_register still returns the same keys. The live form keeps
-- working until the new one deploys: it sends free-text "city", which is now ignored (place not stated).

-- the review queue view reads the old column, so it goes first and is recreated below
drop view if exists public.registration_review_queue;
alter table public.registered_business drop column if exists city;
alter table public.registered_business add column if not exists place_geo_id text references public.geo_reference(geo_id);
alter table public.registered_business add column if not exists place_state text
  check (place_state in ('place', 'unincorporated'));
alter table public.registered_business drop constraint if exists registered_business_place_chk;
alter table public.registered_business add constraint registered_business_place_chk check (
      (place_state is null and place_geo_id is null)
   or (place_state = 'place' and place_geo_id is not null and county_geo_id is not null)
   or (place_state = 'unincorporated' and place_geo_id is null and county_geo_id is not null));

-- A place's display name comes from the Census list (the 410 Florida rows we already held are stored
-- upper-case, "DELAND"; the Census legal name gives "DeLand").
create or replace function public._place_display(p_geo_id text) returns text
language sql stable set search_path = public as $$
  select coalesce(_census_place_base(c.placename), g.name)
    from geo_reference g
    left join census_place_2020 c on c.statefp || c.placefp = g.national_code
   where g.geo_id = p_geo_id and g.admin_level = 3
$$;

-- The dropdown: every Census place in one county, alphabetical. A name that occurs twice in the same
-- county list says which kind it is, so the two entries can be told apart.
create or replace function public.places_for_county(p_county text)
returns jsonb language sql stable security definer set search_path = public as $$
  with p as (
    select g.geo_id, _place_display(g.geo_id) as name, g.level_type
      from geo_place_county x join geo_reference g on g.geo_id = x.place_geo_id
     where x.county_geo_id = p_county),
  d as (select p.*, count(*) over (partition by name) as same_name from p)
  select coalesce(jsonb_agg(jsonb_build_object('geo_id', geo_id,
           'name', case when same_name > 1
                        then name || case when level_type = 'census_designated_place' then ' (census-designated place)' else ' (incorporated)' end
                        else name end,
           'kind', level_type) order by name, level_type desc), '[]'::jsonb)
    from d
$$;

create or replace function public.self_register(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_name   text := btrim(coalesce(p->>'business_name', ''));
  v_state  text := p->>'state';
  v_county text := nullif(p->>'county', '');
  v_place  text := nullif(p->>'place', '');
  v_place_state text; v_place_geo text;
  v_email  text := lower(btrim(coalesce(p->>'contact_email', '')));
  v_creds  jsonb := coalesce(p->'credentials', '[]'::jsonb);
  v_checked jsonb := '[]'::jsonb;
  c jsonb; ck jsonb;
  v_lic_slugs text[] := '{}'; v_name_slugs text[] := '{}'; v_same text;
  v_dup text; v_dup_slugs text[];
  v_id uuid; v_slug text; v_abbr text; v_i int := 0;
begin
  if length(v_name) < 2 or length(v_name) > 200 then return jsonb_build_object('outcome', 'invalid', 'field', 'business_name'); end if;
  select admin1_abbr into v_abbr from geo_reference where geo_id = v_state and country_iso = 'US' and admin_level = 1;
  if v_abbr is null then return jsonb_build_object('outcome', 'invalid', 'field', 'state'); end if;
  if v_county is not null and not exists (select 1 from geo_reference where geo_id = v_county and parent_geo_id = v_state and admin_level = 2) then
    return jsonb_build_object('outcome', 'invalid', 'field', 'county');
  end if;
  if v_place is not null then
    if v_county is null then return jsonb_build_object('outcome', 'invalid', 'field', 'place'); end if;
    if v_place = 'unincorporated' then
      v_place_state := 'unincorporated';
    elsif exists (select 1 from geo_place_county where place_geo_id = v_place and county_geo_id = v_county) then
      v_place_state := 'place'; v_place_geo := v_place;
    else
      return jsonb_build_object('outcome', 'invalid', 'field', 'place');
    end if;
  end if;
  if v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return jsonb_build_object('outcome', 'invalid', 'field', 'contact_email'); end if;
  if jsonb_typeof(v_creds) <> 'array' or jsonb_array_length(v_creds) > 20 then return jsonb_build_object('outcome', 'invalid', 'field', 'credentials'); end if;

  for c in select * from jsonb_array_elements(v_creds) loop
    v_i := v_i + 1;
    if (c->>'kind') not in ('licence', 'certification', 'insurance') then
      return jsonb_build_object('outcome', 'invalid', 'field', 'credentials', 'index', v_i);
    end if;
    if (c->>'kind') = 'licence' and (nullif(btrim(c->>'number'), '') is null or not exists
        (select 1 from geo_reference where geo_id = c->>'issuing_state' and country_iso = 'US' and admin_level = 1)) then
      return jsonb_build_object('outcome', 'invalid', 'field', 'credentials', 'index', v_i);
    end if;
    ck := registration_check_credential(c->>'kind', c->>'issuing_state', c->>'profession', c->>'number');
    v_checked := v_checked || jsonb_build_array(c || ck);
    if ck->>'check_state' = 'register_held_matched' and ck->>'matched_slug' is not null then
      v_lic_slugs := v_lic_slugs || (ck->>'matched_slug');
    end if;
  end loop;

  if v_state = 'US-12' or cardinality(v_lic_slugs) > 0 then
    select b.slug into v_same from businesses b
     where b.slug = any(v_lic_slugs) and _reg_norm_name(b.display_name) = _reg_norm_name(v_name) limit 1;
    if v_same is not null then
      return jsonb_build_object('outcome', 'existing', 'slug', v_same,
        'note', 'This business is already in the Florida register. Claim that entry instead of registering again.');
    end if;
    if v_state = 'US-12' then
      select coalesce(array_agg(slug), '{}') into v_name_slugs from (
        select b.slug from businesses b where _reg_norm_name(b.display_name) = _reg_norm_name(v_name)
          and _reg_norm_name(v_name) <> '' limit 10) x;
    end if;
    v_dup := case when cardinality(v_lic_slugs) > 0 then 'near_match_licence'
                  when cardinality(v_name_slugs) > 0 then 'near_match_name' else 'no_match' end;
    v_dup_slugs := nullif(array(select distinct unnest(v_lic_slugs || v_name_slugs)), '{}');
  else
    v_dup := 'not_checked';
  end if;

  v_slug := trim(both '-' from regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'));
  v_slug := left(v_slug, 60) || '-' || lower(v_abbr) || '-' || substr(md5(random()::text || clock_timestamp()::text), 1, 6);

  insert into registered_business (slug, business_name, country_iso, state_geo_id, county_geo_id, place_geo_id, place_state,
      trades, other_services, contact_name, contact_email, public_phone, website,
      publish_listing, publish_city, publish_phone, publish_website, florida_duplicate_state, florida_duplicate_slugs)
  values (v_slug, v_name, 'US', v_state, v_county, v_place_geo, v_place_state,
      nullif(array(select jsonb_array_elements_text(coalesce(p->'trades', '[]'::jsonb))), '{}'),
      nullif(btrim(p->>'other_services'), ''), nullif(btrim(p->>'contact_name'), ''), v_email,
      nullif(btrim(p->>'public_phone'), ''), nullif(btrim(p->>'website'), ''),
      coalesce((p->'publish'->>'listing')::boolean, false), coalesce((p->'publish'->>'city')::boolean, false),
      coalesce((p->'publish'->>'phone')::boolean, false), coalesce((p->'publish'->>'website')::boolean, false),
      v_dup, v_dup_slugs)
  returning id into v_id;

  insert into registered_credential (business_id, kind, issuing_state_geo_id, profession, trade, number, issuer, expires_on,
      publish, check_state, checked_against, check_note, matched_contractor_id, matched_slug)
  select v_id, x->>'kind', nullif(x->>'issuing_state', ''), x->>'profession', nullif(btrim(x->>'trade'), ''),
         nullif(btrim(x->>'number'), ''), nullif(btrim(x->>'issuer'), ''), nullif(x->>'expires_on', '')::date,
         coalesce((x->>'publish')::boolean, false), x->>'check_state', x->>'checked_against', x->>'check_note',
         nullif(x->>'matched_contractor_id', '')::uuid, x->>'matched_slug'
    from jsonb_array_elements(v_checked) x;

  return jsonb_build_object('outcome', 'received', 'id', v_id, 'slug', v_slug,
    'florida_duplicate_state', v_dup, 'florida_duplicate_slugs', to_jsonb(v_dup_slugs),
    'credentials', (select jsonb_agg(jsonb_build_object('kind', x->>'kind', 'number', x->>'number',
        'issuing_state', x->>'issuing_state', 'check_state', x->>'check_state', 'check_note', x->>'check_note')) from jsonb_array_elements(v_checked) x));
end $$;

-- "city" on the public page: the place, or "Unincorporated <county>", only if the business ticked it.
create or replace function public._registered_city(b registered_business) returns text
language sql stable set search_path = public as $$
  select case when not b.publish_city then null
              when b.place_state = 'place' then _place_display(b.place_geo_id)
              when b.place_state = 'unincorporated' then
                'Unincorporated ' || (select case when level_type = 'county' then name || ' County' else name end
                                        from geo_reference where geo_id = b.county_geo_id)
         end
$$;

create or replace function public.registered_business_page(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'slug', b.slug, 'business_name', b.business_name,
    'state', s.name, 'state_abbr', s.admin1_abbr,
    'county', co.name, 'county_level', co.level_type,
    'city', _registered_city(b),
    'trades', b.trades, 'other_services', b.other_services,
    'public_phone', case when b.publish_phone then b.public_phone end,
    'website', case when b.publish_website then b.website end,
    'registered_on', b.created_at::date, 'approved_on', b.reviewed_at::date,
    'credentials', coalesce((select jsonb_agg(jsonb_build_object(
        'kind', rc.kind, 'number', rc.number, 'issuing_state', ist.name, 'trade', rc.trade, 'issuer', rc.issuer,
        'expires_on', rc.expires_on, 'declared_at', rc.declared_at::date,
        'check_state', rc.check_state, 'check_note', rc.check_note, 'checked_at', rc.checked_at::date,
        'matched_slug', rc.matched_slug) order by rc.kind, rc.declared_at)
      from registered_credential rc left join geo_reference ist on ist.geo_id = rc.issuing_state_geo_id
      where rc.business_id = b.id and rc.publish), '[]'::jsonb))
  from registered_business b
  join geo_reference s on s.geo_id = b.state_geo_id
  left join geo_reference co on co.geo_id = b.county_geo_id
  where b.slug = p_slug and b.review_state = 'approved' and b.publish_listing
$$;

create or replace function public.registered_finder(q text default null, county text default null, lim integer default 30)
returns jsonb language sql stable security definer set search_path = public as $$
  with hits as (
    select b.slug, b.business_name, b.trades, s.name as state, s.admin1_abbr as state_abbr,
           co.name as county, co.level_type as county_level,
           _registered_city(b) as city
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

create view public.registration_review_queue as
select b.id, b.created_at, b.business_name, s.admin1_abbr as state, co.name as county,
       case b.place_state when 'place' then _place_display(b.place_geo_id) when 'unincorporated' then 'Unincorporated' end as place,
       b.place_state, b.trades,
       b.contact_name, b.contact_email, b.publish_listing, b.florida_duplicate_state, b.florida_duplicate_slugs,
       (select jsonb_agg(jsonb_build_object('kind', rc.kind, 'number', rc.number, 'state', rc.issuing_state_geo_id,
                                            'check', rc.check_state, 'note', rc.check_note))
          from registered_credential rc where rc.business_id = b.id) as credentials
  from registered_business b
  join geo_reference s on s.geo_id = b.state_geo_id
  left join geo_reference co on co.geo_id = b.county_geo_id
 where b.review_state = 'received'
 order by b.created_at;
revoke all on public.registration_review_queue from anon, authenticated;

revoke all on function public.places_for_county(text), public.self_register(jsonb), public.registered_business_page(text),
  public.registered_finder(text, text, integer) from public, anon, authenticated;
grant execute on function public.places_for_county(text), public.self_register(jsonb), public.registered_business_page(text),
  public.registered_finder(text, text, integer) to service_role;
