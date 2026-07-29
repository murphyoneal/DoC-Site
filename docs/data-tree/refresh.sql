-- docs/data-tree/refresh.sql
-- Runtime-agnostic refresh for the Data Tree Anchor.
-- Run this in the Supabase SQL editor (or psql) any time tables are added.
-- It returns the census block as ready-to-paste markdown; drop it between the
--   <!-- DATA-TREE:BEGIN --> / <!-- DATA-TREE:END -->
-- markers in docs/DATA_TREE_ANCHOR.md. (Or run build.mjs to do the paste for you.)
--
-- "Wired"    = reaches a parcel: every route EXCEPT J0 (system), J13 (non-parcel) and J14 (orphan).
-- "Orphan"   = J14: no key/spatial/area path exists at all.
-- "Never analyzed" = reltuples = -1 (a planner-stats gap). It is NOT "empty" (see anchor §9).
-- The numbers are LIVE — an orphan resolved, a table loaded, or an ANALYZE run changes them.

SET statement_timeout = 0;

WITH s AS (
  SELECT
    (SELECT count(*) FROM table_inventory)                                                  AS inventory_total,
    (SELECT count(*) FROM nr_master)                                                        AS classified,
    (SELECT count(*) FROM nr_jointype
       WHERE join_type NOT IN ('J0_system','J13_non_parcel_domain','J14_genuine_orphan'))   AS wired,
    (SELECT count(*) FROM nr_jointype WHERE join_type = 'J0_system')                        AS system_tables,
    (SELECT count(*) FROM nr_jointype WHERE join_type = 'J13_non_parcel_domain')            AS non_parcel,
    (SELECT count(*) FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')               AS orphans,
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.reltuples = -1)                 AS never_analyzed,
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.reltuples = 0)                  AS empty_analyzed,
    (SELECT coalesce(string_agg(table_name, ', '), '—')
       FROM nr_jointype WHERE join_type = 'J13_non_parcel_domain')                          AS non_parcel_list,
    (SELECT coalesce(string_agg(table_name || ' (' || row_count || ' rows)', ', '), '—')
       FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')                             AS orphan_list
)
SELECT format(
E'| measure | count |\n'
 '|---|---|\n'
 '| Tables in inventory | %s |\n'
 '| Classified in nr_master | %s |\n'
 '| **Reach a parcel (wired)** | **%s** |\n'
 '| — not wired · J0 system | %s |\n'
 '| — not wired · J13 non-parcel domain (%s) | %s |\n'
 '| — not wired · J14 genuine orphan (%s) | %s |\n'
 '| Unclassified in inventory — in inventory, not in nr_master | %s |\n'
 '| Genuinely empty (reltuples = 0, post-ANALYZE) | %s |\n'
 '| Never analyzed — no planner stats (reltuples = -1; 0 is healthy) | %s |',
  inventory_total, classified, wired, system_tables, non_parcel_list, non_parcel,
  orphan_list, orphans, inventory_total - classified, empty_analyzed, never_analyzed
) AS census_block
FROM s;
