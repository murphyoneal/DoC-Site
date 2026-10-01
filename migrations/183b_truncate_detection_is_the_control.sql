-- 183b - record that the default-privilege fix in 183a closed ONE of two creation paths (ruling 894).
--
-- 183a fixed postgres's default ACL in public. pg_default_acl also holds supabase_admin's entry for public, granting
-- anon=arwdDxtm and authenticated=arwdDxtm (INSERT, SELECT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER, MAINTAIN).
-- A table the PLATFORM creates (extension installs, platform operations) is born with all of them. 183a's red run created
-- its probe as postgres, so "a newly created table no longer gets it" was true of one creation path out of two.
-- Tried 2026-10-01, rolled back:
--   ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public REVOKE ... FROM anon, authenticated;
--   -> SQLSTATE 42501 "permission denied to change default privileges" (current_user postgres, not a member of
--      supabase_admin).
-- So the default cannot be closed by us. THE DETECTION IS THE CONTROL: anon-or-authenticated-hold-truncate checks ACTUAL
-- grants on every actual table in public (has_table_privilege), and runs in the daily defect queue, so a platform-created
-- table that inherits TRUNCATE is caught within a day. Its notes now say so, so the next reader does not believe the
-- defaults are closed.

update public.data_defect_registry
   set false_positive_notes =
     'THIS DETECTION IS THE CONTROL, NOT THE DEFAULT-PRIVILEGE FIX (183b). It checks ACTUAL grants on every table in public '
     || '(except spatial_ref_sys: supabase_admin-owned PostGIS, unrevokable by postgres) plus postgres''s default ACL. '
     || 'supabase_admin''s default ACL in public still grants anon/authenticated arwdDxtm and CANNOT be changed by us '
     || '(ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin -> 42501, tried 2026-10-01), so any table the platform creates '
     || 'is born truncatable by anon; the daily run catches it. Does not cover the Supabase-managed storage/net schemas.'
 where defect_id = 'anon-or-authenticated-hold-truncate';

select public._log_action('cc', 'record_truncate_control', 'data_defect_registry', array['anon-or-authenticated-hold-truncate'], null,
  jsonb_build_object('supabase_admin_default_acl', 'unalterable: 42501'),
  'Ruling 894: 183a closed the postgres default-privilege path only; the supabase_admin path cannot be closed by us, so the daily detection is recorded as the control.', null);

do $$
declare ok boolean; st text;
begin
  select status into st from public.data_defect_registry where defect_id = 'anon-or-authenticated-hold-truncate';
  if st is distinct from 'active' then raise exception '183b: detection status is %, not active - it would not run daily', st; end if;
  execute (select detection_sql from public.data_defect_registry where defect_id = 'anon-or-authenticated-hold-truncate') into ok;
  if ok is distinct from true then raise exception '183b: detection is not green'; end if;
end $$;
