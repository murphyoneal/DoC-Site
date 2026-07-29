-- docs/data-tree/refresh.sql
-- Runtime-agnostic refresh for the Data Tree Anchor.
-- Run this in the Supabase SQL editor (or psql) any time tables are added.
-- It returns the census block as ready-to-paste markdown; drop it between the
--   <!-- DATA-TREE:BEGIN --> / <!-- DATA-TREE:END -->
-- markers in docs/DATA_TREE_ANCHOR.md. (Or run build.mjs to do the paste for you.)
--
-- "Wires in" = every populated table with a resolvable join route.
-- "Orphan"   = J14: no key/spatial/area path exists at all.
-- The numbers are LIVE — an orphan resolved or a table loaded changes them.

SET statement_timeout = 0;

WITH s AS (
  SELECT
    (SELECT count(*) FROM table_inventory)                                                  AS inventory_total,
    (SELECT count(*) FROM table_inventory WHERE row_count > 0)                               AS populated,
    (SELECT count(*) FROM table_inventory WHERE coalesce(row_count,0) = 0)                   AS empty,
    (SELECT count(*) FROM nr_jointype WHERE join_type <> 'J14_genuine_orphan')               AS wires_in,
    (SELECT count(*) FROM nr_jointype WHERE join_type =  'J13_non_parcel_domain')            AS non_parcel,
    (SELECT count(*) FROM nr_jointype WHERE join_type =  'J14_genuine_orphan')               AS orphans,
    (SELECT coalesce(string_agg(table_name || ' (' || row_count || ' rows)', ', '), '—')
       FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')                              AS orphan_list
)
SELECT format(
E'| measure | count |\n'
 '|---|---|\n'
 '| Tables in inventory | %s |\n'
 '| Populated (classified in nr_master) | %s |\n'
 '| Empty — awaiting data | %s |\n'
 '| **Wire into the system** | **%s** |\n'
 '| — parcel-linked | %s |\n'
 '| — non-parcel domain | %s |\n'
 '| **Genuine orphans** | **%s** — %s |',
  inventory_total, populated, empty, wires_in, wires_in - non_parcel, non_parcel, orphans, orphan_list
) AS census_block
FROM s;
