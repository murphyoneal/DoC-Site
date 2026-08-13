-- =============================================================================
-- Error taxonomy for run_defect_detections (ruling 91 §3 / ruling 92). "3 errored" was
-- conflating two different things: a predicate that CANNOT RUN YET (its target table/column
-- does not exist) and a predicate that is GENUINELY BROKEN. Merge them and people learn to
-- ignore "errored", and a real failure — e.g. a bad revoke announcing itself as 42501 —
-- hides in the noise. Same defect class as merging a null and a false.
--
--   42P01 undefined_table / 42703 undefined_column -> NOT_APPLICABLE (registered ahead of data)
--   42501 insufficient_privilege                   -> ERROR, loud (how a bad revoke announces itself)
--   anything else (timeout, syntax, …)             -> ERROR
--   contract violations (no ok / examined=0 / …)   -> ERROR (genuine non-conformance)
-- Board now reads "N errored, M not-applicable" and both numbers mean something.
-- =============================================================================

ALTER TABLE defect_detection_runs ADD COLUMN IF NOT EXISTS error_class text;  -- null=ran to verdict; else not_applicable|errored

CREATE OR REPLACE FUNCTION public.run_defect_detections()
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_run uuid := gen_random_uuid();
  v_at  timestamptz := now();
  r record; v_json jsonb; v_ok boolean; v_err text; v_rows bigint; v_ms int; t0 timestamptz;
  v_state text; v_class text;
BEGIN
  PERFORM set_config('statement_timeout','20000', true);
  FOR r IN SELECT defect_id, detection_sql FROM data_defect_registry WHERE status='active' ORDER BY defect_id LOOP
    v_ok := NULL; v_err := NULL; v_rows := NULL; v_class := NULL;
    t0 := clock_timestamp();
    BEGIN
      EXECUTE 'SELECT to_jsonb(t) FROM (' || E'\n' || rtrim(btrim(r.detection_sql), ';') || E'\n) t LIMIT 1'
        INTO v_json;
      IF v_json IS NULL THEN
        v_err := 'NON-CONFORMING: detection returned no rows'; v_class := 'errored';
      ELSIF v_json ? 'ok' THEN
        IF jsonb_typeof(v_json->'ok') = 'boolean' THEN
          v_ok := (v_json->>'ok')::boolean;
          IF (v_json ? 'hit') AND jsonb_typeof(v_json->'hit')='number' THEN v_rows := (v_json->>'hit')::numeric::bigint; END IF;
        ELSE
          v_err := 'NON-CONFORMING: ok is not boolean ('||coalesce(jsonb_typeof(v_json->'ok'),'absent')||')'; v_class := 'errored';
        END IF;
      ELSIF (v_json ? 'examined') AND (v_json ? 'hit') THEN
        IF (v_json->>'examined') IS NULL OR (v_json->>'examined')::numeric = 0 THEN
          v_err := 'BLIND SPOT: examined=0 (predicate evaluated nothing)'; v_class := 'errored';
        ELSE
          v_rows := (v_json->>'hit')::numeric::bigint;
          v_ok := (v_rows = 0);
        END IF;
      ELSE
        v_err := 'NON-CONFORMING: no ok / examined+hit contract; keys=['
              || coalesce((SELECT string_agg(k, ',') FROM jsonb_object_keys(v_json) k),'') || ']'; v_class := 'errored';
      END IF;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT, v_state = RETURNED_SQLSTATE;
      v_ok := NULL; v_rows := NULL;
      IF v_state IN ('42P01','42703') THEN
        v_class := 'not_applicable';
        v_err := 'NOT_APPLICABLE ('||v_state||'): '||v_err||' — predicate registered ahead of its data; set status=pending until the target exists.';
      ELSIF v_state = '42501' THEN
        v_class := 'errored';
        v_err := 'PERMISSION DENIED ('||v_state||'): '||v_err||' — a grant/revoke broke a legitimate path.';
      ELSE
        v_class := 'errored';
        v_err := 'EXEC ERROR ('||v_state||'): '||v_err;
      END IF;
    END;
    v_ms := round(extract(epoch FROM clock_timestamp()-t0)*1000);
    INSERT INTO defect_detection_runs (run_id, run_at, defect_id, ok, error_text, duration_ms, row_count, geo_id, error_class)
    VALUES (v_run, v_at, r.defect_id, v_ok, v_err, v_ms, v_rows, NULL, v_class);
  END LOOP;
  RETURN v_run;
END $function$;

-- true-state: errored EXCLUDES not_applicable; not_applicable is its own count
CREATE OR REPLACE VIEW detection_true_state AS
WITH cur AS (SELECT * FROM defect_detection_runs WHERE run_id=(SELECT run_id FROM defect_detection_runs ORDER BY run_at DESC LIMIT 1))
SELECT count(*) AS active,
       count(*) FILTER (WHERE cur.ok) AS clean,
       count(*) FILTER (WHERE cur.ok IS FALSE) AS defect,
       count(*) FILTER (WHERE cur.ok IS NULL AND cur.error_class IS DISTINCT FROM 'not_applicable') AS errored,
       count(*) FILTER (WHERE cur.error_class = 'not_applicable') AS not_applicable
FROM cur JOIN data_defect_registry reg ON reg.defect_id=cur.defect_id WHERE reg.status='active';

-- operational dashboard: not_applicable is 'n/a' (a predicate awaiting its data), never red
CREATE OR REPLACE VIEW detection_dashboard AS
WITH runs AS (SELECT run_id, run_at FROM (SELECT DISTINCT run_id, run_at FROM defect_detection_runs) r ORDER BY run_at DESC LIMIT 2),
     cur  AS (SELECT * FROM defect_detection_runs WHERE run_id=(SELECT run_id FROM runs ORDER BY run_at DESC LIMIT 1)),
     prev AS (SELECT * FROM defect_detection_runs WHERE run_id=(SELECT run_id FROM runs ORDER BY run_at DESC OFFSET 1 LIMIT 1)),
     j AS (
       SELECT reg.defect_id, reg.severity, cur.ok, cur.error_class, reg.expected_state, reg.expires_at, reg.magnitude_semantics,
              cur.row_count AS cur_rows, prev.row_count AS prev_rows,
              CASE WHEN reg.expected_state='defect' AND reg.expires_at IS NOT NULL AND reg.expires_at < now()
                   THEN 'clean' ELSE reg.expected_state END AS effective_expected,
              (reg.magnitude_semantics='magnitude' AND cur.row_count IS NOT NULL AND prev.row_count IS NOT NULL
               AND abs(cur.row_count - prev.row_count) > greatest(10, 0.10*prev.row_count)) AS magnitude_moved
       FROM data_defect_registry reg
       JOIN cur ON cur.defect_id=reg.defect_id
       LEFT JOIN prev ON prev.defect_id=reg.defect_id
       WHERE reg.status='active')
SELECT defect_id, severity, ok, expected_state, effective_expected, cur_rows, prev_rows, magnitude_moved,
       (expected_state='defect' AND expires_at < now()) AS expectation_expired,
       CASE
         WHEN error_class='not_applicable' THEN 'n/a'
         WHEN ok IS NULL THEN 'red'
         WHEN ok <> (effective_expected='clean') THEN 'red'
         WHEN magnitude_moved THEN 'red'
         WHEN effective_expected='defect' THEN 'amber'
         ELSE 'green' END AS display,
       error_class
FROM j;
