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

Full findings and evidence: docs/DATA_JOIN_FINDINGS.md
Compliance framework: docs/PROVIDER_REASONABLE_PROCEDURES.md
