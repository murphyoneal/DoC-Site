-- =============================================================================
-- handoff 36 registrations.
-- (2) The COALESCE bridge: get_pir_report keeps the hardcoded Volusia inline reads as
--     the FIRST branch (property.subdivision <- volusia_parcel_centroids;
--     water.boatRamps <- volusia_boat_ramps), with the resolver as the else branch.
--     That preserves Volusia byte-identical but leaves the hardcode Stage 1 exists to
--     remove. Register it with a removal condition. NOTE the school-assignment inline
--     (volusia_parcel_school_assignment) is NOT this kind of debt: a precomputed district
--     assignment is a genuinely SUPERIOR source to a polygon hit, so it is a deliberate
--     source precedence, recorded as backlog to formalise, not removed.
-- Holds (reported to handoff 36, NOT wired): school_zones (payload cannot express
--     assigned-vs-zone-inferred derivation), plat_index (non-Volusia layers not
--     parcel-plat-equivalent; sjc_plat_index has no geometry), environmental_overlay
--     (belongs in nine-section report section 3, spec v5 s0.1).
-- =============================================================================

INSERT INTO data_defect_registry
 (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql,
  expected_denominator, false_positive_notes, status, attribution, disposition,
  attribution_evidence, disclosure_text, harness_predicate, applies_to_counties)
VALUES (
 'get-pir-report-inline-volusia-coalesce',
 'get_pir_report resolves subdivisions and boat ramps via the resolver only as the ELSE branch of COALESCE(inline-Volusia, resolver). The inline Volusia reads (volusia_parcel_centroids.subdivision, volusia_boat_ramps) remain hardcoded as the first branch. Correct for now (keeps Volusia byte-identical) and the wrong end state (Stage 1 removes hardcodes).',
 CURRENT_DATE, 'handoff 36 Phase 2 wiring',
 'entity_confusion','material',
 $det$SELECT (position('volusia_boat_ramps' in pg_get_functiondef('public.get_pir_report(numeric,text)'::regprocedure))=0) AS ok$det$,
 'get_pir_report source: presence of the inline volusia_boat_ramps read.',
 'Reads ok=false while the inline Volusia boat-ramp read remains as the COALESCE first branch. Flips clean when get_pir_report resolves marine (and subdivisions) uniformly through the resolver for Volusia too, at equal-or-better fidelity with matching output. Removal condition per concept: the resolver covers Volusia at >= fidelity AND outputs match. School assignment is EXCLUDED from this debt (see attribution_evidence) — its inline source is superior by design.',
 'active','ours','repair',
 E'COALESCE bridges in get_pir_report (2026-08-08, migration 91b):\n  property.subdivision : volusia_parcel_centroids.subdivision (inline) -> get_parcel_subdivision_resolved (resolver)\n  water.boatRamps      : volusia_boat_ramps (inline) -> get_parcel_boat_ramps_resolved (resolver)\nRemoval condition: resolver covers Volusia at equal-or-better fidelity and outputs match; then drop the inline branch.\nNOT debt: schools section reads volusia_parcel_school_assignment (a precomputed DISTRICT assignment) — genuinely superior to a polygon-zone hit (assignment departs from drawn boundaries: splits, capacity transfers, magnet/choice, grandfathering). This is a deliberate precedence of a superior source, to be formalised in a source-precedence mechanism (backlog), not removed.',
 NULL, 'get-pir-report-resolver-uniform-volusia', NULL)
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql, attribution_evidence=EXCLUDED.attribution_evidence;

WITH base AS (SELECT COALESCE(max(item_no),0) AS m FROM build_backlog),
items(seq,title,spec_ref,evidence) AS (VALUES
 (1,'Wire environmental_overlay into nine-section report section 3 (on/under this parcel)',
    'PIR_REPORT_SPEC_v5 s0.1',
    'handoff 36: the 8 usable environmental_overlay layers (conservation/preserve/eagle-nest/scrub-jay, verified in phase 1, in layer_resolution) are habitat/conservation overlays that belong in section 3 of the nine-section report, not a bolt-on section. Wire during the report restructure, not before.'),
 (2,'Wire school_zones with an assigned-vs-zone-inferred derivation distinction (payload + FE)',
    'handoff 36',
    'handoff 36 condition 1: the schools payload cannot currently express derivation. A precomputed district assignment (Volusia) must render as assigned; a polygon-zone hit (the 22 usable *_school_zones, compose by level) must render as within the published attendance zone — confirm with the district, never assigned. Needs a derivation field on the schools payload + FE handling (coupled deploy). resolution_mode=compose + variant already set for level-split counties.'),
 (3,'CAMA + Volusia school assignment: source-precedence mechanism',
    'handoff 34/36',
    'handoff 36: formalise a source-precedence table so a deliberately superior source (e.g. volusia_parcel_school_assignment over a school-zone polygon) is expressed as precedence data, not a hardcode in get_pir_report. Ties to the CAMA relational-resolver backlog item.'),
 (4,'plat_index resolver model (per-county plat; sjc has no geometry)',
    'handoff 36',
    'handoff 36: plat_index held. Non-Volusia usable layers are miamidade_final_platting (platting CASES) and sjc_plat_index (NO geometry — cannot spatially resolve to a parcel); neither is equivalent to the Volusia subnum-keyed parcel plat. Design a plat model before wiring the plat section for other counties.'))
INSERT INTO build_backlog (item_no, title, priority, status, spec_ref, evidence)
SELECT base.m + items.seq, items.title, 'medium','open', items.spec_ref, items.evidence
FROM items CROSS JOIN base;
