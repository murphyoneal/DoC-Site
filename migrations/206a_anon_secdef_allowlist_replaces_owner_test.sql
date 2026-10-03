-- 206a - the declared allowlist replaces the owner test as well (ruling 937 section 4, correction 938).
--
-- 205b compared browser_rpc against the catalogue but kept `pg_get_userbyid(p.proowner) <> 'supabase_admin'`. That
-- predicate was an allowlist too: nobody declared it, and it held no reasons. It hid three anon-callable SECURITY DEFINER
-- functions. Measured 2026-10-02, the full set in public is SIX:
--   postgres        contractor_register_search, agent_register_search, register_search
--   supabase_admin  st_estimatedextent(text,text), (text,text,text), (text,text,text,boolean) - PostGIS, EXECUTE to PUBLIC
-- All six are declared, and the owner predicate is dropped. A PostGIS upgrade that opens a seventh now goes red on the
-- next run instead of staying invisible.
-- register_search's reason is claude's words, quoted (937 section 5, id corrected by 938). cc writes the declaration,
-- not the justification.
-- The table name stays: browser_rpc is the anon-callable SECURITY DEFINER allowlist. `category` says why each row is
-- reachable.

alter table public.browser_rpc add column if not exists category text;
update public.browser_rpc set category = 'register_surface' where category is null;
alter table public.browser_rpc alter column category set not null;
alter table public.browser_rpc drop constraint if exists browser_rpc_category_ck;
alter table public.browser_rpc add constraint browser_rpc_category_ck check (category in ('register_surface','extension_default'));
comment on table public.browser_rpc is
  '205b/206a (ruling 932/937): every SECURITY DEFINER function in public that anon or authenticated can execute, each with its reason. anon-callable-secdef-functions compares this list with the catalogue, for every owner, and alarms on disagreement in either direction. The allowlist is the count. Adding a row is a decision to expose a function - say why.';

update public.browser_rpc
   set reason = 'Declared by claude in 937: the two-board search the live register page requires; grants and payload checked by the same control as the other two.'
 where function_sig = 'public.register_search(text,integer)'::regprocedure;

insert into public.browser_rpc (function_sig, reason, category) values
  ('public.st_estimatedextent(text,text)'::regprocedure,
   'PostGIS default: EXECUTE to PUBLIC as shipped by the extension, owned by supabase_admin. Deliberately not altered, same standing as spatial_ref_sys (ruling 937). Returns a table extent estimate, no row data.', 'extension_default'),
  ('public.st_estimatedextent(text,text,text)'::regprocedure,
   'PostGIS default: EXECUTE to PUBLIC as shipped by the extension, owned by supabase_admin. Deliberately not altered, same standing as spatial_ref_sys (ruling 937). Returns a table extent estimate, no row data.', 'extension_default'),
  ('public.st_estimatedextent(text,text,text,boolean)'::regprocedure,
   'PostGIS default: EXECUTE to PUBLIC as shipped by the extension, owned by supabase_admin. Deliberately not altered, same standing as spatial_ref_sys (ruling 937). Returns a table extent estimate, no row data.', 'extension_default')
on conflict (function_sig) do update set reason = excluded.reason, category = excluded.category;

update public.data_defect_registry set detection_sql =
$q$with granted as (
      select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.prosecdef
         and (has_function_privilege('anon', p.oid, 'EXECUTE') or has_function_privilege('authenticated', p.oid, 'EXECUTE'))),
    declared as (select function_sig::oid as oid from public.browser_rpc),
    undeclared_grant as (select oid from granted except select oid from declared),
    declared_without_grant as (select d.oid from declared d where not has_function_privilege('anon', d.oid, 'EXECUTE'))
select not exists (select 1 from undeclared_grant) and not exists (select 1 from declared_without_grant) as ok,
       (select count(*) from undeclared_grant) + (select count(*) from declared_without_grant) as row_count,
       (select string_agg(oid::regprocedure::text, ', ') from undeclared_grant) as undeclared_grants,
       (select string_agg(oid::regprocedure::text, ', ') from declared_without_grant) as declared_but_ungranted,
       (select count(*) from declared) as population$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 206a (ruling 937): the owner predicate (<> supabase_admin) was an undeclared allowlist hiding the three PostGIS st_estimatedextent overloads. Dropped; all six declared with reasons. Every owner is now compared.'
 where defect_id = 'anon-callable-secdef-functions';

do $$
declare j jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'anon-callable-secdef-functions')) into j;
  if (j->>'ok')::boolean is distinct from true or (j->>'population')::int is distinct from 6 then
    raise exception '206a: allowlist detection not green on 6: %', j; end if;
end $$;

select public._log_action('cc', 'anon_secdef_allowlist_replaces_owner_test', 'browser_rpc',
  array['st_estimatedextent x3','register_search reason','anon-callable-secdef-functions'], null,
  jsonb_build_object('declared', 6, 'owner_predicate', 'dropped'),
  'Ruling 937 section 4: the owner test was a hidden allowlist with no reasons; the declared list replaces it for every owner.', null);
