-- =============================================================================
-- handoff 34 #1: PICK vs COMPOSE. layer_resolution expressed only PICK (highest
-- precedence wins, one layer answers). School zones need COMPOSE (elementary+middle+high
-- together form one answer); flood's Leon/Lee pre-merge was the same shape solved in data.
-- Add resolution_mode (pick|compose). kind is already in use for GEOMETRY type
-- (point/polygon/relational) across every migrated concept, so it cannot also carry the
-- compose sub-identity; adding a general `variant` column instead (NOT a school-specific
-- level column) — variant carries the sub-member (school level) for compose rows.
-- =============================================================================
ALTER TABLE layer_resolution ADD COLUMN IF NOT EXISTS resolution_mode text NOT NULL DEFAULT 'pick';
ALTER TABLE layer_resolution ADD COLUMN IF NOT EXISTS variant text;
COMMENT ON COLUMN layer_resolution.resolution_mode IS
  'pick (default): highest-precedence single row answers. compose: resolve_layer returns ALL rows at the winning precedence, each distinguished by variant. Retires the flood Leon/Lee pre-merge workaround and covers school-zone levels without a bespoke column.';
COMMENT ON COLUMN layer_resolution.variant IS
  'Compose sub-identity (general, not school-specific): the member a compose row contributes, e.g. elementary|middle|high for school_zones. NULL for pick rows and single-table compose sources.';

-- school_zones: level-split counties (separate elem/middle/high tables) -> compose + variant;
-- single-table counties (one table covers all levels) stay pick.
UPDATE layer_resolution SET resolution_mode='compose',
  variant = CASE WHEN table_name ~* 'element' THEN 'elementary'
                 WHEN table_name ~* 'middle'  THEN 'middle'
                 WHEN table_name ~* 'high'    THEN 'high' END
WHERE concept='school_zones' AND table_name IS NOT NULL
  AND table_name ~* '(element|middle|high)';
