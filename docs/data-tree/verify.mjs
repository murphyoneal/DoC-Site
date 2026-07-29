#!/usr/bin/env node
// docs/data-tree/verify.mjs
// Self-checking gate for the Data Tree Anchor. Thin wrapper: connects, hands a live `query`
// and the rendered diagram to the pure runner, prints, and sets the exit code.
// The logic lives in runner.mjs so verify.test.mjs can prove it goes RED without a database.
//
//   Usage:  DATABASE_URL="postgres://…pooler…" node docs/data-tree/verify.mjs
//   Exit 0 = every claim reproduced. Exit 1 = at least one failed (UNVERIFIABLE counts).

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import pg from 'pg';
import * as checks from './checks.mjs';
import { runChecks, exitCodeFor } from './runner.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const url = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;
if (!url) {
  console.error('Set DATABASE_URL (Supabase pooler connection string) and retry.');
  process.exit(1);
}

async function main() {
  const client = new pg.Client({ connectionString: url });
  await client.connect();
  await client.query('SET statement_timeout = 0');

  const query = (sql) => client.query(sql);
  const html = readFileSync(join(here, checks.closure.file), 'utf8');
  // Machine-owned census snapshot. A missing/malformed file throws → caught by main().catch →
  // FAIL, never a silent skip of the census closure.
  const state = JSON.parse(readFileSync(join(here, checks.censusClosure.stateFile), 'utf8'));

  const results = await runChecks({ query, html, state, checks });
  await client.end();

  let gate = '';
  for (const r of results) {
    if (r.gate !== gate) { gate = r.gate; console.log(`\n${gate.toUpperCase()}`); }
    console.log(`  ${r.ok ? 'ok  ' : 'FAIL'} ${r.id}${r.msg ? ' — ' + r.msg : ''}`);
  }

  // Completeness: every declared check must have produced a result. A check silently dropped
  // from checks.mjs is otherwise indistinguishable from a check that passed.
  const expected = (checks.predicates?.length || 0) + (checks.plans?.length || 0) + (checks.deltas?.length || 0);
  const ran = results.filter((r) => ['predicate', 'plan', 'delta'].includes(r.gate)).length;
  if (ran !== expected) {
    console.error(`\nFAIL — expected ${expected} core checks, ${ran} ran. A check was dropped or failed to load.`);
    process.exit(1);
  }

  const code = exitCodeFor(results);
  const failed = results.filter((r) => !r.ok).length;
  console.log(`\n${code === 0 ? 'PASS — every claim reproduced.' : `FAIL — ${failed} check(s) failed.`}`);
  process.exit(code);
}

// A connection or load failure is a FAILURE, never a silent pass — no catch marks checks
// "skipped" and exits 0.
main().catch((e) => {
  console.error(`\nFAIL — verify ABORTED before it could check anything: ${e.message}`);
  process.exit(1);
});
