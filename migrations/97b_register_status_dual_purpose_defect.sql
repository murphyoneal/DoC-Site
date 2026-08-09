-- =============================================================================
-- handoff 58: register the root cause as a defect class.
-- =============================================================================
INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition, expected_state, disclosure_status,
  attribution_evidence, harness_predicate)
VALUES (
 'registry-status-column-dual-purpose',
 'data_defect_registry.status governed BOTH the detection lifecycle (run_defect_detections WHERE status=active) and the disclosure lifecycle (get_parcel_disclosures WHERE status=active). Retiring a detection therefore silently un-published its user-facing disclosure (DEF-019 Volusia + DEF-003 fragmentation went dark under ruling 51). One column, two meanings.',
 CURRENT_DATE, 'handoff 58 — 28-section baseline caught a disclosure regression',
 'entity_confusion','material',
 $det$SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(get_parcel_disclosures(74,'371300000020')) e WHERE e->>'defect_id'='DEF-019') AS ok$det$,
 'Served-path canary: a Volusia report still emits DEF-019 (a detection-retired but disclosure-active source limit).',
 'ok=true proves the two lifecycles are separated — DEF-019 emits despite status=retired, because get_parcel_disclosures now keys on disclosure_status. GENERAL LESSON: a maintenance action on an internal registry silently changed a user-facing output; the detection suite watches DATA not OUTPUTS and did not catch it — only the 28-section baseline diff did. Argues for making the baseline diff a standing check, not a manual migration step.',
 'active','ours','repair','clean','retired',
 'Fixed 2026-08-09 (migration 97a): added disclosure_status; get_parcel_disclosures re-keyed; DEF-019 + DEF-003 restored (Volusia disclosures md5 back to 97c3f446, a fragmented St. Johns parcel emits DEF-003).',
 'registry-disclosure-and-detection-lifecycles-separate')
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, expected_state=EXCLUDED.expected_state, disclosure_status=EXCLUDED.disclosure_status;
