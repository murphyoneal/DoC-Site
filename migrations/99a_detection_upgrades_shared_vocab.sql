-- =============================================================================
-- handoff 55/64: three detection-suite upgrades + one shared divergence vocabulary
-- across the defect suite and the golden-parcel output suite.
--
-- SHARED 3-STATE DISPLAY (green/amber/red) — kept, not a second name set:
--   GREEN  result matches a HEALTHY expectation (clean & expected-clean; golden all-match)
--   AMBER  result matches an expected-not-clean state (expected_state=defect matched;
--          golden value-only drift = expected on refresh). Known, logged, NOT an alarm.
--   RED    divergence: result != expectation, a magnitude jump, an errored predicate,
--          an expected-defect unexpectedly going clean, or a golden STRUCTURAL move.
-- =============================================================================

-- 1. MAGNITUDE + 3. EXPIRY columns
ALTER TABLE data_defect_registry ADD COLUMN IF NOT EXISTS expires_at timestamptz;
ALTER TABLE data_defect_registry ADD COLUMN IF NOT EXISTS magnitude_semantics text
  CHECK (magnitude_semantics IN ('magnitude','binary'));
COMMENT ON COLUMN data_defect_registry.magnitude_semantics IS
  'magnitude = the predicate returns a hit count that can move materially (divergence considers >10% or >10 rows vs the previous run). binary = genuinely yes/no (bool_and/exists); no magnitude, explicitly not lazy.';
COMMENT ON COLUMN data_defect_registry.expires_at IS
  'For expected_state=defect only: when this passes, the expectation reverts to clean automatically and the predicate diverges until someone renews it deliberately. An exemption with no expiry is a permanent silencer.';

-- magnitude vs binary: examined+hit contracts carry a count; everything else is binary
UPDATE data_defect_registry
   SET magnitude_semantics = CASE WHEN detection_sql ~* '\mexamined\M' AND detection_sql ~* '\mhit\M' THEN 'magnitude' ELSE 'binary' END
 WHERE status='active';

-- expiry on every active expected-defect: 3 months for bridges we are actively retiring, 6 months otherwise
UPDATE data_defect_registry
   SET expires_at = now() + CASE WHEN defect_id IN ('compat-views-pending-retirement','get-pir-report-inline-volusia-coalesce','single-county-table-served-as-universal')
                                 THEN interval '3 months' ELSE interval '6 months' END
 WHERE status='active' AND expected_state='defect';

-- 2. XFAIL display: operational dashboard (green/amber/red), expiry- and magnitude-aware
CREATE OR REPLACE VIEW detection_dashboard AS
WITH runs AS (SELECT run_id, run_at FROM (SELECT DISTINCT run_id, run_at FROM defect_detection_runs) r ORDER BY run_at DESC LIMIT 2),
     cur  AS (SELECT * FROM defect_detection_runs WHERE run_id=(SELECT run_id FROM runs ORDER BY run_at DESC LIMIT 1)),
     prev AS (SELECT * FROM defect_detection_runs WHERE run_id=(SELECT run_id FROM runs ORDER BY run_at DESC OFFSET 1 LIMIT 1)),
     j AS (
       SELECT reg.defect_id, reg.severity, cur.ok, reg.expected_state, reg.expires_at, reg.magnitude_semantics,
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
         WHEN ok IS NULL THEN 'red'
         WHEN ok <> (effective_expected='clean') THEN 'red'
         WHEN magnitude_moved THEN 'red'
         WHEN effective_expected='defect' THEN 'amber'
         ELSE 'green' END AS display
FROM j;

-- true-state view: raw counts, ignores expected_state (stops us forgetting what the system actually looks like)
CREATE OR REPLACE VIEW detection_true_state AS
WITH cur AS (SELECT * FROM defect_detection_runs WHERE run_id=(SELECT run_id FROM defect_detection_runs ORDER BY run_at DESC LIMIT 1))
SELECT count(*) AS active, count(*) FILTER (WHERE ok) AS clean, count(*) FILTER (WHERE ok IS FALSE) AS defect,
       count(*) FILTER (WHERE ok IS NULL) AS errored
FROM cur JOIN data_defect_registry reg ON reg.defect_id=cur.defect_id WHERE reg.status='active';

-- golden suite: same vocabulary. structural move = red; value-only drift = amber; match = green
CREATE OR REPLACE VIEW golden_dashboard AS
WITH cur AS (SELECT * FROM golden_parcel_run WHERE run_id=(SELECT run_id FROM golden_parcel_run ORDER BY run_at DESC LIMIT 1))
SELECT co_no, parcel_id, section, structural_status, value_status,
       CASE WHEN structural_status IN ('diverged','new','missing','error') THEN 'red'
            WHEN value_status='diverged' THEN 'amber' ELSE 'green' END AS display
FROM cur;

-- 3. rolling count of active, unexpired expected-defects -> statewide_metrics (climbing = moving backwards)
INSERT INTO statewide_metrics (metric_key, value_numeric, unit, method_sql, inputs, caveat, computed_at, is_floor)
VALUES ('active_expected_defects',
  (SELECT count(*) FROM data_defect_registry WHERE status='active' AND expected_state='defect' AND (expires_at IS NULL OR expires_at > now())),
  'predicates',
  'SELECT count(*) FROM data_defect_registry WHERE status=''active'' AND expected_state=''defect'' AND (expires_at IS NULL OR expires_at > now())',
  'data_defect_registry',
  'Active, unexpired expected-defect predicates (the AMBER bucket). If it climbs from 6 to 12 to 20 we are moving backwards regardless of the operational view. Refresh via the daily detection run.', now(), false)
ON CONFLICT (metric_key) DO UPDATE SET value_numeric=EXCLUDED.value_numeric, method_sql=EXCLUDED.method_sql, caveat=EXCLUDED.caveat, computed_at=now();

-- register the two observations from the golden review (handoff 64)
WITH base AS (SELECT COALESCE(max(item_no),0) AS m FROM build_backlog)
INSERT INTO build_backlog (item_no, title, priority, status, spec_ref, evidence)
SELECT base.m+1,'Zoning sub-value: bare null -> not_available wrapper (disclosure uniformity)','low','open','handoff 64',
 'get_parcel_zoning_facts returns zoning:null where no polygon matches (Lee/StJohns/MiamiDade/condo). Honest today because the parent section carries the coverage state, but null does not distinguish queried-and-no-polygon from no-layer-held — a false negative if the sub-value is read alone. Wrap in the present/none_recorded/not_available + who-can-answer shape during the disclosure-uniformity pass (queued behind the report restructure).'
FROM base;
