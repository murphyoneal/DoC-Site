-- 160a: ruling 762 part 4 - cap, withdraw, suspend, appeal - carrying 765's evidence rules.
--
-- SUSPENSION is not a column anyone can flip. It is derived from moderation_action (append-only, basis
-- required, actor recorded): the latest of business_suspended / business_reinstated for that business.
-- suspend_business() and reinstate_business() are the only writers, and both refuse an actor who is not
-- an operator_account email - the operator is inside the trail, and nobody else is the operator.
-- REINSTATEMENT IS LOGGED EXACTLY AS HEAVILY AS SUSPENSION (765.5): same function shape, same required
-- basis, same row.
--
-- While suspended (Murphy's ruling): every business-supplied item stops being served
-- (business_profile_public returns nothing; the gallery view excludes it; the logo's public copy is removed
-- by the route that calls suspend), the claim stops working (work_upload_gate refuses with 'suspended',
-- which closes the editor, uploads and the logo), THE PROFILE PAGE GOES, THE SEARCH ROW STAYS
-- (contractors_public is untouched). Suspension is ours: it never renders as a reason anywhere public.
--
-- APPEAL (765.4): the business's explanation is stored VERBATIM as theirs, append-only. Only the approved
-- claimant of a suspended business can file one.
--
-- CAP: 10 photos per business on the free tier, recorded in operating_threshold, counted over live
-- (non-withdrawn) contributions. WITHDRAW keeps the row and the private file (765.3) and drops it from
-- every public read and from the count.

-- ---------- suspension state, derived ----------
create or replace function public.business_is_suspended(p_business_id uuid) returns boolean
language sql stable security definer set search_path = public as $f$
  select coalesce((
    select a.action = 'business_suspended' from moderation_action a
     where a.target_table = 'businesses' and p_business_id::text = any(a.target_ids)
       and a.action in ('business_suspended', 'business_reinstated')
     order by coalesce(a.occurred_at, a.recorded_at) desc, a.id desc limit 1), false)
$f$;
revoke all on function public.business_is_suspended(uuid) from public, anon, authenticated;
grant execute on function public.business_is_suspended(uuid) to service_role;

create or replace function public.set_business_suspension(p_business_id uuid, p_suspend boolean, p_actor text, p_basis text, p_ip inet, p_via text)
returns jsonb language plpgsql security definer set search_path = public as $f$
declare was boolean;
begin
  if not exists (select 1 from businesses where id = p_business_id) then raise exception 'no such business'; end if;
  if not exists (select 1 from operator_account where email = lower(btrim(coalesce(p_actor, '')))) then
    raise exception 'only an operator can % a business', case when p_suspend then 'suspend' else 'reinstate' end; end if;
  if length(btrim(coalesce(p_basis, ''))) < 10 then raise exception 'a basis is required (why we are entitled to act)'; end if;
  was := business_is_suspended(p_business_id);
  if was = p_suspend then return jsonb_build_object('changed', false, 'suspended', was); end if;
  insert into moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via, ip)
  values (now(), lower(btrim(p_actor)), 'operator', case when p_suspend then 'business_suspended' else 'business_reinstated' end,
          'businesses', array[p_business_id::text], jsonb_build_object('suspended', was), jsonb_build_object('suspended', p_suspend),
          btrim(p_basis), coalesce(p_via, 'unspecified'), p_ip);
  return jsonb_build_object('changed', true, 'suspended', p_suspend);
end $f$;
revoke all on function public.set_business_suspension(uuid, boolean, text, text, inet, text) from public, anon, authenticated;
grant execute on function public.set_business_suspension(uuid, boolean, text, text, inet, text) to service_role;

-- what a public page may know: only whether to show the profile. Never a reason.
create or replace function public.business_public_state(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $f$
  select jsonb_build_object('suspended', coalesce(business_is_suspended((select id from businesses where slug = p_slug)), false))
$f$;
revoke all on function public.business_public_state(text) from public, anon, authenticated;
grant execute on function public.business_public_state(text) to service_role;

-- ---------- appeals: verbatim, theirs, append-only ----------
create table public.business_appeal (
  id            bigserial primary key,
  business_id   uuid not null references public.businesses(id),
  submitted_by  text not null,
  explanation   text not null check (length(btrim(explanation)) between 1 and 5000),
  submitted_at  timestamptz not null default now()
);
alter table public.business_appeal enable row level security;
revoke all on public.business_appeal from anon, authenticated;
create trigger append_only_business_appeal before update or delete on public.business_appeal
  for each row execute function public.append_only_strict();

create or replace function public.file_business_appeal(p_slug text, p_email text, p_explanation text) returns jsonb
language plpgsql security definer set search_path = public as $f$
declare bid uuid; ok boolean;
begin
  select id into bid from businesses where slug = p_slug;
  if bid is null then return jsonb_build_object('filed', false, 'reason', 'not_in_register'); end if;
  select exists (select 1 from business_licences bl join claim_requests cr on cr.contractor_id = bl.contractor_id and cr.status = 'approved'
                  where bl.business_id = bid and bl.link_basis = 'member' and lower(cr.requester_email) = lower(coalesce(p_email, ''))) into ok;
  if not ok then return jsonb_build_object('filed', false, 'reason', 'not_the_claimant'); end if;
  if not business_is_suspended(bid) then return jsonb_build_object('filed', false, 'reason', 'not_suspended'); end if;
  if length(btrim(coalesce(p_explanation, ''))) = 0 then return jsonb_build_object('filed', false, 'reason', 'empty'); end if;
  insert into business_appeal (business_id, submitted_by, explanation) values (bid, lower(btrim(p_email)), p_explanation);
  return jsonb_build_object('filed', true, 'business_id', bid);
end $f$;
revoke all on function public.file_business_appeal(text, text, text) from public, anon, authenticated;
grant execute on function public.file_business_appeal(text, text, text) to service_role;

-- ---------- the gate: suspended closes the editor, uploads and the logo ----------
create or replace function public.work_upload_gate(p_slug text, p_email text) returns jsonb
language sql stable security definer set search_path = public as $f$
  with biz as (select id, canonical_contractor_id from businesses where slug = p_slug),
  approved as (
    select cr.requester_email
      from biz
      join business_licences bl on bl.business_id = biz.id and bl.link_basis = 'member'
      join claim_requests cr on cr.contractor_id = bl.contractor_id and cr.status = 'approved')
  select case
    when not exists (select 1 from biz) then jsonb_build_object('allowed', false, 'reason', 'not_in_register')
    when not exists (select 1 from approved) then jsonb_build_object('allowed', false, 'reason', 'no_approved_claim')
    when p_email is null or not exists (select 1 from approved where lower(requester_email) = lower(p_email))
      then jsonb_build_object('allowed', false, 'reason', 'not_the_claimant')
    when business_is_suspended((select id from biz))
      then jsonb_build_object('allowed', false, 'reason', 'suspended', 'claimant', true)
    else jsonb_build_object('allowed', true, 'reason', 'allowed',
      'business_id', (select id from biz), 'contractor_id', (select canonical_contractor_id from biz))
  end
$f$;
revoke all on function public.work_upload_gate(text, text) from public, anon, authenticated;
grant execute on function public.work_upload_gate(text, text) to service_role;

-- ---------- nothing the business supplied is served while suspended ----------
do $m$ declare d text; n text; begin
  d := pg_get_functiondef('public.business_profile_public(text)'::regprocedure);
  n := replace(d, $a$select case when p.business_id is null then null else$a$,
                  $a$select case when p.business_id is null or business_is_suspended(p.business_id) then null else$a$);
  if n = d then raise exception '160a: business_profile_public anchor'; end if;
  execute n;
end $m$;

create or replace view public.work_gallery_public as
 SELECT c.id, c.contractor_id, ct.slug AS contractor_slug, ct.display_name AS contractor_name, r.department, r.display_category,
    c.description, c.work_date, c.assertion_state, c.location_state, i.public_path, i.width, i.height, c.created_at
   FROM work_contribution c
     JOIN contractors_public ct ON ct.id = c.contractor_id
     LEFT JOIN trade_code_registry r ON r.trade_code = ct.trade_code
     JOIN work_contribution_image i ON i.contribution_id = c.id
  WHERE c.visibility = 'public'::text AND i.exif_stripped_at IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM business_licences bl WHERE bl.contractor_id = c.contractor_id AND business_is_suspended(bl.business_id));

-- ---------- cap and withdraw ----------
insert into public.operating_threshold (name, limit_value, warn_at, unit, reason, set_by) values
('free_photos_per_business', 10, 10, 'live (non-withdrawn) photos per business',
 'Murphy''s ruling 762: free accounts get 10 images. Withdrawing a photo frees its slot. More comes with a paid tier later.',
 'murphy ruling 762, recorded by cc');

create or replace function public.work_photo_count(p_contractor_id uuid) returns int
language sql stable security definer set search_path = public as $f$
  select count(*)::int from work_contribution
   where contractor_id = p_contractor_id and visibility not in ('withdrawn_by_contractor', 'withdrawn_by_owner')
$f$;
revoke all on function public.work_photo_count(uuid) from public, anon, authenticated;
grant execute on function public.work_photo_count(uuid) to service_role;

alter table public.submission_event drop constraint submission_event_kind_check;
alter table public.submission_event add constraint submission_event_kind_check
  check (kind in ('work_upload', 'work_withdraw', 'logo_upload', 'logo_remove', 'contractor_claim', 'agent_claim',
                  'profile_save', 'agent_profile_save', 'self_registration', 'appeal'));

insert into public.column_writer (table_name, column_name, writer_class, sanctioned_writers, reason, classified_by)
select 'business_appeal', a.attname,
       case when a.attname = 'explanation' then 'subject' else 'ours' end,
       case when a.attname = 'explanation' then '{file_business_appeal}'::text[] end,
       case when a.attname = 'explanation' then 'the business''s own explanation, stored VERBATIM - never rewritten or summarised (765.4)'
            else 'appeal record (160a)' end, 'cc'
  from pg_attribute a where a.attrelid = 'public.business_appeal'::regclass and a.attnum > 0 and not a.attisdropped;

-- ---------- checks ----------
do $m$ declare bid uuid := 'e8eae372-c292-41f4-9e80-bb79e2b414e2'; r jsonb; begin
  if business_is_suspended(bid) then raise exception '160a: fixture unexpectedly suspended'; end if;
  if (work_upload_gate('zz-test-contracting-dop-system-check', 'murphy.oneal@gmail.com')->>'allowed')::boolean is not true then
    raise exception '160a: gate closed for the approved claimant'; end if;
  -- negative controls, rolled back: a non-operator cannot suspend; an operator can; suspension closes the gate
  -- and the profile; reinstatement reopens both.
  begin
    begin
      perform set_business_suspension(bid, true, 'someone@example.com', 'a basis of enough length', null, 'control');
      raise exception 'CONTROL_FAILED:non-operator';
    exception when others then
      if sqlerrm like 'CONTROL_FAILED%' then raise; end if;
    end;
    r := set_business_suspension(bid, true, 'murphy.oneal@gmail.com', 'control: rolled back inside 160a', null, 'control');
    if not business_is_suspended(bid) then raise exception 'CONTROL_FAILED:not suspended'; end if;
    if (work_upload_gate('zz-test-contracting-dop-system-check', 'murphy.oneal@gmail.com')->>'reason') <> 'suspended' then raise exception 'CONTROL_FAILED:gate'; end if;
    if business_profile_public('zz-test-contracting-dop-system-check') is not null then raise exception 'CONTROL_FAILED:profile served'; end if;
    if not (file_business_appeal('zz-test-contracting-dop-system-check', 'murphy.oneal@gmail.com', 'control')->>'filed')::boolean then raise exception 'CONTROL_FAILED:appeal'; end if;
    r := set_business_suspension(bid, false, 'murphy.oneal@gmail.com', 'control: rolled back inside 160a', null, 'control');
    if business_is_suspended(bid) then raise exception 'CONTROL_FAILED:not reinstated'; end if;
    if (select count(*) from moderation_action where via = 'control') <> 2 then raise exception 'CONTROL_FAILED:trail'; end if;
    raise exception 'CONTROL_OK';
  exception when others then
    if sqlerrm <> 'CONTROL_OK' then raise exception '160a: %', sqlerrm; end if;
  end;
  if (select count(*) from moderation_action where via = 'control') <> 0 then raise exception '160a: control leaked'; end if;
  if (select count(*) from business_appeal) <> 0 then raise exception '160a: control appeal leaked'; end if;
end $m$;
