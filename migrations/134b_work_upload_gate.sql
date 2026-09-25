-- 134b — Who may upload work photos for a business (653 (d); ruling: the upload page is reachable
-- only after a claim exists, and is unreachable today — claim_requests is empty and nothing has
-- been approved. Built, gated, and it lights up when the first claim is approved).
--
-- ALLOWED only when the signed-in user's email is the requester email on an APPROVED claim for a
-- licence record of this business. Anything else returns the reason, so the page can say which
-- door is closed rather than a bare refusal:
--   not_in_register | no_approved_claim | not_the_claimant | allowed
-- The contractor_id returned is the business's canonical licence record — what the contribution
-- is filed against.

create or replace function public.work_upload_gate(p_slug text, p_email text)
returns jsonb language sql stable security definer set search_path = public, pg_temp as
$$
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
    else jsonb_build_object('allowed', true, 'reason', 'allowed',
      'business_id', (select id from biz), 'contractor_id', (select canonical_contractor_id from biz))
  end
$$;

revoke all on function public.work_upload_gate(text, text) from public, anon, authenticated;
grant execute on function public.work_upload_gate(text, text) to service_role;
