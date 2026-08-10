-- =============================================================================
-- WO 94 hardening (ruling 95), before any scheduler is built on the sweep.
-- 1. observed_count_only basis: count is a WEAK detector (a layer can change without the count
--    moving), so a cadence derived from count alone is a LOWER BOUND, never a measurement, and it
--    must not wear the same word as a real observation. BUT — all 119 count-only sources expose an
--    ETag, which DOES move on any edit, so we capture it and prefer it over the count. count_only
--    becomes the honest basis only where neither lastEditDate nor ETag exists (currently none).
-- 2. page_size=0 on one source caused the divide-by-zero — a registry DATA defect, fixed to NULL
--    (0 pages-per-request is a lie; unknown is honest) and guarded by a predicate.
-- 3. A source failing 3 consecutive sweeps is a DEAD SOURCE finding, not a flaky one.
-- =============================================================================

-- 1a. basis vocabulary
ALTER TABLE data_source_registry DROP CONSTRAINT IF EXISTS data_source_registry_cadence_basis_check;
ALTER TABLE data_source_registry ADD CONSTRAINT data_source_registry_cadence_basis_check
  CHECK (cadence_basis IN ('statute','observed','observed_count_only','publisher_stated','not_established'));

-- 1b. capture ETag; fold it into the change hash so the 119 count-only sources get a real signal
ALTER TABLE source_observation ADD COLUMN IF NOT EXISTS etag text;

CREATE OR REPLACE FUNCTION public.cadence_sweep_collect(p_run bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','net','pg_temp'
AS $fn$
DECLARE r record; v_collected int:=0; v_err int:=0; v_changed int:=0; v_trunc int:=0;
        v_last_edit bigint; v_count bigint; v_asof timestamptz; v_hash text; v_prev text; v_etag text;
        v_status text; v_errtext text; v_note text; v_changed_flag boolean; v_page int;
BEGIN
  FOR r IN
    SELECT reg.id AS source_id, reg.page_size,
           mr.status_code AS meta_status, mr.content AS meta_content, mr.headers AS meta_headers, mr.error_msg AS meta_err,
           cr.status_code AS count_status, cr.content AS count_content, cr.error_msg AS count_err
    FROM (SELECT DISTINCT source_id FROM cadence_sweep_request WHERE sweep_run_id = p_run) s
    JOIN data_source_registry reg ON reg.id = s.source_id
    LEFT JOIN cadence_sweep_request qm ON qm.sweep_run_id=p_run AND qm.source_id=s.source_id AND qm.kind='meta'
    LEFT JOIN cadence_sweep_request qc ON qc.sweep_run_id=p_run AND qc.source_id=s.source_id AND qc.kind='count'
    LEFT JOIN net._http_response mr ON mr.id = qm.request_id
    LEFT JOIN net._http_response cr ON cr.id = qc.request_id
  LOOP
    v_status:='ok'; v_errtext:=NULL; v_note:=NULL; v_asof:=NULL; v_count:=NULL; v_changed_flag:=NULL; v_last_edit:=NULL; v_etag:=NULL;
    IF r.count_status IS NULL OR r.count_status <> 200 OR r.count_content IS NULL
       OR (r.count_content ~ '^\s*\{' AND (r.count_content::jsonb ? 'error') AND NOT (r.count_content::jsonb ? 'count')) THEN
      v_status:='error'; v_errtext:='count: '||coalesce(r.count_err, 'http '||coalesce(r.count_status::text,'no response')||' '||left(coalesce(r.count_content,''),120));
    ELSE
      v_count := (r.count_content::jsonb ->> 'count')::bigint;
      IF v_count IS NULL THEN v_status:='error'; v_errtext:='count: no count key in '||left(r.count_content,120);
      ELSE
        v_page := r.page_size;
        IF v_page IS NOT NULL AND v_page > 0 AND v_count > 0 AND v_count % v_page = 0 THEN
          v_trunc := v_trunc + 1; v_note := 'TRUNCATION SUSPECT: count '||v_count||' is an exact multiple of page_size '||v_page||' — recorded, not trusted as a count';
        END IF;
      END IF;
    END IF;
    IF r.meta_status = 200 AND r.meta_content IS NOT NULL AND r.meta_content ~ '^\s*\{' THEN
      v_last_edit := (r.meta_content::jsonb #>> '{editingInfo,lastEditDate}')::bigint;
      IF v_last_edit IS NOT NULL THEN v_asof := to_timestamp(v_last_edit / 1000.0); END IF;
    END IF;
    v_etag := r.meta_headers ->> 'etag';   -- moves on any edit; a stronger signal than count
    v_hash := md5(coalesce(v_last_edit::text,'')||'|'||coalesce(v_count::text,'')||'|'||coalesce(v_etag,''));
    SELECT content_hash INTO v_prev FROM source_observation
      WHERE source_id = r.source_id AND status='ok' ORDER BY observed_at DESC LIMIT 1;
    IF v_status='ok' THEN
      v_changed_flag := CASE WHEN v_prev IS NULL THEN NULL WHEN v_prev <> v_hash THEN true ELSE false END;
      IF v_changed_flag THEN v_changed := v_changed + 1; END IF;
    END IF;
    INSERT INTO source_observation (source_id, method, publisher_as_of, content_hash, etag, source_row_count, our_row_count, changed, status, error_text, note)
    VALUES (r.source_id, 'metadata_poll', v_asof, CASE WHEN v_status='ok' THEN v_hash END, v_etag, v_count,
            (SELECT last_count FROM data_source_registry WHERE id=r.source_id), v_changed_flag, v_status, v_errtext, v_note);
    v_collected := v_collected + 1;
    IF v_status='error' THEN v_err := v_err + 1; END IF;
  END LOOP;
  UPDATE cadence_sweep_run
     SET collected_at=now(), collected=v_collected, errors=v_err, changed=v_changed, truncation_suspects=v_trunc,
         summary=jsonb_build_object('collected',v_collected,'errors',v_err,'changed',v_changed,'truncation_suspects',v_trunc)
   WHERE id=p_run;
  RETURN (SELECT summary FROM cadence_sweep_run WHERE id=p_run);
END $fn$;

-- 2. fix the one page_size=0 source (0 is a lie; NULL = unknown) and guard it
UPDATE data_source_registry SET page_size=NULL WHERE active AND page_size=0;

INSERT INTO data_defect_registry (defect_id, name, class, severity, detection_sql, status, disposition, attribution, expected_state, magnitude_semantics, false_positive_notes) VALUES
 ('registry-page-size-zero','data_source_registry.page_size is 0 (a lie, not a page size)','key_integrity','material',
  $d$SELECT (NOT EXISTS (SELECT 1 FROM data_source_registry WHERE active AND page_size = 0)) AS ok$d$,
  'active','repair','ours','clean','binary','Ruling 95: page_size=0 caused a divide-by-zero in the cadence sweep. 0 pages-per-request is meaningless; NULL (unknown) is honest. Guard so the bad value cannot survive.'),
 ('cadence-dead-source','Source has failed 3 consecutive cadence sweeps (dead, not flaky)','completeness','material',
  $d$SELECT (NOT EXISTS (
     SELECT source_id FROM (
       SELECT source_id, status, row_number() OVER (PARTITION BY source_id ORDER BY observed_at DESC) rn
       FROM source_observation
     ) t WHERE rn <= 3 GROUP BY source_id HAVING count(*) = 3 AND count(*) FILTER (WHERE status='error') = 3
   )) AS ok$d$,
  'active','repair','ours','clean','binary','Ruling 95 §3a: a source whose 3 most-recent sweep observations are all errors is a DEAD SOURCE finding (retire/replace the endpoint), not a transient timeout to retry forever.')
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, expected_state='clean', status='active';
