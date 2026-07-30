#!/usr/bin/env node
// docs/data-tree/verify.test.mjs
// The negative control for the gate itself. A gate only ever seen passing is
// indistinguishable from a gate that always passes. This drives the pure runner with a stub
// (no DB, no credentials) and proves each check goes RED for a deliberate break — one per
// failure class — then confirms the clean case is GREEN.
//
//   node docs/data-tree/verify.test.mjs      (exit 0 = the gate demonstrably gates)

import assert from 'node:assert';
import { runChecks, exitCodeFor } from './runner.mjs';
import * as realChecks from './checks.mjs';

let ran = 0;
const failures = [];
async function test(name, fn) {
  ran++;
  try { await fn(); console.log(`  ok   ${name}`); }
  catch (e) { failures.push(name); console.log(`  FAIL ${name} — ${e.message}`); }
}

// A representative spec with one check per category. Overridable per scenario.
const baseChecks = (over = {}) => ({
  predicates: [{ id: 'dup-guard', claim: 'no duplicates', sql: 'SELECT NOT EXISTS(... HAVING count(*)>1) AS ok' }],
  plans: [{ id: 'index-engaged', claim: 'uses index', sql: 'EXPLAIN SELECT ...',
            mustContain: ['Index Scan using idx_hydrology_waterbodies_geog'],
            mustNotContain: ['Seq Scan on hydrology_waterbodies'] }],
  deltas: [{ id: 'lookups', claim: '8 scans', expected: 8,
             actionSql: ['SELECT get_pir_report(74,$1)', 'SELECT get_parcel_env_findings(74,$1)'],
             countSql: "SELECT seq_scan+idx_scan AS n FROM pg_stat_xact_user_tables WHERE relname='parcels_staging'" }],
  closure: { file: 'diagram.html', liveTotalSql: 'SELECT count(*)::int AS n FROM nr_master',
             sumBranches: ['Attachment', 'Classes'],
             requiredBranchHeads: ['Identity', 'Attachment', 'Relation keys', 'Classes', 'Defects & fixes'] },
  censusClosure: { stateFile: 'state.json',
             liveClassifiedSql: 'SELECT count(*)::int AS n FROM nr_master',
             liveWiredSql: "SELECT count(*)::int AS n FROM nr_jointype WHERE join_type NOT IN ('J0_system','J13_non_parcel_domain','J14_genuine_orphan')" },
  ...over,
});

// Clean census snapshot: the four buckets partition nr_master (1208+16+1+1=1226) and
// wired matches the live parcel-reaching count. Overridable per scenario.
const baseState = (over = {}) => ({ classified: 1226, wired: 1208, system_tables: 16, non_parcel_domain: 1, genuine_orphans: 1, ...over });

// Well-formed rendered tree: children sum to the parent count, which equals the live total.
const goodHtml = `
<span class="code">Identity</span>
<span class="code">Attachment</span><span class="count">1,226 tables</span>
  <span class="fig">311 · 77.8M</span>
  <span class="fig">915 · 20.0M</span>
<span class="code">Relation keys</span>
<span class="code">Classes</span><span class="count">1,226 tables</span>
  <span class="fig">1226 · 96.7M</span>
<span class="code">Defects &amp; fixes</span>
`;

// Stub query. Routes by SQL shape; cfg mutates one thing per scenario.
function makeQuery(cfg = {}) {
  let snap = 0;
  return async (sql) => {
    if (/^\s*(BEGIN|ROLLBACK|COMMIT)/i.test(sql)) return { rows: [] };
    if (/pg_stat_xact_user_tables/.test(sql)) { snap++; return { rows: [{ n: cfg.xactCount ?? 8 }], fields: [{ name: 'n' }] }; }
    if (/nr_jointype/.test(sql)) return { rows: [{ n: cfg.liveWired ?? 1208 }], fields: [{ name: 'n' }] };  // census liveWiredSql
    if (/count\(\*\)::int AS n FROM nr_master/.test(sql)) return { rows: [{ n: cfg.liveTotal ?? 1226 }], fields: [{ name: 'n' }] };
    if (/^EXPLAIN/i.test(sql)) return { rows: [{ 'QUERY PLAN': cfg.planText ?? 'Index Scan using idx_hydrology_waterbodies_geog' }] };
    if (/get_pir_report|get_parcel_env_findings/.test(sql)) return { rows: [{}] };            // action, no scan here
    if (cfg.predShape === 'scalar') return { rows: [{ n: 4474 }], fields: [{ name: 'n' }] };   // the dor_parcel_id-style mistake
    return { rows: [{ ok: cfg.predOk ?? true }], fields: [{ name: 'ok' }] };
  };
}

const run = (cfg = {}, over = {}, html = goodHtml, state = baseState()) => runChecks({ query: makeQuery(cfg), html, state, checks: baseChecks(over) });
const idFailed = (rs, id) => rs.find((r) => r.id === id && !r.ok);

// ── The clean case must be GREEN (or every red below proves nothing) ─────────
await test('clean spec → all green, exit 0', async () => {
  const rs = await run();
  const reds = rs.filter((r) => !r.ok);
  assert.equal(reds.length, 0, `expected all green, got reds: ${reds.map((r) => r.id).join(', ')}`);
  assert.equal(exitCodeFor(rs), 0);
});

// ── One deliberate break per failure class, each must go RED ─────────────────
await test('predicate FALSE → dup-guard red, exit 1', async () => {
  const rs = await run({ predOk: false });
  assert.ok(idFailed(rs, 'dup-guard'), 'dup-guard should fail');
  assert.equal(exitCodeFor(rs), 1);
});

await test('scalar-shaped verify → UNVERIFIABLE red (Gate 1 gates, exit 1)', async () => {
  const rs = await run({ predShape: 'scalar' });
  const r = idFailed(rs, 'dup-guard');
  assert.ok(r, 'scalar-shaped predicate must fail');
  assert.match(r.msg, /UNVERIFIABLE/, 'must be rejected as UNVERIFIABLE, not silently passed');
  assert.equal(exitCodeFor(rs), 1);
});

await test('renamed/absent index in plan → index-engaged red', async () => {
  const rs = await run({ planText: 'Seq Scan on hydrology_waterbodies' });
  assert.ok(idFailed(rs, 'index-engaged'), 'plan-shape should fail when the index scan is gone');
  assert.equal(exitCodeFor(rs), 1);
});

await test('scan count 9 ≠ 8 → lookups red', async () => {
  const rs = await run({ xactCount: 9 });
  assert.ok(idFailed(rs, 'lookups'), 'a 9th lookup must fail the delta');
  assert.equal(exitCodeFor(rs), 1);
});

await test('dropped child row → closure children≠parent red', async () => {
  const dropped = goodHtml.replace('  <span class="fig">915 · 20.0M</span>\n', ''); // Attachment now sums 311
  const rs = await run({}, {}, dropped);
  assert.ok(idFailed(rs, 'closure:Attachment:children==parent'), 'omitted child must fail closure');
  assert.equal(exitCodeFor(rs), 1);
});

await test('child missing its row figure → rows-present red', async () => {
  const noRows = goodHtml.replace('1226 · 96.7M', '1226'); // count but no "· rows"
  const rs = await run({}, {}, noRows);
  assert.ok(idFailed(rs, 'closure:Classes:rows-present'), 'a dropped row-figure must fail');
});

await test('clipped branch head → branch-present red', async () => {
  const clipped = goodHtml.replace('<span class="code">Classes</span>', ''); // export dropped a branch
  const rs = await run({}, {}, clipped);
  assert.ok(idFailed(rs, 'branch-present:Classes'), 'a clipped branch must fail');
  assert.equal(exitCodeFor(rs), 1);
});

await test('render drifts from live total → parent≠live red', async () => {
  const rs = await run({ liveTotal: 1300 }); // DB grew, diagram still says 1,226
  assert.ok(idFailed(rs, 'closure:Attachment:parent==live'), 'stale render must fail against live');
  assert.equal(exitCodeFor(rs), 1);
});

// ── Census closure: the exact class a status report shipped (wired absorbed J0/J13) ──────────
await test('census wired absorbs J0/J13 → partition + wired-vs-live red', async () => {
  const rs = await run({}, {}, goodHtml, baseState({ wired: 1225 })); // "everything but J14" — the bug
  assert.ok(idFailed(rs, 'census:buckets-partition-classified'), 'absorbing a category must break the partition');
  assert.ok(idFailed(rs, 'census:wired==live'), 'and must disagree with the live parcel-reaching count');
  assert.equal(exitCodeFor(rs), 1);
});

await test('census state stale vs live classified → red', async () => {
  const rs = await run({ liveTotal: 1300 }, {}, goodHtml, baseState()); // DB grew, state.json not regenerated
  assert.ok(idFailed(rs, 'census:classified==live'), 'stale state must fail against live nr_master');
  assert.equal(exitCodeFor(rs), 1);
});

// ── Execution failures, not just answer failures (the two gaps) ──────────────
await test('query throws (DB failure at query time) → red, not skipped', async () => {
  const throwing = async () => { throw new Error('connection refused'); };
  const rs = await runChecks({ query: throwing, html: goodHtml, checks: baseChecks() });
  assert.ok(rs.some((r) => !r.ok), 'a throwing query must not pass');
  assert.equal(exitCodeFor(rs), 1);
});

await test('real spec is complete — no check silently dropped', () => {
  // Pinned manifest: adding/removing a check is a deliberate act that updates this.
  // Predicates now: 6 original + fabricated-tables-stay-dropped (regression guard, green) +
  // report-sources-provenance-ratchet (green at baseline 27) + marine-coverage-gap-is-null +
  // no-county-literal-in-report-path + fragment-union-owner-address-invariant (fragment-fix guard) +
  // fact-index-corroboration-requires-independence (guard on the derives_from lineage) +
  // enumeration-closure-{every-geometry-layer-registered, no-dangling-registered-layer} (RED by design:
  // registration-as-rule closure — 7 unregistered layers + 2 dangling rows, the anti-drift guard) +
  // geometry-srid-metadata-not-lying (DEF-005 rule form — 38 base tables report srid=0 while rows are 4326) +
  // active-repair-defects-are-harness-tracked (the registry-consulted-by-harness guard; RED on DEF-017/020/021).
  // The stub exercises runner shape only, so the live-data predicates don't gate this self-test.
  const manifest = { predicates: 17, plans: 1, deltas: 1 };
  assert.equal(realChecks.predicates.length, manifest.predicates, 'predicate count changed — update the manifest on purpose');
  assert.equal(realChecks.plans.length, manifest.plans, 'plan count changed');
  assert.equal(realChecks.deltas.length, manifest.deltas, 'delta count changed');
  assert.ok(realChecks.closure?.sumBranches?.length > 0, 'closure config missing');
  assert.ok(realChecks.censusClosure?.liveWiredSql && realChecks.censusClosure?.liveClassifiedSql, 'censusClosure config missing');
  const all = [...realChecks.predicates, ...realChecks.plans, ...realChecks.deltas];
  const ids = all.map((c) => c.id);
  assert.equal(new Set(ids).size, ids.length, 'duplicate check id');
  for (const p of realChecks.predicates) assert.match(p.sql, /AS ok\b/i, `predicate ${p.id} must return a boolean "AS ok"`);
  for (const d of realChecks.deltas) assert.ok(d.actionSql?.length && /pg_stat_xact_user_tables/.test(d.countSql) && Number.isInteger(d.expected), `delta ${d.id} malformed or not txn-local`);
});

console.log(`\n${failures.length === 0 ? `PASS — ${ran} controls, the gate demonstrably goes red.` : `FAIL — ${failures.length}/${ran} controls did not behave.`}`);
process.exit(failures.length === 0 ? 0 : 1);
