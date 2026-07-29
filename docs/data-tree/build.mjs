#!/usr/bin/env node
// docs/data-tree/build.mjs
// Regenerates the live census in docs/DATA_TREE_ANCHOR.md (between the DATA-TREE
// markers) and writes docs/data-tree/state.json — so the anchor stays true as
// tables are added or orphans resolve.
//
//   Usage:  DATABASE_URL="postgres://…pooler…" node docs/data-tree/build.mjs
//
// Uses the Supabase pooler connection string. Per the project's pooler note, the
// script issues `SET statement_timeout = 0` in-session before querying.
// Requires the `pg` package (npm i pg) — the only dependency.

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import pg from 'pg';

const here = dirname(fileURLToPath(import.meta.url));
const anchorPath = join(here, '..', 'DATA_TREE_ANCHOR.md');
const statePath = join(here, 'state.json');

const url = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;
if (!url) {
  console.error('Set DATABASE_URL (Supabase pooler connection string) and retry.');
  process.exit(1);
}

const fmt = (n) => Number(n).toLocaleString('en-US');

const client = new pg.Client({ connectionString: url });
await client.connect();
await client.query('SET statement_timeout = 0');

const { rows: [r] } = await client.query(`
  SELECT
    (SELECT count(*) FROM table_inventory)::int                                        AS inventory_total,
    (SELECT count(*) FROM nr_master)::int                                              AS classified,
    -- "wired" = reaches a parcel. J0 (system), J13 (non-parcel domain) and J14 (orphan)
    -- do NOT reach a parcel and must be EXCLUDED. Defining wired as "everything but J14"
    -- silently counted J0+J13 as wiring (anchor §9). The census:* closure guards this.
    (SELECT count(*) FROM nr_jointype
       WHERE join_type NOT IN ('J0_system','J13_non_parcel_domain','J14_genuine_orphan'))::int AS wired,
    (SELECT count(*) FROM nr_jointype WHERE join_type = 'J0_system')::int             AS system_tables,
    (SELECT count(*) FROM nr_jointype WHERE join_type = 'J13_non_parcel_domain')::int AS non_parcel,
    (SELECT count(*) FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')::int    AS orphans,
    -- reltuples = -1 is the "never ANALYZEd" sentinel, NOT a row count. Report it as a
    -- stats gap; never derive "empty" from it (anchor §9 — the 792-empty metadata lie).
    -- Only reltuples = 0 (on an ANALYZEd table) means genuinely empty.
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.reltuples = -1)::int      AS never_analyzed,
    (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.reltuples = 0)::int       AS empty_analyzed,
    (SELECT coalesce(string_agg(table_name, ', '), '—')
       FROM nr_jointype WHERE join_type = 'J13_non_parcel_domain')                    AS non_parcel_list,
    (SELECT coalesce(string_agg(table_name || ' (' || row_count || ' rows)', ', '), '—')
       FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')                       AS orphan_list
`);
await client.end();

const unclassified = r.inventory_total - r.classified;
const day = new Date().toISOString().slice(0, 10);

const block = [
  `*Generated ${day} from project eaifqorwmgayiqmbtzcg. Do not hand-edit — run \`node docs/data-tree/build.mjs\`.*`,
  ``,
  `| measure | count |`,
  `|---|---|`,
  `| Tables in inventory | ${fmt(r.inventory_total)} |`,
  `| Classified in \`nr_master\` | ${fmt(r.classified)} |`,
  `| **Reach a parcel (wired)** | **${fmt(r.wired)}** |`,
  `| — not wired · J0 system | ${fmt(r.system_tables)} |`,
  `| — not wired · J13 non-parcel domain (\`${r.non_parcel_list}\`) | ${fmt(r.non_parcel)} |`,
  `| — not wired · J14 genuine orphan (${r.orphan_list}) | ${fmt(r.orphans)} |`,
  `| Unclassified in inventory — in inventory, not in \`nr_master\` | ${fmt(unclassified)} |`,
  `| Genuinely empty (\`reltuples = 0\`, post-ANALYZE) | ${fmt(r.empty_analyzed)} |`,
  `| Never analyzed — no planner stats (\`reltuples = −1\`; 0 is healthy) | ${fmt(r.never_analyzed)} |`,
].join('\n');

const BEGIN = '<!-- DATA-TREE:BEGIN -->';
const END = '<!-- DATA-TREE:END -->';
const md = readFileSync(anchorPath, 'utf8');
if (!md.includes(BEGIN) || !md.includes(END)) {
  console.error(`Markers ${BEGIN} / ${END} not found in ${anchorPath}.`);
  process.exit(1);
}
const next = md.replace(
  new RegExp(`${BEGIN}[\\s\\S]*?${END}`),
  `${BEGIN}\n${block}\n${END}`
);
writeFileSync(anchorPath, next);

writeFileSync(
  statePath,
  JSON.stringify(
    {
      generated_at: new Date().toISOString(),
      project: 'eaifqorwmgayiqmbtzcg',
      inventory_total: r.inventory_total,
      classified: r.classified,
      wired: r.wired,
      system_tables: r.system_tables,
      non_parcel_domain: r.non_parcel,
      genuine_orphans: r.orphans,
      unclassified,
      empty_analyzed: r.empty_analyzed,
      never_analyzed: r.never_analyzed,
      non_parcel_list: r.non_parcel_list,
      orphan_list: r.orphan_list,
    },
    null,
    2
  ) + '\n'
);

console.log(
  `data-tree updated ${day}: ${fmt(r.wired)} reach a parcel, ${fmt(r.orphans)} orphan(s); ` +
  `${fmt(unclassified)} unclassified, ${fmt(r.empty_analyzed)} genuinely empty, ${fmt(r.never_analyzed)} never analyzed.`
);
