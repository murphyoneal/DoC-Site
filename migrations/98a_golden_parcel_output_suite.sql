-- =============================================================================
-- handoff 60/62: golden-parcel OUTPUT suite. A distinct instrument from
-- data_defect_registry: it watches what a report RENDERS, not the data beneath it.
-- Today a registry maintenance action silently emptied a disclosure and only a
-- hand-run baseline diff caught it. This makes that check standing.
--
-- TWO-LEVEL hash per section (handoff 62):
--   structural_hash = the SHAPE — keys present, coverage-state values
--     (present/none_recorded/not_available/...), null vs non-null, array lengths.
--     Structural movement is ALWAYS an alarm (a coverage flip, an array 1->0, a section
--     vanishing — none of that comes from fresh data).
--   value_hash = full content. Value-only movement is EXPECTED after a refresh (a just
--     value 200k->210k, a new permit) — logged, not alarmed. Skipped for the 3
--     genuinely time-varying sections (meta.generatedAt, reposeWindow, taxDeedStatus);
--     their STRUCTURE is still checked, so they are no longer a full blind spot.
-- =============================================================================

-- shape of a jsonb value: content abstracted to types, but coverage-state strings kept.
CREATE OR REPLACE FUNCTION public.pir_section_shape(v jsonb)
RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE jsonb_typeof(v)
    WHEN 'null'    THEN 'null'
    WHEN 'boolean' THEN 'bool'
    WHEN 'number'  THEN 'num'
    WHEN 'string'  THEN CASE WHEN (v #>> '{}') IN
        ('present','none_recorded','not_available','none_on_file','not_established',
         'parcel_not_resolved','none_nearby','assigned','covered','not_evaluated','unknown','none')
      THEN 'cs:'||(v #>> '{}') ELSE 'str' END
    WHEN 'array'   THEN 'arr['||jsonb_array_length(v)||':'||COALESCE(public.pir_section_shape(v->0),'_')||']'
    WHEN 'object'  THEN '{'||COALESCE((SELECT string_agg(k||':'||public.pir_section_shape(v->k), ',' ORDER BY k)
                                       FROM jsonb_object_keys(v) k),'')||'}'
    ELSE 'nil' END
$fn$;

CREATE TABLE IF NOT EXISTS golden_parcel (
  co_no numeric NOT NULL, parcel_id text NOT NULL,
  label text NOT NULL, rationale text, active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (co_no, parcel_id)
);
INSERT INTO golden_parcel (co_no, parcel_id, label, rationale) VALUES
 (74,'371300000020','Volusia deep','Deepest county — CAMA, permits, all inline reads'),
 (52,'21519-000-00','Marion mid','Mid-coverage non-Volusia; resolver-served subdivision/sinkhole'),
 (65,'0000200170','St. Johns fragmented','Duplicate parcel_id fragments (DEF-003 disclosure)'),
 (68,'0042110061','Sarasota flood-deselected','Flood layer de-selected -> flood not_available'),
 (23,'0141280040170','Miami-Dade recovered-flood','Recovered flood layer; no fema_flood_zones coverage'),
 (46,'13462300000041000','Lee zoning-deselected','Zoning de-selected (lee_zoning_cases junk) -> zoning null'),
 (67,'14-1N-29-0075-00G00-0040','Santa Rosa remapped-zoning','Zoning code remapped rezone_ -> district (serves R3)'),
 (13,'36081000000','Bay minimal','Minimal county coverage'),
 (37,'R30 422 18 0000 0020 0040','Hernando near-nothing','Near-nothing coverage county'),
 (74,'634110000010','Volusia condo','Unit-vs-complex case, untested end to end')
ON CONFLICT (co_no,parcel_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS golden_parcel_baseline (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  co_no numeric NOT NULL, parcel_id text NOT NULL, section text NOT NULL,
  structural_hash text, value_hash text, value_checked boolean NOT NULL DEFAULT true,
  baseline_version int NOT NULL, baselined_at timestamptz NOT NULL DEFAULT now(),
  baselined_reason text NOT NULL, known_bad_note text
);
CREATE INDEX IF NOT EXISTS golden_parcel_baseline_key_idx ON golden_parcel_baseline (co_no, parcel_id, baseline_version);

CREATE TABLE IF NOT EXISTS golden_parcel_run (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  run_id uuid NOT NULL, run_at timestamptz NOT NULL,
  co_no numeric NOT NULL, parcel_id text NOT NULL, section text NOT NULL,
  structural_status text NOT NULL,  -- match | diverged | new | missing | error
  value_status text NOT NULL,       -- match | diverged | skipped | n/a
  current_structural text, current_value text
);
CREATE INDEX IF NOT EXISTS golden_parcel_run_run_idx ON golden_parcel_run (run_id);

-- capture a NEW baseline version for all active golden parcels (reason REQUIRED)
CREATE OR REPLACE FUNCTION public.rebaseline_golden_parcels(p_reason text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE gp record; v_ver int; n int := 0;
BEGIN
  IF p_reason IS NULL OR btrim(p_reason)='' THEN RAISE EXCEPTION 'rebaseline_golden_parcels requires a non-empty reason'; END IF;
  PERFORM set_config('statement_timeout','0', true);
  FOR gp IN SELECT co_no, parcel_id FROM golden_parcel WHERE active LOOP
    SELECT COALESCE(max(baseline_version),0)+1 INTO v_ver FROM golden_parcel_baseline WHERE co_no=gp.co_no AND parcel_id=gp.parcel_id;
    INSERT INTO golden_parcel_baseline (co_no,parcel_id,section,structural_hash,value_hash,value_checked,baseline_version,baselined_reason)
    SELECT gp.co_no, gp.parcel_id, key, md5(public.pir_section_shape(value)), md5(value::text),
           (key NOT IN ('meta','reposeWindow','taxDeedStatus')), v_ver, p_reason
    FROM jsonb_each(public.get_pir_report(gp.co_no, gp.parcel_id));
    n := n + 1;
  END LOOP;
  RETURN n;
END $fn$;

-- compare each active golden parcel's current output to its latest baseline
CREATE OR REPLACE FUNCTION public.check_golden_parcels()
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_run uuid := gen_random_uuid(); v_at timestamptz := now(); gp record; v_report jsonb; sec record;
BEGIN
  PERFORM set_config('statement_timeout','0', true);
  FOR gp IN SELECT co_no, parcel_id FROM golden_parcel WHERE active LOOP
    BEGIN v_report := public.get_pir_report(gp.co_no, gp.parcel_id); EXCEPTION WHEN others THEN v_report := NULL; END;
    IF v_report IS NULL THEN
      INSERT INTO golden_parcel_run(run_id,run_at,co_no,parcel_id,section,structural_status,value_status)
      VALUES (v_run,v_at,gp.co_no,gp.parcel_id,'<report>','error','error');
      CONTINUE;
    END IF;
    FOR sec IN
      WITH cur AS (SELECT key sec, md5(public.pir_section_shape(value)) sh, md5(value::text) vh FROM jsonb_each(v_report)),
           bl AS (SELECT section, structural_hash, value_hash, value_checked FROM golden_parcel_baseline b
                  WHERE b.co_no=gp.co_no AND b.parcel_id=gp.parcel_id
                    AND b.baseline_version=(SELECT max(baseline_version) FROM golden_parcel_baseline
                                            WHERE co_no=gp.co_no AND parcel_id=gp.parcel_id))
      SELECT COALESCE(cur.sec,bl.section) section, cur.sh, cur.vh, bl.structural_hash, bl.value_hash,
             COALESCE(bl.value_checked,true) vchk, (cur.sec IS NULL) missing_now, (bl.section IS NULL) new_now
      FROM cur FULL JOIN bl ON bl.section=cur.sec
    LOOP
      INSERT INTO golden_parcel_run(run_id,run_at,co_no,parcel_id,section,structural_status,value_status,current_structural,current_value)
      VALUES (v_run,v_at,gp.co_no,gp.parcel_id,sec.section,
        CASE WHEN sec.new_now THEN 'new' WHEN sec.missing_now THEN 'missing'
             WHEN sec.sh IS DISTINCT FROM sec.structural_hash THEN 'diverged' ELSE 'match' END,
        CASE WHEN sec.new_now OR sec.missing_now OR sec.sh IS DISTINCT FROM sec.structural_hash THEN 'n/a'
             WHEN NOT sec.vchk THEN 'skipped'
             WHEN sec.vh IS DISTINCT FROM sec.value_hash THEN 'diverged' ELSE 'match' END,
        sec.sh, sec.vh);
    END LOOP;
  END LOOP;
  RETURN v_run;
END $fn$;
GRANT EXECUTE ON FUNCTION public.check_golden_parcels() TO service_role;
GRANT EXECUTE ON FUNCTION public.rebaseline_golden_parcels(text) TO service_role;
