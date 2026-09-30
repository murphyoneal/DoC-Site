-- 162a - one basis rule for every operator action (row 786).
--
-- _operator_check gates every /review action and accepted a 3-character basis; set_business_suspension
-- requires 10. "It's ok" (7) was accepted as the recorded justification for approving a registration.
-- A basis is the reason we could show a regulator or an appellant, so the review wrappers now hold the
-- same 10-character floor as suspension, and the refusal says what the basis is for.
--
-- Anchored in-place patch: aborts if the anchor has moved rather than half-applying. _operator_check
-- is service_role-only already (not browser-called), so the secdef sweep strips nothing it relies on;
-- the two public register grants are asserted at the end anyway.

do $$
declare d text;
begin
  d := pg_get_functiondef('public._operator_check(text,text)'::regprocedure);
  if position($a$< 3 then raise exception 'a basis is required'$a$ in d) = 0 then
    raise exception '162a: anchor not found in _operator_check - not applied';
  end if;
  d := replace(d, $a$< 3 then raise exception 'a basis is required'$a$,
                  $a$< 10 then raise exception 'write the reason in at least 10 characters - it is recorded and shown on appeal'$a$);
  execute d;
end $$;

do $$
begin
  -- negative control: a 7-character basis from a real operator must now be refused
  begin
    perform _operator_check((select email from operator_account limit 1), 'It''s ok');
    raise exception '162a: CONTROL_FAILED - short basis accepted';
  exception when others then
    if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
    if sqlerrm not like '%at least 10 characters%' then raise exception '162a: unexpected refusal: %', sqlerrm; end if;
  end;
  -- positive control: a real reason passes
  perform _operator_check((select email from operator_account limit 1), 'Licence matches the register entry');
  -- the browser-called registers must still be reachable
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then
    raise exception '162a: a public register lost its anon grant';
  end if;
end $$;
