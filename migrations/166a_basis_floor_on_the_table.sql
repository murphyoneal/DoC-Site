-- 166a - the basis floor lives on the table, not only in the callers (ruling 799 G2, row 801 item 4).
--
-- moderation_action's CHECK was length(btrim(basis)) > 0: one character passed. The 10-character floor lived in
-- _operator_check (162a) and set_business_suspension, so any other writer - _log_action called directly, or a
-- service_role insert - could record a one-word reason.
--
-- NOT VALID, deliberately, and never to be validated: it enforces on every NEW row and leaves history alone.
-- Row 8 (basis "It's ok", 7 characters, Murphy's registration approval of 2026-09-30 11:17, before 162a) is the
-- honest state of the log at that moment and is NOT touched. Why one row is short: because it predates the rule,
-- and we did not rewrite it.

alter table public.moderation_action
  add constraint moderation_action_basis_floor check (length(btrim(basis)) >= 10) not valid;

comment on constraint moderation_action_basis_floor on public.moderation_action is
  'NOT VALID on purpose (ruling 799 G2): enforces the 10-character basis floor on new rows only. Row 8 ("It''s ok") '
  'predates the rule and stays as recorded. Never VALIDATE this constraint - validating would require rewriting history.';

-- The same floor inside _log_action, so the guarantee does not depend on its callers.
create or replace function public._log_action(p_actor text, p_action text, p_table text, p_ids text[], p_before jsonb, p_after jsonb, p_basis text, p_ip inet)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if length(btrim(coalesce(p_basis, ''))) < 10 then
    raise exception 'write the reason in at least 10 characters - it is recorded and shown on appeal';
  end if;
  insert into moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via, ip)
  values (now(), lower(btrim(p_actor)), 'operator', p_action, p_table, p_ids, p_before, p_after, btrim(p_basis), '/review', p_ip);
end $$;
revoke all on function public._log_action(text,text,text,text[],jsonb,jsonb,text,inet) from public, anon, authenticated;
grant execute on function public._log_action(text,text,text,text[],jsonb,jsonb,text,inet) to service_role;

do $$
declare before_rows jsonb; after_rows jsonb;
begin
  select jsonb_agg(to_jsonb(m) order by id) into before_rows from moderation_action m;
  -- (a) the table refuses a short basis from a direct insert
  begin
    insert into moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, basis, via)
    values (now(), 'control@example.test', 'build_agent', 'control', 'none', array['0'], 'short', 'migration 166a');
    raise exception '166a: CONTROL_FAILED - table accepted a 5-character basis';
  exception when others then
    if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
    if sqlerrm not like '%moderation_action_basis_floor%' then raise exception '166a: unexpected refusal: %', sqlerrm; end if;
  end;
  -- (b) _log_action refuses it before reaching the table
  begin
    perform _log_action('control@example.test', 'control', 'none', array['0'], null, null, 'It''s ok', null);
    raise exception '166a: CONTROL_FAILED - _log_action accepted a 7-character basis';
  exception when others then
    if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
    if sqlerrm not like '%at least 10 characters%' then raise exception '166a: unexpected refusal: %', sqlerrm; end if;
  end;
  -- (c) history untouched, constraint left unvalidated
  select jsonb_agg(to_jsonb(m) order by id) into after_rows from moderation_action m;
  if before_rows is distinct from after_rows then raise exception '166a: the log changed'; end if;
  if (select basis from moderation_action where id = 8) <> 'It''s ok' then raise exception '166a: row 8 was altered'; end if;
  if (select convalidated from pg_constraint where conname = 'moderation_action_basis_floor') then raise exception '166a: constraint must stay NOT VALID'; end if;
  -- (d) grants
  if has_function_privilege('anon', 'public._log_action(text,text,text,text[],jsonb,jsonb,text,inet)', 'execute') then raise exception '166a: anon can execute _log_action'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then
    raise exception '166a: a public register lost its anon grant';
  end if;
end $$;
