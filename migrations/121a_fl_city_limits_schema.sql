-- =============================================================================
-- WO159 — item 139 municipal fix. Target schema + provenance + Weeki Wachee defect for the statewide
-- city-limits layer. The 412-feature GeoJSON is loaded by scripts/wo159_load_city_limits.py (WSL).
-- Source: FDOT-hosted FGDL City_Boundaries (WO157's aquarius URL was dead) — 412, placefp unique+populated,
-- wkid 3087 pulled to 4326. Derived from FDOR TAXAUTHCD dissolved by county = same lineage as parcels_staging.
-- =============================================================================

-- MultiPolygon column forces ST_Multi (trap 1: 174 Polygon + 238 MultiPolygon). is_active carries the
-- Weeki Wachee disincorporation (2020-06-09) without dropping the row. GiST at ingest, not the exception.
CREATE TABLE IF NOT EXISTS public.fl_city_limits (
  fid         integer,
  placefp     text NOT NULL,     -- Census place FIPS; the US-12-<placefp> key component
  name        text,
  bebr_id     text,
  county      text,              -- may list >1 county for the 4 multi-county rows
  tax_count   integer,
  taxauthcd   text,
  acres       numeric,
  descript    text,
  notes       text,
  autoid      text,
  fgdlaq_date date,              -- loader: fgdlaqdate epoch-ms / 1000
  geom        geometry(MultiPolygon, 4326),
  geo_id      text,              -- US-12-<placefp>, set at the geo_reference admin_level-3 step
  is_active   boolean DEFAULT true
);
CREATE INDEX IF NOT EXISTS idx_fl_city_limits_geom    ON public.fl_city_limits USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_fl_city_limits_placefp ON public.fl_city_limits(placefp);

-- provenance (measured, WO159): 1:24000 tax-code proxy, NOT a legal boundary; absent limit != unincorporated.
INSERT INTO data_source_registry
  (table_name, county_name, category, access_technique, source_url, temporal_extent_start, temporal_extent_end,
   temporal_extent_basis, scale_denominator, positional_accuracy_m, cadence_basis, derivation, spatial_extent_note, notes, active, pull_mode)
SELECT 'fl_city_limits','STATEWIDE','municipal_boundary','arcgis_rest',
  'https://gis.fdot.gov/arcgis/rest/services/Hosted/CityLimits/FeatureServer/0',
  '2021-12-31','2021-12-31','publisher_stated', 24000, NULL, 'not_established',
  'Derived from FDOR parcel TAXAUTHCD dissolved by county — SAME LINEAGE as parcels_staging.',
  'FGDL: counties with incomplete parcel data have NO city-limit boundary. AN ABSENT CITY LIMIT IS NOT EVIDENCE A PARCEL IS UNINCORPORATED.',
  'FGDL City_Boundaries via FDOT Hosted. Tax-code proxy for which municipality taxes a parcel, NOT a legal boundary; simplified 1m/65m/100m; "1:24000 should NOT be used for property parcel boundaries." 412 features, placefp unique+populated, wkid 3087->4326.',
  true, 'manual'
WHERE NOT EXISTS (SELECT 1 FROM data_source_registry WHERE table_name='fl_city_limits');

-- source defect: the layer carries a municipality that no longer exists (load + flag inactive, never drop).
INSERT INTO data_defect_registry
  (defect_id, name, class, severity, expected_state, detection_sql, status, attribution, disposition, false_positive_notes)
VALUES ('citylimits-weeki-wachee-disincorporated',
  'fl_city_limits carries Weeki Wachee, disincorporated 2020-06-09, knowingly retained in the FGDL layer',
  'temporal','material','clean',
  $q$SELECT NOT EXISTS(SELECT 1 FROM fl_city_limits WHERE upper(name) LIKE '%WEEKI WACHEE%' AND is_active IS NOT FALSE) AS ok$q$,
  'active','source','disclose',
  'WO159: dissolved 2020-06-09; FGDL knowingly retained it. Load it, flag is_active=false + inactive in geo_reference; never drop. Fires if present AND active.')
ON CONFLICT (defect_id) DO UPDATE SET detection_sql=EXCLUDED.detection_sql;
