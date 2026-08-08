-- =============================================================================
-- Stage 1, Step 2b (handoff 21): the superset resolver schema. Built EMPTY.
-- Supersedes county_layer_registry, zoning_layer_selection, flood_layer_selection,
-- amenity_registry, flood_layer_column_map. Nothing migrated here — concepts move
-- table-to-table, one per commit, cheapest-first (flood, sinkhole, zoning, amenities),
-- inline Volusia-only reads batched into one get_pir_report edit last.
--
-- Constraint from ruling 21: resolution order is ONE ordered walk, not walk + sort.
-- The single primitive is layer_resolution.precedence (3 city > 2 county > 1 state >
-- 0 country). Municipal-at-county is the degenerate case (precedence 3 at the county
-- geo_id), a documented TEMPORARY stand-in for admin_level 3 (backlog item 139).
-- =============================================================================
CREATE TABLE IF NOT EXISTS concept_registry (
  concept        text PRIMARY KEY,
  expected_level smallint NOT NULL,          -- 0 country, 1 state, 2 county, 3 city
  coverage_mode  text,                       -- per_county | statewide | national
  display_name   text, icon_name text, category text, sort_order int,
  who_can_answer text,
  notes text
);
COMMENT ON TABLE concept_registry IS
  'Per-concept catalogue (supersedes amenity_registry). expected_level is the admin level the concept is normally published at; resolve_layer flags fell_back when it resolves ABOVE that level (a state answer to a county concept discloses, never masks).';

CREATE TABLE IF NOT EXISTS layer_resolution (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  geo_id        text NOT NULL REFERENCES geo_reference(geo_id),
  concept       text NOT NULL REFERENCES concept_registry(concept),
  kind          text,
  table_name    text,                        -- NULL = de-selected / none held; selected_by + notes carry why
  precedence    smallint NOT NULL DEFAULT 2, -- THE single ordering primitive: higher = more specific = tried first
  jurisdiction_level text,                   -- 'county' | 'municipal' (TEMPORARY stand-in for admin_level 3)
  jurisdiction_name  text,
  geom_column   text DEFAULT 'geom',
  key_column    text, bridge_key text, key_transform text, srid int,
  row_count     bigint,
  not_mine_values text[],                    -- 999 INCORPORATED class
  flagged_values  text[],
  selected_by   text, verified boolean, verified_at timestamptz,
  candidates    int, needs_curation boolean, notes text,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS layer_resolution_geo_concept_idx ON layer_resolution (geo_id, concept);
COMMENT ON TABLE layer_resolution IS
  'Per (geo_id, concept, layer) resolution. Supersedes county_layer_registry + zoning_layer_selection + flood_layer_selection. A parcel resolves by gathering rows across its geo chain (geo_reference.parent_geo_id walked up: place->county->state->country) and applying ONE ordered walk: ORDER BY precedence DESC, verified DESC NULLS LAST, row_count DESC NULLS LAST; first row with table_name NOT NULL and row_count>0 (and, for polygon layers, spatial containment) wins. Exactly one ordering primitive (precedence); no separate sort.';
COMMENT ON COLUMN layer_resolution.precedence IS
  'Single ordering primitive: 3 city, 2 county, 1 state, 0 country. Set at registration from the geo admin_level, or 3 when jurisdiction_level=municipal.';
COMMENT ON COLUMN layer_resolution.jurisdiction_level IS
  'TEMPORARY stand-in for admin_level 3. Municipal layers sit at the county geo_id with jurisdiction_level=municipal and precedence=3 (populating ~400 FL municipalities into geo_reference is deferred, backlog item 139). TARGET: when geo_reference carries admin_level 3 places, municipal layers move to their own place geo_id (precedence from geo admin_level) and this column retires.';

COMMENT ON TABLE layer_column_map IS
  'Per-layer semantic column map (supersedes flood_layer_column_map and zoning inline *_column fields). col_role vocabulary: zone, sfha, bfe, subty, datum (flood); code, name, url, municipality (zoning/FLU); extend as concepts migrate. Names lie; every role content-verified at wire time.';

GRANT SELECT ON concept_registry, layer_resolution TO anon, authenticated, service_role;
