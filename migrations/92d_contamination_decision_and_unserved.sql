-- =============================================================================
-- handoff 40.
-- (1) Record the DECISION (not debt): statewide FDEP is the authoritative source for
--     contamination; a direct reference is the correct single source, NOT a parochial
--     single-county hardcode. It is not deferred work. It changes ONLY if a county-level
--     contamination layer appears in county_layer_registry or FDEP publishes per-county
--     extracts — then the statewide table would be masking something and must be wired.
-- (2) Register the coverage-state audit finding: three registered contamination concepts
--     have NO served reader at all, so the report silently omits them for every parcel.
-- =============================================================================
UPDATE concept_registry
   SET notes = notes || ' [DECISION 2026-08-08 (handoff 40): statewide FDEP is authoritative; a direct table reference is the correct single source, NOT debt. Wire a county-level layer only if county_layer_registry gains a county contamination layer or FDEP publishes per-county extracts.]'
 WHERE concept IN ('contamination_cleanup','contamination_tanks','contamination_stcm',
                   'institutional_controls','brownfield','drycleaning','gwca','source_water_protection')
   AND notes NOT LIKE '%DECISION 2026-08-08 (handoff 40)%';

INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'contamination-concepts-registered-but-unserved',
 'Three statewide contamination layers are held and registered in layer_resolution but no served function reads them, so every report silently omits them: fdep_stcm_contamination (contamination_stcm), fdep_drycleaning_sites (drycleaning), fdep_source_water_protection (source_water_protection). Data held ≠ data served.',
 CURRENT_DATE, 'handoff 40 — contamination coverage-state audit',
 'completeness','material',
 $det$SELECT count(*)=0 AS ok FROM (VALUES ('fdep_stcm_contamination'),('fdep_drycleaning_sites'),('fdep_source_water_protection')) t(tbl) WHERE NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f' AND pg_get_functiondef(p.oid) ~ ('\m'||t.tbl||'\M'))$det$,
 'The three unserved FDEP contamination tables.',
 'Reads ok=false while any of the three has no served reader. Flips clean when each is surfaced by a served function (ideally via resolve_layer for uniform 3-state instrumentation). Not a false negative in the served payload (the concept simply never appears) — a completeness gap: held data the reader never sees.',
 'active','ours','repair',
 'Coverage-state audit (handoff 40): of 8 contamination concepts — brownfield expresses full 3-state (not_established/present/none_nearby with a non-clearance caveat, via get_parcel_brownfield_facts); contamination_cleanup + contamination_tanks are 2-state present/parcel_not_resolved (defensible: statewide-authoritative, 0 nearby is a real 0) but with no explicit statewide-coverage note; institutional_controls + gwca are served by get_parcel_restrictions as a bare array (empty = no explicit coverage disclosure); contamination_stcm, drycleaning, source_water_protection are UNSERVED. Routing all through resolve_layer would give uniform three states + fell_back + who-can-answer + one detection point.',
 'Some environmental overlays (dry-cleaning solvent sites, source-water protection, additional STCM contamination) are held but not yet shown in the report; consult FDEP directly.',
 'contamination-concepts-all-served-uniformly', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence;
