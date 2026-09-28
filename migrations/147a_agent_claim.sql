-- 147a — the agent claim (work order 712 item 2; rulings R3, R4, R5).
--
-- AN AGENT CLAIMS A PERSON: their licence. agent_license_roster and agent_license_status are the DBPR
-- copy and nobody writes to them. agent_profile is left as the Roz ACCOUNT record (it self-verifies on a
-- name match with no person reviewing - the auto-approval refused everywhere else) and is untouched.
--
--   agent_claim_request   - the claim, the twin of claim_requests. Our licence/name check is RECORDED
--                           (match_agent verdict + whether the licence is Current/Active), never
--                           enforced: a person reviews every claim.
--   agent_public_profile  - written only by the approved claimant, keyed on the licence. Every publish
--                           switch defaults off in the schema. Created by review_agent_claim() on
--                           approval, with the slug the public page lives at: /a/{slug} on DoP (R4).
--
-- BROKERAGE: always shown from agent_license_status.employing_broker, with that file's date. If the
-- agent says they have moved, declared_brokerage is shown BESIDE the register value, never over it.
-- PROPERTY CLASSES live on the public profile (validated against property_class_vocab), NOT in
-- agent_property_class: that table feeds get_agent_property_classes, which trusts the Roz
-- self-verified path, and a reviewed public claim must not be coupled to it.
-- LISTINGS: phase 2 (R5) - we hold no listing data and public records never name the agent.

create table if not exists public.agent_claim_request (
  id              uuid primary key default gen_random_uuid(),
  license_number  text not null,
  requester_name  text not null check (length(btrim(requester_name)) between 2 and 200),
  requester_email text not null check (requester_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(requester_email) <= 254),
  requester_phone text check (requester_phone is null or length(requester_phone) <= 40),
  message         text check (message is null or length(message) <= 2000),
  match_verdict   text,
  licence_active  boolean,
  check_note      text,
  status          text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_at     timestamptz,
  review_note     text,
  created_at      timestamptz not null default now()
);
create index if not exists agent_claim_request_licence_idx on public.agent_claim_request(license_number);

create table if not exists public.agent_public_profile (
  license_number     text primary key,
  slug               text not null unique,
  public_phone       text check (public_phone is null or length(public_phone) <= 40),
  public_email       text check (public_email is null or (public_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' and length(public_email) <= 254)),
  website            text check (website is null or (website ~* '^https?://' and length(website) <= 300)),
  bio                text check (bio is null or length(bio) <= 800),
  counties_served    text[],
  property_classes   text[],
  declared_brokerage text check (declared_brokerage is null or length(declared_brokerage) <= 200),
  publish_phone      boolean not null default false,
  publish_email      boolean not null default false,
  publish_website    boolean not null default false,
  publish_bio        boolean not null default false,
  publish_counties   boolean not null default false,
  publish_classes    boolean not null default false,
  publish_declared_brokerage boolean not null default false,
  updated_by         text,
  updated_at         timestamptz not null default now()
);

alter table public.agent_claim_request enable row level security;
alter table public.agent_public_profile enable row level security;
revoke all on public.agent_claim_request, public.agent_public_profile from anon, authenticated;
grant select, insert, update, delete on public.agent_claim_request, public.agent_public_profile to service_role;

insert into public.column_default_authorship (table_name, column_name, authorship, reason, classified_by, classified_on)
select 'agent_public_profile', c, 'ours', 'false = the agent has not switched this field on; nothing is published by default (712, R3)', 'cc', date '2026-09-28'
  from unnest(array['publish_phone','publish_email','publish_website','publish_bio','publish_counties','publish_classes','publish_declared_brokerage']) c
union all
select 'agent_claim_request', 'status', 'ours', 'pending = our review has not happened; says nothing about the agent', 'cc', date '2026-09-28'
on conflict do nothing;

-- submit: the licence must be in the register we hold; our check is recorded, not enforced
create or replace function public.agent_claim_submit(p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_lic text := upper(regexp_replace(coalesce(p->>'license_number', ''), '[^A-Za-z0-9]', '', 'g'));
        m jsonb; act boolean; v_id uuid; ro record;
begin
  select license_number, name, rank into ro from agent_license_roster where license_number = v_lic;
  if not found then return jsonb_build_object('outcome', 'invalid', 'field', 'license_number',
    'note', 'That licence number is not in the Florida real estate licence file we hold.'); end if;
  if length(btrim(coalesce(p->>'requester_name', ''))) < 2 then return jsonb_build_object('outcome', 'invalid', 'field', 'requester_name'); end if;
  if coalesce(p->>'requester_email', '') !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return jsonb_build_object('outcome', 'invalid', 'field', 'requester_email'); end if;
  if exists (select 1 from agent_claim_request where license_number = v_lic and status = 'approved') then
    return jsonb_build_object('outcome', 'already_claimed'); end if;
  m := match_agent(v_lic, p->>'requester_name');
  act := agent_license_is_eligible(v_lic);
  insert into agent_claim_request (license_number, requester_name, requester_email, requester_phone, message, match_verdict, licence_active, check_note)
  values (v_lic, btrim(p->>'requester_name'), lower(btrim(p->>'requester_email')), nullif(btrim(p->>'requester_phone'), ''),
          nullif(btrim(p->>'message'), ''), m->>'verdict', act,
          'Name given vs the licence file: ' || coalesce(m->>'verdict', 'not compared') || '. Licence ' ||
          case when act then 'Current/Active' else 'not Current/Active' end || ' in the status file dated 23 Jul 2026.')
  returning id into v_id;
  return jsonb_build_object('outcome', 'received', 'id', v_id, 'licence_name', ro.name, 'rank', ro.rank,
                            'match_verdict', m->>'verdict', 'licence_active', act);
end $$;

-- Murphy's review. Approval creates the public profile row (and so the page) with its slug.
create or replace function public.review_agent_claim(p_id uuid, p_decision text, p_note text default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v agent_claim_request%rowtype; v_slug text; ro record;
begin
  if p_decision not in ('approved', 'rejected') then raise exception 'decision must be approved or rejected'; end if;
  update agent_claim_request set status = p_decision, reviewed_at = now(), review_note = p_note where id = p_id returning * into v;
  if not found then raise exception 'no agent claim %', p_id; end if;
  if p_decision = 'approved' then
    select name into ro from agent_license_roster where license_number = v.license_number;
    -- "LETIZIA, ALEXIS B" -> alexis-b-letizia-3578412
    v_slug := trim(both '-' from regexp_replace(lower(
                coalesce(nullif(btrim(split_part(ro.name, ',', 2)), '') || ' ' || split_part(ro.name, ',', 1), ro.name)), '[^a-z0-9]+', '-', 'g'))
              || '-' || lower(v.license_number);
    insert into agent_public_profile (license_number, slug, updated_by) values (v.license_number, v_slug, 'review_agent_claim')
    on conflict (license_number) do nothing;
  end if;
  return jsonb_build_object('id', v.id, 'status', v.status, 'license_number', v.license_number,
    'slug', (select slug from agent_public_profile where license_number = v.license_number), 'claimant_email', v.requester_email);
end $$;

-- the claimant's gate: an APPROVED claim on this licence, and the signed-in email is that claim's
create or replace function public.agent_claim_gate(p_slug text, p_email text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case
    when ap.license_number is null then jsonb_build_object('allowed', false, 'reason', 'no_approved_claim')
    when p_email is null or not exists (select 1 from agent_claim_request c where c.license_number = ap.license_number
                                         and c.status = 'approved' and lower(c.requester_email) = lower(p_email))
      then jsonb_build_object('allowed', false, 'reason', 'not_the_claimant')
    else jsonb_build_object('allowed', true, 'reason', 'allowed', 'license_number', ap.license_number)
  end
  from (select 1) one left join agent_public_profile ap on ap.slug = p_slug
$$;

create or replace function public.agent_profile_get(p_slug text, p_email text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare g jsonb;
begin
  g := agent_claim_gate(p_slug, p_email);
  if not (g->>'allowed')::boolean then return g; end if;
  return g || jsonb_build_object('profile', (select to_jsonb(ap) - 'license_number' from agent_public_profile ap where ap.slug = p_slug),
    'register_brokerage', (select employing_broker from agent_license_status where license_number = g->>'license_number'),
    'classes_vocab', (select jsonb_agg(jsonb_build_object('code', code, 'label', label) order by sort) from property_class_vocab));
end $$;

create or replace function public.agent_profile_save(p_slug text, p_email text, p jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare g jsonb; bad text;
begin
  g := agent_claim_gate(p_slug, p_email);
  if not (g->>'allowed')::boolean then return g; end if;
  select string_agg(c, ',') into bad from jsonb_array_elements_text(coalesce(p->'counties_served', '[]')) c
   where not exists (select 1 from geo_reference where geo_id = c and admin_level = 2);
  if bad is not null then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'counties_served'); end if;
  select string_agg(c, ',') into bad from jsonb_array_elements_text(coalesce(p->'property_classes', '[]')) c
   where not exists (select 1 from property_class_vocab where code = c);
  if bad is not null then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'property_classes'); end if;
  update agent_public_profile set
    public_phone = nullif(btrim(p->>'public_phone'), ''), public_email = nullif(lower(btrim(p->>'public_email')), ''),
    website = nullif(btrim(p->>'website'), ''), bio = nullif(btrim(p->>'bio'), ''),
    counties_served = nullif(array(select jsonb_array_elements_text(coalesce(p->'counties_served', '[]'))), '{}'),
    property_classes = nullif(array(select jsonb_array_elements_text(coalesce(p->'property_classes', '[]'))), '{}'),
    declared_brokerage = nullif(btrim(p->>'declared_brokerage'), ''),
    publish_phone = coalesce((p->>'publish_phone')::boolean, false), publish_email = coalesce((p->>'publish_email')::boolean, false),
    publish_website = coalesce((p->>'publish_website')::boolean, false), publish_bio = coalesce((p->>'publish_bio')::boolean, false),
    publish_counties = coalesce((p->>'publish_counties')::boolean, false), publish_classes = coalesce((p->>'publish_classes')::boolean, false),
    publish_declared_brokerage = coalesce((p->>'publish_declared_brokerage')::boolean, false),
    updated_by = lower(p_email), updated_at = now()
  where slug = p_slug;
  return jsonb_build_object('allowed', true, 'saved', true);
end $$;

-- /a/{slug}: exists only for an APPROVED claim. The register block always, from the files we hold,
-- each with its date; then "from the agent", switch by switch.
create or replace function public.agent_public_page(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'slug', ap.slug,
    'register', jsonb_build_object('name', ro.name, 'license_number', ro.license_number, 'rank', ro.rank, 'county', ro.county,
        'first_issued', ro.original_issue_date,
        'status', case when st.license_number is null then null else st.primary_status || coalesce(' · ' || st.secondary_status, '') end,
        'expiry', st.expiration_date, 'brokerage', st.employing_broker, 'status_as_of', st.snapshot_date,
        'source', 'Florida DBPR real estate licence file'),
    'own', jsonb_strip_nulls(jsonb_build_object(
        'phone', case when ap.publish_phone then ap.public_phone end,
        'email', case when ap.publish_email then ap.public_email end,
        'website', case when ap.publish_website then ap.website end,
        'bio', case when ap.publish_bio then ap.bio end,
        'counties', case when ap.publish_counties then (select jsonb_agg(case when g.level_type = 'county' then g.name || ' County' else g.name end || ', ' || s.admin1_abbr order by s.admin1_abbr, g.name)
                                                         from geo_reference g join geo_reference s on s.geo_id = g.parent_geo_id where g.geo_id = any(ap.counties_served)) end,
        'property_classes', case when ap.publish_classes then (select jsonb_agg(v.label order by v.sort) from property_class_vocab v where v.code = any(ap.property_classes)) end,
        'declared_brokerage', case when ap.publish_declared_brokerage then ap.declared_brokerage end,
        'updated_on', ap.updated_at::date)))
  from agent_public_profile ap
  join agent_license_roster ro on ro.license_number = ap.license_number
  left join agent_license_status st on st.license_number = ap.license_number
  where ap.slug = p_slug
    and exists (select 1 from agent_claim_request c where c.license_number = ap.license_number and c.status = 'approved')
$$;

create or replace view public.agent_claim_review_queue as
select c.id, c.created_at, c.license_number, ro.name as licence_name, ro.rank, c.requester_name, c.requester_email, c.requester_phone,
       c.message, c.match_verdict, c.licence_active, c.check_note, st.employing_broker as register_brokerage
  from agent_claim_request c
  left join agent_license_roster ro on ro.license_number = c.license_number
  left join agent_license_status st on st.license_number = c.license_number
 where c.status = 'pending'
 order by c.created_at;
revoke all on public.agent_claim_review_queue from anon, authenticated;

revoke all on function public.agent_claim_submit(jsonb), public.review_agent_claim(uuid, text, text), public.agent_claim_gate(text, text),
  public.agent_profile_get(text, text), public.agent_profile_save(text, text, jsonb), public.agent_public_page(text) from public, anon, authenticated;
grant execute on function public.agent_claim_submit(jsonb), public.review_agent_claim(uuid, text, text), public.agent_claim_gate(text, text),
  public.agent_profile_get(text, text), public.agent_profile_save(text, text, jsonb), public.agent_public_page(text) to service_role;

do $a$
begin
  if not has_function_privilege('anon', 'public.agent_register_search(text,integer)', 'EXECUTE') then
    raise exception '147a: agent_register_search lost its anon grant';
  end if;
end $a$;
