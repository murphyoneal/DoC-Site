-- =============================================================================
-- Defect detection suite runner. data_defect_registry holds 37 detection_sql
-- predicates that had never been executed as a set. This makes the catalogue a
-- monitor.
--
-- Fails loud THREE ways (an errored detection is never counted clean):
--   ok = true    clean (predicate ran, reports no defect)
--   ok = false   defect present
--   ok = NULL + error_text set  -> ERRORED, and error_text says why:
--       EXEC ERROR:      the query itself failed (syntax, missing table, timeout,
--                        or an un-substituted {placeholder} template)
--       BLIND SPOT:      examined=0 — the predicate looked at nothing (per the
--                        registry's examined/hit convention; zero examined is a
--                        broken query, not a pass)
--       NON-CONFORMING:  ran but declared no pass condition (no `ok`, no
--                        examined+hit) — cannot be classified, so not green
--
-- Result contracts recognised: `... AS ok` (boolean, true=clean) and
-- `count(*) examined, count(*) filter(...) hit` (hit=0 clean, examined=0 blind).
-- Anything else is NON-CONFORMING on purpose — we do not guess a polarity.
--
-- Per-predicate: own exception handler (one broken predicate can't abort the run)
-- and a 20s statement_timeout (a slow one can't hang the suite).
--
-- geo_id (nullable, FK geo_reference) is the spine for per-geography rollup; the
-- registry has no geographic key yet so it is NULL today, but present from day one.
-- =============================================================================
CREATE TABLE IF NOT EXISTS defect_detection_runs (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id      uuid NOT NULL,
  run_at      timestamptz NOT NULL,
  defect_id   text NOT NULL REFERENCES data_defect_registry(defect_id),
  ok          boolean,                       -- NULL == errored (see error_text)
  error_text  text,
  duration_ms integer,
  row_count   bigint,                        -- hit count where the predicate reports one
  geo_id      text REFERENCES geo_reference(geo_id)
);
CREATE INDEX IF NOT EXISTS defect_detection_runs_run_idx    ON defect_detection_runs (run_id);
CREATE INDEX IF NOT EXISTS defect_detection_runs_defect_idx ON defect_detection_runs (defect_id);

CREATE OR REPLACE FUNCTION run_defect_detections()
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_run uuid := gen_random_uuid();
  v_at  timestamptz := now();
  r record; v_json jsonb; v_ok boolean; v_err text; v_rows bigint; v_ms int; t0 timestamptz;
BEGIN
  -- Per-predicate cap, transaction-local so it does not re-arm the outer call's timer.
  PERFORM set_config('statement_timeout','20000', true);
  FOR r IN SELECT defect_id, detection_sql FROM data_defect_registry ORDER BY defect_id LOOP
    v_ok := NULL; v_err := NULL; v_rows := NULL;
    t0 := clock_timestamp();
    BEGIN
      EXECUTE 'SELECT to_jsonb(t) FROM (' || E'\n' || rtrim(btrim(r.detection_sql), ';') || E'\n) t LIMIT 1'
        INTO v_json;
      IF v_json IS NULL THEN
        v_err := 'NON-CONFORMING: detection returned no rows';
      ELSIF v_json ? 'ok' THEN
        IF jsonb_typeof(v_json->'ok') = 'boolean' THEN
          v_ok := (v_json->>'ok')::boolean;
          IF (v_json ? 'hit') AND jsonb_typeof(v_json->'hit')='number' THEN v_rows := (v_json->>'hit')::numeric::bigint; END IF;
        ELSE
          v_err := 'NON-CONFORMING: ok is not boolean ('||coalesce(jsonb_typeof(v_json->'ok'),'absent')||')';
        END IF;
      ELSIF (v_json ? 'examined') AND (v_json ? 'hit') THEN
        IF (v_json->>'examined') IS NULL OR (v_json->>'examined')::numeric = 0 THEN
          v_err := 'BLIND SPOT: examined=0 (predicate evaluated nothing)';
        ELSE
          v_rows := (v_json->>'hit')::numeric::bigint;
          v_ok := (v_rows = 0);
        END IF;
      ELSE
        v_err := 'NON-CONFORMING: no ok / examined+hit contract; keys=['
              || coalesce((SELECT string_agg(k, ',') FROM jsonb_object_keys(v_json) k),'') || ']';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      v_err := 'EXEC ERROR: ' || v_err; v_ok := NULL; v_rows := NULL;
    END;
    v_ms := round(extract(epoch FROM clock_timestamp()-t0)*1000);
    INSERT INTO defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id)
    VALUES (v_run, v_at, r.defect_id, v_ok, v_err, v_ms, v_rows, NULL);
  END LOOP;
  RETURN v_run;
END $fn$;
GRANT EXECUTE ON FUNCTION run_defect_detections() TO service_role;
