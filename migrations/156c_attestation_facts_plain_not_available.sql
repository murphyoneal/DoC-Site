-- 156c: a withheld attestation renders as plain not_available - no sentence of its own (ruling 748).
--
-- 156b gave a parcel with a withheld attestation its own caveat ("An attestation is recorded against
-- this parcel that we do not serve..."). That tells a reader something exists and is being withheld -
-- a gap in OUR coverage rendered as a hint about the SUBJECT, and unfalsifiable. Ruling 748: use the
-- vocabulary we have. The state stays not_available (156b); the special sentence goes.
--
-- The one existing not_available sentence said "No attestation register is held", which is false for
-- a withheld parcel (the register IS held). So that sentence is reworded to be true in both cases, and
-- both cases share it: every not_available parcel reads identically. The none_recorded and present
-- wording is unchanged.

do $m$
declare d text; n text;
  g_roz boolean := has_function_privilege('roz_payload_reader', 'public.get_parcel_attestations_facts(numeric,text)', 'execute');
  g_cr  boolean := has_function_privilege('consumer_report_readonly', 'public.get_parcel_attestations_facts(numeric,text)', 'execute');
begin
  d := pg_get_functiondef('public.get_parcel_attestations_facts(numeric,text)'::regprocedure);

  n := replace(d, $a$case when withheld > 0 then 'An attestation is recorded against this parcel that we do not serve, because we cannot yet verify the person who made it. This is not a finding either way.'
                         when held = 0$a$,
                  $a$case when held = 0 or withheld > 0$a$);
  if n = d then raise exception '156c: withheld-caveat anchor not found'; end if; d := n;

  n := replace(d, $a$'No attestation register is held. This is a gap in our collection, NOT a finding that no attestation exists for this property.'$a$,
                  $a$'We hold no attestation we can serve for this property. This is a gap in our collection, NOT a finding that no attestation exists for this property.'$a$);
  if n = d then raise exception '156c: not_available sentence anchor not found'; end if; d := n;

  execute d;

  if position('do not serve' in pg_get_functiondef('public.get_parcel_attestations_facts(numeric,text)'::regprocedure)) > 0 then
    raise exception '156c: the withheld sentence survived'; end if;
  if g_roz and not has_function_privilege('roz_payload_reader', 'public.get_parcel_attestations_facts(numeric,text)', 'execute') then
    raise exception '156c: roz_payload_reader lost EXECUTE'; end if;
  if g_cr and not has_function_privilege('consumer_report_readonly', 'public.get_parcel_attestations_facts(numeric,text)', 'execute') then
    raise exception '156c: consumer_report_readonly lost EXECUTE'; end if;
end $m$;
