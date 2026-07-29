# data-tree — the live layer of the Data Tree Anchor

The anchor (`docs/DATA_TREE_ANCHOR.md`) is hand-written narrative + query-verified facts.
The **numbers that change as tables are added** live in a generated block inside it, between:

```
<!-- DATA-TREE:BEGIN -->
… generated census …
<!-- DATA-TREE:END -->
```

Everything outside those markers is prose you edit by hand. Everything inside is machine-owned.

## Refresh it (pick one)

**One command (writes the file for you):**

```bash
DATABASE_URL="postgres://…supabase-pooler…" node docs/data-tree/build.mjs
```

Rewrites the census block in the anchor **and** `state.json`. Only dependency is `pg`
(`npm i pg`). Uses the pooler and sets `statement_timeout = 0` in-session.

**No Node (Supabase SQL editor / psql):**

Run `docs/data-tree/refresh.sql`. It returns the census block as markdown — paste it
between the markers.

## What the numbers mean

- **Wire into the system** — populated tables with a resolvable join route (`nr_jointype`, any route except J14).
  - *parcel-linked* vs *non-parcel domain* (`agent_license_status` describes people, not land — reachable, but not via a parcel).
- **Genuine orphans** — `J14`: no key/spatial/area path exists at all. Today: `sjc_plat_index` (a text index by design).
- **Empty** — tables with no rows yet; not orphans. As they load they get classified and, historically, wire in at ~1,225/1,226.

These are **live**. An orphan resolved or a table loaded moves them — so read them from here, never from memory.

## Self-check — `verify.mjs`

A `VERIFIED` tag only means "someone ran a query," and a wrong query passes. `verify.mjs`
re-executes each claim's verify against live data and **fails the build on any mismatch**, so
a wrong tag can't survive a run. It caught nothing you'd want it to miss only if the verifies
are written to be falsifiable — hence the rule.

```bash
DATABASE_URL="postgres://…pooler…" node docs/data-tree/verify.mjs   # exit 1 on any failure
```

**Three gates** (see `checks.mjs`):

1. **Every node has a verify that can fail.** A predicate must return exactly one boolean
   column `ok`. Anything returning a scalar-to-match is rejected as *unverifiable* — that's
   the class the `dor_parcel_id` "4,474 dupes" error belonged to: reproducible **and** wrong,
   because re-running a bad query re-derives the bad answer. The falsifiable form
   (`NOT EXISTS (… HAVING count(*) > 1)`) can only pass if the claim is true.
2. **Closure runs on the rendered diagram, not the DB.** The "sums exactly to 1,226" failures
   were a *rendering* omission — the database was never wrong. So the check parses
   `diagram.html`, sums each branch's child figures, and asserts they equal the live total;
   it also asserts every branch head is present (a clipped export drops one).
3. **Timing asserts plan shape, never milliseconds.** Lookup times swing >10× on scan
   position before cache — a ms threshold goes red on noise and gets muted. The FIXED tag on
   the geography index rests on `Index Scan using idx_hydrology_waterbodies_geog`, not on a
   sampled `31.6 ms`.

A fourth kind of verify, for the parcel-lookup cost:

- **scan-count delta.** Wrap the entry points in one transaction and read
  `pg_stat_xact_user_tables` — the **transaction-local** counter, immune to concurrent traffic
  (the global `pg_stat_user_tables` would flake red under load — the millisecond mistake again).
  Measured 2026-07-28: `get_pir_report` = 4, `get_parcel_env_findings` = 4, full answer = **8**,
  transaction-local. Replaced a `Filter: (parcel_id` plan-check that was wrong twice —
  parameterised on which parcel, and designed to go red *when the index lands* (breaking the
  build on an improvement). The count is an integer, deterministic, and **stable across adding
  the index** (count doesn't change, only cost).

Adding a claim? Write its verify as a predicate, plan-line, closure invariant, or scan-delta,
and ask the one question: *can this return red if the claim is false?* If not, it isn't a verify.

### Prove it goes red — `verify.test.mjs`

A gate only ever seen passing is indistinguishable from a gate that always passes. So the
runner is a pure function (`runner.mjs`) driven by an injected `query`, and `verify.test.mjs`
feeds it a stub to fire **one deliberate break per failure class** — predicate false,
scalar-shaped verify (must be `UNVERIFIABLE` and exit 1, not a warning), renamed index,
scan-delta off by one, dropped child, missing row-figure, clipped branch, stale-vs-live — and
confirms each goes red plus the clean case green. No database, no credentials:

```bash
node docs/data-tree/verify.test.mjs     # 9 controls; exit 0 means the gate demonstrably gates
```

Run this **before** wiring the CI hook. A gate installed before it's been seen to fail is a
green light nobody has tested.

> Known limit (stated, not hidden): a predicate can be boolean-shaped and still
> self-consistently wrong — the harness enforces the *form*, not the *reasoning*. Mitigation is
> the authoring rule (existence/`HAVING` predicates, not arithmetic identities) plus review.

## Files

| file | role |
|---|---|
| `../DATA_TREE_ANCHOR.md` | the document; narrative + the generated census block |
| `build.mjs` | regenerates the census block + `state.json` from the live DB |
| `verify.mjs` | **self-check** — connects, runs the runner against live data, sets exit code |
| `runner.mjs` | the pure engine (injected `query` + `html` → results); no DB/exit, so it's testable |
| `checks.mjs` | the verifiable claims: predicates, plan signatures, scan-deltas, closure config |
| `verify.test.mjs` | **negative control** — stub-drives the runner, proves each check goes red (no DB) |
| `refresh.sql` | census query, runtime-agnostic; returns paste-ready markdown |
| `state.json` | last generated snapshot (machine-readable) |
| `diagram.html` | the root→branch visual. **Snapshot**, not auto-generated — regenerate when the tree's *shape* changes, not just its counts |

Both `build.mjs` and `verify.mjs` need `pg` (`npm i pg`) and the pooler `DATABASE_URL`.
Run `verify.mjs` in CI / pre-commit so a drift or a bad edit fails the build, not a reader.

## Keeping it current automatically

`build.mjs` is safe to run on a schedule. Hook it to the existing refresh cadence
(e.g. after `master_refresh`) or a Windows Task Scheduler job so the census tracks the
data without anyone remembering to run it.
