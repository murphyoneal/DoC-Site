#!/usr/bin/env node
// scripts/check-client-rpc.mjs
// CI guard — "record, not memory." A client bundle must never call a Postgres function the
// browser cannot execute. After the anon-EXECUTE revoke, the report/maintenance surface is
// server-only: it is called from API routes with the service_role client. A `.rpc('<fn>')`
// in a `'use client'` module would 403 at runtime for anon (or silently leak if re-granted),
// so this fails the build the day someone adds one back. The frontend-is-clean confirmation
// was a memory; this makes it a check.
//
// The REVOKED set is a SNAPSHOT, not a live read (Tier 1 CI: no DB, no secret). Regenerate it
// whenever grants change, from project eaifqorwmgayiqmbtzcg:
//
//   SELECT p.proname
//   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
//   WHERE n.nspname = 'public' AND p.prokind = 'f'
//     AND NOT has_function_privilege('anon', p.oid, 'EXECUTE')
//   ORDER BY 1;
//
// (A DB-backed job recomputing this live is Tier 2 — deferred until a read-only CI credential
//  exists; see .github/workflows/data-integrity.yml.)

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';

// Functions where has_function_privilege('anon', …, 'EXECUTE') = false. Snapshot 2026-07-29.
const REVOKED = new Set([
  'assistant_cost_report', 'assistant_cost_since', 'assistant_maybe_alert',
  'get_area_findings', 'get_encumbered_parcels', 'get_hazard_map_layer', 'get_nearby_amenities',
  'get_parcel_archaeological_risk', 'get_parcel_attestations', 'get_parcel_containment_findings',
  'get_parcel_encumbrances', 'get_parcel_env_findings', 'get_parcel_env_findings_core',
  'get_parcel_planned_works', 'get_parcel_restrictions', 'get_parcel_roof_lifespan',
  'get_parcel_sales_agent', 'get_pir_map_geojson', 'get_pir_parcel_closeup', 'get_pir_report',
  'get_site_intelligence', 'get_site_intelligence_batch',
  'rebuild_contractor_name_index', 'refresh_permit_contractor_match',
]);

const ROOTS = (process.env.RPC_GUARD_ROOTS || 'app,lib,components,src').split(',').filter(Boolean);
const EXTS = new Set(['.ts', '.tsx', '.js', '.jsx', '.mjs']);
const IS_CLIENT = /^\s*['"]use client['"]\s*;?\s*$/m; // the directive that ships a module to the browser
const RPC = /\.rpc\(\s*['"`]([A-Za-z0-9_]+)['"`]/g;

const files = [];
function walk(dir) {
  let entries;
  try { entries = readdirSync(dir); } catch { return; } // missing root is fine
  for (const e of entries) {
    if (e === 'node_modules' || e === '.next' || e.startsWith('.')) continue;
    const p = join(dir, e);
    if (statSync(p).isDirectory()) walk(p);
    else if (EXTS.has(extname(p))) files.push(p);
  }
}
for (const r of ROOTS) walk(r);

let clientFiles = 0;
const violations = [];
for (const f of files) {
  const src = readFileSync(f, 'utf8');
  if (!IS_CLIENT.test(src)) continue; // server components / API routes may call any RPC
  clientFiles++;
  for (const m of src.matchAll(RPC)) {
    if (REVOKED.has(m[1])) {
      violations.push(`${f}: .rpc('${m[1]}') — the browser cannot execute this function (server-only since the anon revoke)`);
    }
  }
}

if (violations.length) {
  console.error(`FAIL — ${violations.length} client bundle(s) call a revoked (server-only) function:`);
  for (const v of violations) console.error('  ' + v);
  console.error('\nMove the call to an API route using the service_role client, and have the client fetch that route.');
  process.exit(1);
}
console.log(`ok — no 'use client' bundle names a revoked function (${clientFiles} client file(s) of ${files.length} scanned).`);
