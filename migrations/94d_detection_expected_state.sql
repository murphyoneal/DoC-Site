-- =============================================================================
-- handoff 49: add expected_state to data_defect_registry so the dashboard shows only
-- DIVERGENCE from the expected/healthy state, not the known-red backlog. A bridge's
-- healthy state is red (expected='defect'); a monitor's healthy state is clean
-- (expected='clean'). A result matching expected_state is GREEN; a result differing is
-- the only thing that draws attention — including a bridge unexpectedly going clean
-- (someone dropped a view / removed a hardcode without recording it).
-- Baseline set from the 2026-08-08 run: divergence = 0.
-- =============================================================================
ALTER TABLE data_defect_registry ADD COLUMN IF NOT EXISTS expected_state text
  CHECK (expected_state IN ('clean','defect'));
COMMENT ON COLUMN data_defect_registry.expected_state IS
  'The healthy result for this predicate: clean (a monitor that should pass) or defect (a deliberate/known red — bridge, source limitation, instructed-not-to-fix). Dashboard alarms only on divergence from expected_state, including an expected-defect predicate going clean.';

-- default every active predicate to 'defect' (expected red), then mark the healthy monitors clean.
UPDATE data_defect_registry SET expected_state='defect' WHERE status='active';
UPDATE data_defect_registry SET expected_state='clean' WHERE status='active' AND defect_id IN (
  'brownfield-served-volusia-only','contamination-concepts-registered-but-unserved',
  'county-layer-registry-misnamed-for-multilevel','DEF-016','flood-bfe-9999-sentinel-served-null',
  'flood-lake-county-name-trap','geometry-resolution-served-path','gwca-orphaned-from-served-payload',
  'ownership-served-path','registry-rowcount-stamp-unreliable','served-flood-legacy-fema-flood-zones',
  'values-flat-keys-duplicate-of-valuesfacts','zoning-shadow-duplicate-representation');
