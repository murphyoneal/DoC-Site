-- =============================================================================
-- handoff 47 pass 1: (0) runner skips retired predicates (retiring preserves knowledge
-- in the registry, never deletes); (B) rewrite the 2 now-resolved predicates to
-- served-path form + record they errored while already fixed; (C) bring the 3 real ones
-- to contract; step 3: add ownership + geometry served-path checks.
-- =============================================================================
CREATE OR REPLACE FUNCTION run_defect_detections()
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_run uuid := gen_random_uuid();
  v_at  timestamptz := now();
  r record; v_json jsonb; v_ok boolean; v_err text; v_rows bigint; v_ms int; t0 timestamptz;
BEGIN
  PERFORM set_config('statement_timeout','20000', true);
  FOR r IN SELECT defect_id, detection_sql FROM data_defect_registry WHERE status='active' ORDER BY defect_id LOOP
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

-- (B)
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT (get_parcel_brownfield_facts(52,'21519-000-00')->>'field_status') IN ('present','none_nearby') AS ok$det$,
  false_positive_notes = 'Served-path: brownfield resolves for a non-Volusia parcel (Marion). Was ERRORED while its defect was ALREADY fixed — the cost of a broken predicate is absence of information, not a false alarm.'
WHERE defect_id='brownfield-served-volusia-only';
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(get_parcel_restrictions(11,'02514-007-000')) e WHERE e->>'field'='gwca_restriction') AS ok$det$,
  false_positive_notes = 'Served-path: a known GWCA parcel (Alachua) surfaces gwca_restriction in get_parcel_restrictions. Was ERRORED while already fixed — absence of information, not a false alarm.'
WHERE defect_id='gwca-orphaned-from-served-payload';

-- (C)
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT NOT EXISTS (SELECT 1 FROM regexp_matches(pg_get_functiondef('public.get_pir_report(numeric,text)'::regprocedure),'\mvolusia_[a-z0-9_]+','g')) AS ok$det$,
  false_positive_notes = 'Full inventory of volusia_* tables read directly by get_pir_report (ok=false while any remain). Tracked subset with removal conditions is get-pir-report-inline-volusia-coalesce; the CAMA scalar reads + centroids are the recorded not-debt. One account of the inline-Volusia surface, cross-referenced.'
WHERE defect_id='single-county-table-served-as-universal';
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='fdep_clm' AND column_name ~* 'contaminant|substance|analyte|chemical') AS ok$det$
WHERE defect_id='fdep-clm-no-contaminant-field';
UPDATE data_defect_registry SET
  detection_sql = $det$SELECT COALESCE((SELECT source_url IS NOT NULL FROM table_inventory WHERE table_name='parcel_elevations' LIMIT 1), false) AS ok$det$
WHERE defect_id='DEF-024';

-- step 3: ownership + geometry served-path
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, status, attribution, disposition, false_positive_notes)
VALUES
 ('ownership-served-path','Ownership must resolve to a named owner on the served path (get_parcel_owner_facts).',
  CURRENT_DATE,'handoff 47 step 3','key_integrity','material',
  $det$SELECT (get_parcel_owner_facts(74,'371300000020')->>'field_status')='present' AS ok$det$,
  'active','ours','repair',
  'Served-path. Do NOT assert owner percentages sum to 100 — Volusia tenancy-by-entirety records PCTOWN=100 per owner by design (memory cama-ownership-model).'),
 ('geometry-resolution-served-path','Parcel geometry must resolve to a valid non-empty geometry on the served path (resolve_parcel_geometry), which de-dups the multiple parcels_staging rows per parcel_id.',
  CURRENT_DATE,'handoff 47 step 3','geometry','material',
  $det$SELECT COALESCE((SELECT ST_IsValid(geom) AND NOT ST_IsEmpty(geom) FROM resolve_parcel_geometry(74,'371300000020') LIMIT 1), false) AS ok$det$,
  'active','ours','repair','Served-path: resolve_parcel_geometry returns a valid non-empty geometry.')
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, false_positive_notes=EXCLUDED.false_positive_notes;
