-- =============================================================================
-- Ruling 155 #1 — four detections were ERRORING on our own contract (bare count, no boolean ok),
-- and it drifted four times unnoticed because the contract lived only in CLAUDE.md. Fix the four,
-- then ENFORCE the contract at registration so a non-conforming detection_sql cannot be stored.
--
-- Contract: detection_sql returns exactly ONE row with a boolean column `ok` (true = clean).
-- =============================================================================

-- (1) The four, converted to one-row-boolean-ok --------------------------------
UPDATE data_defect_registry SET detection_sql =
  $q$SELECT NOT EXISTS(SELECT 1 FROM data_source_registry WHERE derived_from='fgs_subsidence_incidents_raw' AND notes NOT ILIKE '%VOLUNTARY-REPORT%') AS ok$q$
WHERE defect_id='fgs-subsidence-voluntary-register';

-- expected_state=defect (the 94 served-unregistered). NOT IN -> NOT EXISTS to dodge the NULL-in-NOT-IN trap.
UPDATE data_defect_registry SET detection_sql =
  $q$SELECT NOT EXISTS(SELECT 1 FROM layer_resolution lr WHERE lr.table_name IS NOT NULL AND NOT EXISTS(SELECT 1 FROM data_source_registry r WHERE r.table_name=lr.table_name)) AS ok$q$
WHERE defect_id='registry-derivation-unexpressed';

-- REFRAMED: the original bare-count ("public tables without RLS except spatial_ref_sys") was meaningless
-- on a service_role app. It now encodes the real knowledge: spatial_ref_sys must STAY RLS-disabled --
-- PostGIS reads it during ST_Transform and a policy there breaks transforms as WRONG GEOMETRY. Fires if
-- anyone enables RLS on it. (The Supabase advisor's RLS alert on spatial_ref_sys is a false positive.)
UPDATE data_defect_registry SET detection_sql =
  $q$SELECT NOT c.relrowsecurity AS ok FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relname='spatial_ref_sys'$q$
WHERE defect_id='supabase-alert-spatial-ref-sys-false-positive';

UPDATE data_defect_registry SET detection_sql =
  $q$SELECT NOT EXISTS(SELECT 1 FROM data_source_registry d JOIN pg_class c ON c.relname=d.table_name JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public' WHERE d.active AND c.relkind='r' AND coalesce(obj_description(c.oid),'') NOT LIKE 'PROVENANCE%') AS ok$q$
WHERE defect_id='table-provenance-comment-missing';

-- (2) Enforcement: a CHECK cannot execute SQL, so a BEFORE-write trigger runs the detection and
--     validates the shape. Missing/non-boolean `ok` raises; row_count <> 1 raises. A bare count, text,
--     zero rows, or multiple rows can no longer be registered. Verified with a planted negative control
--     (bad count REJECTED, multi-row REJECTED, conforming ACCEPTED).
CREATE OR REPLACE FUNCTION public._enforce_detection_contract() RETURNS trigger
LANGUAGE plpgsql AS $fn$
DECLARE v_ok boolean; v_n int;
BEGIN
  IF NEW.detection_sql IS NULL OR btrim(NEW.detection_sql)='' THEN RETURN NEW; END IF; -- measurement-only rows
  BEGIN
    EXECUTE format('WITH _p AS (%s) SELECT count(*)::int, bool_and(ok) FROM _p', NEW.detection_sql)
      INTO v_n, v_ok;
  EXCEPTION WHEN others THEN
    RAISE EXCEPTION 'detection_sql for "%" violates the detection contract (needs exactly one boolean column named ok, true=clean): %',
      NEW.defect_id, SQLERRM;
  END;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'detection_sql for "%" must return exactly ONE row (returned %). Contract: one row, boolean ok, true=clean.',
      NEW.defect_id, v_n;
  END IF;
  RETURN NEW;
END $fn$;

DROP TRIGGER IF EXISTS trg_enforce_detection_contract ON data_defect_registry;
CREATE TRIGGER trg_enforce_detection_contract
  BEFORE INSERT OR UPDATE OF detection_sql ON data_defect_registry
  FOR EACH ROW EXECUTE FUNCTION public._enforce_detection_contract();

-- After: run_defect_detections() -> 31 clean, 19 defect, 0 ERRORED (was 27/18/4).
