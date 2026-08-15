-- =============================================================================
-- Ruling 227 Stage A — the four RED "expected-clean" predicates. Applied to production Supabase;
-- recorded here so the DB does not get ahead of the repo again (ruling 218).
--
-- 1. P0 access-control: the SECURITY DEFINER guard did not cover PROCEDURES. repair_invalid_served_layers
--    (a geometry-mutating maintenance PROCEDURE, prokind=p) kept its default PUBLIC EXECUTE and was
--    anon/authenticated-callable. The event trigger revoke_public_on_new_secdef() looped
--    pg_event_trigger_ddl_commands() WHERE object_type='function' — procedures were never processed, and
--    even widening the filter failed because that function does not surface CREATE PROCEDURE here.
--    FIX: the guard no longer depends on the DDL command info — it scans ALL public SECURITY DEFINER
--    routines on every ddl_command_end and revokes any anon/authenticated-executable one (functions +
--    procedures by construction, self-healing). Verified with a planted negative control (a fresh secdef
--    procedure AND function are both auto-revoked).
-- =============================================================================

-- close the live exposure
DO $$ DECLARE r regprocedure;
BEGIN
  SELECT p.oid INTO r FROM pg_proc p WHERE p.proname='repair_invalid_served_layers' AND p.pronamespace='public'::regnamespace;
  IF r IS NOT NULL THEN
    EXECUTE format('REVOKE ALL ON ROUTINE %s FROM PUBLIC, anon, authenticated', r);
    EXECUTE format('GRANT EXECUTE ON ROUTINE %s TO service_role', r);
  END IF;
END $$;

-- rebuild the guard to cover every SECURITY DEFINER routine, not just object_type='function'
CREATE OR REPLACE FUNCTION public.revoke_public_on_new_secdef() RETURNS event_trigger
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.prosecdef AND pg_get_userbyid(p.proowner)<>'supabase_admin'
      AND (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE'))
  LOOP
    BEGIN
      EXECUTE format('REVOKE EXECUTE ON ROUTINE %s FROM PUBLIC, anon, authenticated', r.oid::regprocedure);
      EXECUTE format('GRANT EXECUTE ON ROUTINE %s TO service_role', r.oid::regprocedure);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'revoke_public_on_new_secdef: could not tighten %: %', r.oid::regprocedure, SQLERRM;
    END;
  END LOOP;
END $function$;

-- 2. DEF-009: evaluate only RECURRING sources; a one-time manual load has no cadence path. Boolean contract.
UPDATE data_defect_registry SET detection_sql =
  $q$SELECT NOT EXISTS(SELECT 1 FROM data_source_registry WHERE active AND pull_mode IS DISTINCT FROM 'manual' AND last_successful_pull_date < now()-interval '35 days') AS ok$q$
WHERE defect_id='DEF-009';

-- 3. disposition taxonomy: add 'blocked' (blocked-on-a-dependency is distinct from repair/undecided)
DO $$ DECLARE cn text;
BEGIN
  SELECT con.conname INTO cn FROM pg_constraint con JOIN pg_class cl ON cl.oid=con.conrelid
   WHERE cl.relname='data_defect_registry' AND con.contype='c' AND pg_get_constraintdef(con.oid) ILIKE '%disposition%';
  EXECUTE format('ALTER TABLE data_defect_registry DROP CONSTRAINT %I', cn);
  EXECUTE 'ALTER TABLE data_defect_registry ADD CONSTRAINT '||cn||
    ' CHECK (disposition = ANY (ARRAY[''repair'',''transform_on_ingest'',''disclose'',''substitute'',''undecided'',''blocked'']))';
END $$;

-- miamidade-zoning ruled: blocked on item 139 (no admin_level-3 city rung to wire the municipal layer to);
-- the served path already renders not_established honestly, so this is a coverage gap, not a false answer.
UPDATE data_defect_registry SET attribution='ours', disposition='blocked', expected_state='defect', expires_at='2027-02-13'
WHERE defect_id='miamidade-zoning-wired-to-unincorporated-only';

-- (The new defect class secdef-guard-missed-procedures was registered via the registry directly; it is a
--  documentation entry for the guard-failure mechanism, expected_state clean, detection over secdef procedures.)
