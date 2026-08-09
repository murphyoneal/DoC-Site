-- =============================================================================
-- handoff 56: the other three zoning verdict actions (after Santa Rosa 96a).
-- De-select Lee junk, relabel 4 municipal layers, set verified on the 89 passers.
-- =============================================================================
-- Lee: rezoning-applications table, not zoning -> de-select (flood pattern, reason retained)
UPDATE layer_resolution
   SET notes = COALESCE(notes||' | ','')||'DE-SELECTED junk (handoff 56): lee_zoning_cases is a rezoning-APPLICATIONS table (case_name/case_status/case_type/case_link), no current-zoning column; 1406 distinct case numbers/dates. Lee zoning -> not_available.',
       table_name=NULL, verified=false, verified_at=now()
 WHERE table_name='lee_zoning_cases';

-- 4 municipal layers mislabeled county -> municipal (precedence 3)
UPDATE layer_resolution SET jurisdiction_level='municipal', precedence=3
 WHERE table_name IN ('lake_montverde_zoning','sumter_bushnell_zoning','charlotte_punta_gorda_zoning','lake_fruitlandpark_flu');

-- verified=true on the passers (interior-point >=0.9 in-county + value distribution); santarosa done in 96a, lee excluded
UPDATE layer_resolution
   SET verified=true, verified_at=now(),
       selected_by='content-verified 2026-08-09 (handoff 53): interior-point >=0.9 in-county + value-distribution on code/name'
 WHERE concept IN ('zoning','land_use') AND table_name IS NOT NULL AND verified IS NOT TRUE;
