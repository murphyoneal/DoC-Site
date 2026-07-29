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
| 2026-07-29 | Migration `get_parcel_flood_zone_makevalid_robustness` — the new flood resolver threw GEOS `side location conflict` on the first parcel tested (`ST_Intersection`/`ST_Intersects` on invalid geometry). `ST_MakeValid` the resolved parcel geom once + each candidate layer polygon (the `&&` bbox prefilter stays raw). Precondition before wiring it into the report path in place of the broken `fema_flood_zones` (the St Pete false-flood incident) | Volusia `744901030061` returns per-part zones (AE 56% BFE 6 / X 37% / AE 7%), no throw | revert: drop the `ST_MakeValid` wraps |
| 2026-07-29 | Migration `get_site_intelligence_multipart_representative_point` (#2/#5) — containment lookups (census block group, flood zone) now use a point on the parcel's **largest part** (`ST_PointOnSurface` of the biggest `ST_Dump` part) instead of `ST_Intersects(whole multipolygon)+LIMIT 1`, which picked an arbitrary feature for the 5,547 multipart parcels; distance metrics (nearest water, traffic) keep the full geom. #5 audit: all 8 sources real (`fema_flood_zones` batch-label `county_name` is the only defect → re-pull #10) | smoke: single-part `744901030061` (BG 1 / AE) unchanged; multipart `744403020120` (2 parts → dominant BG 1 / X) returns cleanly | revert: restore the whole-geom `ST_Intersects` |

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
8. **Cardinality backstop needs rendered-column scoping** (not built). A table-level `n_distinct ∈ {0,1}` scan over the 32 report-source tables fires on **102 columns, ~all legitimate** (`state='FL'`, CAMA `TAXYR` single-year loads, null `expand_*`, GIS `created_user`) — the cry-wolf case. It is only meaningful over the columns the report actually **renders**, which needs a field→backing-column manifest. Build that, keep the threshold at `<= 1` (never raise), and note it catches only the *constant* failure mode: a table seeded with plausible per-parcel randomness passes it clean (same residual as any self-consistent check — a green is not proof of authenticity). `get_site_intelligence` reads unaudited tables and is live in the Roz path.

---

## 9. Caught errors — the reason this document exists

Recorded so corrections are traceable, not buried. The survey failures also live in `nr_failures`.

| error | claimed | actual | how caught |
|---|---|---|---|
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
| `get_site_intelligence` "ST_Centroid in the road" `[RELAYED, corrected 2026-07-29]` | the function uses `ST_Centroid(geom)`, so the measuring point lands in the road on multipart parcels | **no `ST_Centroid` anywhere in the function** (0 matches in `pg_get_functiondef`) — it measures from the whole `v_parcel_geom`, which is *correct* for distance (nearest water, traffic). The real multipart bug was `ST_Intersects(whole geom)+LIMIT 1` picking an **arbitrary** block group / flood zone. Fixed §7 with a dominant-part representative point | read the source. The problem was real; the mechanism was not — same lesson as the "wind dial is real" miss. Fix the actual bug, not the described one |
| 10 "never-pulled" sources `[VERIFIED 2026-07-29]` | `data_source_registry.last_successful_pull_date IS NULL` on 10 active sources — reads as missing data | **all 10 exist with rows** — `fuds_*` 139–711, `volusia_flood_zones` 11,061, `volusia_gopher_tortoise_overlay` 1 (**live in `get_pir_report`**), `coastal_high_hazard_area`/`environmental_core_overlay`/`fdep_critical_erosion` feed `get_parcel_containment_findings`. Not missing — a **registry bookkeeping gap**: loaded via migration/one-off outside the registry-writing path (`sjrwmd_wells`, pulled 2026-07-24, proves the path works when used). Same root cause as the unreconciled county GIS | registry-vs-`pg_class` set-diff. Fix: pull-script contract rule #4 (write-back on success only) stops recurrence; a one-time `returnIdsOnly` reconciliation (catches any 200-multiple truncation) clears the existing 10. Also: 3 FUDS `source_url`s lack a layer index; NHD + statewide lands-available are **unregistered**, so their pull scripts are gated on rule #1 |

**The pattern in every row:** a plausible number that wasn't derived from what it claimed to
be. The defence is this document's contract — a query beside every fact, and a negative
control on every test that could otherwise only confirm.

---

*Re-derive everything here by running the SQL blocks against project `eaifqorwmgayiqmbtzcg`.
If a block's output disagrees with the prose, the output wins and the row moves to §9.*
