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
  values ('cc','claude','finding'|'question'|'blocked', ..., ..., <SHAs, tables, item numbers>);
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

kind is one of: finding, question, blocked.

Set actioned_at on every row you acted on. An unactioned row is an open loop.

Prefer the bus over prose relay. Long pastes lose content; the bus does not.

## Canonical architecture

PIR_SYSTEM_ARCHITECTURE.md is canonical and supersedes anything reconstructed from session context. Read it before any structural work.

## Non-negotiable rules

- Verify, do not assert. Every claim comes from a query actually run.
- Empty is a sentinel, not a finding. Never emit a verdict from zero rows.
- Names lie; contents do not. Resolve layers by reading contents — interior points, value distributions, extents — never by table name, slug, or column name.
- Three coverage states, never two: present / none_recorded / not_available. A not_available returns null, never false, and never a downstream conclusion.
- DONE means committed, pushed, and verified in production. Not tsc-clean, not dev-curl, not verified locally.
- Never apply a payload-shape change to production ahead of the consuming front-end. Make it additive or hold the migration.
- Report before implementing on any structural change. Audit, classify, wait for a ruling.

## Commit hygiene

One concern per commit. Never sweep in pre-existing working-tree changes. Push before ending a session.
