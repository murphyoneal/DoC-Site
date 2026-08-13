-- =============================================================================
-- handoff 38 Phase: register the 8 statewide FDEP contamination layers at admin_level 1
-- (geo US-12, Florida) in layer_resolution, content-verified first (interior-in-FL
-- ratio ~1.0, row counts live). precedence=1 (state) — the single ordering primitive.
-- These are the layers the hierarchy walk resolves to for a county parcel: no county
-- layer exists, so resolve_layer walks county -> state and returns the state layer with
-- resolved_at_level=1. concept_registry.expected_level=1 marks that as NORMAL (not a
-- fallback), unlike flood (expected_level 2) resolving at state.
-- Not served here; get_parcel_contamination_facilities rewiring is the next step.
-- =============================================================================
SET statement_timeout = 0;

INSERT INTO concept_registry (concept, expected_level, coverage_mode, display_name, icon_name, category, sort_order, who_can_answer, notes) VALUES
 ('contamination_cleanup', 1,'statewide','Contaminated Site Cleanup','flask','hazards',50,'FDEP (Florida Department of Environmental Protection).','FDEP CLM cleanup sites (statewide).'),
 ('contamination_tanks',   1,'statewide','Petroleum / Storage Tanks','fuel','hazards',51,'FDEP.','FDEP STCM storage-tank facilities (statewide).'),
 ('contamination_stcm',    1,'statewide','Contamination Monitoring','flask','hazards',52,'FDEP.','FDEP STCM contamination points (statewide).'),
 ('institutional_controls',1,'statewide','Institutional Controls','lock','hazards',53,'FDEP.','FDEP institutional/engineering controls (statewide).'),
 ('brownfield',            1,'statewide','Brownfield Areas','factory','hazards',54,'FDEP.','FDEP brownfield areas (statewide).'),
 ('drycleaning',           1,'statewide','Dry-Cleaning Solvent Sites','shirt','hazards',55,'FDEP.','FDEP dry-cleaning solvent program sites (statewide).'),
 ('gwca',                  1,'statewide','Groundwater Contamination Areas','droplet','hazards',56,'FDEP.','FDEP groundwater contamination / delineation areas (statewide).'),
 ('source_water_protection',1,'statewide','Source Water Protection','shield','hazards',57,'FDEP.','FDEP source-water protection areas (statewide).')
ON CONFLICT (concept) DO NOTHING;

INSERT INTO layer_resolution
  (geo_id, concept, kind, table_name, precedence, jurisdiction_level, jurisdiction_name,
   geom_column, srid, row_count, verified, verified_at, selected_by, notes)
VALUES
 ('US-12','contamination_cleanup','point','fdep_clm',1,'state','Florida','geom',4326,10185,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0'),
 ('US-12','contamination_tanks','point','fdep_stcm_tanks',1,'state','Florida','geom',4326,74262,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0'),
 ('US-12','contamination_stcm','polygon','fdep_stcm_contamination',1,'state','Florida','geom',4326,72357,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 0.998'),
 ('US-12','institutional_controls','polygon','fdep_institutional_controls',1,'state','Florida','geom',4326,2637,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0'),
 ('US-12','brownfield','polygon','fdep_brownfield_areas',1,'state','Florida','geom',4326,624,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0'),
 ('US-12','drycleaning','polygon','fdep_drycleaning_sites',1,'state','Florida','geom',4326,1293,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0'),
 ('US-12','gwca','polygon','fdep_gwca',1,'state','Florida','geom',4326,376,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0'),
 ('US-12','source_water_protection','polygon','fdep_source_water_protection',1,'state','Florida','geom',4326,9513,true,TIMESTAMPTZ '2026-08-08 00:00:00+00','content-verified 2026-08-08 (handoff 38)','interior-in-FL ratio 1.0')
ON CONFLICT DO NOTHING;

DO $$
DECLARE v int;
BEGIN
  SELECT count(*) INTO v FROM layer_resolution WHERE geo_id='US-12' AND jurisdiction_level='state';
  IF v <> 8 THEN RAISE EXCEPTION 'FDEP state layers registered: % (expected 8)', v; END IF;
END $$;