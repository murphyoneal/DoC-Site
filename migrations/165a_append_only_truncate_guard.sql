-- 165a - append-only means a table wipe is refused too (ruling 799 G1, row 801 item 3).
--
-- Measured 2026-09-30: 15 tables carry an append-only trigger (799 named six - the append_only_strict family;
-- nine more use append_only_guard / per-table guards). Every one is BEFORE UPDATE OR DELETE FOR EACH ROW
-- (tgtype 27). A row trigger never sees TRUNCATE, so one statement could empty any of them and fire nothing.
-- service_role held UPDATE, DELETE and TRUNCATE on all 15; anon/authenticated held TRUNCATE on 7.
--
-- Two locks, because a trigger can be disabled and a missing grant cannot be used:
--   1. a statement-level BEFORE TRUNCATE trigger on all 15;
--   2. revoke TRUNCATE and UPDATE from service_role, anon and authenticated on all 15, and DELETE on the 9 whose
--      guard refuses every delete. The 6 append_only_guard tables keep DELETE for service_role ON PURPOSE: that
--      guard lets is_test rows be cleared without disabling the trigger, and real rows stay refused by the trigger.
-- Nothing that works today loses anything: every UPDATE, and every non-test DELETE, was already refused.

create or replace function public.append_only_no_truncate() returns trigger
language plpgsql set search_path to 'public' as $$
begin
  raise exception 'append-only: TRUNCATE on % is not permitted. A correction is a new row that supersedes.', tg_table_name;
end $$;

do $$
declare t text;
  strict_tables text[] := array['moderation_action','business_appeal','language_flag','language_flag_notice','scan_result',
                                'submission_event','dbpr_licence_ledger','tax_deed_observations','web_observations'];
  guard_tables  text[] := array['assistant_exchange_opinion','assistant_query_log','attestation_register',
                                'roz_document_click','roz_glossary_hit','user_version_acceptance'];
begin
  foreach t in array strict_tables || guard_tables loop
    execute format('drop trigger if exists append_only_no_truncate on public.%I', t);
    execute format('create trigger append_only_no_truncate before truncate on public.%I for each statement execute function public.append_only_no_truncate()', t);
    execute format('revoke truncate, update on public.%I from service_role, anon, authenticated', t);
  end loop;
  foreach t in array strict_tables loop
    execute format('revoke delete on public.%I from service_role, anon, authenticated', t);
  end loop;
end $$;

-- Negative controls. Each attempt runs in a subtransaction; if it ever succeeded, the raise inside the same
-- block rolls the wipe back before the migration fails.
do $$
declare t text; n bigint;
begin
  -- (a) service_role: refused by the missing grant
  foreach t in array array['moderation_action','scan_result','dbpr_licence_ledger'] loop
    execute format('select count(*) from public.%I', t) into n;
    begin
      set local role service_role;
      execute format('truncate public.%I', t);
      raise exception '165a: CONTROL_FAILED - service_role truncated %', t;
    exception when others then
      reset role;
      if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
      if sqlerrm not like '%permission denied%' then raise exception '165a: unexpected refusal for service_role on %: %', t, sqlerrm; end if;
    end;
    reset role;
    execute format('select count(*) from public.%I', t) into strict n;  -- still readable, nothing lost
    if has_table_privilege('service_role', format('public.%I', t), 'UPDATE')
       or has_table_privilege('service_role', format('public.%I', t), 'DELETE') then
      raise exception '165a: service_role still holds UPDATE or DELETE on %', t;
    end if;
  end loop;
  -- (b) the owner holds every privilege, so only the trigger stands in the way: it must refuse
  foreach t in array array['moderation_action','roz_glossary_hit','tax_deed_observations'] loop  -- none FK-referenced: a referenced table is refused by the FK check before any trigger fires, which would prove nothing
    begin
      execute format('truncate public.%I', t);
      raise exception '165a: CONTROL_FAILED - owner truncated %', t;
    exception when others then
      if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
      if sqlerrm not like '%TRUNCATE on % is not permitted%' then raise exception '165a: unexpected owner refusal on %: %', t, sqlerrm; end if;
    end;
  end loop;
  -- (c) INSERT and SELECT still work for service_role (the app's only needs)
  if not has_table_privilege('service_role', 'public.moderation_action', 'INSERT')
     or not has_table_privilege('service_role', 'public.moderation_action', 'SELECT') then
    raise exception '165a: service_role lost INSERT/SELECT on moderation_action';
  end if;
  -- (d) is_test cleanup kept on the guard tables
  if not has_table_privilege('service_role', 'public.assistant_query_log', 'DELETE') then
    raise exception '165a: is_test cleanup path removed from assistant_query_log';
  end if;
end $$;
