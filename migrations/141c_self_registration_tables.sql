-- 141c — self-registration for businesses in any of the 50 states and DC (work order 699, ruling 701).
--
-- WHAT A REGISTRATION WRITES TO. contractors is a copy of the Florida DBPR licence file and a person
-- never writes to it. A self-registration is a business's own DECLARATION, so it lives in its own
-- tables and is joined at READ time only:
--   registered_business    - who they say they are, where, what they do; private contact; per-field
--                            publish choices; our review state.
--   registered_credential  - each licence / certification / insurance they declare, and SEPARATELY
--                            our check of it. Declaration and check are different facts.
--   register_coverage      - which state registers we hold, per profession. The check reads it, so
--                            "no match" can only ever be said where we hold the register.
--
-- THE CHECK has three states (ruling 648/651 vocabulary):
--   register_held_matched  - we hold that state's register and the number is in it.
--   register_held_no_match - we hold it and the number is not in it. A real negative, only where held.
--   register_not_held      - we do not hold that register. SAYS NOTHING ABOUT THE BUSINESS.
-- Certifications and insurance are never checkable (we hold no such registers) and read not_held.
--
-- PUBLICATION: nothing is public until Murphy approves it (review_state, ruling 701 §1) AND the
-- business has switched each field on. Every publish flag defaults FALSE in the schema, so a field
-- nobody chose is a field nobody sees.
--
-- FLORIDA DUPLICATES (ruling 701 §5): a declared Florida licence that is in the register AND whose
-- business name agrees is the same business - self_register() does not insert, it returns that
-- profile so the form sends them to its claim. A licence match with a different name, or a name
-- match with no licence match, is a NEAR MATCH: it is inserted, flagged, and goes to a person.
--
-- All functions are SECURITY DEFINER and service_role only; the browser reaches them through
-- server routes. International is keyed (country_iso) and not built.

create table if not exists public.register_coverage (
  state_geo_id   text not null references public.geo_reference(geo_id),
  profession     text not null check (profession in ('construction', 'electrical')),
  coverage_state text not null check (coverage_state in ('held', 'not_held')),
  source         text,
  retrieved_date date,
  notes          text,
  primary key (state_geo_id, profession)
);

create table if not exists public.registered_business (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,
  business_name   text not null check (length(btrim(business_name)) between 2 and 200),
  country_iso     text not null check (country_iso = 'US'),
  state_geo_id    text not null references public.geo_reference(geo_id),
  county_geo_id   text references public.geo_reference(geo_id),
  city            text check (city is null or length(city) <= 100),
  trades          text[],
  other_services  text check (other_services is null or length(other_services) <= 500),
  contact_name    text check (contact_name is null or length(contact_name) <= 200),
  contact_email   text not null check (contact_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(contact_email) <= 254),
  public_phone    text check (public_phone is null or length(public_phone) <= 40),
  website         text check (website is null or website ~* '^https?://' and length(website) <= 300),
  publish_listing boolean not null default false,
  publish_city    boolean not null default false,
  publish_phone   boolean not null default false,
  publish_website boolean not null default false,
  review_state    text not null default 'received' check (review_state in ('received', 'approved', 'rejected', 'withdrawn')),
  reviewed_at     timestamptz,
  review_note     text,
  florida_duplicate_state text not null check (florida_duplicate_state in ('not_checked', 'no_match', 'near_match_licence', 'near_match_name')),
  florida_duplicate_slugs text[],
  created_at      timestamptz not null default now()
);

create table if not exists public.registered_credential (
  id                    uuid primary key default gen_random_uuid(),
  business_id           uuid not null references public.registered_business(id) on delete cascade,
  kind                  text not null check (kind in ('licence', 'certification', 'insurance')),
  issuing_state_geo_id  text references public.geo_reference(geo_id),
  profession            text check (profession in ('construction', 'electrical')),
  trade                 text check (trade is null or length(trade) <= 100),
  number                text check (number is null or length(number) <= 60),
  issuer                text check (issuer is null or length(issuer) <= 200),
  expires_on            date,
  publish               boolean not null default false,
  check_state           text not null check (check_state in ('register_held_matched', 'register_held_no_match', 'register_not_held')),
  checked_against       text,
  check_note            text,
  matched_contractor_id uuid,
  matched_slug          text,
  checked_at            timestamptz not null default now(),
  declared_at           timestamptz not null default now(),
  check (kind <> 'licence' or (issuing_state_geo_id is not null and number is not null))
);
create index if not exists registered_credential_business_idx on public.registered_credential(business_id);
create index if not exists registered_business_state_idx on public.registered_business(state_geo_id) where review_state = 'approved' and publish_listing;

alter table public.register_coverage enable row level security;
alter table public.registered_business enable row level security;
alter table public.registered_credential enable row level security;
revoke all on public.register_coverage, public.registered_business, public.registered_credential from anon, authenticated;
grant select, insert, update, delete on public.register_coverage, public.registered_business, public.registered_credential to service_role;

-- The defaults above are OUR state (unpublished, unreviewed), never a fact about the business.
insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by, classified_on) values
  ('registered_business', 'publish_listing', 'ours', 'false = we have not been told to publish; the business switches it on (ruling 699: off in the schema)', 'cc', '2026-09-27'),
  ('registered_business', 'publish_city',    'ours', 'false = we have not been told to publish the city', 'cc', '2026-09-27'),
  ('registered_business', 'publish_phone',   'ours', 'false = we have not been told to publish the phone', 'cc', '2026-09-27'),
  ('registered_business', 'publish_website', 'ours', 'false = we have not been told to publish the website', 'cc', '2026-09-27'),
  ('registered_business', 'review_state',    'ours', 'received = our review has not happened yet; says nothing about the business', 'cc', '2026-09-27'),
  ('registered_credential', 'publish',       'ours', 'false = we have not been told to publish this credential', 'cc', '2026-09-27')
on conflict do nothing;

-- Coverage: every state and DC x both professions, explicitly. Florida construction is the DBPR
-- file; Florida ELECTRICAL is licensed by a separate board and is NOT in that file, so an EC/ER
-- number checked against it would be a false "no match" - it is not_held.
insert into public.register_coverage (state_geo_id, profession, coverage_state, source, retrieved_date, notes)
select g.geo_id, p.profession,
       case when g.geo_id = 'US-12' and p.profession = 'construction' then 'held' else 'not_held' end,
       case when g.geo_id = 'US-12' and p.profession = 'construction' then 'Florida DBPR construction licence file (Construction Industry Licensing Board)' end,
       case when g.geo_id = 'US-12' and p.profession = 'construction' then (select max(register_file_date) from public.contractors) end,
       case when g.geo_id = 'US-12' and p.profession = 'electrical' then 'Electrical contractors are licensed by the Electrical Contractors'' Licensing Board and are not in the construction file we hold.' end
  from public.geo_reference g
 cross join (values ('construction'), ('electrical')) p(profession)
 where g.country_iso = 'US' and g.admin_level = 1
on conflict (state_geo_id, profession) do nothing;

create or replace function public._reg_norm_name(p text) returns text
language sql immutable set search_path = public as $$
  select btrim(regexp_replace(
           regexp_replace(lower(coalesce(p, '')), '[^a-z0-9 ]', ' ', 'g'),
           '\m(llc|l l c|inc|incorporated|corp|corporation|co|company|ltd|pllc|pa|the)\M', ' ', 'g'), ' ')
$$;

create or replace function public._reg_norm_licence(p text) returns text
language sql immutable set search_path = public as $$
  select upper(regexp_replace(coalesce(p, ''), '[^A-Za-z0-9]', '', 'g'))
$$;

-- One credential's check. Reads coverage first: where we do not hold the register, nothing else runs.
create or replace function public.registration_check_credential(p_kind text, p_state text, p_profession text, p_number text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_cov   register_coverage%rowtype;
  v_norm  text := _reg_norm_licence(p_number);
  v_prof  text := coalesce(p_profession, 'construction');
  v_state text; v_hit record;
begin
  if p_kind <> 'licence' then
    return jsonb_build_object('check_state', 'register_not_held',
      'check_note', 'We do not hold ' || case when p_kind = 'insurance' then 'insurance' else 'certification' end || ' records, so this cannot be checked.');
  end if;
  select name into v_state from geo_reference where geo_id = p_state;
  -- a Florida EC/ER/EF number is an electrical licence whatever trade was ticked
  if p_state = 'US-12' and v_norm ~ '^E[CRF][0-9]' then v_prof := 'electrical'; end if;
  select * into v_cov from register_coverage where state_geo_id = p_state and profession = v_prof;
  if not found or v_cov.coverage_state <> 'held' then
    return jsonb_build_object('check_state', 'register_not_held', 'profession', v_prof,
      'check_note', 'Not verified. We don''t yet hold ' || coalesce(v_state, 'this state') || '''s '
        || case when v_prof = 'electrical' then 'electrical ' else '' end
        || 'licence records, so we can''t check this against the state register.');
  end if;
  select c.id, c.license_number, c.register_file_state, b.slug into v_hit
    from contractors c
    left join business_licences bl on bl.contractor_id = c.id
    left join businesses b on b.id = bl.business_id
   where _reg_norm_licence(c.license_number) = v_norm and v_norm <> ''
   order by (c.register_file_state = 'in_latest_file') desc
   limit 1;
  if not found then
    return jsonb_build_object('check_state', 'register_held_no_match', 'profession', v_prof,
      'checked_against', v_cov.source || ', retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY'),
      'check_note', 'Not found in the ' || v_state || ' licence file retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY') || '.');
  end if;
  return jsonb_build_object('check_state', 'register_held_matched', 'profession', v_prof,
    'checked_against', v_cov.source || ', retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY'),
    'matched_contractor_id', v_hit.id, 'matched_slug', v_hit.slug,
    'check_note', 'Matches the ' || v_state || ' licence file retrieved ' || to_char(v_cov.retrieved_date, 'FMDD Mon YYYY')
      || case when v_hit.register_file_state = 'absent_from_latest_file' then ' (the licence was in an earlier file and is not in the latest one)' else '' end || '.');
end $$;

-- The form's one write. Validates, checks every credential, applies the Florida duplicate rule,
-- then inserts - or does NOT insert and returns the existing profile.
create or replace function public.self_register(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  v_name   text := btrim(coalesce(p->>'business_name', ''));
  v_state  text := p->>'state';
  v_county text := nullif(p->>'county', '');
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

  -- Florida duplicate rule. Exact = the matched licence's business has the same name.
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

  insert into registered_business (slug, business_name, country_iso, state_geo_id, county_geo_id, city, trades, other_services,
      contact_name, contact_email, public_phone, website, publish_listing, publish_city, publish_phone, publish_website,
      florida_duplicate_state, florida_duplicate_slugs)
  values (v_slug, v_name, 'US', v_state, v_county, nullif(btrim(p->>'city'), ''),
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

-- The public /r/{slug} page. Returns nothing unless approved AND the business chose to list it;
-- every field is gated by its own flag. The private email is never returned.
create or replace function public.registered_business_page(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'slug', b.slug, 'business_name', b.business_name,
    'state', s.name, 'state_abbr', s.admin1_abbr,
    'county', co.name, 'county_level', co.level_type,
    'city', case when b.publish_city then b.city end,
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

-- Murphy's review. approved / rejected / withdrawn; records when and why.
create or replace function public.review_registration(p_id uuid, p_decision text, p_note text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v registered_business%rowtype;
begin
  if p_decision not in ('approved', 'rejected', 'withdrawn') then raise exception 'decision must be approved, rejected or withdrawn'; end if;
  update registered_business set review_state = p_decision, reviewed_at = now(), review_note = p_note
   where id = p_id returning * into v;
  if not found then raise exception 'no registration %', p_id; end if;
  return jsonb_build_object('id', v.id, 'slug', v.slug, 'review_state', v.review_state,
    'publicly_listed', v.review_state = 'approved' and v.publish_listing);
end $$;

-- Murphy's queue: what is waiting, and which ones need a person because of a Florida near match.
create or replace view public.registration_review_queue as
select b.id, b.created_at, b.business_name, s.admin1_abbr as state, co.name as county, b.city, b.trades,
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

revoke all on function public.registration_check_credential(text, text, text, text) from public, anon, authenticated;
revoke all on function public.self_register(jsonb) from public, anon, authenticated;
revoke all on function public.registered_business_page(text) from public, anon, authenticated;
revoke all on function public.review_registration(uuid, text, text) from public, anon, authenticated;
grant execute on function public.registration_check_credential(text, text, text, text), public.self_register(jsonb),
  public.registered_business_page(text), public.review_registration(uuid, text, text) to service_role;
