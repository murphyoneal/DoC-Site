-- =============================================================================
-- Ruling 177 — pir_report_snapshot: the customer disclosure record. Applied to production.
--
-- What it is: an APPEND-ONLY ledger of every PIR ever rendered and delivered. Each row is the exact
-- bytes a customer (or a public-interest publication) was shown, sealed with a sha256, plus the state
-- of the machine that produced it. This is the document Murphy must be able to produce years later to
-- answer "what did you tell them, and when." A hash without the document it hashes is useless as evidence,
-- so the payload is stored WHOLE (measured 38,231 bytes for Vizcaya; 1M reports < 40 GB).
--
-- Ruling 177 decisions, each realised below:
--   Q1  store the payload WHOLE (jsonb) + a hash seal, not hash-and-reference.
--   Q2  snapshot what was RENDERED (post-scrub), not what was computed. scrub_manifest records what was
--       removed and by which rule - so the ruling-169 render-boundary check is trivial (scan snapshots for
--       name fields; if the scrub works they are absent) without putting withheld data in the customer's record.
--   Q3  generate-time, one row PER RENDER. purchase_id is a nullable soft-FK; the logical key is
--       (co_no, parcel_id, rendered_at) - the same 30-day purchase renders many times, answers can differ.
--   Q4  capture BOTH code_version (git sha of the serving app) AND db_state_hash (md5 over the
--       get_pir_%/get_parcel_% function bodies). If db_state_hash moves with no migration, that is a finding.
--   Q5  public_interest writes a snapshot too (purchase_id null) - the strongest provenance for a contested site.
--
-- APPEND-ONLY by constraint, not convention: a BEFORE UPDATE OR DELETE trigger RAISES. The disclosure
-- record must never itself be scrubbed, corrected, or deleted.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.pir_report_snapshot (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  co_no          numeric NOT NULL,
  parcel_id      text    NOT NULL,
  rendered_at    timestamptz NOT NULL DEFAULT now(),   -- (co_no, parcel_id, rendered_at) is the logical key
  realm          text    NOT NULL,                     -- 'purchase' | 'public_interest' | ...
  purchase_id    text,                                 -- nullable soft-FK to pir_purchases; NULL for public_interest
  payload        jsonb   NOT NULL,                     -- POST-SCRUB: the exact bytes rendered/delivered
  payload_hash   text    NOT NULL,                     -- sha256(payload::text) - integrity seal on the stored bytes
  scrub_manifest jsonb,                                -- [{field, rule, authority}] removed at the render boundary
  code_version   text,                                 -- git sha of the serving app at render
  db_state_hash  text,                                 -- md5 over the get_pir_%/get_parcel_% function defs (Q4)
  defects_disclosed text[],                            -- defect_ids disclosed on this report at render
  source_as_of   jsonb,                                -- {as_of:[...], sources:[...]} behind the report
  is_test        boolean NOT NULL DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_pir_snapshot_subject
  ON public.pir_report_snapshot (co_no, parcel_id, rendered_at DESC);

-- APPEND-ONLY enforcement. Immutability is a constraint here, not a coding guideline.
CREATE OR REPLACE FUNCTION public._pir_snapshot_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'pir_report_snapshot is APPEND-ONLY: % blocked. It is the customer disclosure record and must never be updated, deleted, or scrubbed.', TG_OP;
END $$;
DROP TRIGGER IF EXISTS trg_pir_snapshot_immutable ON public.pir_report_snapshot;
CREATE TRIGGER trg_pir_snapshot_immutable BEFORE UPDATE OR DELETE ON public.pir_report_snapshot
  FOR EACH ROW EXECUTE FUNCTION public._pir_snapshot_immutable();

-- Q4: what actually determines the answer. Changes on any CREATE OR REPLACE of a serving function,
-- migration or not - so a snapshot whose db_state_hash differs from a sibling with the same code_version
-- proves an out-of-band function edit happened between the two renders.
CREATE OR REPLACE FUNCTION public.pir_db_state_hash() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT md5(string_agg(pg_get_functiondef(p.oid), '' ORDER BY p.proname, p.oid))
  FROM pg_proc p WHERE p.pronamespace='public'::regnamespace
    AND (p.proname LIKE 'get_pir_%' OR p.proname LIKE 'get_parcel_%');
$$;

-- The render boundary (ruling 169: LOAD COMPLETE, SCRUB AT RENDER). ONE place, auditable.
-- Removes third-party deed-party names (grantor/grantee) from the conveyance chain and last_market_sale.
-- Owner-of-record is public record and RENDERS - it is NOT scrubbed. Returns {payload:<scrubbed>, manifest:[...]}.
-- The manifest is self-evidencing: it names the exact keys removed, the locations, and the count of values
-- removed (exercised on Volusia 74/372500000050 - a 5-deed chain - values_removed=10, payload leaks nothing).
CREATE OR REPLACE FUNCTION public.pir_scrub_payload(p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE
  v_out jsonb := p_payload;
  v_manifest jsonb := '[]'::jsonb;
  v_tf jsonb; v_conv jsonb; v_new_conv jsonb := '[]'::jsonb; v_elem jsonb; v_lms jsonb;
  k text;
  v_keys_removed text[] := '{}';           -- the actual key names encountered and removed
  v_locations    text[] := '{}';           -- where they were removed from
  v_count int := 0;                        -- how many party-name values were removed
  NAME_KEYS text[] := ARRAY['grantor','grantee','grantor_detail','grantee_detail','grantor_name','grantee_name','party','party_detail'];
BEGIN
  v_tf := p_payload->'transactionFacts';
  IF v_tf IS NOT NULL AND jsonb_typeof(v_tf) = 'object' THEN
    v_conv := v_tf->'conveyances';
    IF v_conv IS NOT NULL AND jsonb_typeof(v_conv) = 'array' THEN
      FOR v_elem IN SELECT * FROM jsonb_array_elements(v_conv) LOOP
        FOREACH k IN ARRAY NAME_KEYS LOOP
          IF v_elem ? k THEN
            v_elem := v_elem - k;
            IF NOT (v_keys_removed @> ARRAY[k]) THEN v_keys_removed := v_keys_removed || k; END IF;
            v_count := v_count + 1;
          END IF;
        END LOOP;
        v_new_conv := v_new_conv || jsonb_build_array(v_elem);
      END LOOP;
      v_tf := jsonb_set(v_tf, '{conveyances}', v_new_conv);
      IF v_count > 0 THEN v_locations := v_locations || 'transactionFacts.conveyances[]'::text; END IF;
    END IF;
    v_lms := v_tf->'last_market_sale';
    IF v_lms IS NOT NULL AND jsonb_typeof(v_lms) = 'object' THEN
      FOREACH k IN ARRAY NAME_KEYS LOOP
        IF v_lms ? k THEN
          v_lms := v_lms - k;
          IF NOT (v_keys_removed @> ARRAY[k]) THEN v_keys_removed := v_keys_removed || k; END IF;
          v_count := v_count + 1;
          IF NOT (v_locations @> ARRAY['transactionFacts.last_market_sale'::text]) THEN
            v_locations := v_locations || 'transactionFacts.last_market_sale'::text; END IF;
        END IF;
      END LOOP;
      v_tf := jsonb_set(v_tf, '{last_market_sale}', v_lms);
    END IF;
    v_out := jsonb_set(v_out, '{transactionFacts}', v_tf);
    IF v_count > 0 THEN
      v_manifest := v_manifest || jsonb_build_array(jsonb_build_object(
        'rule','third_party_deed_party_name_scrub',
        'authority','ruling-169 (LOAD COMPLETE, SCRUB AT RENDER)',
        'fields_removed', to_jsonb(v_keys_removed),
        'locations', to_jsonb(v_locations),
        'values_removed', v_count));
    END IF;
  END IF;
  RETURN jsonb_build_object('payload', v_out, 'manifest', v_manifest);
END $fn$;

-- The writer. Generate-time, one snapshot per render (Q3). POST-SCRUB payload (Q2). Both code_version and
-- db_state_hash (Q4). public_interest writes one too (Q5). Append-only enforced by the table trigger.
CREATE OR REPLACE FUNCTION public.pir_write_snapshot(
  p_co_no numeric, p_parcel_id text, p_realm text DEFAULT 'purchase',
  p_purchase_id text DEFAULT NULL, p_code_version text DEFAULT NULL, p_is_test boolean DEFAULT false)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','extensions','pg_temp' AS $fn$
DECLARE
  v_raw jsonb; v_scr jsonb; v_payload jsonb; v_manifest jsonb;
  v_hash text; v_dbhash text; v_defects text[]; v_source_as_of jsonb; v_id uuid;
BEGIN
  v_raw := public.get_pir_report(p_co_no, p_parcel_id);
  IF v_raw IS NULL THEN RAISE EXCEPTION 'get_pir_report returned NULL for %/% - nothing to snapshot', p_co_no, p_parcel_id; END IF;
  v_scr := public.pir_scrub_payload(v_raw);
  v_payload  := v_scr->'payload';
  v_manifest := v_scr->'manifest';
  v_hash   := encode(digest(v_payload::text, 'sha256'), 'hex');   -- integrity seal on the exact stored bytes
  v_dbhash := public.pir_db_state_hash();
  SELECT array_agg(DISTINCT x) INTO v_defects FROM (
    SELECT coalesce(d->>'defect_id', d->>'defectId', d->>'id') AS x
    FROM jsonb_array_elements(coalesce(v_payload->'disclosures','[]'::jsonb)) d
  ) s WHERE x IS NOT NULL;
  v_source_as_of := jsonb_build_object(
    'as_of',   (SELECT jsonb_agg(DISTINCT v) FROM jsonb_path_query(v_payload, 'strict $.**.as_of') v),
    'sources', (SELECT jsonb_agg(DISTINCT v) FROM jsonb_path_query(v_payload, 'strict $.**.source') v));
  INSERT INTO public.pir_report_snapshot
    (co_no, parcel_id, realm, purchase_id, payload, payload_hash, scrub_manifest,
     code_version, db_state_hash, defects_disclosed, source_as_of, is_test)
  VALUES (p_co_no, p_parcel_id, p_realm, p_purchase_id, v_payload, v_hash, v_manifest,
     p_code_version, v_dbhash, v_defects, v_source_as_of, p_is_test)
  RETURNING id INTO v_id;
  RETURN v_id;
END $fn$;

-- Open follow-ups (NOT built here, deliberately):
--   * The FE render path must call pir_write_snapshot at delivery time (coupled deploy). Until then no
--     production rows are written except by explicit call - the mechanism is proven, the wiring is FE work.
--   * rendered_text column: add only if the delivered artifact (PDF/HTML) ever diverges from the payload
--     bytes. Today the FE renders the payload directly, so payload IS the delivered artifact.
--   * Retention: this table is exempt from every scrub/erasure job by construction (the immutability trigger).
