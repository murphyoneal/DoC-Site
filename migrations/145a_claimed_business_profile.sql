-- 145a — what an approved contractor claim allows (work order 712 item 3; rulings R1, R2).
--
-- R1: a claimed business's own details live in business_profile, keyed on the BUSINESS
-- (businesses.id), never in the empty claimant columns of contractors. contractors is the DBPR copy,
-- it is per licence row, and contractors_public serves those columns to anyone holding the
-- publishable key - a phone number written there would be public at once, unreviewed.
-- Written ONLY by the approved claimant (the same gate as the photo gallery); every publish switch
-- defaults off in the schema.
--
-- R2: "claimed" is DERIVED - an approved claim_request on any licence of the business - and never
-- written onto the DBPR row. contractor_is_claimed() is the one definition; contractors_public and the
-- three functions that read contractors.claimed switch to it. contractors.claimed (false on every
-- row) is left in place and no longer read.
--
-- contractor_register_search is called from the browser as anon. Replacing it revokes its own grant
-- (trg_revoke_public_on_new_secdef), so it is re-granted here and asserted below.

create or replace function public.contractor_is_claimed(p_contractor_id uuid) returns boolean
language sql stable set search_path = public as $$
  select exists (
    select 1 from business_licences bl
      join business_licences sib on sib.business_id = bl.business_id
      join claim_requests cr on cr.contractor_id = sib.contractor_id and cr.status = 'approved'
     where bl.contractor_id = p_contractor_id)
$$;

-- ---- the business's own details --------------------------------------------------------------
create table if not exists public.business_profile (
  business_id        uuid primary key references public.businesses(id) on delete cascade,
  public_phone       text check (public_phone is null or length(public_phone) <= 40),
  public_email       text check (public_email is null or (public_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(public_email) <= 254)),
  website            text check (website is null or (website ~* '^https?://' and length(website) <= 300)),
  description        text check (description is null or length(description) <= 600),
  specialties        text[],
  other_specialties  text check (other_specialties is null or length(other_specialties) <= 200),
  counties_worked    text[],
  years_in_business  integer check (years_in_business is null or years_in_business between 0 and 150),
  publish_phone       boolean not null default false,
  publish_email       boolean not null default false,
  publish_website     boolean not null default false,
  publish_description boolean not null default false,
  publish_specialties boolean not null default false,
  publish_counties    boolean not null default false,
  publish_years       boolean not null default false,
  updated_by         text not null,
  updated_at         timestamptz not null default now()
);

-- Insurance and workers' comp as the business declares them. We hold no insurance records, so every
-- one is shown as declared, beside the statement that we cannot check it.
create table if not exists public.business_declared_insurance (
  id          uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  kind        text not null check (kind in ('general_liability', 'workers_comp', 'other')),
  carrier     text not null check (length(carrier) between 1 and 200),
  cover_note  text check (cover_note is null or length(cover_note) <= 200),
  expires_on  date,
  publish     boolean not null default false,
  declared_at timestamptz not null default now()
);
create index if not exists business_declared_insurance_business_idx on public.business_declared_insurance(business_id);

alter table public.business_profile enable row level security;
alter table public.business_declared_insurance enable row level security;
revoke all on public.business_profile, public.business_declared_insurance from anon, authenticated;
grant select, insert, update, delete on public.business_profile, public.business_declared_insurance to service_role;

insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by, classified_on)
select 'business_profile', c, 'ours', 'false = the business has not switched this field on; nothing is published by default (712, R1)', 'cc', date '2026-09-28'
  from unnest(array['publish_phone','publish_email','publish_website','publish_description','publish_specialties','publish_counties','publish_years']) c
union all
select 'business_declared_insurance', 'publish', 'ours', 'false = the business has not switched this entry on', 'cc', date '2026-09-28'
on conflict do nothing;

-- ---- Murphy's review of a claim ---------------------------------------------------------------
create or replace function public.review_claim(p_id uuid, p_decision text, p_note text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v claim_requests%rowtype; v_slug text;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'decision must be approved or rejected'; end if;
  update claim_requests set status = p_decision, reviewed_at = now(), reviewed_by = 'murphy', updated_at = now(),
         message = case when p_note is null then message else coalesce(message || E'\n', '') || '[review] ' || p_note end
   where id = p_id returning * into v;
  if not found then raise exception 'no claim %', p_id; end if;
  select b.slug into v_slug from business_licences bl join businesses b on b.id = bl.business_id where bl.contractor_id = v.contractor_id limit 1;
  return jsonb_build_object('id', v.id, 'status', v.status, 'business_slug', v_slug,
    'claimed_now', contractor_is_claimed(v.contractor_id), 'claimant_email', v.requester_email);
end $$;

-- ---- the claimant's editor: read and save, behind the photo gate ------------------------------
create or replace function public.business_profile_get(p_slug text, p_email text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g jsonb; bid uuid;
begin
  g := work_upload_gate(p_slug, p_email);
  if not (g->>'allowed')::boolean then return g; end if;
  bid := (g->>'business_id')::uuid;
  return g || jsonb_build_object(
    'profile', (select to_jsonb(p) - 'business_id' from business_profile p where p.business_id = bid),
    'insurance', coalesce((select jsonb_agg(jsonb_build_object('kind', kind, 'carrier', carrier, 'cover_note', cover_note,
                   'expires_on', expires_on, 'publish', publish) order by declared_at) from business_declared_insurance where business_id = bid), '[]'::jsonb));
end $$;

create or replace function public.business_profile_save(p_slug text, p_email text, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare g jsonb; bid uuid; x jsonb; bad text;
begin
  g := work_upload_gate(p_slug, p_email);
  if not (g->>'allowed')::boolean then return g; end if;
  bid := (g->>'business_id')::uuid;
  -- counties must be real counties; specialties must be trade keys
  select string_agg(c, ',') into bad from jsonb_array_elements_text(coalesce(p->'counties_worked', '[]')) c
   where not exists (select 1 from geo_reference where geo_id = c and admin_level = 2);
  if bad is not null then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'counties_worked'); end if;
  if jsonb_array_length(coalesce(p->'insurance', '[]')) > 10 then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance'); end if;

  insert into business_profile as bp (business_id, public_phone, public_email, website, description, specialties, other_specialties,
      counties_worked, years_in_business, publish_phone, publish_email, publish_website, publish_description, publish_specialties,
      publish_counties, publish_years, updated_by, updated_at)
  values (bid, nullif(btrim(p->>'public_phone'), ''), nullif(lower(btrim(p->>'public_email')), ''), nullif(btrim(p->>'website'), ''),
      nullif(btrim(p->>'description'), ''),
      nullif(array(select jsonb_array_elements_text(coalesce(p->'specialties', '[]'))), '{}'),
      nullif(btrim(p->>'other_specialties'), ''),
      nullif(array(select jsonb_array_elements_text(coalesce(p->'counties_worked', '[]'))), '{}'),
      nullif(p->>'years_in_business', '')::int,
      coalesce((p->>'publish_phone')::boolean, false), coalesce((p->>'publish_email')::boolean, false),
      coalesce((p->>'publish_website')::boolean, false), coalesce((p->>'publish_description')::boolean, false),
      coalesce((p->>'publish_specialties')::boolean, false), coalesce((p->>'publish_counties')::boolean, false),
      coalesce((p->>'publish_years')::boolean, false), lower(p_email), now())
  on conflict (business_id) do update set
      public_phone = excluded.public_phone, public_email = excluded.public_email, website = excluded.website,
      description = excluded.description, specialties = excluded.specialties, other_specialties = excluded.other_specialties,
      counties_worked = excluded.counties_worked, years_in_business = excluded.years_in_business,
      publish_phone = excluded.publish_phone, publish_email = excluded.publish_email, publish_website = excluded.publish_website,
      publish_description = excluded.publish_description, publish_specialties = excluded.publish_specialties,
      publish_counties = excluded.publish_counties, publish_years = excluded.publish_years,
      updated_by = excluded.updated_by, updated_at = now();

  delete from business_declared_insurance where business_id = bid;
  for x in select * from jsonb_array_elements(coalesce(p->'insurance', '[]')) loop
    if nullif(btrim(x->>'carrier'), '') is null then continue; end if;
    insert into business_declared_insurance (business_id, kind, carrier, cover_note, expires_on, publish)
    values (bid, coalesce(nullif(x->>'kind', ''), 'other'), btrim(x->>'carrier'), nullif(btrim(x->>'cover_note'), ''),
            nullif(x->>'expires_on', '')::date, coalesce((x->>'publish')::boolean, false));
  end loop;
  return jsonb_build_object('allowed', true, 'saved', true);
end $$;

-- ---- what the public page shows: switched-on fields of a CLAIMED business only ---------------
create or replace function public.business_profile_public(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when p.business_id is null then null else jsonb_strip_nulls(jsonb_build_object(
      'phone',       case when p.publish_phone then p.public_phone end,
      'email',       case when p.publish_email then p.public_email end,
      'website',     case when p.publish_website then p.website end,
      'description', case when p.publish_description then p.description end,
      'specialties', case when p.publish_specialties then p.specialties end,
      'other_specialties', case when p.publish_specialties then p.other_specialties end,
      'counties',    case when p.publish_counties then (select jsonb_agg(case when g.level_type = 'county' then g.name || ' County' else g.name end || ', ' || s.admin1_abbr order by s.admin1_abbr, g.name)
                                                          from geo_reference g join geo_reference s on s.geo_id = g.parent_geo_id
                                                         where g.geo_id = any(p.counties_worked)) end,
      'years_in_business', case when p.publish_years then p.years_in_business end,
      'insurance',   (select jsonb_agg(jsonb_build_object('kind', i.kind, 'carrier', i.carrier, 'cover_note', i.cover_note,
                        'expires_on', i.expires_on, 'declared_at', i.declared_at::date,
                        'check_note', 'We do not hold insurance records, so this cannot be checked.') order by i.declared_at)
                        from business_declared_insurance i where i.business_id = b.id and i.publish),
      'updated_on',  p.updated_at::date)) end
    from businesses b
    left join business_profile p on p.business_id = b.id
   where b.slug = p_slug
     and exists (select 1 from business_licences bl where bl.business_id = b.id and contractor_is_claimed(bl.contractor_id))
$$;

revoke all on function public.review_claim(uuid, text, text), public.business_profile_get(text, text),
  public.business_profile_save(text, text, jsonb), public.business_profile_public(text) from public, anon, authenticated;
grant execute on function public.review_claim(uuid, text, text), public.business_profile_get(text, text),
  public.business_profile_save(text, text, jsonb), public.business_profile_public(text) to service_role;

-- ---- R2: every reader of "claimed" reads the derived value -----------------------------------
do $f$
declare def text; nd text; fn text;
begin
  foreach fn in array array['contractor_register_search(text,integer)', 'contractor_finder(text,text,text,integer,integer)', 'get_related_businesses'] loop
    if fn = 'get_related_businesses' then
      select p.oid::regprocedure::text into fn from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = 'get_related_businesses';
    end if;
    def := pg_get_functiondef(fn::regprocedure);
    nd := replace(replace(def, 'coalesce(c.claimed,false)', 'public.contractor_is_claimed(c.id)'),
                                'coalesce(c.claimed, false)', 'public.contractor_is_claimed(c.id)');
    if nd = def then raise exception '145a: no claimed anchor in %', fn; end if;
    if nd ~ '\mc\.claimed\M' then raise exception '145a: a raw c.claimed remains in %', fn; end if;
    execute nd;
  end loop;
end $f$;

grant execute on function public.contractor_register_search(text, integer) to anon, authenticated;

-- contractors_public: same columns, same order; "claimed" becomes the derived value. Grants on a view
-- survive CREATE OR REPLACE VIEW.
do $v$
declare def text; nd text;
begin
  def := pg_get_viewdef('public.contractors_public'::regclass);
  nd := replace(def, E'\n    claimed,\n', E'\n    public.contractor_is_claimed(contractors.id) AS claimed,\n');
  if nd = def then raise exception '145a: claimed anchor missing in contractors_public'; end if;
  execute 'create or replace view public.contractors_public as ' || nd;
end $v$;

do $a$
begin
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'EXECUTE') then
    raise exception '145a: contractor_register_search lost its anon grant';
  end if;
  if not has_table_privilege('anon', 'public.contractors_public', 'SELECT') then
    raise exception '145a: contractors_public lost its anon grant';
  end if;
  if exists (select 1 from contractors_public where claimed) then
    raise exception '145a: a business reads as claimed with no approved claim';
  end if;
  if (select (public.contractor_register_search('roofing', 5)) is null) then
    raise exception '145a: contractor_register_search returned nothing';
  end if;
end $a$;
