-- =============================================================================
-- P0 (ruling 90): the paywall was bypassable. 36 of our 97 SECURITY DEFINER functions in
-- schema public were EXECUTE-able by PUBLIC (hence by the anon key that ships in the browser
-- bundle). That exposed the report INGREDIENTS (get_parcel_values / identity_frame / wetland /
-- sinkhole / brownfield / econzone / repose_window / subdivision / boat_ramps / aquifer),
-- bulk ENUMERATION (search_properties / find_parcels / resolve_parcel_query / search_contractors /
-- match_contractor_license / agent_claim_preview), and — worst — volatile AUTHZ/INTEGRITY writes
-- (agent_claim_confirm, agent_verify_license, rebaseline_golden_parcels, check_golden_parcels,
-- roz_log_*). gating the composite (get_pir_report, correctly not anon-executable) did NOT gate
-- the parts.
--
-- FIX (default-deny, grant by exception). Named caller: the APPLICATION SERVER, which calls every
-- RPC via service_role (getSupabaseAdmin / SUPABASE_SECRET_KEY, server-side only). Verified from
-- the codebase that NO browser/anon path calls our RPCs directly — the browser client
-- (getSupabaseBrowser, anon key) is used for auth only (LoginForm/PasswordChange/AppShell), never
-- .rpc(). Therefore anon and authenticated get NOTHING; service_role gets every function.
-- The 3 PostGIS ST_EstimatedExtent SECURITY DEFINER functions are extension-owned — left untouched.
--
-- Deferred (ruling 90 §4, report-not-redesign): agent_claim_confirm / agent_verify_license take a
-- user_id PARAMETER instead of deriving it from the session; the revoke closes the anon path, the
-- param-trust design is reported separately.
-- =============================================================================

DO $p0$
DECLARE r record; n int := 0;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace ns ON ns.oid = p.pronamespace
    LEFT JOIN pg_depend d ON d.objid = p.oid AND d.deptype = 'e'   -- extension membership
    WHERE ns.nspname = 'public' AND p.prosecdef AND d.objid IS NULL  -- OURS only (excludes PostGIS)
  LOOP
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC', r.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM anon', r.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM authenticated', r.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'P0 grant-tightening applied to % SECURITY DEFINER functions', n;
END
$p0$;
