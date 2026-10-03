-- 207e - revert the anon/authenticated grants and the read policy from 207a-207c (ruling 946; claude's session is
-- blocked from destructive DDL, so cc applies it).
--
-- 207c gave name_placeholder_registry an anon SELECT grant plus a USING (true) policy. That made it the only table in
-- public that the published key could actually read, and the anon-reachable-table-grant-unexpected guard could not see
-- it (that guard skips RLS tables). No served path needs any of this. register_search and contractor_register_search
-- are SECURITY DEFINER, owned by postgres (rolbypassrls), so inside them the helper reads its list with no grant and no
-- policy. Proven 2026-10-02 in a rolled-back transaction: with no grant and no policy, an anon call through a
-- SECURITY DEFINER caller returned true.
-- trade_chip_map is read at build time with the service key, so the browser never needs it either. The pattern copied
-- is trade_code_registry: RLS on, no grant, no policy, read only through definer functions or service_role.
-- is_name_placeholder also carried EXECUTE to PUBLIC (the default for a new function). Revoking from anon and
-- authenticated alone would leave anon executing it via PUBLIC, so PUBLIC is revoked too and the result is asserted.

drop policy if exists name_placeholder_registry_read on public.name_placeholder_registry;
revoke all on public.name_placeholder_registry from anon, authenticated;
revoke all on public.trade_chip_map from anon, authenticated;
revoke execute on function public.is_name_placeholder(text) from public, anon, authenticated;
grant execute on function public.is_name_placeholder(text) to service_role;

do $$
declare j jsonb;
begin
  if has_table_privilege('anon', 'public.name_placeholder_registry', 'SELECT')
     or has_table_privilege('authenticated', 'public.name_placeholder_registry', 'SELECT')
     or has_table_privilege('anon', 'public.trade_chip_map', 'SELECT')
     or has_table_privilege('authenticated', 'public.trade_chip_map', 'SELECT')
     or has_function_privilege('anon', 'public.is_name_placeholder(text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.is_name_placeholder(text)', 'EXECUTE') then
    raise exception '207e: an anon/authenticated privilege survived the revoke';
  end if;
  if exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'name_placeholder_registry') then
    raise exception '207e: a policy remains on name_placeholder_registry';
  end if;
  -- the placeholder detections run as the runner's owner and must still see the list
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'name-placeholder-registry-incomplete')) into j;
  if (j->>'ok')::boolean is distinct from true or (j->>'examined')::int is distinct from 3623 then raise exception '207e: registry-incomplete detection changed: %', j; end if;
  -- the public searches still run for anon (the allowlist is unchanged)
  if not has_function_privilege('anon', 'public.register_search(text,integer)', 'EXECUTE') then raise exception '207e: register_search lost anon'; end if;
end $$;

select public._log_action('cc', 'revert_placeholder_and_chip_grants', 'name_placeholder_registry',
  array['name_placeholder_registry','trade_chip_map','is_name_placeholder','name_placeholder_registry_read'],
  jsonb_build_object('anon_select', true, 'policy', 'USING (true)', 'execute', 'public, anon, authenticated'),
  jsonb_build_object('anon_select', false, 'policy', null, 'execute', 'service_role (+ owner)'),
  'Ruling 946: 207b/207c opened the only genuinely public table in the schema for a call path that does not exist; definer functions need no grant.', null);
