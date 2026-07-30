# Data Tree Anchor — Keys, Joins & Fixes

**Purpose.** One durable, self-verifying reference for how the tables key together, which
keys lie, and which performance defects are found/fixed — so these problems stop being
re-discovered from scratch in chat. This document supersedes nothing in the data; the live
tables (`nr_master`, `pg_indexes`, the functions) are the truth. This is the readable index
into them, with a query beside every claim.

**Last full re-derivation:** 2026-07-28, against project `eaifqorwmgayiqmbtzcg` (live).

---

## 0. How to trust this document — the re-derivation contract

You should never have to take a number here on faith, and you should never have to referee
two chat sessions against each other. Every factual row carries the query that reproduces
it. Run it.

**Status tags** — every claim wears exactly one:

| tag | meaning |
|---|---|
| `[VERIFIED 2026-07-28]` | re-derived against the live DB in the session that wrote this. A query is given. |
| `[DECLARED: src]` | asserted by a person or a prior document, **not** re-derived here. Treat as a lead, not a fact. |
| `[RELAYED: src]` | produced by another chat session and passed in; **not** re-run here. Verify before trusting. |

**Rules that keep it honest**

1. No number is tagged `VERIFIED` without a query in this document that reproduces it.
2. A `RELAYED` or `DECLARED` number is never silently promoted to `VERIFIED`. It gets re-run first, and if it fails, it goes in §9 (caught errors), not quietly deleted.
3. County size, cache warmth, and sample position change measurements by 2×+ — so every timing records whether it was warm/cold and how the sample was chosen. A single warm number is not a launch metric.
4. When a check *can't fail* (e.g. a 1-row sample is always "clustered"; the first partition row always scans in 0 ms), it is marked as such and rerun with a case that *can* fail.

---

## 1. Ground-truth artifacts

The live "data tree" is a set of tables, not this document. Row counts `[VERIFIED 2026-07-28]`:

| table | rows | what it holds |
|---|---|---|
| `nr_master` | 1,226 | one row per populated table: class, geometry, srid, own/parcel/other keys, cardinality, join type |
| `nr_keys` | 39,223 | every column classified (own key / near-unique / high-card / constant / repeating) |
| `nr_content` | 27,012 | actual column value sets |
| `nr_index` | 1,226 | probed geometry + SRID, key/date/status/code columns |
| `nr_jointype` | 1,226 | join route per table (§3) |
| `nr_fam` | 1,226 | source family (21 families) |
| `nr_cardinality` | 344 | rows-per-key |
| `nr_failures` | 79 | logged survey failures incl. caught fabrications (§9) |
| `parcel_relation_key` | 5 | parcel→parcel keys with verified examples (§5) |
| `ladm_declaration` | 51 | signed classifications with rationale |
| `jurisdiction_prefix_map` | 46 | 7 county aliases + 39 municipalities |
| `ladm_map_fault_register` | 21 | fault classes from classification runs |

```sql
-- Verify:
SELECT 'nr_master' t, count(*) FROM nr_master
UNION ALL SELECT 'nr_keys', count(*) FROM nr_keys
UNION ALL SELECT 'nr_jointype', count(*) FROM nr_jointype
UNION ALL SELECT 'nr_failures', count(*) FROM nr_failures
UNION ALL SELECT 'parcel_relation_key', count(*) FROM parcel_relation_key;
```

---

## 1a. Live census — GENERATED, do not hand-edit

Regenerate with `node docs/data-tree/build.mjs` (or `docs/data-tree/refresh.sql`) whenever
tables are added. Everything between the markers is machine-owned; the prose around it is not.

<!-- DATA-TREE:BEGIN -->
*Generated 2026-07-29 from project eaifqorwmgayiqmbtzcg. Do not hand-edit — run `node docs/data-tree/build.mjs`.*

| measure | count |
|---|---|
| Tables in inventory | 2,018 |
| Classified in `nr_master` | 1,226 |
| **Reach a parcel (wired)** | **1,208** |
| — not wired · J0 system | 16 |
| — not wired · J13 non-parcel domain (`agent_license_status`) | 1 |
| — not wired · J14 genuine orphan (`sjc_plat_index`, 2,709 rows) | 1 |
| Unclassified in inventory — in inventory, not in `nr_master` | 792 |
| Genuinely empty (`reltuples = 0`, post-ANALYZE) | 57 |
| Never analyzed — no planner stats (`reltuples = −1`; 0 is healthy) | 0 |
<!-- DATA-TREE:END -->

**In words:** of the 1,226 classified tables, **1,208 reach a parcel and 18 do not** — 16 J0
system/internal tables, one J13 non-parcel domain (`agent_license_status`, DBPR licences —
correctly parcel-less), and one J14 genuine orphan (`sjc_plat_index`, a text index by design).
1,208 + 16 + 1 + 1 = 1,226; those four rows partition `nr_master`, and the harness enforces
that sum against live counts (the `census:*` checks). **What sits *outside* `nr_master` is two
different figures, and neither means "empty":** 792 of the 2,018 `table_inventory` rows aren't
classified, and 872 of the 2,098 public base tables aren't — different denominators. `nr_master`
itself has **zero** empty tables, so classification excluded nothing for looking empty. An
`ANALYZE` of all 805 never-analyzed tables (2026-07-29, §7) closed the stats gap — now **0**
never-analyzed — and settled the "empty" question: only **57** public base tables are genuinely
empty (`reltuples = 0`), not 792. Whether the (few) truly-empty tables explain any of the
unclassified set is **untested** (§8.6). This block is live — an orphan resolving, a table
loading, or an `ANALYZE` run moves it.

---

## 2. Parcel identity — the three keys

A Florida parcel carries **three** independent identifiers; joining the wrong one silently
fans out or returns nothing. See memory `db-parcel-keying`.

| key | example (1511 S Riverside) | shape | where it lives |
|---|---|---|---|
| **DOR `parcel_id`** (geographic) | `744901030061` | 12-digit geographic | `parcels_staging.parcel_id`, `*_nal_dor_source.PARCEL_ID`, `properties.dor_parcel_id`, `volusia_parcel_centroids.fullpid` |
| **`alt_key`** (internal/AltKey) | `3886208` | 7-digit | `*_nal_dor_source.ALT_KEY`, Volusia CAMA `PARID`, `parcels_staging.alt_key` |
| **`properties.id`** | uuid | uuid | internal FK target (`property_id`) |

**`parcel_id` is not one key — its format depends on the county.** A cross-county join on
the column name is wrong by construction (e.g. Volusia `744901030061` geographic vs Alachua
`00002-000-000` hyphenated vs Broward `folio`). `[DECLARED: DATA_TREE_DEFINITION §5]`

**`properties.dor_parcel_id` is unique where present, but NULL on 4,474 rows.** Values do not
duplicate (max 1 row each). The 4,474 is a **coverage hole** — rows with no DOR key that drop
out of any parcel-key join (NULL matches nothing), the *opposite* of a fan-out. `[VERIFIED 2026-07-28]`

> **Retraction.** Earlier drafts read "not unique — 4,474 duplicates, any join fans out,"
> tagged VERIFIED. **False.** `count(*) − count(DISTINCT)` counted NULLs as duplicates because
> `DISTINCT` drops NULLs, so 313,578 − 309,104 = the NULL count, not a duplicate count. There
> are zero duplicates. Logged in §9 — this is the self-consistent-check failure the document
> exists to stop, landing on the document.

```sql
-- 0 duplicate values, 4,474 NULLs, max 1 row per non-null value:
SELECT count(*) - count(dor_parcel_id) AS nulls,
  (SELECT count(*) FROM (SELECT dor_parcel_id FROM properties
     WHERE dor_parcel_id IS NOT NULL GROUP BY dor_parcel_id HAVING count(*) > 1) d) AS dup_values,
  (SELECT max(c) FROM (SELECT count(*) c FROM properties
     WHERE dor_parcel_id IS NOT NULL GROUP BY dor_parcel_id) x) AS max_per_value
FROM properties;
```

**CAMA bridge (Volusia):** `get_pir_report` maps DOR `parcel_id` → `alt_key` via
`volusia_parcels_govt_source.pid`, then `alt_key::bigint::text` → CAMA `PARID`. Volusia CAMA
tables have **no single own key**; the real key is `PARID + TAXYR + line`, so a single-column
`PARID` join returns every tax year and line item at once.

---

## 3. Join routes — `nr_jointype`

The 13 routes sum to exactly 1,226 tables. `[VERIFIED 2026-07-28]`

| route | tables | rows | mechanism |
|---|---|---|---|
| J1 parcel key + geometry | 138 | 38,635,579 | key join, geometry to verify |
| J2 parcel key only | 170 | 38,501,445 | key join, no spatial fallback |
| J2b `property_id` FK | 3 | 631,440 | FK to `properties.id` |
| J3 containment | 544 | 6,110,445 | polygon contains parcel |
| J4 proximity | 265 | 8,242,543 | point within distance |
| J5 frontage | 57 | 976,882 | line adjacent to parcel |
| J7 zip / J8 place / J9 county | 6 / 4 / 16 | 34,727 / 801,924 / 1,774,947 | area key |
| J12 indirect key | 5 | 40,301 | joins via another table |
| J13 non-parcel domain | 1 | 493,556 | correctly parcel-less (`agent_license_status`) |
| J14 genuine orphan | 1 | 2,709 | `sjc_plat_index` — text index by design |
| J0 system | 16 | 498,175 | internal |

```sql
-- Verify (tables must total 1226):
SELECT join_type, count(*) tables, sum(row_count) rows
FROM nr_jointype GROUP BY join_type ORDER BY join_type;
```

> Note: the row-count column of J12 was **fabricated** as 531,061 in an earlier draft; the
> real sum of its five tables is 40,301. See §9.

---

## 4. Dead / broken keys — test at load

Six county roll tables ship an `altkey`/`ALT_KEY` column holding **one distinct value across
every row** — a join on it returns the whole county as a single parcel, silently. Five are
ARPC-sourced. `[VERIFIED 2026-07-28]`

| table | column | distinct | rows |
|---|---|---|---|
| `santarosa_nal_dor_source` | `ALT_KEY` | 1 | 120,501 |
| `jackson_parcels_govt_source` | `altkey` | 1 | 39,266 |
| `franklin_parcels_govt_source` | `altkey` | 1 | 17,780 |
| `gulf_parcels_govt_source` | `altkey` | 1 | 17,478 |
| `calhoun_parcels_govt_source` | `altkey` | 1 | 10,985 |
| `liberty_parcels_govt_source` | `altkey` | 1 | 5,646 |

```sql
-- Verify one (returns distinct=1):
SELECT count(*) rows, count(DISTINCT "ALT_KEY") distinct_vals FROM santarosa_nal_dor_source;
```

**Load-time rule:** for any keyed table, assert `count(distinct key) > 1` (and ideally
≈ `count(*)`) before wiring it. A dead key passes every downstream query while being wrong.

---

## 5. Parcel→parcel relation keys — `parcel_relation_key`

A parcel's record includes the parcels it relates to; these are labelled separately, never
merged into the subject parcel.

- **`CNDCMPLX`** (Volusia condo complex) — the only link from a unit to its building/association. Complex `022301` (Oceans Atrium One) groups **78 unit parcels** with association parcel `4988688`; the association's permits (incl. 2022 concrete restoration $589,750) reach a unit only through this key. `[VERIFIED 2026-07-28]`
- **`LUC = 0900`** — common-element role marker (association-owned, $0 value). Finds the building record; **must never be returned as anyone's property**.
- **`NBHD`/`NBRHD_CD`/`MKT_AR`** — neighbourhood/market groupings present in every county roll, currently unused.

```sql
-- Verify CNDCMPLX 022301 = 78 members:
SELECT count(*) FROM volusia_cama_condo_bldg WHERE "CNDCMPLX"='022301';
```

**Worked discovery (proof the "assemble by discovery" method works on an unseen address):**
1511 S Riverside Dr, New Smyrna Beach — `PARID 3886208`, DOR `744901030061`, `CO_NO 74`,
owner `CLOUTIER DAVID C TR`, JV $4,323,870, 8,001 sqft, built 2017. Rows held: `res_area` 17,
`sales` 9, `permits` 3, `exemptions` 3, `misc` 3, `land` 2, `owner`/`res_bldg`/`situs`/
`nonadvalorem` 1 each; `comm_*`/`condo_bldg`/`agland` 0 → single-family, not a condo.
Cardinality decides the render: 9 sales is a *list*, owner is a *value*. `[VERIFIED 2026-07-28]`

---

## 6. Performance defect register

The actionable spine. These are the recurring "table problems." Each carries measured
evidence and a fix.

### 6.1 The `::geography` cast defeats the GiST index (the dominant cost)

A predicate written `ST_DWithin(col.geom::geography, pt::geography, r)` casts the **column**,
so the planner cannot match a *geometry* GiST index against a *geography* expression. It falls
back to a full (often parallel) sequential scan and computes a geodesic distance on every row.
Cost is **CPU-bound**, not I/O — cache barely moves it. `[VERIFIED 2026-07-28]`

Evidence — `hydrology_waterbodies` (41,087 rows), 3 km, same point, same session:

| query form | plan | time | rows |
|---|---|---|---|
| `ST_DWithin(geom::geography,…)` — as written | Parallel Seq Scan (index ignored) | **1,679 ms** | 5 |
| `+ geom && ST_Expand(pt,…)` bbox prefilter | Index Scan on geometry GiST | **34 ms** | 5 (same 30 candidates) |
| **functional geography index** (fix applied §7) | Index Scan, planner emits `&&_st_expand` itself | **31.6 ms** | 5 (same) |

**Two fix classes — choose by predicate:**

- **`ST_DWithin(::geography)` layers → build a functional geography index:**
  `CREATE INDEX … USING gist ((geom::geography));`
  Zero code change, and **no buffer-math risk** — the planner generates the correct envelope
  via `_st_expand` internally. This also fixes tables that have *no* index at all, in one step.
- **`<->` KNN layers (`ORDER BY geom <-> pt`) → geometry GiST, or rewrite to geography KNN.**
  A functional *geography* index does **not** serve a *geometry* `<->` sort. `hifld_transmission_lines`
  uses `<->` with **no index at all** → a full 3,739-row sort every call (the earlier
  "`<->` is always safe" reassurance was false).

> `RELAYED: prior session` per-layer cast cost enumeration (stcm_tanks ~830 ms, brownfield
> ~277 ms, pnp ~181 ms, frs ~138 ms, …). **Not re-run here.** Re-derive each with `EXPLAIN
> (ANALYZE, BUFFERS)` before trusting the totals; only hydrology (above) and the brownfield
> complexity (6.4) were re-verified this session.

### 6.2 `parcels_staging` has no `(co_no, parcel_id)` index

These RPCs filter `WHERE co_no = X AND parcel_id = Y`; there is **no index on `parcel_id` at
all** — not standalone, not composite. The planner narrows by `co_no` (via the cohort index)
then **scans the partition** to match `parcel_id`. `[VERIFIED 2026-07-28]`

| county | co_no | partition rows | my single warm sample |
|---|---|---|---|
| Volusia | 74 | 306,889 | 33 ms (parcel near partition start) |
| Miami-Dade | 23 | 585,220 | 371 ms (deep parcel — 287,661 rows skipped) |

> **`rows removed by filter` is scan-position dependent** — ~0 for a partition's first parcel,
> up to the whole partition for its last. A single figure (an earlier draft's "Miami skips
> 287,661") is *one parcel's* value, not a county property. Cite the partition size, or sample
> across position. Cross-session sampling put medians near ~140 ms (Volusia) / ~320 ms
> (Miami-Dade) `[RELAYED: cross-session]` — re-run before citing.

The lookup is issued by **13 functions** (`get_site_intelligence` twice), so a full report/env
answer runs it **≥5 times** — `get_pir_report`, `get_parcel_env_findings`,
`get_parcel_env_findings_core`, `get_parcel_planned_works`, `get_parcel_archaeological_risk`.
`[VERIFIED 2026-07-28]` **Fix:** `CREATE INDEX CONCURRENTLY … ON parcels_staging (co_no,
parcel_id);` — one index removes it from all of them. Real, but still not the dominant cost
(6.1 is).

```sql
-- Verify the scan (look for "Rows Removed by Filter"):
EXPLAIN (ANALYZE, BUFFERS)
SELECT geom FROM parcels_staging WHERE co_no=23 AND parcel_id='3660170170020' LIMIT 1;
-- NB: pick a parcel that is NOT the first row of the partition, or the scan reads 0 rows
-- and the test cannot fail (see §9).
```

### 6.3 Funnel index map — what each layer needs

`[VERIFIED 2026-07-28]` — GiST status for every table the PIR funnel touches:

| table | geom GiST? | geog func idx? | note |
|---|---|---|---|
| `hydrology_waterbodies` | yes | **yes (applied §7)** | fixed |
| `fema_flood_zones`, `fdep_pnp`, `fdep_stcm_tanks`, `fdep_brownfield_sites`, `fdep_clm`, `fuds_property_boundaries`, `fuds_munitions_response_sites`, `fuds_property_points`, `hifld_dams`, `volusia_scenic_roads`, `volusia_boat_ramps`, `traffic_aadt` | yes | no | cast still defeats it → add geog func idx |
| `fl_sinkhole_incidents` | **yes** (`idx_fl_sinkhole_geom`, matview) | no | has an index — the relayed "no GiST" claim was wrong (§9) |
| `epa_landfills` | **no** | no | build index |
| `hifld_frs_relevant` | **no** | no | build index |
| `hifld_rcra_tsd_sites` | **no** | no | build index |
| `hifld_superfund_sites` | **no** | no | build index |
| `hifld_transmission_lines` | **no** | no | `<->` KNN with no index → full sort |
| `parcel_elevations` | no (n/a) | n/a | non-spatial; keyed by `btree(co_no,parcel_id)` — correct as-is |

**Five spatially-queried tables lack a GiST index entirely:** `epa_landfills`,
`hifld_frs_relevant`, `hifld_rcra_tsd_sites`, `hifld_superfund_sites`,
`hifld_transmission_lines`. Fixing the cast on these does nothing until an index exists.

```sql
-- Verify the whole map:
WITH funnel(tbl) AS (VALUES ('hydrology_waterbodies'),('fema_flood_zones'),
  ('fdep_pnp'),('fdep_stcm_tanks'),('fdep_brownfield_sites'),('fdep_clm'),
  ('fuds_property_boundaries'),('fuds_munitions_response_sites'),('fuds_property_points'),
  ('hifld_dams'),('volusia_scenic_roads'),('volusia_boat_ramps'),('traffic_aadt'),
  ('fl_sinkhole_incidents'),('epa_landfills'),('hifld_frs_relevant'),
  ('hifld_rcra_tsd_sites'),('hifld_superfund_sites'),('hifld_transmission_lines'),
  ('parcel_elevations'))
SELECT f.tbl,
  bool_or(i.indexdef ILIKE '%gist%' AND i.indexdef NOT ILIKE '%geography%') geom_gist,
  bool_or(i.indexdef ILIKE '%gist%' AND i.indexdef ILIKE '%geography%')     geog_funcidx
FROM funnel f LEFT JOIN pg_indexes i ON i.tablename=f.tbl GROUP BY f.tbl ORDER BY f.tbl;
```

### 6.4 Complex-polygon per-row cost

`fdep_brownfield_sites`: 571 `MultiPolygon` rows, **avg 74 / max 3,251 vertices**, ~0.5 ms/row —
vs `epa_landfills` (single `Point`, ~0.017 ms/row), a 28× per-row gap. Geodesic distance cost
scales with vertex count, so an index/prefilter matters *more* on vertex-heavy layers because
it skips the expensive per-polygon math. `[VERIFIED 2026-07-28]`

### 6.5 `fl_sinkhole_incidents` scanned 4× per report

`get_parcel_env_findings` runs one `count(*)` plus three independent scalar subqueries over
the same layer, each re-running `ST_DWithin` + `ORDER BY <-> LIMIT 1`. Consolidate to one
`LATERAL`. Correctness-neutral, independent of any index work. `[VERIFIED 2026-07-28: read from function source]`

---

## 7. Applied fixes log

| date | change | evidence | rollback |
|---|---|---|---|
| 2026-07-28 | `CREATE INDEX idx_hydrology_waterbodies_geog ON hydrology_waterbodies USING gist ((geom::geography))` | hydrology query 1,679 → 31.6 ms; **`get_pir_report` (Volusia, warm) 5,238 → ~2,096 ms** (3 runs: 2,175 / 2,063 / 2,096) | `DROP INDEX IF EXISTS idx_hydrology_waterbodies_geog;` |
| 2026-07-29 | Migration `strip_fabricated_v_env_constants_from_get_pir_report` — removed the 13 single-valued `property_environmental` (v_env) fields from `get_pir_report`: the whole `air` block, `radonZone`/`sinkholeRisk`/`sinkholeHistoryCount`/`waterSourceType`/`waterUtility`/`leadServiceLineRisk`/`algaeBloomRisk`, and the `environmentSources` provenance line. Kept only the two real fields — `inFlightPath` (caveat verbatim) + `airportDistanceM`. Surgical exact-substring strip; function otherwise byte-identical | each removed field `count(DISTINCT)=1` across 313,578 rows; post-fix smoke: report returns, all fabricated keys absent, `inFlightPath`/`airportDistanceM`/`elevationM`/gopher present, `get_parcel_env_findings` intact (29 findings) | source in the migration; re-add the keys to the `land`/`air` blocks to revert |
| 2026-07-29 | `ANALYZE` on all 805 never-analyzed public tables (`reltuples = −1`) | never-analyzed 805 → **0**; the planner now has statistics on all 2,098 public tables (~99M rows newly visible); settled the "empty" question — **57** genuinely empty, not 792 | none needed — statistics-only, non-destructive |
| 2026-07-29 | Migration `strip_fabricated_v_haz_block_from_get_pir_report` — removed the **entire** `property_hazard_risk` (v_haz) surface: the `wind` and `climate` entries, the 3 v_haz `flood` fields (`countyZone`/`stormSurgeZone`/`floodEvents10yr`), and `climateSources`. All 25 rendered v_haz fields were constant or all-null across 313,578 rows — incl. `fl_wind_design_speed_mph=130` / zone II statewide (fabricated FBC & insurance figure, understated toward "safer"). Post-condition: **zero `v_haz.` references remain** | smoke: report returns; `wind`/`climate`/`climateSources` absent; `flood.zone` + `areaRepetitiveLoss` kept; env findings unaffected (29 / 26 by parcel) | source in the migration; frontend `WindDial.tsx` deleted (dead) |
| 2026-07-29 | Migration `remove_fabricated_table_reads_from_get_pir_report` — removed the last v_env reads: both `SELECT INTO`s and the `inFlightPath`/`airportDistanceM` render (unrendered on the page; property_environmental has no recorded source). Report now references **neither** fabricated table | post-condition: 0 `property_environmental`/`property_hazard_risk`/`v_env.`/`v_haz.` refs; report returns | re-add the reads to revert |
| 2026-07-29 | Migration `drop_fabricated_property_environmental_and_hazard_risk` — `DROP TABLE` both. Fabricated end to end (incl. non-rendered cols); verified **no reader outside `get_pir_report`** (functions/views/matviews/FKs + app grep) | report still returns; both `to_regclass` NULL; retires the ~13 indexes built over constant/all-null columns | re-create (fabricated — no real data lost); guarded by `fabricated-tables-stay-dropped` |
| 2026-07-29 | #2(b) statewide values — `values_source_selection` (co_no → NAL table, all 67, from each table's own `CO_NO`) + resolver `get_parcel_values()` (JV / LND_VAL / AV_SD·NSD / TV_SD·NSD / ASMNT_YR / SPEC_FEAT_VAL / homestead from EXMPT_01·02, all UPPERCASE-quoted §11) + wired as the **NAL fallback** in `get_pir_report`'s values/tax coalesce chains (CAMA preferred → v_prop → NAL). Fixes null just/land/assessed/taxable/rollYear on every non-Volusia paid report. The `flood_layer_selection` pattern, not a per-county join | Marion `2572-010-003` → JV 629,964 / land 109,772 / assessed 629,964 / roll 2025 (was null); Volusia keeps CAMA (4,406,267, fresher). Also closed same day: v_prop `county_fips` collision filter (`= registry.fips`, 127 aligned — Sarasota-collision guard) and the Roz sources instruction made county-aware (no Volusia viewer URL on a non-Volusia parcel; "not applicable here" was the leak) | revert: drop the NAL fallbacks + the two functions |
| 2026-07-29 | Migrations `resolve_parcel_geometry_aggregate_fragments` + `get_site_intelligence_aggregate_parcel_fragments` — `parcels_staging` has duplicate `parcel_id` **within** a county (St. Johns ~26.7%) that are real geometry **fragments**; both geometry reads did `LIMIT 1` → one fragment → the 0.21-acre / 0-ft St. Johns Pier failure. Now **aggregate** all fragments with `ST_Union(ST_MakeValid())` — never dedupe. Any per-parcel geometry lookup must aggregate its rows | parcel 65/0251700001 (**1,215 fragments**): one-fragment 0.057 ac → aggregated **90.169 ac**; `get_site_intelligence.gis_acres` = 90.169 | revert: restore `LIMIT 1` |
| 2026-07-29 | Function `roz_fixtures_layer1()` + `docs/data-tree/roz-fixtures.mjs` — Roz test runner **Layer 1** (payload assertions, no model calls): for each `roz_test_fixtures` row it checks every `expected_status` key against the live RPC (flood / marine / wind / tax-deed / coverage). Layer 2 (narration, `must_contain`/`must_not_contain`, model calls) is a separate on-demand runner still to build | **all 12 fixtures pass** — incl. both live incidents (Orange "not loaded" → present/488,959/wind; St Pete flood → `not_available`) and the marine coverage-direction pair (`none_recorded` vs `not_available`) | `DROP FUNCTION roz_fixtures_layer1()` |
| 2026-07-29 | Migration `fix_area_repetitive_loss_county_literal_in_pir_report` — the report's `areaRepetitiveLoss` hardcoded `WHERE county ILIKE '%volusia%'`, so **every parcel statewide got Volusia's** FEMA repetitive-loss figures (Farragut showed 1,652/4,221 instead of Pinellas's 3,294/11,996). Resolve county from `p_co_no` via `county_registry`, stripping the " COUNTY" suffix the source field carries; `not_available` (not zero, not another county's numbers) when the county has no rows | Volusia 1,652/4,221, Pinellas 3,294/11,996 — each its own county | revert: restore the `'%volusia%'` literal |
| 2026-07-29 | Migration `wire_flood_resolver_into_get_pir_report` — **the cure for the St Pete false-flood incident.** The report's `flood` block now calls `get_parcel_flood_zone(p_co_no,p_parcel_id)` (coverage-aware: `field_status` / `zones[]` / `in_sfha` / BFE / datum / `coverage_caveat`) merged with `areaRepetitiveLoss`, replacing the flat `v_si.flood_zone` that read the broken `fema_flood_zones` and returned `available:false` with no field_status (which Roz narrated as "outside the SFHA"). Now Roz gets a real `field_status` the honesty contract + new prompt guard handle | verified on the incident parcel `get_pir_report(62,'16 31 18 00075 001 0010')`.flood = present / in_sfha true / BFE 11 NAVD88 / 6 zones; report intact (19 keys) | revert: restore `jsonb_build_object('zone',v_si.flood_zone,…)` |
| 2026-07-29 | Migration `get_parcel_flood_zone_makevalid_robustness` — the new flood resolver threw GEOS `side location conflict` on the first parcel tested (`ST_Intersection`/`ST_Intersects` on invalid geometry). `ST_MakeValid` the resolved parcel geom once + each candidate layer polygon (the `&&` bbox prefilter stays raw). Precondition before wiring it into the report path in place of the broken `fema_flood_zones` (the St Pete false-flood incident) | Volusia `744901030061` returns per-part zones (AE 56% BFE 6 / X 37% / AE 7%), no throw | revert: drop the `ST_MakeValid` wraps |
| 2026-07-29 | Migration `get_site_intelligence_multipart_representative_point` (#2/#5) — containment lookups (census block group, flood zone) now use a point on the parcel's **largest part** (`ST_PointOnSurface` of the biggest `ST_Dump` part) instead of `ST_Intersects(whole multipolygon)+LIMIT 1`, which picked an arbitrary feature for the 5,547 multipart parcels; distance metrics (nearest water, traffic) keep the full geom. #5 audit: all 8 sources real (`fema_flood_zones` batch-label `county_name` is the only defect → re-pull #10) | smoke: single-part `744901030061` (BG 1 / AE) unchanged; multipart `744403020120` (2 parts → dominant BG 1 / X) returns cleanly | revert: restore the whole-geom `ST_Intersects` |
| 2026-07-30 | Predicate `fragment-union-owner-address-invariant` (`checks.mjs`, manifest → 11) — the **standing guard that makes the §7 `ST_Union` fragment fix safe on the 61 counties not hand-checked.** Falsifiable: RED if any multi-row `(co_no,parcel_id)` group has >1 distinct `own_name` OR >1 distinct `phy_addr1` (fragments of different properties, which union would silently merge). Supersedes the proposed acreage-vs-`lnd_sqfoot` guard — that is only **12.7%** agreement (assessed land ≠ geometry area), a cross-examine lead not a guard. Runs in Tier-2 (full statewide GROUP BY over 10.7M under `SET statement_timeout=0`; the MCP connector's ~2-min cap can't run it) | maintainer's exhaustive stress test: **3,443 groups, 6 counties (incl. St.Johns 26.7% dup), zero violations**; harness self-test green at 13 controls | revert: remove the predicate + restore manifest 10 |
| 2026-07-30 | Migration `roz_fact_index_lineage_substrate` — **the fact index's mechanical corroboration guard, before the persona.** A fact is subject·predicate·value·source·tier·as_of·corroborators·contradictors. Tables `roz_source` (slug·authority·tier·as_of_kind — tier is an evidentiary rank, **not a confidence score**) + `roz_source_lineage` (`child derives_from parent`), functions `roz_source_ancestors()` (recursive) + `roz_sources_independent(a,b)` (TRUE iff ancestor-sets disjoint). Corroboration requires independence = TRUE; **no confidence score anywhere**. Seeded with the maintainer's three hand-verified cases; predicate `fact-index-corroboration-requires-independence` (manifest → 12) locks them | RealtyTrac sqft vs DOR roll → **not** independent (re-published, one witness); parcels_staging.jv vs NAL → **not** independent (shared DOR lineage); DOR `act_yr_blt` 1939 vs NPS nomination 1939 → **independent** (two agencies, no shared upstream = real corroboration). Self-test green (13 controls) | `DROP` both functions + both tables (additive; nothing reads them yet) |
| 2026-07-30 | View `v_county_layer_map` — **two-maps reconciliation with executable precedence.** `county_layer_registry.concept` (operational, per-county, built for lookup) is **authoritative for discovery**; `ladm_final_v3` (`name_v`/`schema_v`/`content_v`) is a **structural advisory vote**, inherited into `discovery_concept` **only** where `concept='other'` AND ≥2 LADM axes agree. Neither map is overwritten; both persist; disagreements surface via `reconciliation` + `needs_review` rather than being silently resolved (§15). Precedence is executable here so the pair can't drift the way `data_source_registry`/`table_inventory` did. **Reframes "152 already classified":** of 468 `other` layers, only **11 are safe to promote** (strong multi-axis) — 10 clean (census→`LOC_socio`, superfund→`REG_contamination`, sidewalks→`EXT_utility`, daycares→`LOC_amenity`) + **1 flagged** (`volusia_official_records_private`→`PART2_source`, access-fenced). **109 are name-only weak hints** (not promoted — vindicates the read-first mandate), **7 conflicts**, **341 unclassified** | view returns 1,678 rows; `inherit_candidates=11`, `promoted=11`, `promoted_but_flagged=1`, `weak_hints=109`, `conflicts=7` | `DROP VIEW v_county_layer_map` — additive, reads nothing |
| 2026-07-30 | Predicates `enumeration-closure-every-geometry-layer-registered` + `enumeration-closure-no-dangling-registered-layer` (manifest → 14) — **registration-as-rule closure, RED by design.** Mapping ran 4× as a *project* (`ladm_map_run1..v3`); each snapshot decayed from its run date because nothing fired when a new layer arrived. Forward: every geometry-bearing base table/matview in the **auto-maintained `geometry_columns` spine (which cannot decay — PostGIS keeps it from the catalog)** must appear in `table_inventory`. Reverse: every registered layer must still exist. Generalises §10 inv.6 (`empty≠done`) from pulls to registration; the spine's zero shelf-life is what makes it a rule, not a fourth snapshot | RED: forward **7** (`calhoun_zoning`/`broward_bmsd_zoning` pulls, FUDS×3 one-off, `fl_sinkhole_incidents` matview, `parcel_geometry_supplement` migration — 4 arrival routes, none touching a registry); reverse **2** (`property_environmental`/`property_hazard_risk` inventory rows outlived the §7 `DROP`, so `table_inventory` still advertised two fabricated sources) | revert: remove both predicates + restore manifest 12 |
| 2026-07-30 | Registration-closure debt cleared (same day) — `DELETE` the 2 dangling `table_inventory` rows (finishing the §7 fabricated-table `DROP`) + `INSERT` the 7 unregistered geometry layers with reviewed classes (zoning→`PART5_plan`, FUDS→`REG_contamination`, sinkhole→`REG_geohazard`, `parcel_geometry_supplement`→**`PART2_parcel`**, in the parcel family) and **row-probed actual srid/geometry** — all **4326**, not the metadata's srid=0. Both closure predicates now **GREEN**; the guard becomes a permanent drift regression check | `forward_unregistered 7→0`, `reverse_dangling 2→0` | revert: delete the 7, re-insert the 2 |
| 2026-07-30 | Predicate `geometry-srid-metadata-not-lying` (DEF-005 rule form, manifest → 15) + repair of **37** tables. Sweep found **38** base tables reporting `geometry_columns.srid=0` while rows are 4326 (`fdep_*`, `seminole_*`, `hifld_*`, `lake/osceola_school_zones`, `fuds_*`) — the class DEF-005 undercounted as "Seminole ~20", and its registry-based detector structurally can't see (FUDS isn't in `county_layer_registry`). New detector `detect_srid_metadata_lie()` probes **rows** (the only place the truth lives). Repaired 37 via **uniformity-guarded** `UpdateGeometrySRID` (per-table: only if one real row-SRID, using the actual srid — skips mixed to avoid `ST_SetSRID` relabel-corruption). The lie never corrupted a report — rows carry 4326, so `ST_Contains` saw 4326-vs-4326 | remaining `38→1` — RED on `fl_cadastral_dor_statewide` alone (10.8M; a **superset** of `parcels_staging` — column diff shows twn/rng/sec + OR deed refs unique to it — NOT a drop; typmod fix needs a direct connection) | revert: remove predicate + detector; the typmod fixes are harmless (data already 4326) |
| 2026-07-30 | Registry-consulted-by-harness — **DEF-005 detection EXTENDED** from `county_layer_registry.srid` (blind to unregistered tables like FUDS) to a row-probe via `detect_srid_metadata_lie()`, folding my parallel detector INTO DEF-005 rather than maintaining a fifth map; mapped to `harness_predicate='geometry-srid-metadata-not-lying'`. New column `data_defect_registry.harness_predicate` lets each defect declare how it is mechanically watched (DEF-003→fragment predicate, DEF-024→provenance ratchet). New predicate `active-repair-defects-are-harness-tracked` (manifest → 16): an active `repair` defect with a globally-runnable detection and no `harness_predicate` fails the build — the guard that would have stopped DEF-005 sitting active 6 days | RED on **DEF-017 / DEF-020 / DEF-021** (untracked repair defects). FUDS coverage measured: **183,085** parcels intersect a boundary, **61,936** a munitions area — served correctly by existing containment (incident retracted, §9) | revert: drop column + predicate; restore DEF-005 detection |

```sql
-- Verify report-level effect (warm):
CREATE TEMP TABLE _b(ms numeric);
DO $$ DECLARE t timestamptz; BEGIN
  t:=clock_timestamp(); PERFORM get_pir_report(74,'744901030061');
  INSERT INTO _b VALUES (extract(epoch from clock_timestamp()-t)*1000); END $$;
SELECT * FROM _b;
```

---

## 8. Open — explicitly not proven

Nothing here is a fact yet. Do not cite as one.

1. **The `env_findings` 3.7 s warm/cold swing is unexplained.** First-touch 6,856 ms → warm 3,167 ms `[VERIFIED 2026-07-28]`, but hydrology is CPU-bound and does *not* swing — so a *different*, I/O-bound cost lives in `get_parcel_env_findings_core` or the encumbrance/restriction/attestation/roof/archaeological sub-functions. Unnamed.
2. **No cold big-county baseline exists.** Every report timing above is warm Volusia. The honest statewide number (cold Miami-Dade/Broward/Palm Beach) is unmeasured.
3. **The per-layer cast enumeration (6.1) is `RELAYED`, not re-derived.** Re-run each `EXPLAIN` before summing.
4. **Remaining index builds are pending:** geography func-indexes for the 6.3 "cast still defeats it" layers; geometry GiST for the five no-index layers; the `transmission_lines` `<->` decision.
5. **Precompute vs request-time is undecided** and should stay undecided until 1–4 are measured. If casts+indexes bring a report under ~1 s, precompute demotes from prerequisite to optimization.
6. **The "unclassified" tables are uncharacterised.** 792 `table_inventory` rows (872 public base tables — different denominators) sit outside `nr_master`. Post-`ANALYZE` only **57** public tables are genuinely empty and `nr_master` has **0** empty, so "excluded for looking empty" explains at most a handful — the earlier re-inventory story is refuted, not supported. What the other ~800 unclassified tables actually are (staging, view base tables, duplicates, genuinely un-joinable, or truly missed) is **uncharacterised**. Intersect the exclusion set with the now-reliable row counts and classify it before rebuilding any re-inventory on it; `ANALYZE` (§7) closed the stats gap but does not itself prove any excluded table holds parcel-joinable data.
7. **Provenance gate — built, as a ratchet** (`report-sources-provenance-ratchet`). Base rate: of four report data sources, **two were entirely fabricated** (`property_environmental`, `property_hazard_risk` — dropped §7), one real (`v_si`). **27 of 32** tables the report path reads have no `source_url` in `table_inventory` (only `fema_flood_zones`, `volusia_zoning`/`future_land_use`/`gopher_tortoise_overlay`, `volusia_parcels_govt_source` do). That is a **true positive** — you cannot say where a paid report's data came from — *not* the cry-wolf case (that would be raising the cardinality threshold so `fema_flood_zones.fld_zone`'s 6 legitimate codes fire). Provenance is the primary gate because it fails closed even on *plausibly-varied* fabrication, which cardinality can't. Built as a **ratchet** (green at baseline 27, red the instant an unsourced table joins the path, every backfill lowers the floor) so the build isn't permanently red and muted. **Backfill target #1: `parcel_elevations`** — 10.7M rows, `provenance_route=migration`, no registry row, no vertical datum; the table that forced the BFE retraction. A **partial provenance record** (verifiable-only — migration `20260705013109`, single load 2026-07-05, 10,739,881 rows / 67 counties, elevation range −9.16…+104.19 m, "datum unconfirmed, orthometric likely") is now in `table_inventory.source_document_ref`, but **`source_url` stays null (ratchet holds at 27)** and `ground_elevation_ft`/`elevation_above_bfe_ft` remain suppressed. The real DEM source + vertical datum must still come from the pull records / maintainer — a guessed source would fabricate the provenance we're establishing. **Provenance recorded ≠ data correct** (see `fema_flood_zones`, §9): a green ratchet measures attribution, not quality.
9. **`discover_county_layers` is NOT yet rewired to `v_county_layer_map`** (deliberate). The reconciled view exists and declares precedence, but discovery still reads `county_layer_registry.concept` raw — so Roz's behaviour is unchanged and the 11 `inherit_candidate` promotions are *proposed*, not live. Rewiring is gated on two things: (a) maintainer confirms the precedence rule (operational authoritative; inherit a **strong** structural class where `concept='other'`; name-only stays a hint, never an authority); (b) the **one `needs_review` promotion** — `volusia_official_records_private` (structurally `PART2_source`, but the access-fenced personal-research-only layer, memory `volusia-official-records`) — is explicitly excluded from discovery, not silently promoted. Do NOT flip discovery to the view until both hold. `needs_review` also flags the quarantine/system smells (`*_abandoned_YYYYMMDD`, `*_scrape_progress`, `arrest_booking`) that must never enter discovery.
11. **FUDS boundary held but reported absent (sjc_-class, registered-now / WIRING still open).** `fuds_property_boundaries` (142 **POLYGON**) and `fuds_munitions_response_sites` (139 **MULTIPOLYGON**) are real areas at SRID **4326**, but `geometry_columns` metadata reported **srid=0 / type GEOMETRY** — so they were shelved as unjoinable and never wired, and Roz has reported FUDS as "point only, no mapped boundary" while **139 of 142 boundaries intersect parcels**. Registered 2026-07-30 (§7), but the *fix* is unshipped: `get_parcel_env_findings` / FUDS containment must query the boundary **polygons** (area membership), not only `fuds_property_points` (711 Point). Also correct the `geometry_columns` SRID (the rows are 4326). Same class as the sjc_ flood miss — we hold the boundary and tell the user we don't. Found during the registration-closure audit.
13. **fl_cadastral SRID fix + backfill its unique fields into the working path** (DEF-005, blocking). `fl_cadastral_dor_statewide` is a 10.8M-row **superset** of `parcels_staging`. (a) Fix its `srid=0` typmod on a **direct connection**: `SELECT UpdateGeometrySRID('public','fl_cadastral_dor_statewide','geom',4326)` after confirming uniform 4326 (the scan + rewrite exceed the 2-min pooler/MCP limit — greens the last SRID-lie). (b) Backfill into the working path: **thread #35** — `twn/rng/sec` (section-township-range; the STR we believed absent, blocking the 315 cadastral-hole investigation); **thread #58** — `or_book1/or_page1/clerk_no1` (Clerk OR deed refs; the deed-URL source we thought we'd parse from LEGDESC). Also unique: `s_legal`, `census_bk`, `nbrhd_cd/mkt_ar`, `tax_auth_c`, `par_splt/dt_last_in/spc_cir_cd`.
14. **Cardinality backstop needs rendered-column scoping** (not built). A table-level `n_distinct ∈ {0,1}` scan over the 32 report-source tables fires on **102 columns, ~all legitimate** (`state='FL'`, CAMA `TAXYR` single-year loads, null `expand_*`, GIS `created_user`) — the cry-wolf case. It is only meaningful over the columns the report actually **renders**, which needs a field→backing-column manifest. Build that, keep the threshold at `<= 1` (never raise), and note it catches only the *constant* failure mode: a table seeded with plausible per-parcel randomness passes it clean (same residual as any self-consistent check — a green is not proof of authenticity). `get_site_intelligence` reads unaudited tables and is live in the Roz path.

---

## 9. Caught errors — the reason this document exists

Recorded so corrections are traceable, not buried. The survey failures also live in `nr_failures`.

| error | claimed | actual | how caught |
|---|---|---|---|
| `roz_sources_independent` fail-OPEN | reported "3 seed cases classify correctly" | an **unregistered/typo source key returned `true` (independent)** — `('realtytrac','dor_nal')` and even `('foo','bar')` → true. Ancestor-set of an unknown key was `{itself}`, so it shared nothing with anyone and read as an independent second witness — the exact false confidence the substrate exists to prevent | maintainer called it with `'dor_nal'` (not the seeded `'dor_roll'`). My seed-case predicate tested ONLY the seeded slugs → structurally blind to the permissive default. Fixed fail-CLOSED (both sources must be registered; unknown ⇒ not independent) + predicate now exercises unknown keys |
| "370 unmapped geometry layers" | 370 geometry tables in no classification map | **6 base tables + 1 matview = 7**; the other **363 are VIEWS**, legitimately outside a *table* inventory | a `relkind IN ('r','m')` predicate. The 370 was asserted, then "confirmed" by re-running a query that proved the rows *existed*, not *what they were* — count without identity, the 3rd instance this session (cf. mean-high-water distance without which-feature, fragment acreage without how-many-rows). Correction pattern is always one more predicate on identity |
| FUDS "held boundary but reported absent" | I claimed a live sjc_-class incident (139 boundaries intersect parcels, Roz says "point only") | `get_parcel_env_findings` **already** does `ST_Contains(fuds_property_boundaries.geom, g)` + munitions containment + MMRP, and emits `field_status:'present'` (relation contains/intersects) vs `not_evaluated` (point-only, with the honest "cannot place inside or outside… NOT a clearance" caveat) vs real-negative. FT Marion is correctly point-only. **No wiring gap.** The `srid=0` metadata never broke it (rows carry 4326) | reading the function — which must precede an incident claim. I inferred a report consequence from 139 intersections without checking the code path: the same "consult before rediscover" lesson as not checking the defect registry |
| `fl_cadastral_dor_statewide` "redundant — DROP it" | I proposed dropping it as redundant with `parcels_staging` (row-count reasoning) | it is a **superset**: 14 columns present there and ABSENT from `parcels_staging` — `twn/rng/sec` (unblocks thread #35), `or_book1/or_page1/clerk_no1` (unblocks thread #58), `s_legal`, `census_bk`, `nbrhd_cd/mkt_ar`, `tax_auth_c`, `par_splt/dt_last_in/spc_cir_cd`. The `srid=0` lie made it read as dead weight | column-level diff (maintainer). **Redundancy claims need a column diff, not a row count.** DEF-005 (re-severitied blocking) has now shelved a **3rd** real layer — this time as an argument for *deletion* |
| J12 row count | 531,061 | 40,301 | verification; number not derived from anything (`nr_failures` id 79) |
| topology hand-edited | v3 §3 listed J12/J13/J14 | artifact still held J10/J11 | verification (`nr_failures` id 78) |
| Miami-Dade size | "900,000" | 585,220 | `count(*)` |
| "county size drives cost" | Alachua slower ⇒ bigger scan | Alachua (117,522) < Volusia (306,889); slower = **cold cache**, not volume | own row-count query contradicted it |
| "6 tables have no GiST" | included `fl_sinkhole_incidents` | sinkhole **has** `idx_fl_sinkhole_geom`; real count is **5** | `pg_indexes`, this session |
| "`<->` KNN always safe" | reassurance | `hifld_transmission_lines` has no index → full sort | index map |
| Miami-Dade scan sample | 0.086 ms (looked fast/fixed) | sample was the **first partition row** → could-not-fail; a mid-partition parcel took 371 ms | recognised the invalid sample |
| timing via `clock_timestamp()` in one SELECT | 14,916 ms | evaluated once ⇒ artifact; real timing needs assignment across statements in a `DO` block | second run returned 0 ms |
| `dor_parcel_id` "not unique — 4,474 dupes, fans out" `[VERIFIED]` | 4,474 duplicates | **0 duplicates**; the 4,474 are NULLs (`count(*)−count(DISTINCT)` counts NULLs as dupes). Real defect = coverage hole: those rows drop from joins, they don't multiply | cross-session audit + `GROUP BY … HAVING count(*)>1` |
| diagram "sums exactly to 1,226" | 7 class rows = 1,167; 7 routes = 1,209 | DB closes to 1,226; the tree **omitted** `(unclassified)` 41·2.09M + `SYSTEM` 18 (classes) and `J0` 16 + `J13` 1·493,556 (routes) — the residual is the honest part | visible-sum arithmetic |
| "Miami skips 287,661" as an intrinsic cost | 287,661 | one deep parcel's `rows removed by filter`; scan-position dependent (0…585,220), not a county property | couldn't source it to any count |
| parcel lookup "3× / ~1 s" | 3 call sites | issued by **13 functions**, ≥5 per report/env answer; and a relayed benchmark used co_no 64 (Putnam, 97,305) mislabeled as Volusia (74, 306,889) | `pg_proc` scan + `county_registry` |
| census "1,225 wire in / 792 empty" `[status report, 2026-07-29]` | 1,225 wired, 792 empty | **1,208 wired** — J0 (16) + J13 (1) + J14 (1) don't reach a parcel and were rounded into the success figure; **0 empty** — "792" was `reltuples ≤ 0`, but `−1` is the *never-analyzed* sentinel (805 tables), not a row count (a 30-table sample was 25 populated) | cross-session audit. Root cause: `build.mjs`/`refresh.sql`/`state.json` defined wired as *everything but J14* and read counts from `reltuples`. Fixed all three generators + added the `census:*` closure so it can't recur |
| `property_environmental` fabricated `[2026-07-29]` | a per-parcel env table (radon / sinkhole / lead / air / provenance) | **13 of 15** fields `get_pir_report` rendered are **single-valued across all 313,578 rows** — `radon_zone`, `lead_service_line_risk` (health claims), `sinkhole_risk`, `sinkhole_history_count`, air block, and `source_attribution`/`data_retrieved_at` (fabricated provenance); `radon_zone = 2` statewide is impossible (FL spans EPA Zones 2–3). Only `in_flight_path` / `airport_distance_m` are real, and `in_flight_path` was the sole caveated field — caveat discipline running backwards. A one-field fix (the `get_pir_report` sinkhole constant) would have left 12 in place **and** deleted the *honest* derived `sinkhole_risk` in `get_parcel_env_findings` | cross-session audit; `count(DISTINCT)` per column. Render stripped then **table DROPPED 2026-07-29 (§7)** — remediated; guarded by `fabricated-tables-stay-dropped`. `v_haz` audited same day, also entirely fabricated (next row). |
| `property_hazard_risk` fabricated `[2026-07-29]` | a per-parcel hazard table (wind / climate / flood / storm-surge / provenance) | **all 25** rendered fields single-valued or all-null across 313,578 rows — zero real. Worst: `fl_wind_design_speed_mph = 130` / `fl_wind_speed_zone = II` **statewide** — a Florida Building Code & insurance-underwriting parameter that varies by design (Miami-Dade/Broward HVHZ ~170+ mph), understated toward "safer"; `fema_flood_zone` / `storm_surge_zone` all-null (no surge zone in a coastal-FL product); `climateSources` a second fake provenance line. I had **preserved the wind dial** in the v_env pass believing it real — this pass corrected that | cross-session audit; `count(DISTINCT)` per column. Stripped then **table DROPPED 2026-07-29 (§7)** with property_environmental — remediated; both guarded by `fabricated-tables-stay-dropped` |
| `fema_flood_zones` sourced-but-broken `[RELAYED 2026-07-29 — not re-verified here]` | one of the 5 tables that *has* a `source_url` | `county_name` is a **pull-batch label** (`swcoast`, `spacecoast`, `central1`, `panhandlewest`…), not a county — only `Volusia` is a real name; coverage **stops at ~27°N** (no Miami-Dade / Broward / Monroe / Collier, most of Palm Beach, W panhandle); every batch count is an exact **multiple of 200** → page-boundary truncation (the Orange County failure again), so polygons are likely missing inside covered regions too. Volusia tested 400/400 covered so Volusia findings stand; other counties return `flood_zone_available=false` — honest *by accident* (`county_name` never matches) | relayed cross-session; re-pull is a Tier-3 task. **Provenance recorded ≠ data correct** — a green ratchet measures attribution, not quality |
| parcel geometry via `LIMIT 1` fragment `[2026-07-29]` | one geometry row per (co_no, parcel_id) | `parcels_staging` has duplicate `parcel_id` within a county — real geometry **fragments** (St. Johns 26.7%: 205,773 rows / 150,880 parcels). `LIMIT 1` picked one fragment → 0.21 ac, centroid in a swamp 1.5 mi away, 0 ft (the St. Johns Ocean & Fishing Pier reported as a tiny inland lot). Fixed §7 — **aggregate (`ST_Union`), never dedupe**; the fragments together ARE the parcel | verified 65/0251700001: 0.057 → 90.169 ac. Discovery infra also confirmed live: `discover_county_layers()` + concept map (1,678 layers, `other` 468 of 1,678 after the 255-reclass) — Roz should ENUMERATE layers from it, never hardcode. **Union safety verified:** 8,000-group sample of multi-row (co_no,parcel_id) is 100% one-owner-one-address (genuine fragments, not colliding properties). The proposed acreage-vs-`lnd_sqfoot` guard is a **noisy lead, not a hard guard** — only 12.7% agree within 25% (assessed land ≠ geometry area broadly: units/ROW/submerged); use it as a cross-examine signal. The **owner/address invariant** is the guard (>1 owner or >1 address on a multi-row parcel_id ⇒ do not union) — exhaustive statewide check timed out, so run it as a bounded sample |
| Roz "Orange not loaded / Volusia only" `[live incident 2026-07-29]` | Roz told a user Orange County (Sea World, **488,959 parcels loaded**, flood layer returns Zone A) was not loaded — "my data covers Volusia only" | a **hardcoded** coverage claim in the Roz prompt (+ a runtime coverageNote), not derived — the mirror of the Pinellas false-negative. Fixed: prompt now "coverage is queried, never assumed; all 67 loaded"; `get_county_coverage()` wired as the sole authority. **THE PATTERN (not 3 coincidences):** 2 of 3 live incidents were a Volusia value/assumption presented as universal — `fema_flood_zones.county_name=v_county_name` (false negative in Pinellas), prose "Volusia only" (false gap in Orange), `areaRepetitiveLoss '%volusia%'` (Volusia numbers everywhere). Any county literal in a function taking `p_co_no` is a bug by definition — harness predicate to enforce (coverage-lookup fns the sanctioned exception) |
| `get_site_intelligence` "ST_Centroid in the road" `[RELAYED, corrected 2026-07-29]` | the function uses `ST_Centroid(geom)`, so the measuring point lands in the road on multipart parcels | **no `ST_Centroid` anywhere in the function** (0 matches in `pg_get_functiondef`) — it measures from the whole `v_parcel_geom`, which is *correct* for distance (nearest water, traffic). The real multipart bug was `ST_Intersects(whole geom)+LIMIT 1` picking an **arbitrary** block group / flood zone. Fixed §7 with a dominant-part representative point | read the source. The problem was real; the mechanism was not — same lesson as the "wind dial is real" miss. Fix the actual bug, not the described one |
| 10 "never-pulled" sources `[VERIFIED 2026-07-29]` | `data_source_registry.last_successful_pull_date IS NULL` on 10 active sources — reads as missing data | **all 10 exist with rows** — `fuds_*` 139–711, `volusia_flood_zones` 11,061, `volusia_gopher_tortoise_overlay` 1 (**live in `get_pir_report`**), `coastal_high_hazard_area`/`environmental_core_overlay`/`fdep_critical_erosion` feed `get_parcel_containment_findings`. Not missing — a **registry bookkeeping gap**: loaded via migration/one-off outside the registry-writing path (`sjrwmd_wells`, pulled 2026-07-24, proves the path works when used). Same root cause as the unreconciled county GIS | registry-vs-`pg_class` set-diff. Fix: pull-script contract rule #4 (write-back on success only) stops recurrence; a one-time `returnIdsOnly` reconciliation (catches any 200-multiple truncation) clears the existing 10. Also: 3 FUDS `source_url`s lack a layer index; NHD + statewide lands-available are **unregistered**, so their pull scripts are gated on rule #1 |

**The pattern in every row:** a plausible number that wasn't derived from what it claimed to
be. The defence is this document's contract — a query beside every fact, and a negative
control on every test that could otherwise only confirm.

---

*Re-derive everything here by running the SQL blocks against project `eaifqorwmgayiqmbtzcg`.
If a block's output disagrees with the prose, the output wins and the row moves to §9.*
