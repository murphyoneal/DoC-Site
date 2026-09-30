-- 172a - the armed claim paths (ruling 830, step 1).
--
-- ACCESS EXPOSURE - bulk_accept_permit_candidates: EXECUTE to anon + authenticated, SECURITY INVOKER, inserts
-- permit_claims rows with claim_status 'confirmed' from algorithmic match scores, no person involved. Only a
-- table grant stood between an anonymous caller and a "confirmed" claim. DELETED.
-- The same fence-not-lock shape on five more functions with NO caller in the DB or the repo:
-- issue_permit_with_audit, verify_permit_submission, recompute_proven_areas, generate_candidates_for_contractor,
-- answer_hazard_prompt (and the trigger function). EXECUTE revoked from public/anon/authenticated; the intake
-- functions stay (see below) for service_role.
--
-- NOT DROPPED, AGAINST RULING 830, AND WHY: permit_claims. My 810 report described it as auto-acceptance only. It
-- is also where the DoA permit-intake workflow records a claim when COUNTY STAFF issue a permit through our
-- system (issue_permit_with_audit / verify_permit_submission: claim_method 'manual_admin', "county-staff-
-- attested") - the strongest corroboration the project could hold. It is retired when the spine exists and
-- those two functions write the spine instead. 0 rows; nothing can write it except service_role now.
--
-- SEMANTIC EXPOSURE - agent_claim_confirm: service_role only (access fine), but it recorded status 'confirmed'
-- for an agent's own paste, and the served fact said "corroborated to a recorded sale". The attached sale is only
-- the most recent recorded sale on the parcel; a deed never names the agent, so it corroborates nothing about the
-- agent's role. Now: status 'stated_by_party'; only a public listing naming the agent may later add
-- 'listing_names_this_agent' (810/812). State names name their cause (827).

-- 1. delete the access exposure
drop function if exists public.bulk_accept_permit_candidates(uuid, text);

-- 2. lock the other unguarded claim/intake functions
do $$ declare f regprocedure; begin
  for f in select p.oid::regprocedure from pg_proc p
            where p.pronamespace = 'public'::regnamespace
              and p.proname in ('issue_permit_with_audit','verify_permit_submission','recompute_proven_areas',
                                'generate_candidates_for_contractor','answer_hazard_prompt','trg_recompute_on_claim_confirm') loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

-- 3. agent self-claims are stated, never confirmed
alter table public.agent_parcel_claim alter column status drop default;
alter table public.agent_parcel_claim add constraint agent_parcel_claim_status_check
  check (status in ('stated_by_party','listing_names_this_agent','withdrawn_by_party'));
comment on column public.agent_parcel_claim.status is
  'stated_by_party = the agent''s own statement, nothing independent behind it; listing_names_this_agent = a public listing page names this agent for this parcel (the only corroboration we can perform, 810/812); withdrawn_by_party. Never "confirmed" (ruling 830). No default: the writer states it.';

do $$ declare d text; begin
  d := pg_get_functiondef('public.agent_claim_confirm(uuid,numeric,text[])'::regprocedure);
  if position('''address_paste'',''confirmed'')' in d) = 0 then raise exception '172a: agent_claim_confirm anchor not found'; end if;
  d := replace(d, '''address_paste'',''confirmed'')', '''address_paste'',''stated_by_party'')');
  execute d;
end $$;
revoke all on function public.agent_claim_confirm(uuid,numeric,text[]) from public, anon, authenticated;
grant execute on function public.agent_claim_confirm(uuid,numeric,text[]) to service_role;
comment on function public.agent_claim_confirm(uuid,numeric,text[]) is
  'Records an agent''s own statement that they handled a sale on these parcels, as status stated_by_party. The name says "confirm" for its caller''s sake; it confirms nothing (ruling 830).';

do $$ declare d text; begin
  d := pg_get_functiondef('public.get_parcel_sales_agent(numeric,text)'::regprocedure);
  if position('c.status=''confirmed''' in d) = 0 then raise exception '172a: sales agent status anchor not found'; end if;
  if position('corroborated to a recorded sale where one attached' in d) = 0 then raise exception '172a: sales agent wording anchor not found'; end if;
  d := replace(d, 'c.status=''confirmed''', 'c.status in (''stated_by_party'',''listing_names_this_agent'')');
  d := replace(d, '''source'',''agent self-report (firsthand)''',
                  '''source'',''agent self-report (firsthand)'',''corroboration'', case when c.status = ''listing_names_this_agent'' then ''a public listing names this agent for this parcel'' else ''none - stated by the agent'' end');
  d := replace(d, 'Self-reported by a licensed agent from firsthand knowledge, corroborated to a recorded sale where one attached.',
                  'STATED BY a licensed agent; nothing independent confirms their role unless corroboration says a public listing names them. The attached sale is the most recent recorded sale on this parcel - a deed does not name the agent, so it does not corroborate the role of the agent.');
  execute d;
end $$;

-- 4. the record (799)
insert into public.moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via)
values (now(), 'cc', 'build_agent', 'close_armed_claim_paths', 'claim functions',
  array['bulk_accept_permit_candidates','issue_permit_with_audit','verify_permit_submission','recompute_proven_areas','generate_candidates_for_contractor','answer_hazard_prompt','agent_claim_confirm','get_parcel_sales_agent'],
  jsonb_build_object('bulk_accept_permit_candidates','anon+authenticated EXECUTE, invoker, writes confirmed claims from match scores',
                     'five_more','anon+authenticated EXECUTE, invoker, no callers',
                     'agent_claim_confirm','writes status confirmed for a self-assertion', 'sales_agent_wording','corroborated to a recorded sale where one attached'),
  jsonb_build_object('bulk_accept_permit_candidates','dropped', 'five_more','service_role only',
                     'agent_claim_confirm','writes stated_by_party', 'sales_agent_wording','stated by the agent; a deed does not name the agent',
                     'permit_claims','kept until the spine replaces the DoA intake claim path'),
  'Ruling 830 step 1: a claim path that mints "confirmed" with no person, reachable by anyone, is locked by deleting it; a self-assertion is recorded as stated, never confirmed. permit_claims kept, against the ruling, because the DoA intake workflow writes county-staff-attested claims there.',
  'migration 172a');

do $$ begin
  if exists (select 1 from pg_proc where proname = 'bulk_accept_permit_candidates') then raise exception '172a: not dropped'; end if;
  if exists (select 1 from pg_proc p where p.pronamespace='public'::regnamespace
              and p.proname in ('issue_permit_with_audit','verify_permit_submission','recompute_proven_areas','generate_candidates_for_contractor','answer_hazard_prompt','trg_recompute_on_claim_confirm','agent_claim_confirm','get_parcel_sales_agent')
              and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))) then
    raise exception '172a: a claim function is still anon/authenticated-executable'; end if;
  if position('''confirmed''' in pg_get_functiondef('public.agent_claim_confirm(uuid,numeric,text[])'::regprocedure)) > 0 then raise exception '172a: confirmed survived'; end if;
  if (get_parcel_sales_agent_facts(74, '633001001890')->>'field_status') is null then raise exception '172a: sales agent facts broke'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '172a: register grants lost'; end if;
end $$;
