-- 149a — a reserved test range (ruling 723, option B): synthetic records that can be claimed by direct
-- URL but that no public search, count or list ever returns. A facility, not a one-off: Washington and
-- Texas fixtures will use it too.
--
-- KEYED ON A REGISTRY, NOT ON THE PREFIX ALONE. "ZZ" collides with nothing today (measured 2026-09-28:
-- 0 contractors, 0 agent roster/status, 0 Oregon numbers begin ZZ; Florida contractor numbers DO carry
-- letter prefixes - CGC, CBC, CZC... - and Oregon has 478 "9999OCLS" numbers, so "every number is
-- numeric" is NOT the reason it is safe). Exclusion therefore applies only to keys REGISTERED in
-- test_fixture. If a real register ever issues a ZZ number, it is still shown - and the second
-- detection below goes red, because an unregistered ZZ row exists. A hidden real licence is the one
-- outcome that would not be recoverable, so the exclusion cannot cause it.
--
-- The two anon-called searches are replaced here; CREATE OR REPLACE strips anon EXECUTE
-- (trg_revoke_public_on_new_secdef), so both are re-granted and asserted in this migration.

create table if not exists public.test_fixture (
  register    text not null check (register in ('contractors', 'agent_license_roster')),
  key         text not null check (key like 'ZZ%'),
  label       text not null,
  note        text,
  created_at  timestamptz not null default now(),
  primary key (register, key)
);
alter table public.test_fixture enable row level security;
revoke all on public.test_fixture from anon, authenticated;
grant select, insert, update, delete on public.test_fixture to service_role;
comment on table public.test_fixture is
  'Deliberate synthetic records (ZZ range) for walking claim flows without touching a real licensee. Public searches, counts and lists skip exactly these keys. A future session must NOT "clean them up" without asking: see data_defect_registry reserved-test-fixture-*. 149a.';

create or replace function public.is_test_fixture(p_register text, p_key text) returns boolean
language sql stable set search_path = public as $$
  select exists (select 1 from test_fixture where register = p_register and key = p_key)
$$;

do $f$
declare def text; nd text;
begin
  -- agent register search: the count, the rows, and the "identity as of" date all skip fixtures
  def := pg_get_functiondef('public.agent_register_search(text,integer)'::regprocedure);
  nd := replace(def, 'SELECT max(r.original_issue_date) INTO v_identity_min FROM agent_license_roster r;',
                     'SELECT max(r.original_issue_date) INTO v_identity_min FROM agent_license_roster r WHERE NOT public.is_test_fixture(''agent_license_roster'', r.license_number);');
  nd := replace(nd, E'  FROM agent_license_roster r\n  WHERE r.name ILIKE ''%''||v_q||''%''\n     OR r.license_number ILIKE v_q||''%'';',
                    E'  FROM agent_license_roster r\n  WHERE (r.name ILIKE ''%''||v_q||''%''\n     OR r.license_number ILIKE v_q||''%'')\n    AND NOT public.is_test_fixture(''agent_license_roster'', r.license_number);');
  nd := replace(nd, E'    WHERE r.name ILIKE ''%''||v_q||''%''\n       OR r.license_number ILIKE v_q||''%''',
                    E'    WHERE (r.name ILIKE ''%''||v_q||''%''\n       OR r.license_number ILIKE v_q||''%'')\n      AND NOT public.is_test_fixture(''agent_license_roster'', r.license_number)');
  if (length(nd) - length(replace(nd, 'is_test_fixture', ''))) / length('is_test_fixture') <> 3 then
    raise exception '149a: agent_register_search anchors - expected 3 fixture clauses';
  end if;
  execute nd;

  -- contractor register search
  def := pg_get_functiondef('public.contractor_register_search(text,integer)'::regprocedure);
  nd := replace(def, E'     WHERE c.active IS NOT FALSE\n       AND NOT EXISTS (SELECT 1 FROM public.trade_code_registry tr',
                     E'     WHERE c.active IS NOT FALSE\n       AND NOT public.is_test_fixture(''contractors'', c.license_number)\n       AND NOT EXISTS (SELECT 1 FROM public.trade_code_registry tr');
  if nd = def then raise exception '149a: contractor_register_search anchor missing'; end if;
  execute nd;

  -- the finder's result list (its county counts already require a county, which fixtures do not have)
  def := pg_get_functiondef('public.contractor_finder(text,text,text,integer,integer)'::regprocedure);
  nd := replace(def, E'     WHERE c.active IS NOT FALSE\n       AND NOT EXISTS (SELECT 1 FROM trade_code_registry tr WHERE tr.trade_code = c.trade_code AND tr.department = ''none'')\n       AND (v_county IS NULL',
                     E'     WHERE c.active IS NOT FALSE\n       AND NOT public.is_test_fixture(''contractors'', c.license_number)\n       AND NOT EXISTS (SELECT 1 FROM trade_code_registry tr WHERE tr.trade_code = c.trade_code AND tr.department = ''none'')\n       AND (v_county IS NULL');
  if nd = def then raise exception '149a: contractor_finder anchor missing'; end if;
  execute nd;
end $f$;

grant execute on function public.agent_register_search(text, integer) to anon, authenticated;
grant execute on function public.contractor_register_search(text, integer) to anon, authenticated;

-- DETECTION 1: no registered fixture is ever returned by a public search.
insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
    false_positive_notes, status, remediation, attribution, expected_state, magnitude_semantics)
values ('reserved-test-fixture-in-public-search',
  'A registered test fixture (ZZ range) appears in a public search result',
  date '2026-09-28', 'ruling 723 / migration 149a', 'access_control', 'blocking',
  $d$select not exists (
     select 1 from test_fixture f
      where (f.register = 'agent_license_roster' and exists (select 1 from jsonb_array_elements(public.agent_register_search(f.label, 25)->'results') e where e->>'license_number' = f.key))
         or (f.register = 'contractors' and (
               exists (select 1 from jsonb_array_elements(public.contractor_register_search(f.label, 25)->'results') e where e->>'license_number' = f.key)
            or exists (select 1 from jsonb_array_elements(public.contractor_finder(f.label, null, null, 60, 0)->'results') e
                        where e->>'slug' in (select b.slug from businesses b join contractors c on c.id = b.canonical_contractor_id where c.license_number = f.key))))
   ) as ok$d$,
  'Searches each fixture by its own label, the query most likely to surface it. Green with zero fixtures registered is vacuous; it was proven red in a rolled-back transaction when written.',
  'active', 'Restore the is_test_fixture() clause in the public search that returned it (149a).', 'ours', 'clean', 'binary')
on conflict (defect_id) do nothing;

-- DETECTION 2: every ZZ-prefixed row in a register is a registered fixture. Red means a REAL register
-- has issued a ZZ number (or a fixture was made without registering it) - look before anything else.
insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
    false_positive_notes, status, remediation, attribution, expected_state, magnitude_semantics)
values ('reserved-prefix-row-not-a-registered-fixture',
  'A ZZ-prefixed licence row exists that is not a registered test fixture',
  date '2026-09-28', 'ruling 723 / migration 149a', 'key_integrity', 'blocking',
  $d$select not exists (
     select 1 from contractors c where upper(c.license_number) like 'ZZ%' and not public.is_test_fixture('contractors', c.license_number)
     union all
     select 1 from agent_license_roster r where upper(r.license_number) like 'ZZ%' and not public.is_test_fixture('agent_license_roster', r.license_number)
     union all
     select 1 from reg_us_or.ccb_active_license o where upper(o.license_number) like 'ZZ%'
   ) as ok$d$,
  'Oregon has no fixtures, so any ZZ number there is real and must be seen. Florida numbers carry letter prefixes but none is ZZ (measured 2026-09-28).',
  'active', 'If the row is real: the reserved prefix has collided with a live register - stop using ZZ for that register and register a new prefix. If it is a fixture: add it to test_fixture.', 'ours', 'clean', 'binary')
on conflict (defect_id) do nothing;

do $a$
begin
  if not has_function_privilege('anon', 'public.agent_register_search(text,integer)', 'EXECUTE') then raise exception '149a: agent_register_search lost anon'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'EXECUTE') then raise exception '149a: contractor_register_search lost anon'; end if;
  if (public.agent_register_search('LETIZIA', 5)->>'count')::int <> 4 then raise exception '149a: agent search result changed'; end if;
  if public.contractor_register_search('roofing', 5) is null then raise exception '149a: contractor search returned nothing'; end if;
end $a$;
