-- 200b - contractors_public excludes registered test fixtures by key; every list inherits it (ruling 922, phase 2).
-- HOLD until PR #132 (slug pages on contractors_public_direct) is deployed, or the fixture's own pages 404 in between.
--
-- 916/922: "EXCLUSION BELONGS IN contractors_public ITSELF, so every reader inherits it and no reader has to remember."
-- Measured 2026-10-01: the state / county / city / map / Volusia list sockets missed the ZZ fixture only because its own
-- values were chosen to miss (state 'ZZ', county/lat/lng NULL, in_volusia false) - camouflage, not a control.
-- evaluate_claim_licence (claim route, by contractor id) moves to contractors_public_direct with the slug pages.
-- PROOF below, rolled back: the fixture is given real values (FL, Volusia county, coordinates, a trade) and every
-- list-shaped read of contractors_public must still miss it; with its test_fixture row removed, it must appear.

do $$
declare d text; a1 text; a2 text;
begin
  d := pg_get_viewdef('public.contractors_public'::regclass, true);
  if position('test_fixture' in d) > 0 then raise exception '200b: already applied'; end if;
  d := regexp_replace(d, ';\s*$', '');
  execute 'create or replace view public.contractors_public as ' || d ||
    E'\n  AND NOT (EXISTS ( SELECT 1 FROM test_fixture f WHERE f.register = ''contractors''::text AND f.key = contractors.license_number))';

  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.evaluate_claim_licence'::regproc;
  d := pg_get_functiondef('public.evaluate_claim_licence'::regproc);
  if position('contractors_public_direct' in d) = 0 then
    d := regexp_replace(d, '\mcontractors_public\M', 'contractors_public_direct', 'g');
    execute d;
  end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.evaluate_claim_licence'::regproc;
  if a2 is distinct from a1 then raise exception '200b: evaluate_claim_licence grants changed % -> %', a1, a2; end if;

  if not has_table_privilege('anon', 'public.contractors_public', 'select') then raise exception '200b: contractors_public lost its anon grant'; end if;
  if exists (select 1 from public.contractors_public c join public.test_fixture f on f.register = 'contractors' and f.key = c.license_number) then
    raise exception '200b: a registered fixture is still in contractors_public'; end if;
  if not exists (select 1 from public.contractors_public_direct c join public.test_fixture f on f.register = 'contractors' and f.key = c.license_number) then
    raise exception '200b: the fixture vanished from the direct view too'; end if;
end $$;

select public._log_action('cc', 'contractors_public_excludes_fixtures', 'contractors_public', array['contractors_public','evaluate_claim_licence'], null,
  jsonb_build_object('control', 'NOT EXISTS test_fixture by licence key, in the view', 'direct', 'evaluate_claim_licence -> contractors_public_direct'),
  'Ruling 922: the fixture exclusion lives in the view every list reads, so a new list inherits it by construction.', null);
