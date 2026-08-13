-- =============================================================================
-- WO 94: the ArcGIS metadata cadence sweep. Runs IN THE DATABASE on pg_net (no laptop, no Action,
-- no Edge Function). Collect ONLY — derive nothing; cadence_basis stays not_established until >=3
-- observed changes exist. Two metadata calls per source, near-zero transfer:
--   {url}?f=json           -> editingInfo.lastEditDate -> publisher_as_of
--   {url}/query?returnCountOnly=true -> count -> source_row_count
-- Invariants (all already paid for): APPEND ONLY; ABORT-ON-ZERO (nothing back => status=error,
-- NEVER changed=false); an exact-multiple-of-page-size count is a truncation SUSPECT not a count;
-- per-request timeout; run summary logged the same night. Async: dispatch queues, collect reads
-- net._http_response a couple minutes later (pg_cron schedules the pair; NOT scheduled here — the
-- first run is reported before a scheduler is built on top of it).
-- =============================================================================

CREATE TABLE IF NOT EXISTS cadence_sweep_run (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  started_at   timestamptz NOT NULL DEFAULT now(),
  collected_at timestamptz,
  dispatched   int, collected int, errors int, changed int, truncation_suspects int,
  summary      jsonb
);
CREATE TABLE IF NOT EXISTS cadence_sweep_request (
  sweep_run_id bigint NOT NULL REFERENCES cadence_sweep_run(id),
  request_id   bigint NOT NULL,
  source_id    bigint NOT NULL REFERENCES data_source_registry(id),
  kind         text   NOT NULL CHECK (kind IN ('meta','count')),
  url          text
);
CREATE INDEX IF NOT EXISTS cadence_sweep_request_run ON cadence_sweep_request (sweep_run_id, request_id);

-- DISPATCH: queue metadata+count for every active ArcGIS layer source. Fast (just enqueues).
CREATE OR REPLACE FUNCTION public.cadence_sweep_dispatch(p_limit int DEFAULT 1000)
 RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','net','pg_temp'
AS $fn$
DECLARE v_run bigint; r record; v_base text; v_meta bigint; v_count bigint; n int := 0;
BEGIN
  INSERT INTO cadence_sweep_run (started_at) VALUES (now()) RETURNING id INTO v_run;
  FOR r IN SELECT id, source_url FROM data_source_registry
           WHERE active AND (source_url ILIKE '%/FeatureServer/%' OR source_url ILIKE '%/MapServer/%')
           ORDER BY id LIMIT p_limit
  LOOP
    v_base := rtrim(split_part(r.source_url, '?', 1), '/');
    v_meta  := net.http_get(v_base || '?f=json', timeout_milliseconds := 8000);
    v_count := net.http_get(v_base || '/query?where=1%3D1&returnCountOnly=true&f=json', timeout_milliseconds := 8000);
    INSERT INTO cadence_sweep_request (sweep_run_id, request_id, source_id, kind, url) VALUES
      (v_run, v_meta,  r.id, 'meta',  v_base || '?f=json'),
      (v_run, v_count, r.id, 'count', v_base || '/query?returnCountOnly');
    n := n + 1;
  END LOOP;
  UPDATE cadence_sweep_run SET dispatched = n WHERE id = v_run;
  RETURN v_run;
END $fn$;

-- COLLECT: read responses, write ONE append-only source_observation row per source. Never updates.
CREATE OR REPLACE FUNCTION public.cadence_sweep_collect(p_run bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','net','pg_temp'
AS $fn$
DECLARE r record; v_collected int:=0; v_err int:=0; v_changed int:=0; v_trunc int:=0;
        v_last_edit bigint; v_count bigint; v_asof timestamptz; v_hash text; v_prev text;
        v_status text; v_errtext text; v_note text; v_changed_flag boolean; v_page int;
BEGIN
  FOR r IN
    SELECT reg.id AS source_id, reg.page_size,
           mr.status_code AS meta_status, mr.content AS meta_content, mr.error_msg AS meta_err,
           cr.status_code AS count_status, cr.content AS count_content, cr.error_msg AS count_err
    FROM (SELECT DISTINCT source_id FROM cadence_sweep_request WHERE sweep_run_id = p_run) s
    JOIN data_source_registry reg ON reg.id = s.source_id
    LEFT JOIN cadence_sweep_request qm ON qm.sweep_run_id=p_run AND qm.source_id=s.source_id AND qm.kind='meta'
    LEFT JOIN cadence_sweep_request qc ON qc.sweep_run_id=p_run AND qc.source_id=s.source_id AND qc.kind='count'
    LEFT JOIN net._http_response mr ON mr.id = qm.request_id
    LEFT JOIN net._http_response cr ON cr.id = qc.request_id
  LOOP
    v_status:='ok'; v_errtext:=NULL; v_note:=NULL; v_asof:=NULL; v_count:=NULL; v_changed_flag:=NULL;
    -- ABORT-ON-ZERO: no response, non-200, or an ArcGIS {"error":...} body is an ERROR row, never changed=false
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
    -- publisher_as_of from meta (best-effort; its absence does not error the row — the count is the abort gate)
    IF r.meta_status = 200 AND r.meta_content IS NOT NULL AND r.meta_content ~ '^\s*\{' THEN
      v_last_edit := (r.meta_content::jsonb #>> '{editingInfo,lastEditDate}')::bigint;
      IF v_last_edit IS NOT NULL THEN v_asof := to_timestamp(v_last_edit / 1000.0); END IF;
    END IF;
    v_hash := md5(coalesce(v_last_edit::text,'')||'|'||coalesce(v_count::text,''));
    -- changed vs the PREVIOUS observation for this source (first obs -> null, no prior)
    SELECT content_hash INTO v_prev FROM source_observation
      WHERE source_id = r.source_id AND status='ok' ORDER BY observed_at DESC LIMIT 1;
    IF v_status='ok' THEN
      v_changed_flag := CASE WHEN v_prev IS NULL THEN NULL WHEN v_prev <> v_hash THEN true ELSE false END;
      IF v_changed_flag THEN v_changed := v_changed + 1; END IF;
    END IF;
    INSERT INTO source_observation (source_id, method, publisher_as_of, content_hash, source_row_count, our_row_count, changed, status, error_text, note)
    VALUES (r.source_id, 'metadata_poll', v_asof, CASE WHEN v_status='ok' THEN v_hash END, v_count,
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
