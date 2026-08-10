-- =============================================================================
-- P0 recurrence PREVENTION (ruling 93): ALTER DEFAULT PRIVILEGES is a no-op here (4 independent
-- observations — 3 of mine + claude's), so the hole reopens on every CREATE FUNCTION. A
-- ddl_command_end event trigger closes it, same shape as the existing postgres-owned
-- rls_auto_enable trigger. The standing detection predicate STAYS (trigger prevents, predicate
-- verifies; neither trusted alone).
--
-- Conditions (ruling 93): schema public + SECURITY DEFINER only; never touch supabase_admin-owned
-- (extension DDL would break an upgrade); GRANT service_role (a new function invisible to the app
-- fails as a broken feature, worse than a permission error); and NEVER abort the DDL on its own
-- failure (a guard that turns a migration into an outage is the guard becoming the incident).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.revoke_public_on_new_secdef()
 RETURNS event_trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_ddl_commands() WHERE object_type = 'function' AND schema_name = 'public'
  LOOP
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid = obj.objid AND p.prosecdef
                   AND pg_get_userbyid(p.proowner) <> 'supabase_admin') THEN
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', obj.objid::regprocedure);
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', obj.objid::regprocedure);
      END IF;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'revoke_public_on_new_secdef: could not tighten %: %', obj.object_identity, SQLERRM;  -- swallow: never abort the DDL
    END;
  END LOOP;
END
$fn$;

DROP EVENT TRIGGER IF EXISTS trg_revoke_public_on_new_secdef;
CREATE EVENT TRIGGER trg_revoke_public_on_new_secdef ON ddl_command_end
  WHEN TAG IN ('CREATE FUNCTION','ALTER FUNCTION')
  EXECUTE FUNCTION public.revoke_public_on_new_secdef();

-- the trigger function is itself a public SECURITY DEFINER function created before the trigger
-- existed, so it took the PUBLIC leak; tighten it (it is fired by the event system as its owner,
-- needs no role grant) so the detection predicate stays at 0.
REVOKE EXECUTE ON FUNCTION public.revoke_public_on_new_secdef() FROM PUBLIC, anon, authenticated;
