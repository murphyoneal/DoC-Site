-- =============================================================================
-- handoff 56: de-selected zoning rows (table_name NULL) must not reach _zoning_lookup,
-- which formats %I on table_name BEFORE its exception handler (a NULL throws uncaught).
-- Exclude them in the compatibility view (the null-handling flood does at the reader,
-- done here at the view). Lee -> no zoning rows -> _zoning_lookup returns null cleanly.
-- =============================================================================
CREATE OR REPLACE VIEW zoning_layer_selection AS
SELECT lr.id, g.dor_co_no::numeric AS co_no, lr.jurisdiction_level, lr.jurisdiction_name,
       CASE WHEN lr.concept='land_use' THEN 'flu' ELSE 'zoning' END AS kind,
       lr.table_name, cm.code_col AS code_column, cm.name_col AS name_column, cm.url_col AS url_column,
       lr.geom_column, lr.verified, lr.notes, lr.not_mine_values, cm.muni_col AS municipality_column, lr.flagged_values
FROM layer_resolution lr
JOIN geo_reference g ON g.geo_id = lr.geo_id
LEFT JOIN LATERAL (
  SELECT max(column_name) FILTER (WHERE col_role='code')         AS code_col,
         max(column_name) FILTER (WHERE col_role='name')         AS name_col,
         max(column_name) FILTER (WHERE col_role='url')          AS url_col,
         max(column_name) FILTER (WHERE col_role='municipality') AS muni_col
  FROM layer_column_map WHERE table_name = lr.table_name) cm ON true
WHERE lr.concept IN ('zoning','land_use') AND lr.table_name IS NOT NULL;
