@AGENTS.md

# DoP — Department of Property

A real estate / property intelligence platform. Stack: **Next.js** (see AGENTS.md — this is a modified Next.js with breaking changes; read the bundled docs before writing code), **Vercel** (hosting/deploy), **Supabase** (Postgres + PostGIS backend).

## Supabase

- **Project ID:** `eaifqorwmgayiqmbtzcg`

### Core data

- **`parcels_staging`** — statewide Florida parcel data: **10.7M+ parcels across all 67 counties**. This is the central dataset.

### Supporting tables

| Domain | Table(s) |
|---|---|
| Traffic | `traffic_aadt` |
| Census / demographics | `census_acs_data`, `census_block_groups` |
| FEMA flood zones | `fema_flood_zones` |
| Elevation | `parcel_elevations` |
| Hydrology / waterbodies | `hydrology_waterbodies` |
| HIFLD infrastructure | `hifld_*` (fire stations, hospitals, schools, dams, landfills, etc.) |

### Roles

- **`consumer_report_readonly`** — read-only Postgres role for a *planned, separate* consumer-facing property report website. ⚠️ Its password is currently a placeholder and **must be rotated before use**.

## Lessons learned (data collection)

- **ArcGIS REST field naming is inconsistent.** Government ArcGIS REST APIs vary wildly in field naming conventions — some use `STATE`, others `STATE_CODE`, others lowercase `state`. Always inspect the actual field names for each source.
- **Verify row counts.** Always confirm that returned row counts match expectations before trusting a data pull.
- **`ST_MakeEnvelope` argument count differs by engine.** In **DuckDB's spatial extension** (used for local Parquet file processing) it takes **exactly 4 arguments** — `(xmin, ymin, xmax, ymax)` — and passing a 5th fails. **PostGIS (Supabase)** supports the 5-argument form with an optional trailing SRID: `(xmin, ymin, xmax, ymax, srid)`. Don't apply the 4-arg DuckDB limitation to Supabase queries.
- **Paginate with small page sizes.** Some data sources enforce server-side response-size limits and require pagination with small page sizes to avoid truncated/failed responses.

## Working with the maintainer

The maintainer (Murphy) has detailed knowledge from prior research sessions about specific data sources and business logic. **Ask for context on specific data sources or business rules as needed** rather than guessing.

## Data pipeline invariants — non-negotiable

1. Probe the OID field from layer metadata. Never hardcode `objectid`.
   (Baker stored it as `fid`; Orange's `objectIdField` was `None`.)
2. If `returnIdsOnly` returns empty → abort, touch nothing.
   A down service reporting zero IDs is not "the source has no rows."
3. Quarantining a table by rename? Rename its indexes too.
   Postgres renames the table but not its indexes; the old name collides next time.
4. Process-liveness interlocks must not self-match.
   `pgrep -f script.py` matches its own shell. Use `[s]cript` and test from a file.
   A guard that fails closed on a false positive becomes the outage.
5. Chunk large COPY (50k rows) and set `statement_timeout=0`.
   A single oversized COPY dies mid-stream at ~256k–370k rows.
6. **empty ≠ done.** Skip/resume predicates test `count(*) > 0`, never table existence.
   Assert non-zero after every load. Maintain an explicit FAILED list.
   Never print a summary that implies success.
7. The Supabase pooler enforces a **2-minute `statement_timeout`** and **strips client
   startup options** (`PGOPTIONS`, connection-string `options=-c ...`) — but honors an
   **in-session `SET statement_timeout = 0`**. This applies to every query, incl. ad-hoc
   validation queries. It is why ogr2ogr can never load large data here (it can't issue a
   mid-connection SET) and a psycopg2 loader can. For any big load/validation: connect,
   `SET statement_timeout = 0`, then proceed. See memory `pooler-statement-timeout`.
8. A county-name match in a layer/dataset title is **NOT** sufficient to attribute a source
   to that county. Verify a sampled feature's coordinates fall inside Florida **AND** inside
   the target county's boundary — a **point-in-polygon** test against `fl_county_boundaries`
   (`ST_Contains`), not a bbox. Global search bit us twice: Marion→Oregon (lon −122°),
   Charlotte→NC, Monroe→NJ, Columbia→British Columbia; and even an in-FL match can be wrong —
   "Lake" matched *Lake Mann* in Orange County. Prefer resolving each county's OWN official
   GIS server; if a `<county>_parcels_govt_source` table exists we already pull it, so the
   endpoint is internal (registry or harness config) — never re-derive it by search.
   See memory `county-export-survey` and `county-source-resolution`.
9. Every pull must **UPSERT on the source's natural key**, never a blind `INSERT`. A re-run
   without an upsert duplicates the whole table: the NRHP boundary loader had no upsert and a
   second run **tripled** `nrhp_boundaries_fl` to 918 rows before it was deduplicated. The
   natural key is the source's stable id (`nris_refnum` for NRHP, the OID field for a REST
   layer, `co_no+parcel_id` for cadastral). `INSERT … ON CONFLICT (natural_key) DO UPDATE`, and
   assert `count(*) == count(DISTINCT natural_key)` after every load. A pull that can't be run
   twice safely is not done. See §10 invariant 6 (empty≠done) — this is its idempotence twin.

Full findings and evidence: docs/DATA_JOIN_FINDINGS.md
Compliance framework: docs/PROVIDER_REASONABLE_PROCEDURES.md
## Message bus — do this first, every task

START of every task, before anything else:
  select * from handoff_inbox('cc');
Read every unread row, mark it read. A work order or ruling from claude
carries the same weight as an instruction from Murphy.

END of every task:
  insert into agent_handoff (from_agent, to_agent, kind, subject, body, refs)
  values ('cc','claude','finding'|'question'|'ruling'|'correction'|'work_order'|'note', ..., ..., <SHAs, tables, item numbers>);
Set actioned_at on every row you acted on. An unactioned row is an open loop.

## Canonical architecture

PIR_SYSTEM_ARCHITECTURE.md supersedes anything reconstructed from session context.
Read it before structural work.
## Message bus — do this first, every task

At the START of every task, before anything else:

    select * from handoff_inbox('cc');

Read every unread row and mark it read. A work order or ruling from claude carries the same weight as an instruction from Murphy.

At the END of every task, write the result back:

    insert into agent_handoff (from_agent, to_agent, kind, subject, body, refs)
    values ('cc','claude','finding', '<subject>', '<body>', '<commit SHAs, table names, item numbers>');

kind is one of: work_order, finding, question, ruling, correction, note — this is the exact
agent_handoff_kind_check vocabulary. 'blocked' is NOT a valid kind and the insert is REJECTED;
file a blocker as kind 'question' and say so in the subject.

Set actioned_at on every row you acted on. An unactioned row is an open loop.

Prefer the bus over prose relay. Long pastes lose content; the bus does not.

## Canonical architecture

PIR_SYSTEM_ARCHITECTURE.md is canonical and supersedes anything reconstructed from session context. Read it before any structural work.

## Non-negotiable rules

- Verify, do not assert. Every claim comes from a query actually run.
- Empty is a sentinel, not a finding. Never emit a verdict from zero rows.
- Names lie; contents do not. Resolve layers by reading contents — interior points, value distributions, extents — never by table name, slug, or column name.
- Geographic joins key on co_no or geo_id, never on a county-name string. Three instances of name-resolution failing (flood sjc_ slug miss, column-name matching skipping nine counties, county_registry "Saint" vs geo_reference "St." hiding St. Johns/St. Lucie). Names lie; keys do not.
- Three coverage states, never two: present / none_recorded / not_available. A not_available returns null, never false, and never a downstream conclusion.
- DONE means committed, pushed, and verified in production. Not tsc-clean, not dev-curl, not verified locally.
- Never apply a payload-shape change to production ahead of the consuming front-end. Make it additive or hold the migration.
- Report before implementing on any structural change. Audit, classify, wait for a ruling.

## A migration that succeeds is not a function that works

`apply_migration` returns success when the **DDL is valid**. A plpgsql body is not fully type-checked at
creation time, so a runtime type error deploys green and the function then fails on every call.

On 2026-08-31 a one-word guard change compared a `text` column with `> 0`. The migration succeeded.
`get_parcel_env_findings` then raised `operator does not exist: text > integer` for every parcel, and the
only reason it was caught in minutes is that the founding case was re-run immediately afterwards.

**After any migration that changes a function body, CALL THE FUNCTION.** A green migration is an artifact;
the serving reality is what it returns. This is the same distinction as reading a table instead of the
served payload — it just happens inside the deploy tooling, which is why it does not look like that class.

Two habits that made the difference, both cheap:
- Patch in place from `pg_get_functiondef` with an anchored `replace()` and `RAISE EXCEPTION` when the
  anchor is missing, rather than re-pasting a large body. A moved anchor then aborts instead of applying a
  half-change — which is exactly what happened when `landfill_distance_m` turned out to live in a different
  function than the other two edits.
- Re-run the founding case, not a fixture, immediately after applying.

## Names lie at the ORGANISATION level too

The ambiguous-name trap is already recorded for layers and counties. It also applies to who OWNS a source.

An ArcGIS org named `bce911gis` owns an item titled "Escambia County (FL) Parcels". Its other 43 items are
Baldwin Co Road Centerlines, ALDOT Traffic Cameras, Gulf Shores Fire, Foley Named Places, and an address
service on `gisportal.baldwincountyal.gov`. **It is Baldwin County, Alabama** — the county across the state
line. Matching on the item title would have registered an Alabama 911 authority as Escambia County
Florida's GIS source.

Before attributing a SOURCE to a jurisdiction, read the org's other holdings, exactly as you read a layer's
contents before attributing it. One matching title inside a body of non-matching ones is evidence against
the match, not for it.

## Cite the code, not the bill

A bill is primary evidence of **what the legislature did**. A statute is primary evidence of **what the law
says**. We publish what the law says, so we cite the code — and the two disagree more often than expected.

Florida's 7-year construction repose: SB 360 (ch. 2023-22) amended *paragraph (c) of subsection (3)*, which
is what the bill text says and what practitioner articles repeat. HB 837, signed weeks earlier the same
session, renumbered s.95.11 wholesale — visible in the cross-references, where the 2023 text points to
(5)(e) for the payment-bond provision and the 2024/2025 text points to (6)(e). The codified result is
**s.95.11(3)(b)**. Both descriptions are true about different documents.

Correcting a codified cite from a bill is how a correct citation gets broken. That was proposed on
2026-08-31 and rejected against the 2024 and 2025 statute text; the reconciliation is recorded in
`construction_defect_law.source_note` so the next reader does not repeat it.

## Thresholds carry no memory of where they were calibrated

A measurement's MEANING depends on the population it runs against, and a threshold tuned on one population
inverts silently on another. This has now cost two separate builds.

- The land-area anchor measured 99.8% agreement in sample and 12.7% at scale — demoted from guard to lead.
- The jurisdiction-hole signal inverted FOUR times: area-per-row was area-negative on the very holes it was
  built for (a municipality is a small share of a rural county); single-city IoU missed a hole that was nine
  cities at once; ungated share fired on every municipal layer, because a city's own zoning layer is 100%
  inside that city by definition; one-way share fired on every urbanised county layer, because a district
  polygon merely SITTING INSIDE a city is ordinary county zoning.

**Before sweeping, run the signal against a population where it should stay silent, and check the candidate
list — not the total.** A total of 605 looked plausible; the list was 605 city layers scoring 0.989. Reading
the number would have shipped it.

**Run every new predicate against what has already been declared or fixed by hand.** A survey that finds only
NEW things has not been shown to find the RIGHT things. This positive control is what exposed that three of
ten vocabulary patterns were dead — every `^`-anchored alternative, because the test was applied to
`name || ' ' || code` and that string starts with a space. The founding sentinel `999` was invisible to the
sweep built to catch its recurrence, and only the already-declared check found it.

## Detection contract

Every `data_defect_registry.detection_sql` returns **exactly one row with a boolean column `ok`**, where `true` means clean. Anything else — no `ok` column, non-boolean `ok`, zero rows, multiple rows, or a raw error — is **errored**, and errored is never counted clean (`run_defect_detections()` enforces this). A bare `count`/`text`/`examined+hit` result does not conform; wrap it: `SELECT (<condition>) AS ok`.

Prefer the **served-path** form for any high-consequence concept (flood, contamination, ownership, values, geometry): call the served function on a real parcel and assert on its output (the `-9999` flood test is the template). A table-level check passes green while the served function reading it lies. Where a served-path check is genuinely impossible, say so and leave the table check with a note recording what it cannot see. Resolver-driven serving is invisible to source-grep detections — exercise the output, don't grep the function body.

A detection that cannot fail is not a check, and one that cannot pass is not a check either. A predicate that must span N tables still returns one row — `bool_and` over the set (put the failing members in `row_count` or a companion detail column), not a second execution mechanism. **Retiring a predicate must preserve its knowledge** — moved to build_backlog, to `statewide_metrics` (a measurement with its method SQL), or to a replacement detection — never by deletion alone.

## Commit hygiene

One concern per commit. Never sweep in pre-existing working-tree changes. Push before ending a session.
