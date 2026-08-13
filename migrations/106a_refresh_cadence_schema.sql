-- =============================================================================
-- WO 81 refresh-cadence schema (design approved, ruling 93, amendments A/B/C).
-- The 90-day default is not data (207 of 287 carry it). Separate the one overloaded column,
-- build the append-only series everything derives from, and stamp every existing basis as
-- not_established because none of them was observed.
-- =============================================================================

-- append-only series: one row per source per check. Never UPDATE in place. A source returning
-- nothing writes status='error', NEVER changed=false — empty is a sentinel.
CREATE TABLE IF NOT EXISTS source_observation (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_id        bigint NOT NULL REFERENCES data_source_registry(id),
  observed_at      timestamptz NOT NULL DEFAULT now(),
  method           text NOT NULL CHECK (method IN ('metadata_poll','full_pull')),
  publisher_as_of  timestamptz,   -- editingInfo.lastEditDate / HTTP Last-Modified / page timestamp / ftp mtime
  content_hash     text,
  source_row_count bigint,
  our_row_count    bigint,
  changed          boolean,
  status           text NOT NULL DEFAULT 'ok' CHECK (status IN ('ok','error')),
  error_text       text,
  note             text
);
CREATE INDEX IF NOT EXISTS source_observation_source_idx ON source_observation (source_id, observed_at DESC);
COMMENT ON TABLE source_observation IS
  'Append-only cadence series (WO 81). One row per source per check. publisher_as_of is the source-declared currency read cheaply from metadata. Never updated in place; a nothing-returned check is status=error, never changed=false.';

-- the one column doing three jobs, separated. refresh_interval_days is RETAINED as the DECLARED
-- value (makes CADENCE_CONTRADICTED expressible; dropping it would destroy the evidence we assumed 90).
ALTER TABLE data_source_registry ADD COLUMN IF NOT EXISTS publish_cadence_days numeric;  -- observable: how often the artifact is rewritten (>=3 observed changes before set)
ALTER TABLE data_source_registry ADD COLUMN IF NOT EXISTS change_cadence_days  numeric;  -- process-governed: commission calendar / statutory roll dates
-- Amendment B: name it for what it actually holds — capture vs publisher-declared currency
-- (volusia_cama_snapshot_log: capture_date - data_current_as_of). The buyer-relevant event-to-file
-- lag is left UNBUILT and UNNAMED until we can measure it (a column that promises more than it holds
-- is how the elevation field got fabricated over).
ALTER TABLE data_source_registry ADD COLUMN IF NOT EXISTS publisher_lag_days   numeric;
ALTER TABLE data_source_registry ADD COLUMN IF NOT EXISTS cadence_basis        text NOT NULL DEFAULT 'not_established';
ALTER TABLE data_source_registry DROP CONSTRAINT IF EXISTS data_source_registry_cadence_basis_check;
ALTER TABLE data_source_registry ADD CONSTRAINT data_source_registry_cadence_basis_check
  CHECK (cadence_basis IN ('statute','observed','publisher_stated','not_established'));

-- Amendment A: every existing interval was ASSIGNED, not observed -> not_established (never
-- publisher_stated). The DEFAULT already stamps every row; this is explicit for the audit trail.
UPDATE data_source_registry SET cadence_basis='not_established' WHERE cadence_basis IS NULL OR cadence_basis='not_established';
