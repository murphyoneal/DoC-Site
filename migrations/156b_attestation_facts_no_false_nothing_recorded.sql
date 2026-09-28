-- 156b: get_parcel_attestations_facts must not say "nothing is recorded" about a withheld dispute.
--
-- A consequence of 156a, closed in the same concern. get_parcel_attestations_facts decides its
-- coverage state from items (what get_parcel_attestations serves) and held (count(*) of the register).
-- After 156a a parcel whose only attestation disputes our finding gets items = [] and held > 0, so it
-- would return 'none_recorded' with "The attestation register is held and was searched; nothing is
-- recorded against this parcel." That is false: something is recorded, and we are withholding it.
--
-- Now: if the parcel has non-test rows that were not served, the state is 'not_available' and the
-- caveat says an attestation is recorded that we do not serve because we cannot verify the attester.
-- It does not say what the attestation claims. Existing vocabulary only.
--
-- NOT changed here (reported to claude, ruling 746 said measure-and-report): held still counts
-- is_test rows, so a single test row flips the statewide state from not_available to none_recorded.

do $m$
declare d text; n text;
  g_roz boolean := has_function_privilege('roz_payload_reader', 'public.get_parcel_attestations_facts(numeric,text)', 'execute');
  g_cr  boolean := has_function_privilege('consumer_report_readonly', 'public.get_parcel_attestations_facts(numeric,text)', 'execute');
begin
  d := pg_get_functiondef('public.get_parcel_attestations_facts(numeric,text)'::regprocedure);

  n := replace(d, $a$declare items jsonb; held bigint;$a$, $a$declare items jsonb; held bigint; withheld bigint;$a$);
  if n = d then raise exception '156b: declare anchor not found'; end if; d := n;

  n := replace(d, $a$select count(*) into held from attestation_register;$a$,
                  $a$select count(*) into held from attestation_register;
  -- rows recorded against this parcel that get_parcel_attestations does not serve (156a)
  select count(*) into withheld from attestation_register
   where co_no = p_co_no and parcel_id = p_parcel_id and is_test = false and disputes_finding is distinct from false;$a$);
  if n = d then raise exception '156b: held anchor not found'; end if; d := n;

  n := replace(d, $a$                        when held = 0 then 'not_available'$a$,
                  $a$                        when held = 0 or withheld > 0 then 'not_available'$a$);
  if n = d then raise exception '156b: field_status anchor not found'; end if; d := n;

  n := replace(d, $a$'coverage_caveat', case when held = 0$a$,
                  $a$'coverage_caveat', case when withheld > 0 then 'An attestation is recorded against this parcel that we do not serve, because we cannot yet verify the person who made it. This is not a finding either way.'
                         when held = 0$a$);
  if n = d then raise exception '156b: caveat anchor not found'; end if; d := n;

  execute d;

  if g_roz and not has_function_privilege('roz_payload_reader', 'public.get_parcel_attestations_facts(numeric,text)', 'execute') then
    raise exception '156b: roz_payload_reader lost EXECUTE'; end if;
  if g_cr and not has_function_privilege('consumer_report_readonly', 'public.get_parcel_attestations_facts(numeric,text)', 'execute') then
    raise exception '156b: consumer_report_readonly lost EXECUTE'; end if;
end $m$;
