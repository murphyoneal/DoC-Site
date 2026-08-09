-- =============================================================================
-- handoff 47 pass 3, category A (the 11 {...} templates). Ruling: aggregate to one
-- bool_and, or if it genuinely cannot be a single aggregate boolean it is a report.
-- The 20s per-predicate budget makes a live full-table sweep infeasible, so the
-- geometry-quality templates are re-expressed against the WIRE-TIME interior-point /
-- row_count verification stored in layer_resolution (ruling: superseded ne resolved —
-- the guarantee survives here if the wire-time check is bypassed).
--
-- Converted to aggregate booleans: DEF-016 (dead spatial), DEF-006 (out-of-FL),
--   DEF-007 (out-of-county), DEF-013 (dup plat, concrete over the plat family).
-- Folded + retired: DEF-004 (per-row null geom -> subsumed by DEF-016).
-- Reclassified to build_backlog (need per-entity params; cannot be one aggregate boolean
--   within the contract/20s): DEF-002, 003, 010, 011, 012, 015.
-- =============================================================================
UPDATE data_defect_registry SET
  detection_sql=$det$SELECT bool_and(COALESCE(row_count,0)>0) AS ok FROM layer_resolution WHERE table_name IS NOT NULL AND kind IN ('point','polygon')$det$,
  false_positive_notes='Aggregate over all resolved spatial layers: none is dead (row_count, refreshed live at wire time, is >0). Subsumes the per-row null-geometry template DEF-004.'
WHERE defect_id='DEF-016';
UPDATE data_defect_registry SET
  detection_sql=$det$SELECT bool_and(COALESCE(verified,true)) AS ok FROM layer_resolution WHERE table_name IS NOT NULL$det$,
  false_positive_notes='Re-expressed against the wire-time interior-point verification (ruling 47): no resolved layer is verified=false. The wire-time check tested feature points inside FL/county before selection.'
WHERE defect_id='DEF-006';
UPDATE data_defect_registry SET
  detection_sql=$det$SELECT bool_and(COALESCE(verified,true)) AS ok FROM layer_resolution WHERE table_name IS NOT NULL AND jurisdiction_level='county'$det$,
  false_positive_notes='County-level form of DEF-006, re-expressed against the wire-time county-containment verification.'
WHERE defect_id='DEF-007';
UPDATE data_defect_registry SET
  detection_sql=$det$SELECT NOT EXISTS (SELECT 1 FROM volusia_subdivision_plats WHERE subnum IS NOT NULL GROUP BY subnum HAVING count(*)>1) AS ok$det$,
  false_positive_notes='Concrete aggregate over the plat family we hold: no subnum has duplicate plat rows. Reads false today — the known duplicate-plat defect get_pir_report already discloses in the plat note.'
WHERE defect_id='DEF-013';

UPDATE data_defect_registry SET status='retired',
  false_positive_notes='RETIRED 2026-08-08 (handoff 47): folded into DEF-016 (dead-spatial aggregate). A per-row null-geometry sweep across all tables cannot run within the 20s budget; the wire-time row_count check covers the served set.'
WHERE defect_id='DEF-004';

UPDATE data_defect_registry SET status='retired',
  false_positive_notes='RETIRED 2026-08-08 (handoff 47): per-entity parameterized data-quality template (needs each table''s key/id/target column); not a single aggregate boolean without instantiation, and a live full sweep exceeds 20s. Knowledge -> build_backlog parameterized-sweep item.'
WHERE defect_id IN ('DEF-002','DEF-003','DEF-010','DEF-011','DEF-012','DEF-015');

WITH base AS (SELECT COALESCE(max(item_no),0) AS m FROM build_backlog)
INSERT INTO build_backlog (item_no, title, priority, status, spec_ref, evidence)
SELECT base.m+1,
 'Parameterized per-layer data-quality sweep (ex templates DEF-002/003/010/011/012/015)',
 'low','open','handoff 47',
 'Six retired templates need per-entity params and cannot be single aggregate booleans within the one-contract/20s budget: markup-in-identifier (002), duplicate keys (003, note parcels_staging legitimately multi-rows a parcel_id), roll-type contamination (010, per-CAMA-vendor), CAMA date-parse (011, per-col), uniform-value column (012, per-col), doubled-load (015, per-key). Decide an instantiation that still returns one bool_and per check batched over the layer set, or express each concretely per known family as DEF-013 now is.'
FROM base;
