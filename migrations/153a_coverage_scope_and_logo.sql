-- 153a — work order 733: coverage as the business's own choice, and a logo. Plus a standing sweep of
-- published free text (733 item 3).
--
-- COVERAGE. business_profile had counties_worked only, so a statewide licence could not say so.
--   coverage_scope: 'nationwide' | 'statewide' | 'counties' - and NO DEFAULT. It is a fact about the
--   subject: the business declares it or it is absent. NOT inferred from the licence (a DBPR certified
--   licence is statewide, a registered one is not; deriving it would publish our inference as their
--   words). Registered in column_default_authorship as deliberately default-free.
--   Backfill: rows that already listed counties declared 'counties' themselves (the only option they
--   had), so scope = 'counties' for those - taken from their own entry, never from a licence.
--   publish_coverage is a NEW switch (default false, ours). publish_counties is not renamed: the
--   editor already deployed still sends it, and a rename would have reset the switch on its next save
--   before the new editor shipped. The save accepts either name; the public page reads
--   publish_coverage; publish_counties retires later.
--
-- LOGO. logo_path (the private, re-encoded copy) + publish_logo (default false, ours). The file is
--   copied to the public bucket only while the switch is on, at a path of our ids - never the
--   uploader's filename. EXIF is stripped by re-encoding; the gallery's GPS check is NOT run and no
--   location state is written: a logo is artwork, not a photograph of a place. It sits beside the
--   business name, never in place of it.

alter table public.business_profile
  add column if not exists coverage_scope text check (coverage_scope in ('nationwide', 'statewide', 'counties')),
  add column if not exists coverage_state_geo_id text references public.geo_reference(geo_id),
  add column if not exists publish_coverage boolean not null default false,
  add column if not exists logo_path text,
  add column if not exists logo_updated_at timestamptz,
  add column if not exists publish_logo boolean not null default false;
alter table public.business_profile drop constraint if exists business_profile_coverage_chk;
alter table public.business_profile add constraint business_profile_coverage_chk check (
      coverage_scope is null
   or coverage_scope = 'nationwide'
   or (coverage_scope = 'statewide' and coverage_state_geo_id is not null)
   or (coverage_scope = 'counties' and cardinality(counties_worked) > 0));

update public.business_profile set coverage_scope = 'counties', publish_coverage = publish_counties
 where coverage_scope is null and cardinality(counties_worked) > 0;

insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by, classified_on) values
  ('business_profile', 'publish_coverage', 'ours', 'false = the business has not switched its coverage on (733)', 'cc', date '2026-09-28'),
  ('business_profile', 'publish_logo', 'ours', 'false = the business has not switched its logo on (733)', 'cc', date '2026-09-28'),
  ('business_profile', 'coverage_scope', 'theirs', 'DELIBERATELY NO DEFAULT: coverage is the business''s own statement; NULL until declared, never inferred from the licence type (733)', 'cc', date '2026-09-28')
on conflict do nothing;

insert into storage.buckets (id, name, public) values ('logo-private', 'logo-private', false), ('logo-public', 'logo-public', true)
on conflict (id) do nothing;

create or replace function public.business_profile_save(p_slug text, p_email text, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare g jsonb; bid uuid; ins jsonb; bad text; v_scope text; v_state text;
begin
  g := work_upload_gate(p_slug, p_email);
  if not (g->>'allowed')::boolean then return g; end if;
  bid := (g->>'business_id')::uuid;
  select string_agg(c, ',') into bad from jsonb_array_elements_text(coalesce(p->'counties_worked', '[]')) c
   where not exists (select 1 from geo_reference where geo_id = c and admin_level = 2);
  if bad is not null then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'counties_worked'); end if;
  if jsonb_array_length(coalesce(p->'insurance', '[]')) > 10 then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance'); end if;
  if offensive_text(p->>'description') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'description', 'reason', 'language'); end if;
  if offensive_text(p->>'other_specialties') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'other_specialties', 'reason', 'language'); end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p->'insurance', '[]')) lang_x where offensive_text(lang_x->>'carrier') or offensive_text(lang_x->>'cover_note')) then
    return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance', 'reason', 'language'); end if;

  -- coverage: the business's choice, or nothing. Never inferred.
  v_scope := nullif(p->>'coverage_scope', '');
  v_state := nullif(p->>'coverage_state', '');
  -- the editor deployed before this change sends counties and no scope: that is a 'counties' choice
  if not (p ? 'coverage_scope') and jsonb_array_length(coalesce(p->'counties_worked', '[]')) > 0 then v_scope := 'counties'; end if;
  if v_scope is not null and v_scope not in ('nationwide', 'statewide', 'counties') then
    return jsonb_build_object('allowed', true, 'saved', false, 'field', 'coverage'); end if;
  if v_scope = 'statewide' and not exists (select 1 from geo_reference where geo_id = v_state and admin_level = 1 and country_iso = 'US') then
    return jsonb_build_object('allowed', true, 'saved', false, 'field', 'coverage'); end if;
  if v_scope = 'counties' and jsonb_array_length(coalesce(p->'counties_worked', '[]')) = 0 then
    return jsonb_build_object('allowed', true, 'saved', false, 'field', 'counties_worked'); end if;

  insert into business_profile as bp (business_id, public_phone, public_email, website, description, specialties, other_specialties,
      counties_worked, coverage_scope, coverage_state_geo_id, years_in_business,
      publish_phone, publish_email, publish_website, publish_description, publish_specialties,
      publish_counties, publish_coverage, publish_years, publish_logo, updated_by, updated_at)
  values (bid, nullif(btrim(p->>'public_phone'), ''), nullif(lower(btrim(p->>'public_email')), ''), nullif(btrim(p->>'website'), ''),
      nullif(btrim(p->>'description'), ''),
      nullif(array(select jsonb_array_elements_text(coalesce(p->'specialties', '[]'))), '{}'),
      nullif(btrim(p->>'other_specialties'), ''),
      case when v_scope = 'counties' then nullif(array(select jsonb_array_elements_text(coalesce(p->'counties_worked', '[]'))), '{}') end,
      v_scope, case when v_scope = 'statewide' then v_state end,
      nullif(p->>'years_in_business', '')::int,
      coalesce((p->>'publish_phone')::boolean, false), coalesce((p->>'publish_email')::boolean, false),
      coalesce((p->>'publish_website')::boolean, false), coalesce((p->>'publish_description')::boolean, false),
      coalesce((p->>'publish_specialties')::boolean, false),
      coalesce((p->>'publish_coverage')::boolean, (p->>'publish_counties')::boolean, false),
      coalesce((p->>'publish_coverage')::boolean, (p->>'publish_counties')::boolean, false),
      coalesce((p->>'publish_years')::boolean, false), coalesce((p->>'publish_logo')::boolean, false),
      lower(p_email), now())
  on conflict (business_id) do update set
      public_phone = excluded.public_phone, public_email = excluded.public_email, website = excluded.website,
      description = excluded.description, specialties = excluded.specialties, other_specialties = excluded.other_specialties,
      counties_worked = excluded.counties_worked, coverage_scope = excluded.coverage_scope,
      coverage_state_geo_id = excluded.coverage_state_geo_id, years_in_business = excluded.years_in_business,
      publish_phone = excluded.publish_phone, publish_email = excluded.publish_email, publish_website = excluded.publish_website,
      publish_description = excluded.publish_description, publish_specialties = excluded.publish_specialties,
      publish_counties = excluded.publish_counties, publish_coverage = excluded.publish_coverage,
      publish_years = excluded.publish_years, publish_logo = excluded.publish_logo,
      updated_by = excluded.updated_by, updated_at = now();

  delete from business_declared_insurance where business_id = bid;
  for ins in select * from jsonb_array_elements(coalesce(p->'insurance', '[]')) loop
    if nullif(btrim(ins->>'carrier'), '') is null then continue; end if;
    insert into business_declared_insurance (business_id, kind, carrier, cover_note, expires_on, publish)
    values (bid, coalesce(nullif(ins->>'kind', ''), 'other'), btrim(ins->>'carrier'), nullif(btrim(ins->>'cover_note'), ''),
            nullif(ins->>'expires_on', '')::date, coalesce((ins->>'publish')::boolean, false));
  end loop;
  return jsonb_build_object('allowed', true, 'saved', true, 'business_id', bid);
end $$;

-- the logo is set only by the upload route (never by the form): record or clear its private path
create or replace function public.business_logo_set(p_slug text, p_email text, p_logo_path text)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare g jsonb; bid uuid;
begin
  g := work_upload_gate(p_slug, p_email);
  if not (g->>'allowed')::boolean then return g; end if;
  bid := (g->>'business_id')::uuid;
  insert into business_profile (business_id, logo_path, logo_updated_at, updated_by, updated_at)
  values (bid, p_logo_path, now(), lower(p_email), now())
  on conflict (business_id) do update set logo_path = excluded.logo_path, logo_updated_at = now(),
     publish_logo = case when excluded.logo_path is null then false else business_profile.publish_logo end;
  return jsonb_build_object('allowed', true, 'saved', true, 'business_id', bid,
    'publish_logo', (select publish_logo from business_profile where business_id = bid));
end $$;

create or replace function public.business_profile_public(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when p.business_id is null then null else jsonb_strip_nulls(jsonb_build_object(
      'phone',       case when p.publish_phone then p.public_phone end,
      'email',       case when p.publish_email then p.public_email end,
      'website',     case when p.publish_website then p.website end,
      'description', case when p.publish_description then p.description end,
      'specialties', case when p.publish_specialties then p.specialties end,
      'other_specialties', case when p.publish_specialties then p.other_specialties end,
      -- kept for the page already deployed; 'coverage' supersedes it
      'counties',    case when p.publish_coverage and p.coverage_scope = 'counties' then (select jsonb_agg(case when g.level_type = 'county' then g.name || ' County' else g.name end || ', ' || s.admin1_abbr order by s.admin1_abbr, g.name)
                                                          from geo_reference g join geo_reference s on s.geo_id = g.parent_geo_id
                                                         where g.geo_id = any(p.counties_worked)) end,
      'coverage',    case when p.publish_coverage and p.coverage_scope is not null then jsonb_build_object(
                        'scope', p.coverage_scope,
                        'state', (select name from geo_reference where geo_id = p.coverage_state_geo_id),
                        'counties', case when p.coverage_scope = 'counties' then (select jsonb_agg(case when g.level_type = 'county' then g.name || ' County' else g.name end || ', ' || s.admin1_abbr order by s.admin1_abbr, g.name)
                                                          from geo_reference g join geo_reference s on s.geo_id = g.parent_geo_id
                                                         where g.geo_id = any(p.counties_worked)) end) end,
      'logo',        case when p.publish_logo and p.logo_path is not null then
                        'https://eaifqorwmgayiqmbtzcg.supabase.co/storage/v1/object/public/logo-public/' || p.business_id || '.png?v=' || extract(epoch from p.logo_updated_at)::bigint end,
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

revoke all on function public.business_profile_save(text, text, jsonb), public.business_logo_set(text, text, text), public.business_profile_public(text)
  from public, anon, authenticated;
grant execute on function public.business_profile_save(text, text, jsonb), public.business_logo_set(text, text, text), public.business_profile_public(text)
  to service_role;

-- 733 item 3: a standing sweep, not a one-off. Every PUBLISHED free-text field must pass offensive_text.
insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
    false_positive_notes, status, remediation, attribution, expected_state, magnitude_semantics)
values ('published-free-text-fails-language-check',
  'A published free-text field on a claimed or self-registered page fails offensive_text()',
  date '2026-09-28', 'work order 733 / migration 153a', 'access_control', 'material',
  $d$select not exists (
     select 1 from business_profile p where (p.publish_description and offensive_text(p.description)) or (p.publish_specialties and offensive_text(p.other_specialties))
     union all select 1 from business_declared_insurance i where i.publish and (offensive_text(i.carrier) or offensive_text(i.cover_note))
     union all select 1 from agent_public_profile a where (a.publish_bio and offensive_text(a.bio)) or (a.publish_declared_brokerage and offensive_text(a.declared_brokerage))
     union all select 1 from registered_business r where r.review_state = 'approved' and r.publish_listing and (offensive_text(r.business_name) or offensive_text(r.other_services))
   ) as ok$d$,
  'The save path refuses new offensive text (152a); this catches anything saved before it, or published by a route that bypasses it. RED AT CREATION on one known row: the ZZ test fixture description Murphy typed before the check existed (business e8eae372...). It is his data and is left for him.',
  'active', 'Ask the owner to change it, or switch the field off (publish_* = false) pending review. Never edit their words.', 'ours', 'clean', 'binary')
on conflict (defect_id) do nothing;
