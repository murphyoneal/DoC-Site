-- =============================================================================
-- WO 111 — FEMA NFHL flood ingest schema for the 14 counties that currently serve not_available
-- (item 80). One SHARED statewide table, keyed by co_no for provenance/reconcile. The served function
-- get_parcel_flood_zone resolves flood_layer_selection.table_name per county then queries the table
-- SPATIALLY with no county filter (f.geom && parcel) — so a shared table serves each county correctly
-- via the GIST index; 14 bespoke per-county tables would be needless duplication. The resolver reads
-- columns through flood_col(table, role) and already nulls -9999 BFE at serve; we ALSO null it at ingest.
--
-- NOT wired here. layer_resolution / flood_layer_selection stay untouched until the load reconciles
-- 14/14 (Brevard is TWO files combining to 23,480). Wiring an empty table would flip 14 counties from
-- an honest not_available to a false none_intersecting. Wiring is migration 114b, run post-load.
-- =============================================================================

CREATE TABLE IF NOT EXISTS nfhl_flood_zones (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  co_no       smallint NOT NULL,                 -- DOR county number (parcels key on this)
  fips        text NOT NULL,                      -- 5-digit county FIPS (source-side key)
  objectid    bigint,                             -- FEMA OBJECTID: unique WITHIN a county DFIRM, not across
  fld_ar_id   text,                               -- FEMA flood-area id
  fld_zone    text,                               -- zone code (AE, X, VE, A, AO, ...) — the served 'zone'
  zone_subty  text,
  static_bfe  double precision CHECK (static_bfe IS NULL OR static_bfe <> -9999),  -- -9999 = NOT DETERMINED; nulled at load, CHECK is the backstop
  depth       double precision CHECK (depth      IS NULL OR depth      <> -9999),  -- AO-zone depth; same sentinel
  v_datum     text,
  len_unit    text,
  dual_zone   text,
  source_cit  text,
  dfirm_id    text,
  geom        geometry(MultiPolygon,4326)
);
CREATE INDEX IF NOT EXISTS nfhl_flood_zones_geom_gix  ON nfhl_flood_zones USING gist (geom);
CREATE INDEX IF NOT EXISTS nfhl_flood_zones_co_no_ix  ON nfhl_flood_zones (co_no);

-- schema-adaptive column map the resolver reads via flood_col(). Inert until a county's
-- flood_layer_selection row points at this table (114b). No 'sfha' role: NFHL S_FLD_HAZ_AR has no SFHA
-- flag, so the resolver derives it from the zone code (A#/V# prefix) — correct for this layer.
DELETE FROM flood_layer_column_map WHERE table_name = 'nfhl_flood_zones';
INSERT INTO flood_layer_column_map (table_name, col_role, column_name, note) VALUES
 ('nfhl_flood_zones','zone','fld_zone','FEMA NFHL S_FLD_HAZ_AR zone code'),
 ('nfhl_flood_zones','subty','zone_subty',NULL),
 ('nfhl_flood_zones','bfe','static_bfe','-9999 nulled at ingest and at serve'),
 ('nfhl_flood_zones','datum','v_datum',NULL);

INSERT INTO data_source_registry (county_name, category, table_name, source_url, access_technique, active, pull_mode, refresh_owner, cadence_basis, notes)
VALUES ('Statewide','flood','nfhl_flood_zones',
  'https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer/28','arcgis_paged',true,'manual','Murphy','not_established',
  'FEMA NFHL S_FLD_HAZ_AR (layer 28), the 14 counties with no held FIRM (WO111). Verification targets sum 175,728; Brevard is two files = 23,480. -9999 BFE/DEPTH nulled at ingest. Geometry is heavy: Brevard holds 77 features >1MB incl. one 594,198-vertex / 14.7MB polygon (> the 550k-vertex Marion timeout case) — simplified serving geometry to be assessed, not yet built.')
ON CONFLICT (table_name, county_name) DO NOTHING;
