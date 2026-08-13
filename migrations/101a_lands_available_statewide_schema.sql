-- =============================================================================
-- work order 67 — generalise the Volusia Lands Available register into a statewide,
-- co_no-keyed shape with NULLABLE columns + a per-county field map (the layer_column_map
-- pattern). Counties publish overlapping-but-different fields; we must not force one
-- county's field list on another.
--
-- Money is NOT one concept. Volusia + Indian River publish an OPENING BID (a floor);
-- Putnam publishes an ESTIMATED PURCHASE PRICE (the clerk's estimate of the total, still
-- not final). Separate columns, so we never render one as the other.
--
-- Escheat: Indian River PUBLISHES the escheat date (ground truth). Volusia + Putnam do
-- not, so downstream we compute + caveat. published_escheat_date is null where unpublished.
--
-- STAGE 1a is additive: this holds Putnam (64) + Indian River (41). Volusia (74) still
-- lives in lands_available_for_taxes_volusia, which the served path reads; it folds in
-- via a compatibility-view swap in Stage 1b (a coupled structural change, reported first).
-- The field map already documents co_no 74 so this table is the statewide dictionary now.
-- =============================================================================

CREATE TABLE IF NOT EXISTS lands_available_for_taxes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  co_no numeric NOT NULL,
  certificate_number text NOT NULL,     -- Clerk's stable id (natural key with co_no)
  case_number text,                     -- Indian River publishes a TD case number
  parcel_id text,                       -- stored verbatim as the county publishes it
  owner_name text,                      -- Putnam publishes owner
  legal_description text,               -- Putnam publishes legal
  date_original_sale date,              -- day offered for public sale (the escheat anchor, F.S. 197.502(8))
  date_available_public date,           -- when it becomes purchasable (Volusia, Putnam)
  original_opening_bid numeric,         -- a FLOOR, not a price (Volusia, Indian River)
  estimated_purchase_price numeric,     -- clerk ESTIMATE of total, still not final (Putnam) — different concept
  published_escheat_date date,          -- county-published escheat date (Indian River) = ground truth
  county_contact_name text,             -- required routing: who quotes the real price
  county_contact_phone text,
  source_url text,
  loaded_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (co_no, certificate_number)
);
COMMENT ON TABLE lands_available_for_taxes IS
  'Statewide Lands Available for Taxes (tax-deed unsold-parcel registers), co_no-keyed. Nullable superset; per-county field presence in lands_available_field_map. original_opening_bid and estimated_purchase_price are DIFFERENT money concepts and both are stale — only the county can quote the current purchase total.';

-- per-county field dictionary: which canonical fields each county actually publishes, and
-- what the county calls it. This is what makes null honest (unpublished vs empty).
CREATE TABLE IF NOT EXISTS lands_available_field_map (
  co_no numeric NOT NULL,
  canonical_field text NOT NULL,
  source_label text,            -- the county's own label for it
  is_published boolean NOT NULL,
  note text,
  PRIMARY KEY (co_no, canonical_field)
);
COMMENT ON TABLE lands_available_field_map IS
  'Per-county field presence for lands_available_for_taxes. is_published=false means the county does not publish that field — a null in the data table is then "not published by this county", not "missing".';
