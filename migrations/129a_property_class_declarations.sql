-- 129a — Property class: residential / commercial / industrial / agricultural (work order 621 item 2).
-- DATABASE SIDE ONLY. The claim form, /agent multi-select and the search filter UI are held
-- (ruling 2026-09-24: a filter returning nothing teaches people the site is broken).
--
-- Rulings 2026-09-24:
--   * SELF-DECLARED, never derived. A roofing licence does not say they do commercial work.
--   * PUBLIC ON APPROVAL ONLY. An unapproved claimant stating what a named business does is a
--     false statement about a third party. A declaration lives on the claim that carried it and
--     is served only once that claim is 'approved'. Agents: only once the licence is verified.
--   * UNDECLARED = "Not stated by the business". Never a default.
--   * Four classes. Agricultural is real in Florida in a way it would not be in most states.
--
-- Why declarations hang off the CLAIM, not a copied business row: no copy step to drift, and the
-- claim targets a licence record (contractor_id), which is stable across register rebuilds —
-- a business id can be retired by a merge (128d), a licence record cannot. The served function
-- resolves licence -> business at read time.
--
-- Three coverage states in the served payload: present / none_recorded / not_available (null =
-- the slug is not in the register).

create table if not exists public.property_class_vocab (
  code   text primary key check (code ~ '^[a-z_]+$'),
  label  text not null,
  sort   int  not null
);
insert into public.property_class_vocab (code, label, sort) values
  ('residential',  'Residential',  1),
  ('commercial',   'Commercial',   2),
  ('industrial',   'Industrial',   3),
  ('agricultural', 'Agricultural', 4)
on conflict (code) do nothing;

-- claim_requests.status was free text with no approval path at all. 'approved' now means
-- something — it is the event that publishes a declaration — so the vocabulary is fixed.
-- 0 rows today, so nothing is reinterpreted.
alter table public.claim_requests drop constraint if exists claim_requests_status_chk;
alter table public.claim_requests add constraint claim_requests_status_chk
  check (status in ('pending', 'approved', 'rejected'));

create table if not exists public.claim_request_property_class (
  claim_request_id uuid not null references public.claim_requests(id) on delete cascade,
  property_class   text not null references public.property_class_vocab(code),
  primary key (claim_request_id, property_class)
);

create table if not exists public.agent_property_class (
  license_number   text not null,
  property_class   text not null references public.property_class_vocab(code),
  declared_by_user uuid,
  declared_at      timestamptz not null default now(),
  primary key (license_number, property_class)
);

alter table public.property_class_vocab          enable row level security;
alter table public.claim_request_property_class  enable row level security;
alter table public.agent_property_class          enable row level security;

create or replace function public.get_business_property_classes(p_slug text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as
$$
  with biz as (select id from businesses where slug = p_slug),
  latest as (
    -- the most recent APPROVED claim on any licence record of this business
    select cr.id, cr.reviewed_at
      from biz
      join business_licences bl on bl.business_id = biz.id and bl.link_basis = 'member'
      join claim_requests cr on cr.contractor_id = bl.contractor_id and cr.status = 'approved'
     order by cr.reviewed_at desc nulls last, cr.created_at desc
     limit 1),
  classes as (
    select v.code, v.label, v.sort
      from latest l
      join claim_request_property_class p on p.claim_request_id = l.id
      join property_class_vocab v on v.code = p.property_class)
  select case
    when not exists (select 1 from biz) then null
    when exists (select 1 from classes) then jsonb_build_object(
      'field_status', 'present',
      'classes', (select jsonb_agg(jsonb_build_object('code', code, 'label', label) order by sort) from classes),
      'basis', 'self_declared',
      'declared_at', (select reviewed_at from latest),
      'note', 'As stated by the business. Not verified.')
    else jsonb_build_object(
      'field_status', 'none_recorded',
      'classes', '[]'::jsonb,
      'note', 'Not stated by the business.')
  end
$$;

create or replace function public.get_agent_property_classes(p_license_number text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as
$$
  with verified as (
    select 1 from agent_profile
     where license_number = p_license_number and license_verified_at is not null limit 1),
  classes as (
    select v.code, v.label, v.sort, a.declared_at
      from agent_property_class a join property_class_vocab v on v.code = a.property_class
     where a.license_number = p_license_number and exists (select 1 from verified))
  select case
    when not exists (select 1 from agent_license_roster where license_number = p_license_number) then null
    when exists (select 1 from classes) then jsonb_build_object(
      'field_status', 'present',
      'classes', (select jsonb_agg(jsonb_build_object('code', code, 'label', label) order by sort) from classes),
      'basis', 'self_declared',
      'declared_at', (select max(declared_at) from classes),
      'note', 'As stated by the agent. Not verified.')
    else jsonb_build_object(
      'field_status', 'none_recorded',
      'classes', '[]'::jsonb,
      'note', 'Not stated by the agent.')
  end
$$;

revoke all on function public.get_business_property_classes(text) from public, anon, authenticated;
revoke all on function public.get_agent_property_classes(text)    from public, anon, authenticated;
grant execute on function public.get_business_property_classes(text) to service_role;
grant execute on function public.get_agent_property_classes(text)    to service_role;

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('property-class-served-before-approval',
 'A property-class declaration must never be served for a business whose only declaring claim is not approved',
 date '2026-09-24', 'work order 621 item 2', 'entity_confusion', 'blocking',
 $d$select (
    not exists (
      select 1
        from claim_request_property_class p
        join claim_requests cr on cr.id = p.claim_request_id and cr.status <> 'approved'
        join business_licences bl on bl.contractor_id = cr.contractor_id and bl.link_basis = 'member'
        join businesses b on b.id = bl.business_id
       where not exists (select 1 from claim_requests a
                          join business_licences bl2 on bl2.contractor_id = a.contractor_id and bl2.link_basis = 'member'
                         where bl2.business_id = b.id and a.status = 'approved')
         and public.get_business_property_classes(b.slug)->>'field_status' = 'present')
    and public.get_business_property_classes('red-stag-contracting-inc-jacksonville-fl')->>'field_status' in ('present', 'none_recorded')
    and public.get_business_property_classes('no-such-business-slug') is null
  ) as ok$d$,
 'every business with a declaration on a non-approved claim; plus the founding case and a missing slug',
 'SERVED PATH: calls get_business_property_classes. Vacuous while there are no declarations (0 today) — the last two terms keep it from being a check that cannot fail: they assert the three coverage states still come back. Negative control 2026-09-24, rolled back: a PENDING claim with a class served none_recorded; the same claim APPROVED served present.',
 'active', 'ours', 'clean',
 'Find the claim; the served function must filter on status = approved.')
on conflict (defect_id) do nothing;
