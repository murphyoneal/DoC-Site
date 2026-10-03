-- 210d - the government register can never be written by a browser role (ruling 973; Murphy's law: "We do NOT change
-- the government record unless it is done by the person who owns the business fully traceable").
--
-- A dormant RLS policy sat on the register table itself:
--   policy "Contractor update own" ON public.contractors FOR UPDATE TO PUBLIC USING (auth.uid()::text = id::text)
--   WITH CHECK NULL - so USING is reused, which pins the id and leaves EVERY other column writable.
-- Inert today (measured): no UPDATE grant to anon or authenticated, and 0 of 4 auth users has an id equal to a
-- contractors row. A leftover from an early design where a contractor row's id was the user's id. Still armed: one
-- GRANT - most likely written for the claim feature by someone looking at business_profile - would let a signed-in user
-- rewrite licence number, status, expiry, name and address on the register.
--   1. Drop it.
--   2. Detection register-table-writable-by-browser-role: NO INSERT/UPDATE/DELETE/TRUNCATE grant AND NO write policy for
--      anon, authenticated or PUBLIC on any register table (the government record and our copies of it). Population =
--      register tables examined. Red-run below by recreating the policy in a subtransaction: a policy WITHOUT a grant
--      must still read red, because "a policy without a grant is not safe, it is armed".
-- Claimed details live in business_profile, written only through definer functions; nothing here touches that path.

drop policy if exists "Contractor update own" on public.contractors;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('register-table-writable-by-browser-role',
  'A government-register table carries a write grant or a write policy for anon, authenticated or PUBLIC - the register must be read-only to every browser role',
  current_date, 'ruling 973 (dormant "Contractor update own" policy on contractors)', 'access_control', 'blocking',
$q$with reg(t) as (values ('public.contractors'), ('public.contractor_name_index'), ('public.businesses'), ('public.business_licences'),
                          ('public.dbpr_construction_snapshot'), ('reg_us_fl.eclb_licence'), ('public.agent_license_roster'),
                          ('public.agent_license_status'), ('reg_us_or.ccb_active_license')),
    present as (select t, to_regclass(t) rel from reg where to_regclass(t) is not null),
    grants as (select t from present p, (values ('anon'), ('authenticated')) r(role), (values ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')) x(priv)
                where has_table_privilege(r.role, p.rel, x.priv)),
    pols as (select p.t from present p join pg_policy pol on pol.polrelid = p.rel
              where pol.polcmd in ('w','a','d','*')   -- UPDATE, INSERT, DELETE, ALL
                and (pol.polroles = '{0}' or pol.polroles && array(select oid from pg_roles where rolname in ('anon','authenticated'))))
select not exists (select 1 from grants) and not exists (select 1 from pols) as ok,
       (select count(*) from grants) + (select count(*) from pols) as row_count,
       (select string_agg(distinct t, ', ') from (select t from grants union all select t from pols) z) as writable,
       (select count(*) from present) as population$q$,
  'clean', 'register tables that exist (9 listed: the construction and electrical registers, agent roster/status, Oregon CCB, and our businesses/licence-link copies)',
  'Checks grants AND policies separately: a write policy with no grant is armed, not safe, and reads red. Red-run in 210d by recreating the dropped policy. Population = listed register tables that exist; a renamed table silently drops out, so the list is reviewed when registers are added.',
  'active', 'ours', 'Keep every register table read-only to browser roles; claimed details go to business_profile through definer functions only.',
  'public_api', 'blocking');

do $$
declare q text; j jsonb; red jsonb;
begin
  select detection_sql into q from public.data_defect_registry where defect_id = 'register-table-writable-by-browser-role';
  execute format('select to_jsonb(x) from (%s) x', q) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) < 5 then raise exception '210d: not clean: %', j; end if;
  begin
    create policy "redrun_contractor_update_own" on public.contractors for update to public using ((select auth.uid())::text = id::text);
    execute format('select to_jsonb(x) from (%s) x', q) into red;
    raise exception 'redrun_done';
  exception when raise_exception then
    if sqlerrm <> 'redrun_done' then raise; end if;
  end;
  if (red->>'ok')::boolean is distinct from false then raise exception '210d: red run did not catch a policy without a grant: %', red; end if;
  if exists (select 1 from pg_policies where tablename = 'contractors' and cmd in ('UPDATE','INSERT','DELETE','ALL')) then raise exception '210d: a write policy remains'; end if;
  raise notice '210d: clean %; red run %', j, red;
end $$;

select public._log_action('cc', 'register_policy_dropped', 'contractors', array['Contractor update own'],
  jsonb_build_object('policy', 'FOR UPDATE TO PUBLIC USING (auth.uid() = id), WITH CHECK NULL'), null,
  'Ruling 973: a dormant write policy on the government register, armed for the first UPDATE grant.', null);
