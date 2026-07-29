#!/usr/bin/env node
// docs/data-tree/roz-fixtures.mjs
// Roz test runner — LAYER 1 (payload assertions, NO model calls). Runs the DB function
// roz_fixtures_layer1(), which for each row in roz_test_fixtures evaluates every key in
// expected_status against the live RPC (get_parcel_flood_zone / marine / wind / tax-deed /
// get_county_coverage) and reports mismatches. Catches the DATA side of both live incidents
// (Orange "not loaded", St Pete flood coverage gap) and the marine coverage-direction pair.
//
//   DATABASE_URL="postgres://…pooler…" node docs/data-tree/roz-fixtures.mjs
//   exit 0 = every fixture's payload matches expected_status; exit 1 = a mismatch.
//
// DB-backed, so it belongs in the credentialed (Tier-2) CI job next to verify.mjs — NOT the no-DB
// Tier-1. LAYER 2 (narration: must_contain / must_not_contain, model calls, run on demand /
// pre-release) is a separate runner still to build.

import pg from 'pg';

const url = process.env.DATABASE_URL || process.env.SUPABASE_DB_URL;
if (!url) { console.error('Set DATABASE_URL (Supabase pooler connection string) and retry.'); process.exit(1); }

const client = new pg.Client({ connectionString: url });
try {
  await client.connect();
  await client.query('SET statement_timeout = 0');
  const { rows } = await client.query(
    'SELECT case_name, ok, mismatches FROM roz_fixtures_layer1() ORDER BY ok, case_name');
  for (const r of rows) {
    console.log(`  ${r.ok ? 'ok  ' : 'FAIL'} ${r.case_name}${r.ok ? '' : ' — ' + JSON.stringify(r.mismatches)}`);
  }
  const failed = rows.filter((r) => !r.ok).length;
  console.log(`\n${failed === 0
    ? `PASS — ${rows.length} fixtures, payload matches expected_status.`
    : `FAIL — ${failed}/${rows.length} fixtures mismatched.`}`);
  process.exit(failed === 0 ? 0 : 1);
} catch (e) {
  console.error(`\nFAIL — roz-fixtures ABORTED before it could check: ${e.message}`);
  process.exit(1);
} finally {
  try { await client.end(); } catch { /* already closed */ }
}
