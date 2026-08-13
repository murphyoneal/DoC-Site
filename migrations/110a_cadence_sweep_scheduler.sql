-- =============================================================================
-- WO 94 scheduler (ruling 96 — approved in principle, gated on the measured ETag number, now known:
-- of 147 count-only sources, 81 have an ETag, 66 are genuinely count-only). Nightly, in-database.
-- Ruling 96 spec: 30s timeout; nightly not finer; 05:00 UTC (EARLIER than the 07:00 detection run and
-- the 09:00 brief, so both see the night's observations, not yesterday's); concurrency is bounded by
-- pg_net's worker (observed: 552 requests processed over a few minutes, not a burst).
-- dispatch queues at 05:00; collect runs at 05:10, after responses (incl. 30s-timeout failures) land.
-- =============================================================================

-- dispatch with the ruled 30s timeout (git record of the function already deployed via ruling-96 verification)
DROP FUNCTION IF EXISTS public.cadence_sweep_dispatch(int);
CREATE OR REPLACE FUNCTION public.cadence_sweep_dispatch(p_limit int DEFAULT 1000, p_timeout_ms int DEFAULT 30000)
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
    v_meta  := net.http_get(v_base || '?f=json', timeout_milliseconds := p_timeout_ms);
    v_count := net.http_get(v_base || '/query?where=1%3D1&returnCountOnly=true&f=json', timeout_milliseconds := p_timeout_ms);
    INSERT INTO cadence_sweep_request (sweep_run_id, request_id, source_id, kind, url) VALUES
      (v_run, v_meta,  r.id, 'meta',  v_base || '?f=json'),
      (v_run, v_count, r.id, 'count', v_base || '/query?returnCountOnly');
    n := n + 1;
  END LOOP;
  UPDATE cadence_sweep_run SET dispatched = n WHERE id = v_run;
  RETURN v_run;
END $fn$;

-- collect the most recent un-collected run (robust against an ad-hoc run sneaking in)
SELECT cron.schedule('cadence-sweep-dispatch', '0 5 * * *',  $$SELECT public.cadence_sweep_dispatch();$$);
SELECT cron.schedule('cadence-sweep-collect',  '10 5 * * *', $$SELECT public.cadence_sweep_collect((SELECT id FROM cadence_sweep_run WHERE collected_at IS NULL ORDER BY started_at DESC LIMIT 1));$$);
