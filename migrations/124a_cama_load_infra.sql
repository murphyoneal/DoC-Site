-- =============================================================================
-- Rulings 176/181 — parked CAMA loads (Pinellas, Collier, Pasco): load infrastructure + provenance.
-- The bulk data is loaded by scripts/wo_cama_load.py in WSL on Silverbox (files there, not in the repo).
-- This migration is the DB-side, verifiable-now half: the per-FILE load manifest and honest provenance.
--
-- Design (flagged to claude on the bus): the loader is schema-ADAPTIVE — it reads each CSV's REAL header
-- at load time and builds the table from it (ruling 150), all columns TEXT (the Volusia CAMA pattern; casts
-- happen at the fact/serving layer). So the concrete <county>_cama_<table> tables are created by the loader,
-- not here. Provenance is registered ahead of the load (table_name is just metadata); the pending pcpao-*
-- and BOM/staleness DEFECTS are registered POST-load, because their detection_sql must query tables that
-- exist and the registration trigger runs the detection at register time.
-- =============================================================================

-- Per-FILE manifest. as_of is recorded PER FILE, never per county (Pasco extrafeatures is a week stale vs its
-- siblings — msg 157). header_sha256 is a change signal in the spirit of Collier's RowCheckSum (msg 155).
CREATE TABLE IF NOT EXISTS public.cama_load_manifest (
  id             bigserial PRIMARY KEY,
  county         text NOT NULL,
  co_no          numeric NOT NULL,
  table_name     text NOT NULL,
  source_archive text,
  source_member  text NOT NULL,
  file_as_of     timestamptz,           -- the file's own mtime; PER FILE
  row_count      bigint,
  expected_count bigint,                -- baseline verification target from the bus
  count_ok       boolean,               -- row_count = expected_count (NULL when no target was published)
  columns_loaded int,
  had_bom        boolean DEFAULT false, -- Collier UTF-8 BOM (msg 155)
  dup_columns    text[],                -- e.g. {year_built} for Pinellas RP_PROPERTY_INFO (msg 150)
  header_sha256  text,
  loaded_at      timestamptz DEFAULT now(),
  loader_version text,
  UNIQUE (table_name, source_member)
);

-- Provenance, one row per intended table. table_name matches what the loader derives from the member stem.
-- Pinellas: nightly, http POST form (msg 129). Collier: ~weekly claimed / 4-day measured, ASP->Google Drive
-- redirect bundle (msg 154). Pasco: weekly but files diverge, direct zip dir (msg 157).
INSERT INTO data_source_registry
  (table_name, county_name, category, access_technique, source_url,
   temporal_extent_start, temporal_extent_end, temporal_extent_basis, cadence_basis, derivation, pull_mode, notes, active)
SELECT 'pinellas_cama_'||t, 'Pinellas', 'cama_relational', 'http_post_form',
  'https://www.pcpao.gov/dal/databasefile/downloadDatabaseFile',
  '2026-08-10','2026-08-10','file_timestamp','nightly',
  'PCPAO relational CAMA CSV. POST hdn_tbl_name=<TABLE>&hdn_ftype=csv, browser UA (msg 129). Returns <TABLE>.csv in a zip.',
  'manual',
  'Schema read from the real header at load (all TEXT). STRAP is 18ch, leading zeros preserved. Pending defects go active on load: pcpao-json-trailing-comma, pcpao-format-staleness-divergence, pcpao-assessor-flag-blank-is-not-negative (SEAWALL/CONTAMINATION_YN/SUBSIDENCE_YN/DLHL_YN/WATERFRONT_YN/ELEVATION_CERT presence-only; ELEVATION_CERT is NOT an elevation). RP_PROPERTY_INFO carries YEAR_BUILT twice.',
  true
FROM unnest(ARRAY['rp_structural_elements','rp_sales_history','rp_permits','rp_exemptions','rp_sub_areas',
  'rp_extra_features','rp_all_owners','rp_all_site_addresses','rp_legal','rp_property_info','rp_building',
  'rp_land','rp_sales','rp_millage_rates']) t
WHERE NOT EXISTS (SELECT 1 FROM data_source_registry d WHERE d.table_name='pinellas_cama_'||t);

INSERT INTO data_source_registry
  (table_name, county_name, category, access_technique, source_url,
   temporal_extent_start, temporal_extent_end, temporal_extent_basis, cadence_basis, derivation, pull_mode, notes, active)
SELECT 'collier_cama_'||t, 'Collier', 'cama_relational', 'google_drive_redirect',
  'https://www.collierappraiser.com/Main_Data/downloadgdfile.asp?folderName=INT FILES (NEW)&file=intfiles_csv.zip',
  '2026-08-07','2026-08-07','file_timestamp','publisher_claims_regular_measured_4day',
  'Collier INT relational CAMA. ASP page 302-redirects to a Google Drive bundle (intfiles_csv.zip); Drive ids resolve per run, never hardcoded (msg 154).',
  'manual',
  'UTF-8 BOM on every file (stripped at load). Per-row RowCheckSum shipped (change signal). Parcel count 298,248 measured, NOT the 364,827 work-list figure. Ownership FLATTENED (OwnerLine1..5, no owners table); sales carry GranteeLine1..5 but NO grantor. Native Section/Township/Range. USECODES/BUILDINGCODES are the crosswalks. No permits table.',
  true
FROM unnest(ARRAY['int_values_rp_history','int_sales','int_parcels','int_legal','int_buildings','int_land',
  'int_accounts','int_cra_history','int_values_tp_history','int_taxing_authorities_history','int_subcondos',
  'int_naics12','int_buildingcodes','int_usecodes','int_millage_rates','int_ctlfil']) t
WHERE NOT EXISTS (SELECT 1 FROM data_source_registry d WHERE d.table_name='collier_cama_'||t);

INSERT INTO data_source_registry
  (table_name, county_name, category, access_technique, source_url,
   temporal_extent_start, temporal_extent_end, temporal_extent_basis, cadence_basis, derivation, pull_mode, notes, active)
SELECT 'pasco_cama_'||t, 'Pasco', 'cama_relational', 'http_zip_directory',
  'https://ftp01.pascopa.com/real_estate/',
  '2026-08-09','2026-08-09','file_timestamp','weekly_files_diverge',
  'Pasco real-estate CAMA. Per-table zips under the directory (msg 157). sales.zip holds THREE members — load sales_all only, the subset sales_last_10years and README are skipped. parcel_summary is XLSX+PDF, not loaded here.',
  'manual',
  'as_of recorded PER FILE: extrafeatures.csv is stamped 2026-08-02, a week behind the 2026-08-09 siblings. Ownership FLATTENED (Owner_Mail_Name1/2, fewer owners than parcels). Preserve the header typo Sale_Qalified_Code. building carries Bldg_ActYrBlt (anchor) AND Bldg_EffYrBlt (renovation-adjusted, never the anchor). land carries Land_Zoning — CAMA-native zoning, a real corroboration source. No permits table.',
  true
FROM unnest(ARRAY['sales_all','land','site_addresses','parcel','owners','building','extrafeatures']) t
WHERE NOT EXISTS (SELECT 1 FROM data_source_registry d WHERE d.table_name='pasco_cama_'||t);
