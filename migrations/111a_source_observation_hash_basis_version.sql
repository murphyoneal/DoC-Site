-- =============================================================================
-- Ruling 97: version the content-hash basis. Adding ETag to the hash in 109a reset the baseline
-- once and banked 242 artifact "changed" rows. Left unfixed, derivation (gated on >=3 observed
-- changes) would count an artifact toward the threshold and derive a FASTER-than-real cadence on
-- the 'observed' basis — the one basis meant to be trustworthy. Deleting/updating-in-place would
-- break append-only. Instead: every observation records WHICH hash definition produced it, and
-- derivation only ever compares observations within the same version. A version boundary is not a
-- change, it is an absence of comparison. Generalises: any future change to the hash (Last-Modified,
-- a new field, a normalisation) bumps the version instead of silently corrupting the series.
--   v1 = md5(lastEditDate | count)              (runs 1-2, pre-ETag)
--   v2 = md5(lastEditDate | count | etag)        (run 3 onward)
-- =============================================================================
ALTER TABLE source_observation ADD COLUMN IF NOT EXISTS hash_basis_version int NOT NULL DEFAULT 2;
UPDATE source_observation
   SET hash_basis_version = CASE WHEN observed_at >= (SELECT collected_at FROM cadence_sweep_run WHERE id=3) THEN 2 ELSE 1 END
 WHERE hash_basis_version IS DISTINCT FROM (CASE WHEN observed_at >= (SELECT collected_at FROM cadence_sweep_run WHERE id=3) THEN 2 ELSE 1 END);

-- collect stamps the current basis version and computes `changed` only against the previous
-- observation OF THE SAME VERSION. Bump v_basis (and add the term to v_hash) together, forever.
CREATE OR REPLACE FUNCTION public.cadence_sweep_collect(p_run bigint)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','net','pg_temp'
AS $fn$
DECLARE r record; v_collected int:=0; v_err int:=0; v_changed int:=0; v_trunc int:=0;
        v_last_edit bigint; v_count bigint; v_asof timestamptz; v_hash text; v_prev text; v_etag text;
        v_status text; v_errtext text; v_note text; v_changed_flag boolean; v_page int;
        v_basis int := 2;   -- md5(lastEditDate | count | etag)
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
    v_etag := r.meta_headers ->> 'etag';
    v_hash := md5(coalesce(v_last_edit::text,'')||'|'||coalesce(v_count::text,'')||'|'||coalesce(v_etag,''));  -- basis v2
    SELECT content_hash INTO v_prev FROM source_observation
      WHERE source_id = r.source_id AND status='ok' AND hash_basis_version = v_basis
      ORDER BY observed_at DESC LIMIT 1;
    IF v_status='ok' THEN
      v_changed_flag := CASE WHEN v_prev IS NULL THEN NULL WHEN v_prev <> v_hash THEN true ELSE false END;  -- null = no same-version prior
      IF v_changed_flag THEN v_changed := v_changed + 1; END IF;
    END IF;
    INSERT INTO source_observation (source_id, method, publisher_as_of, content_hash, etag, hash_basis_version, source_row_count, our_row_count, changed, status, error_text, note)
    VALUES (r.source_id, 'metadata_poll', v_asof, CASE WHEN v_status='ok' THEN v_hash END, v_etag, v_basis, v_count,
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
