-- 151a — the claim page knows, when it LOADS, whether this business or licence is claimed, and by whom
-- relative to the visitor (work order 727). Three states, never two: none / pending / approved. "mine"
-- is true only when the signed-in email is the claim's email; a visitor who is not signed in is never
-- told whose claim it is, and the claimant is never named.
create or replace function public.claim_state_for_business(p_slug text, p_email text)
returns jsonb language sql stable security definer set search_path = public as $$
  with biz as (select id from businesses where slug = p_slug),
  cl as (
    select cr.status, cr.requester_email, cr.created_at, cr.reviewed_at
      from biz join business_licences bl on bl.business_id = biz.id
      join claim_requests cr on cr.contractor_id = bl.contractor_id
     where cr.status in ('approved', 'pending'))
  select jsonb_build_object(
    'state', case when exists (select 1 from cl where status = 'approved') then 'approved'
                  when exists (select 1 from cl where status = 'pending') then 'pending' else 'none' end,
    'mine', p_email is not null and exists (select 1 from cl where lower(requester_email) = lower(p_email)
                  and status = case when exists (select 1 from cl where status = 'approved') then 'approved' else 'pending' end),
    'on', (select coalesce(max(reviewed_at), max(created_at))::date from cl
            where lower(requester_email) = lower(coalesce(p_email, '')) ))
$$;

create or replace function public.claim_state_for_licence(p_licence text, p_email text)
returns jsonb language sql stable security definer set search_path = public as $$
  with cl as (select status, requester_email, created_at, reviewed_at from agent_claim_request
               where license_number = upper(regexp_replace(coalesce(p_licence, ''), '[^A-Za-z0-9]', '', 'g'))
                 and status in ('approved', 'pending'))
  select jsonb_build_object(
    'state', case when exists (select 1 from cl where status = 'approved') then 'approved'
                  when exists (select 1 from cl where status = 'pending') then 'pending' else 'none' end,
    'mine', p_email is not null and exists (select 1 from cl where lower(requester_email) = lower(p_email)
                  and status = case when exists (select 1 from cl where status = 'approved') then 'approved' else 'pending' end),
    'on', (select coalesce(max(reviewed_at), max(created_at))::date from cl where lower(requester_email) = lower(coalesce(p_email, ''))),
    'slug', (select slug from agent_public_profile where license_number = upper(regexp_replace(coalesce(p_licence, ''), '[^A-Za-z0-9]', '', 'g'))))
$$;

revoke all on function public.claim_state_for_business(text, text), public.claim_state_for_licence(text, text) from public, anon, authenticated;
grant execute on function public.claim_state_for_business(text, text), public.claim_state_for_licence(text, text) to service_role;
