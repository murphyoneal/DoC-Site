# DoP — Department of Property: Project Rundown

_Snapshot: 2026-07-20. Figures pulled live from Supabase project `eaifqorwmgayiqmbtzcg` at time of writing._

A Florida real-estate / property-intelligence platform. Two halves that are very unequal in maturity:

- **The data layer** — a statewide Florida property + GIS corpus. This is the bulk of the work and the actual moat. 1,812 tables, 57 GB, all 67 counties.
- **The application layer** — Next.js 16.2.9 on Vercel, rendering that corpus as consumer reports and B2B surfaces. Substantially newer, largely uncommitted.

---

## 1. Stack

| Layer | Tech |
|---|---|
| App | Next.js **16.2.9** (see `AGENTS.md` — a modified build with breaking changes; read `node_modules/next/dist/docs/` before writing code) |
| Hosting | Vercel |
| Data | Supabase — Postgres + PostGIS, project `eaifqorwmgayiqmbtzcg` |
| Ingestion | Python + GDAL/`ogr2ogr`, run from WSL (`/home/murphy/`) |
| Scheduling | Windows Task Scheduler → WSL wrapper script |

---

## 2. Data layer

### Scale

| Metric | Value |
|---|---|
| Tables (public schema) | **1,812** |
| Total size | **57 GB** |
| `parcels_staging` | ~10.3M parcels, 21 GB — the central statewide dataset |
| `parcel_elevations` | ~10.7M rows |
| `fema_flood_zones` | ~101K polygons, 1.4 GB |

Largest per-county tables are the government-source parcel layers: Miami-Dade (596K), Broward (549K), Lee (530K), Orange (498K), Duval (404K), Manatee (321K), Volusia (308K), Sarasota (304K), Pasco (300K), Collier (289K).

### County coverage

Tracked in `county_coverage_status` against a 10-category taxonomy: `parcels`, `zoning`, `future_land_use`, `address_points`, `subdivisions`, `parks`, `schools`, `fire_stations`, `hospitals`, `flood_zones`.

**Average completeness: 7.99 / 10.** Distribution:

| Categories complete | Counties |
|---|---|
| 10 | 17 |
| 9 | 17 |
| 8 | 10 |
| 7 | 8 |
| 6 | 15 |
| 5 | 2 |
| 4 | 2 |

No county sits below 4/10, and there are no blackout counties. `completeness_pct` is a GENERATED column — only ever UPDATE `categories_complete`.

> **Data-hygiene note:** this table has **71** rows and the registry has **69** distinct `county_name` values, against 67 Florida counties. Likely name variants or municipal rows that leaked in. Worth reconciling — it means "avg 7.99 across 71" is not strictly "avg across the 67 counties."

### Supporting datasets

| Domain | Tables |
|---|---|
| Traffic | `traffic_aadt` |
| Census / demographics | `census_acs_data`, `census_block_groups` |
| Flood | `fema_flood_zones` |
| Elevation | `parcel_elevations` |
| Hydrology | `hydrology_waterbodies` |
| Infrastructure | `hifld_*` (fire, hospitals, schools, dams, landfills…) |
| Economic | BEBR population (estimates + 2050 projections), BLS labor (LAUS/QCEW) |
| Hazard / environment | sinkhole incidents, burn detection history, brownfields, Superfund |
| Insurance | Citizens policies, OIR average premiums (PDF-sourced) |
| Civic | disaster declarations, code enforcement requests |

---

## 3. Refresh system

Built to make the corpus genuinely re-runnable rather than a one-time dump.

- **`data_source_registry`** — 261 active rows, 16 inactive. Columns: `county_name`, `category`, `table_name`, `source_url`, `access_technique`, `filter_where`, `page_size`, `last_count`, `last_successful_pull_date`, `notes`, `active`.
- **`~/master_refresh.py`** — reads the registry, stages into `<table>_stg`, and **swaps only on a sane (>0) count**, flagging count drift. Writes to `refresh_log`.
- **`~/run_monthly_refresh.sh`** — wrapper. Arguments are **hardcoded inside it**, deliberately: passing them across the `wsl.exe` boundary mangles them.
- **Trigger:** Windows Task Scheduler, monthly, `StartWhenAvailable` so a missed run catches up. WSL cron is *not* reliable here.

### Access techniques in use

| Technique | Sources |
|---|---|
| `fast_pull` | 218 |
| `geoplan_flu_county` | 12 |
| `chunked_small` | 10 |
| `arpc_cntyname` | 5 |
| `nfhl_dfirm` | 4 |
| `materialized_from_parcels` | 3 |
| `pdf_table_extract` | 2 |
| others (`geojson_paged`, `fid_partition`, `gdb_download`, `epa_envirofacts_api`, `fema_openfema_api`, `arcgis_statistics_by_county`, `arcgis_query_filtered`) | 1 each |

### Registry coverage by category

`future_land_use` 50 · `zoning` 43 · `parcels` 38 · `flood_zones` 31 · `address_points` 28 · `parks` 22 · `subdivisions` 19 · `fire_stations` 12 · `hospitals` 6 · `schools` 3 — plus one row each for the standalone statewide datasets.

---

## 4. Private research layers ⚠️

Three tables sit behind an explicit governance fence. **RLS enabled with zero policies = service-role only.** Each carries a table comment documenting provenance and the restriction.

| Table | Rows | Source |
|---|---|---|
| `volusia_arrest_booking_records` | 1,810 | Clerk of Court arrest/booking download (`app02.clerk.org/cr_24`) |
| `volusia_arrest_reports_private` | 47 | VCSO Daily Activity Reports |
| `volusia_official_records_private` | in progress (§7) | Clerk Official Records (`app02.clerk.org/or_m`) |

**The rule:** personal research use only. **Not** fed to the PIR, the B2B product, or any customer-facing output; no redistribution or resale. This was an explicit decision, not an inherited default — the counties publish no paid bulk product, and the arrest source's own terms prohibit commercial redistribution.

These tables store real PII (names, DOB, addresses). Any use that crosses into customer-facing output needs a fresh decision, not an assumption.

---

## 5. Application layer

### Routes

**Public / consumer**
`/` · `/florida` · `/florida/{volusia,orange,seminole,osceola,lake,miami-dade}` · `/florida/volusia/spruce-creek` · `/report/[coNo]/[parcelId]` · `/assistant` · `/checkout` · `/disclaimer`

**B2B / contractor**
`/c/[slug]` · `/c/[slug]/scan` · `/claim/[slug]`

**API**
`/api/pir` · `/api/pir/map` · `/api/pir/closeup` · `/api/properties` · `/api/amenities` · `/api/contractors` · `/api/assistant` · `/api/checkout` · `/api/scan` · `/api/qr/[slug]` · `/api/vcard/[slug]`

### Data access — `lib/sockets/`

`pir.ts` · `parcels.ts` · `amenities.ts` · `contractors.ts` · `b2b.ts`

### Notable components

`PropertyReportMap` · `PropertyMap` / `PropertyMapShell` · `PropertyRolodex` · `AmenityCompass` · `WindDial` · `CountyLanding` · `ContractorMap` · `ScanTracker` · `AssistantChat` · `JsonLd`

### Uncommitted SQL

Five `PROPOSED_*.sql` files at repo root, not yet applied: `get_pir_report`, `get_pir_map_geojson`, `get_pir_parcel_closeup`, `optimize_get_site_intelligence`, `site_intelligence_batch`.

> Most of the app layer is currently **untracked in git** — new API routes, components, county pages, sockets, and types all show as untracked. Worth committing.

---

## 6. Hard-won operational knowledge

The expensive lessons. These are failure modes that pass silently.

### Verification discipline

- **Never trust a tool's "OK / loaded / N succeeded" line.** Verify against real source counts.
- **A self-consistent check validates your parser, not your data.** If an upstream lies consistently, an assertion against *its own* reported count passes. Check the **distribution** instead — identical or suspiciously round counts repeating across units that should be independent means truncation. This cost 93% of a dataset before being caught (§7).
- **Always bbox/FIPS-verify** that data is the correct Florida county.

### Ambiguous-name traps (all confirmed real)

Santa Rosa **CA** · Monroe **OH** · Duval **TX** · Jacksonville **NC** · Clay **GA** · Columbia **SC** · Osceola → Orange County **CA** (`ocgis.com`) · DeSoto **TX** · Taylor **TX** · Union **NJ** · Washington **MD** · Calhoun **TX** · Hamilton **OH** · Jefferson **AL** · Franklin **VA/PA** · Lafayette **WI**

### Source-resolution ladder

Own-server probe → hub DCAT → AGOL owner/content search → **AGOL Web Map `/data` → `operationalLayers[].url` drilldown** → Property Appraiser public-viewer proxy path.

### Known failure modes and fixes

| Symptom | Fix |
|---|---|
| Pooler `statement_timeout` on large COPY | small `-gt` batch size |
| ESRIJSON paging "Missing 'features' member" | `chunked_small` explicit `resultOffset` |
| ESRIJSON types `fid` as `numeric(4)` → COPY overflow | request `f=geojson` |
| `supportsPagination:false` + maxRec cap, oidField `FID` | FID-range partition |
| "current transaction is aborted" | a CASCADE — `grep -v` it to find the *real* first error |

### WSL interop gotchas

- **Shell variables blank out** through `wsl bash -lc '...'` — `$var`, `$1`, loop vars, `$(...)` all silently become empty. **Fix:** write the script to a file with literal values, then run it by path.
- **`/tmp` is wiped between `wsl.exe` invocations** (the VM shuts down). Persist working files to `$HOME`.
- Detached background processes **do** survive across invocations as long as one stays running.

### PostGIS vs DuckDB

`ST_MakeEnvelope` takes exactly 4 args in DuckDB spatial, but PostGIS accepts a 5th trailing SRID. Don't carry the DuckDB limit over to Supabase.

---

## 7. In flight

**Volusia Official Records crawl** — running now, resumable.

- Scope: `RESTRICTIONS`, `LIEN`, `JUDGMENT/ORDER`, `LIS PENDENS`; 2015-01-01 → present; one week per search.
- Progress at snapshot: **200 / 2,412** week-jobs, 0 failed, ~137K party-rows, ~56K distinct documents. Projects to ~1.3M party-rows over ~30–33 hours.
- Collector `~/volusia_or_collect.py`, log `~/or_crawl.log`, ledger `volusia_or_scrape_progress`.

**The bug worth remembering:** reusing one ASP.NET session across searches corrupts the grid — every later search returns exactly 25 rows under a *false* `Records found 25` label. Because the label is self-consistent, per-page assertions passed and the run reported `ok=12 failed=0` while discarding 93% of the data (438 rows vs 6,628 actual). Fixes: a **fresh session per week** (mandatory, not hygiene) plus a re-run-and-agree guard on any exactly-25 result.

**Source contract:** the app's own JS clamps searches to 7 days (a month-long range silently returns only its first week); the export button dumps only the *current page*, not the result set; the grid has 9 fixed columns, so parse by index — filtering empty cells shifts columns when `Legal` is blank.

**Semantics:** one row per **party** per instrument (`party_direction` D=grantor / R=grantee). `COUNT(*)` is a party count; use `count(distinct instrument_number)` for documents. HOA declarations file under `RESTRICTIONS` (Volusia has no `DECLARATION` doctype); HOA liens under `LIEN` with the association as a named party.

Deliberately **not** in `data_source_registry` — it isn't a REST source and the monthly driver would try to re-crawl the full history. The ledger makes incremental top-up free instead.

> A week absent from, or non-`ok` in, the ledger means **not collected** — never "zero records."

---

## 8. Documented walls

Recorded as inactive registry rows so they aren't silently re-attempted.

| County | Category | Wall |
|---|---|---|
| Washington | parcels | FDOT statewide parcels tool — re-confirmed dead |
| Holmes | parcels | same as Washington |
| Osceola | parcels | the `ocgis.com` lead is a **wrong-state trap** (Orange County CA) |
| Highlands | parcels | county endpoint token-gated (HTTP 499) |
| Polk | permits | no bulk permit API exists; portal-only |
| Leon | flood_zones | not one layer — split across layers 1–4 by zone type |
| Bay | flood_zones | bad auto-match (Floodways ≠ flood zones), rejected |
| Marion / Osceola | hospitals, fire_stations | source URLs dead on healthcheck 2026-07-19 |

Also disproven by direct verification: OIR MIR has no county/zip breakdown (statewide only); Miami-Dade 311 has **zero** noise categories (control-tested with POTHOLE = 10,984); FWC "Fire Occurrences" is a USGS burn-detection raster dominated by sugarcane burning — renamed `burn_detection_history` rather than passed off as wildfire.

---

## 9. Open items

1. **Commit the app layer.** Most routes, components, sockets, and types are untracked.
2. **Apply or discard** the five `PROPOSED_*.sql` files.
3. **Reconcile the 71/69 vs 67 county-name discrepancy** in `county_coverage_status` and `data_source_registry`.
4. **Rotate `consumer_report_readonly`** — its password is still a placeholder and must be rotated before that role is used.
5. **Arrest tables are unregistered** — orphaned from the monthly refresh. Given the PII and terms constraints, whether they *should* be on an automated schedule is a deliberate decision, not a default.
6. **Re-verify dead URLs** flagged by the 2026-07-19 healthcheck (Marion hospitals, Osceola fire/hospitals).
7. Optional backfills previously scoped but not run: a `statewide_clip` technique for ~25 flood tables, and ~18 remaining per-category gaps.

---

## 10. Working notes

- `~/autonomous_pull_notes.md` (1,189 lines) — the master mission log for the GIS/data-compilation effort. **Scoped to that mission**; it does not cover the arrest pipeline, which predates it.
- Per-county pull scripts live in WSL at `/home/murphy/pull_<county>.sh` — invisible to Windows search.
- Table comments carry provenance and governance for the private layers. That is deliberate: the documentation travels with the data rather than living only in prose.
