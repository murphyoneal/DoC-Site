-- 183a - anon and authenticated may not empty, lock, trigger or reference our tables (ruling 892).
--
-- MEASURED 2026-10-01 over every relation in public: anon and authenticated hold TRUNCATE on 2,614, TRIGGER and MAINTAIN
-- on 2,621. Row-level security does not restrain TRUNCATE, and MAINTAIN includes LOCK TABLE. The cause is the DEFAULT
-- privileges: pg_default_acl for role postgres in schema public grants anon=Dxtm and authenticated=Dxtm (TRUNCATE,
-- REFERENCES, TRIGGER, MAINTAIN), so every table a migration creates is born with them. Revoking on existing tables
-- alone would be undone by the next CREATE TABLE.
-- Not exploitable today (verified by claude, 892): PostgREST exposes no TRUNCATE verb and no anon-callable function
-- executes one. What prevents it is the ABSENCE of a function, not of a permission - one future helper and the dataset
-- is one request from empty. Defence by accident, closed here.
-- Scope, stated with its denominator: schema public only. storage (3) and net (2) carry the same grants but are
-- Supabase-managed schemas - reported, not touched. supabase_admin's own default ACL in public (arwdDxtm to anon) cannot
-- be altered by postgres; it applies only to objects supabase_admin creates.
-- anon's INSERT/UPDATE/DELETE (3 PostGIS objects) are unchanged; SELECT is unchanged everywhere.
-- EXCLUDED BY NAME: public.spatial_ref_sys, owned by supabase_admin (PostGIS). postgres holds no grant option on it, so
-- the revoke cannot reach it - the first apply of this migration raised on exactly that table and rolled back.

revoke truncate, trigger, maintain, references on all tables in schema public from anon, authenticated;
alter default privileges for role postgres in schema public revoke truncate, trigger, maintain, references on tables from anon, authenticated;

insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('anon-or-authenticated-hold-truncate',
  'anon or authenticated hold TRUNCATE, TRIGGER or MAINTAIN on a table in public, or postgres''s default privileges would grant them to new tables',
  'access_control', 'blocking',
  $q$select (not exists (select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
                        where n.nspname = 'public' and c.relkind in ('r','p','m','f') and c.relname <> 'spatial_ref_sys'
                          and (has_table_privilege('anon', c.oid, 'TRUNCATE') or has_table_privilege('authenticated', c.oid, 'TRUNCATE')
                            or has_table_privilege('anon', c.oid, 'TRIGGER') or has_table_privilege('authenticated', c.oid, 'TRIGGER')
                            or has_table_privilege('anon', c.oid, 'MAINTAIN') or has_table_privilege('authenticated', c.oid, 'MAINTAIN')))
            and not exists (select 1 from pg_default_acl d join pg_namespace n on n.oid = d.defaclnamespace
                             where n.nspname = 'public' and d.defaclobjtype = 'r' and pg_get_userbyid(d.defaclrole) = 'postgres'
                               and (d.defaclacl::text ~ '(anon|authenticated)=[a-zA-Z]*[Dtm]'))) as ok$q$,
  'Catalog check over every table in public (except spatial_ref_sys, supabase_admin-owned PostGIS, unrevokable by us) plus postgres''s default ACL. Cannot see supabase_admin''s default ACL (not alterable by us) or the Supabase-managed storage/net schemas, which are out of scope by decision (183a).');

select public._log_action('cc', 'revoke_anon_truncate', 'pg_class', array['public.* tables','pg_default_acl postgres/public'],
  jsonb_build_object('anon_truncate', 2614, 'authenticated_truncate', 2614, 'anon_trigger', 2621, 'anon_maintain', 2621),
  jsonb_build_object('revoked', 'truncate, trigger, maintain, references', 'from', 'anon, authenticated', 'default_privileges', 'postgres in public'),
  'Ruling 892: TRUNCATE is not restrained by RLS; anon/authenticated held it on every public table by default privilege. Revoked, defaults fixed, detection added.', null);

do $$
declare n int; ok boolean;
begin
  select count(*) into n from pg_class c join pg_namespace s on s.oid = c.relnamespace
   where s.nspname = 'public' and c.relkind in ('r','p','m','f') and c.relname <> 'spatial_ref_sys'
     and (has_table_privilege('anon', c.oid, 'TRUNCATE') or has_table_privilege('authenticated', c.oid, 'TRUNCATE'));
  if n is distinct from 0 then raise exception '183a: % tables still truncatable by anon/authenticated', n; end if;
  execute (select detection_sql from data_defect_registry where defect_id = 'anon-or-authenticated-hold-truncate') into ok;
  if ok is distinct from true then raise exception '183a: detection not green after the revoke'; end if;
  -- the register searches the public site depends on still work
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '183a: register grants lost'; end if;
end $$;
