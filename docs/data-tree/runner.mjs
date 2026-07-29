// docs/data-tree/runner.mjs
// Pure verification engine — no DB connection, no filesystem, no process.exit.
// Takes an injected `query` (any {rows,fields}-returning async fn) and the rendered `html`,
// returns a flat list of {id, gate, ok, msg}. This separation is what lets verify.test.mjs
// drive it with a stub and prove it goes RED — the negative control the gate itself needs.

export async function runChecks({ query, html, state, checks }) {
  const results = [];
  const add = (id, gate, ok, msg) => results.push({ id, gate, ok, msg });

  // ── Gate 1: predicates. Must return exactly one BOOLEAN column `ok`.
  // Anything else is rejected as UNVERIFIABLE and counts as a FAILURE (not a warning),
  // so a node with no usable verify cannot sail through.
  for (const p of checks.predicates || []) {
    let res;
    try { res = await query(p.sql); }
    catch (e) { add(p.id, 'predicate', false, `query errored: ${e.message}`); continue; }
    const cols = (res.fields || []).map((f) => f.name);
    if (!res.rows || res.rows.length !== 1 || cols.length !== 1 || cols[0] !== 'ok') {
      add(p.id, 'predicate', false,
        `UNVERIFIABLE — verify must return exactly one column named "ok" (got [${cols.join(', ')}]); a scalar-to-match is not a verify`);
      continue;
    }
    const v = res.rows[0].ok;
    if (typeof v !== 'boolean') {
      add(p.id, 'predicate', false,
        `UNVERIFIABLE — "ok" must be boolean, got ${typeof v} (${v}); rewrite as a falsifiable predicate`);
      continue;
    }
    add(p.id, 'predicate', v === true, v === true ? p.claim : `predicate is FALSE — ${p.claim}`);
  }

  // ── Gate 3: plan shape. Assert the plan line; never milliseconds.
  for (const pl of checks.plans || []) {
    let text;
    try {
      const r = await query(pl.sql);
      text = r.rows.map((x) => x['QUERY PLAN']).join('\n');
    } catch (e) { add(pl.id, 'plan', false, `EXPLAIN errored: ${e.message}`); continue; }
    const missing = (pl.mustContain || []).filter((s) => !text.includes(s));
    const present = (pl.mustNotContain || []).filter((s) => text.includes(s));
    const ok = missing.length === 0 && present.length === 0;
    add(pl.id, 'plan', ok, ok ? pl.claim
      : `plan shape changed — ${[
          missing.length ? `missing: ${missing.map((s) => JSON.stringify(s)).join(', ')}` : '',
          present.length ? `unexpected: ${present.map((s) => JSON.stringify(s)).join(', ')}` : '',
        ].filter(Boolean).join('; ')}`);
  }

  // ── Scan-count deltas, measured TRANSACTION-LOCALLY. pg_stat_xact_user_tables counts only the
  // current transaction, so concurrent app traffic can't inflate it. Wrap the actions + count in
  // one transaction and roll back (the functions are read-only). Deterministic integer; stable
  // when an index is added (count unchanged, only cost) — no false-fail on a fix.
  for (const d of checks.deltas || []) {
    let count;
    try {
      await query('BEGIN');
      for (const a of d.actionSql) await query(a);
      count = Number((await query(d.countSql)).rows[0]?.n ?? NaN);
      await query('ROLLBACK');
    } catch (e) {
      try { await query('ROLLBACK'); } catch { /* already aborted */ }
      add(d.id, 'delta', false, `delta measure errored: ${e.message}`); continue;
    }
    add(d.id, 'delta', count === d.expected,
      count === d.expected ? `${d.claim} (measured ${count}, txn-local)`
        : `scan count ${count} ≠ expected ${d.expected} — a lookup was added or removed`);
  }

  // ── Gate 2: closure on the RENDERED tree. children == rendered parent, AND parent == live.
  // The two-sided form catches clipping even when the DB is unreachable, and doesn't assume
  // every branch equals the global count.
  if (checks.closure) {
    const c = checks.closure;
    const doc = html.replace(/&amp;/g, '&');
    const heads = c.requiredBranchHeads;

    for (const h of heads) {
      const present = doc.includes(`>${h}<`);
      add(`branch-present:${h}`, 'closure', present, present ? 'rendered' : 'branch missing from render — export may be clipped');
    }

    let live = NaN;
    try { live = Number((await query(c.liveTotalSql)).rows[0].n); }
    catch (e) { add('closure:live-total', 'closure', false, `live total errored: ${e.message}`); }

    for (const head of c.sumBranches) {
      const start = doc.indexOf(`>${head}<`);
      if (start < 0) { add(`closure:${head}`, 'closure', false, 'branch not found'); continue; }
      const after = heads.map((h) => doc.indexOf(`>${h}<`, start + 1)).filter((i) => i > start);
      const slice = doc.slice(start, after.length ? Math.min(...after) : doc.length);

      const pm = slice.match(/class="count">([\d,]+)/);
      const parent = pm ? Number(pm[1].replace(/,/g, '')) : NaN;

      let sum = 0; const malformed = [];
      for (const m of slice.matchAll(/class="fig">([^<]*)</g)) {
        const mm = m[1].trim().match(/^([\d,]+)\s*·\s*(\S.*)$/); // "count · rows"
        if (!mm) { malformed.push(m[1].trim()); continue; }
        sum += Number(mm[1].replace(/,/g, ''));
      }

      const kids = sum === parent;
      add(`closure:${head}:children==parent`, 'closure', kids,
        kids ? `children ${sum} == parent ${parent}` : `children ${sum} ≠ rendered parent ${parent} — a row is omitted or clipped`);
      const pl = parent === live;
      add(`closure:${head}:parent==live`, 'closure', pl,
        pl ? `parent ${parent} == live ${live}` : `rendered parent ${parent} ≠ live ${live}`);
      add(`closure:${head}:rows-present`, 'closure', malformed.length === 0,
        malformed.length === 0 ? `all children carry a row figure` : `children with a count but no row figure: ${malformed.join(' | ')}`);
    }
  }

  // ── Census closure on the machine-owned state.json. Guards the §1a block against a summary
  // figure absorbing a category (the "1,225 wired" error) and stale render vs live. Live counts
  // are recomputed here, independent of the generator, so a redefined "wired" goes RED.
  if (checks.censusClosure && state) {
    const cc = checks.censusClosure;
    let liveClassified = NaN, liveWired = NaN;
    try { liveClassified = Number((await query(cc.liveClassifiedSql)).rows[0].n); }
    catch (e) { add('census:live-classified', 'closure', false, `live classified errored: ${e.message}`); }
    try { liveWired = Number((await query(cc.liveWiredSql)).rows[0].n); }
    catch (e) { add('census:live-wired', 'closure', false, `live wired errored: ${e.message}`); }

    const wired = Number(state.wired), sys = Number(state.system_tables),
          np = Number(state.non_parcel_domain), orph = Number(state.genuine_orphans),
          classified = Number(state.classified);

    const partition = wired + sys + np + orph === classified;
    add('census:buckets-partition-classified', 'closure', partition,
      partition ? `wired+system+non_parcel+orphan ${wired}+${sys}+${np}+${orph} == classified ${classified}`
        : `buckets ${wired}+${sys}+${np}+${orph} = ${wired + sys + np + orph} ≠ classified ${classified} — a category is absorbed or dropped`);

    const wiredOk = wired === liveWired;
    add('census:wired==live', 'closure', wiredOk,
      wiredOk ? `state wired ${wired} == live parcel-reaching ${liveWired}`
        : `state wired ${wired} ≠ live parcel-reaching ${liveWired} — generator definition drifted (J0/J13 absorbed?)`);

    const classOk = classified === liveClassified;
    add('census:classified==live', 'closure', classOk,
      classOk ? `state classified ${classified} == live nr_master ${liveClassified}`
        : `state classified ${classified} ≠ live nr_master ${liveClassified} — state.json is stale, regenerate`);
  }

  return results;
}

export const exitCodeFor = (results) => (results.some((r) => !r.ok) ? 1 : 0);
