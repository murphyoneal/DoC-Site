-- 188a - the deed-party scrub is DORMANT, and Roz is not Rosalind (ruling 903 sections 2-3).
--
-- MEASURED 2026-10-01 before changing anything:
--   - get_pir_report_scrubbed has NO caller: no SQL function references it, and nothing under app/ or lib/ calls
--     pirSocket.forParcelScrubbed. The second assistant route it was written for no longer exists.
--   - Roz (app/api/roz/route.ts, get_property_record tool) already calls get_pir_report directly - the UNSCRUBBED
--     payload - and its prompt carries no instruction to withhold deed-party names.
-- So "Roz uninhibited today" was already true in the serving path. What was wrong was the LABEL: this function's comment
-- named its target as "the Roz/B2B assistant", conflating an internal audit instrument (Roz) with an undefined future
-- customer product (Rosalind). A control described as aimed at our audit tool.
-- Ruling 903: the mechanism stays, recorded DORMANT with its reactivation condition. Not deleted, not widened. The
-- manifest it returns keeps reporting what it removes ("nothing removed" when inert is evidence, not an assumption).

comment on function public.get_pir_report_scrubbed(numeric, text) is
  'DORMANT (188a, ruling 903). get_pir_report with the deed-party scrub applied; the applied manifest is carried at meta.scrubManifest. NO CALLER as of 2026-10-01. It is NOT for Roz: Roz is the internal audit tool and reads get_pir_report unscrubbed by design. REACTIVATION CONDITION: when Rosalind (the B2B assistant, not yet defined) faces a customer, decide on the evidence of what she renders whether she reads this function - never inherited from what Roz is allowed. Constitutional rule (903): we show what the county shows; this scrub is a distribution choice for a future surface, not a redaction judgement. Do not reimplement the scrub client-side; do not delete this mechanism while it is idle.';

select public._log_action('cc', 'mark_scrub_dormant', 'pg_proc', array['get_pir_report_scrubbed'],
  jsonb_build_object('comment_target', 'the Roz/B2B assistant'),
  jsonb_build_object('state', 'dormant', 'callers', 0, 'roz_reads', 'get_pir_report (unscrubbed)', 'reactivation', 'when Rosalind faces a customer'),
  'Ruling 903: Roz (internal audit) and Rosalind (future B2B) were conflated in the scrub''s stated target; Roz already reads the full payload and the scrub has no caller. Recorded dormant with its reactivation condition; mechanism kept.', null);
