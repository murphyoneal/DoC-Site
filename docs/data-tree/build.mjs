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
    (SELECT count(*) FROM table_inventory)::int                                     AS inventory_total,
    (SELECT count(*) FROM table_inventory WHERE row_count > 0)::int                 AS populated,
    (SELECT count(*) FROM table_inventory WHERE coalesce(row_count,0) = 0)::int     AS empty,
    (SELECT count(*) FROM nr_jointype WHERE join_type <> 'J14_genuine_orphan')::int AS wires_in,
    (SELECT count(*) FROM nr_jointype WHERE join_type =  'J13_non_parcel_domain')::int AS non_parcel,
    (SELECT count(*) FROM nr_jointype WHERE join_type =  'J14_genuine_orphan')::int AS orphans,
    (SELECT coalesce(string_agg(table_name || ' (' || row_count || ' rows)', ', '), '—')
       FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')                     AS orphan_list
`);
await client.end();

const parcelLinked = r.wires_in - r.non_parcel;
const day = new Date().toISOString().slice(0, 10);

const block = [
  `*Generated ${day} from project eaifqorwmgayiqmbtzcg. Do not hand-edit — run \`node docs/data-tree/build.mjs\`.*`,
  ``,
  `| measure | count |`,
  `|---|---|`,
  `| Tables in inventory | ${fmt(r.inventory_total)} |`,
  `| Populated (classified in \`nr_master\`) | ${fmt(r.populated)} |`,
  `| Empty — awaiting data | ${fmt(r.empty)} |`,
  `| **Wire into the system** | **${fmt(r.wires_in)}** |`,
  `| — parcel-linked | ${fmt(parcelLinked)} |`,
  `| — non-parcel domain | ${fmt(r.non_parcel)} |`,
  `| **Genuine orphans** | **${fmt(r.orphans)}** — ${r.orphan_list} |`,
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
      populated: r.populated,
      empty: r.empty,
      wires_in: r.wires_in,
      parcel_linked: parcelLinked,
      non_parcel_domain: r.non_parcel,
      genuine_orphans: r.orphans,
      orphan_list: r.orphan_list,
    },
    null,
    2
  ) + '\n'
);

console.log(
  `data-tree updated ${day}: ${fmt(r.wires_in)} wire in, ${fmt(r.orphans)} orphan(s), ${fmt(r.empty)} empty awaiting data.`
);
