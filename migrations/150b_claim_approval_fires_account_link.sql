-- 150b — approving a claim fires step 3 of the cycle (work order 725): the moment a contractor or
-- agent claim becomes 'approved', the database asks /api/claims/approved to issue the claimant's
-- set-password link. pg_net is asynchronous and does not retry, so a pg_cron sweep every 10 minutes
-- asks again for any approved claim that still has no link (account_invite_state IS NULL). The route
-- acts only on what the database says, and records the outcome in account_invite_state (150a).

create or replace function public._claim_approved_fire() returns trigger
language plpgsql security definer set search_path = public, net as $$
begin
  if new.status = 'approved' and (old.status is distinct from 'approved') and new.account_invite_state is null then
    perform net.http_post(
      url := 'https://departmentofconstruction.com/api/claims/approved',
      body := jsonb_build_object('kind', case tg_table_name when 'claim_requests' then 'contractor' else 'agent' end, 'id', new.id),
      headers := '{"Content-Type": "application/json"}'::jsonb);
  end if;
  return new;
end $$;

drop trigger if exists claim_approved_fire on public.claim_requests;
create trigger claim_approved_fire after update of status on public.claim_requests
  for each row execute function public._claim_approved_fire();
drop trigger if exists agent_claim_approved_fire on public.agent_claim_request;
create trigger agent_claim_approved_fire after update of status on public.agent_claim_request
  for each row execute function public._claim_approved_fire();

select cron.unschedule('claim-account-link-sweep') where exists (select 1 from cron.job where jobname = 'claim-account-link-sweep');
select cron.schedule('claim-account-link-sweep', '*/10 * * * *',
  $c$select net.http_post(url := 'https://departmentofconstruction.com/api/claims/approved', body := '{"sweep": true}'::jsonb, headers := '{"Content-Type": "application/json"}'::jsonb)$c$);
