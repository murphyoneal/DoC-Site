-- =============================================================================
-- handoff 51: rule the 8 undecided dispositions, narrow DEF-008, and schedule the daily
-- results-only run. Retiring/rehoming preserves knowledge (statewide_metrics/backlog).
-- After this the divergence is 3 predicates (DEF-006/007/009), each a real watch item.
-- =============================================================================
-- DEF-008: narrow to a RESOLVED empty layer (the hospitals danger); estate -> statewide_metrics
UPDATE data_defect_registry SET
  detection_sql=$det$SELECT bool_and(COALESCE(row_count,0)>0) AS ok FROM layer_resolution WHERE table_name IS NOT NULL$det$,
  disposition='repair', attribution='ours', expected_state='clean',
  false_positive_notes='Narrowed (handoff 51): flags only a RESOLVED layer with 0 live rows (the hospitals danger — served as a finding while empty). The broad empty-held-tables count is inventory -> statewide_metrics.empty_held_tables.'
WHERE defect_id='DEF-008';

INSERT INTO statewide_metrics (metric_key, value_numeric, unit, method_sql, inputs, caveat, computed_at, is_floor)
VALUES ('empty_held_tables',
  (SELECT count(*) FROM daily_table_rowcounts WHERE snapshot_date=(SELECT max(snapshot_date) FROM daily_table_rowcounts) AND row_count=0),
  'tables','SELECT count(*) FROM daily_table_rowcounts WHERE snapshot_date=(SELECT max(snapshot_date) FROM daily_table_rowcounts) AND row_count=0',
  'daily_table_rowcounts (latest snapshot)',
  'Held tables with 0 rows. Inventory, not a defect — an empty RESOLVED layer is the danger, caught by DEF-008. Ex the broad form of DEF-008.', now(), false)
ON CONFLICT (metric_key) DO UPDATE SET value_numeric=EXCLUDED.value_numeric, method_sql=EXCLUDED.method_sql, inputs=EXCLUDED.inputs, caveat=EXCLUDED.caveat, computed_at=now();

UPDATE data_defect_registry SET disposition='repair', attribution='ours', expected_state='defect',
  false_positive_notes='57 registry layers with null key_column (untested join key = metadata gap). Repair belongs in the wire-time verification pass (set key_column with row_count). Accepted-open until then.'
WHERE defect_id='DEF-001';
UPDATE data_defect_registry SET disposition='repair', attribution='ours', expected_state='clean',
  false_positive_notes='POST-HOC GUARD on the wire-time interior-point verification (handoff 51) — do NOT retire as redundant. Reads DEFECT: 91 zoning/land_use layers fidelity-migrated (87a) and served WITHOUT interior-point verification. Backlog: content-verify zoning/FLU. Would have caught the 8 junk flood layers.'
WHERE defect_id='DEF-006';
UPDATE data_defect_registry SET disposition='repair', attribution='ours', expected_state='clean',
  false_positive_notes='County-level post-hoc guard on the wire-time verification (handoff 51) — do NOT retire. Same 91 unverified zoning/FLU layers as DEF-006.'
WHERE defect_id='DEF-007';
UPDATE data_defect_registry SET disposition='repair', attribution='ours', expected_state='clean',
  false_positive_notes='Only freshness monitor. Reads DEFECT: lands_available_for_taxes_volusia (Volusia tax-deed, manual, owner Murphy) last pulled 2026-07-03, past its 30-day interval.'
WHERE defect_id='DEF-009';
UPDATE data_defect_registry SET disposition='disclose', attribution='source', expected_state='defect',
  false_positive_notes='Spec v5 Part J: duplicate keys are source, disclose + aggregate, never dedupe. get_pir_report plat note already discloses for affected Volusia parcels. Stays red by design.'
WHERE defect_id='DEF-013';
UPDATE data_defect_registry SET disposition='repair', attribution='ours', expected_state='clean',
  false_positive_notes='Guard that every resolved spatial layer has rows (row_count>0, refreshed live at wire time). Currently clean.'
WHERE defect_id='DEF-016';
UPDATE data_defect_registry SET disposition='repair', attribution='ours', expected_state='defect',
  false_positive_notes='Real open served-path item: volusia_* tables read directly by get_pir_report. PAIRED with get-pir-report-inline-volusia-coalesce; single removal condition: get_pir_report reads no volusia_* table directly. Expected defect (bridge) until then.'
WHERE defect_id='single-county-table-served-as-universal';

WITH base AS (SELECT COALESCE(max(item_no),0) AS m FROM build_backlog)
INSERT INTO build_backlog (item_no, title, priority, status, spec_ref, evidence)
SELECT base.m+1,'Content-verify the 96 zoning/FLU layers (interior-point), set layer_resolution.verified','low','open','handoff 51 (DEF-006/007)',
 'zoning+FLU migration (87a) was an exact-fidelity swap of the pre-existing zoning_layer_selection, never interior-point content-verified (verified=false on 91 served layers). Run interior-point + value-distribution per layer, set verified=true for passers / de-select junk. DEF-006/007 read defect until done.'
FROM base;

-- schedule the daily results-only run (no blocking, no rendering changes). Watch a week before teeth.
SELECT cron.schedule('defect-detections-daily', '0 7 * * *', $$SELECT public.run_defect_detections();$$);
