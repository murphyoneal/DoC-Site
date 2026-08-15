# Dataset Audit — full database, 2026-08-11

**Two passes, both re-runnable in the database.** This document is a snapshot; the artifacts are the source of truth.

```sql
-- structure / registration
select verdict, count(*) from dataset_audit group by verdict;

-- content: geometry validity, nulls, vertex counts
select * from dataset_content_audit order by run_at desc;
select audit_layer_content('some_table');   -- re-audit one layer
```

**Why these exist:** the same question was asked four times in one morning and answered four different ways, three of them wrong, because a metadata field was read as ground truth about the data. The rule already existed — *self-consistent checks lie; verify against live data, not stored summaries* — and was not followed. These replace the conversation with a query.

---

# PASS 1 — Structure and registration

| verdict | tables | rows | size |
|---|---|---|---|
| **DORMANT_UNREGISTERED** | 1,602 | 65,685,339 | 50.7 GB |
| OK | 334 | 14,891,732 | 14.8 GB |
| **SERVED_UNREGISTERED** | 170 | 8,544,811 | 4.2 GB |
| EMPTY | 56 | 0 | — |
| **SRID_ZERO** | 4 | 10,832,235 | 16.7 GB |
| REGISTERED_BUT_EMPTY | 1 | 0 | — |
| **total** | **2,167** | ~99.9M | ~86 GB |

**292 active registry entries against 2,063 populated tables — 14%.**

## 1.1 SERVED_UNREGISTERED — 170 tables the report reads today

No source URL, no refresh, no cadence, no audit trail, invisible to the nightly sweep. **172 of 302 `layer_resolution` rows (57%) point at unregistered tables.**

| concept | served | unregistered | |
|---|---|---|---|
| sinkhole | 59 | **59** | 100% |
| school_zones | 22 | **22** | 100% |
| cama | 19 | **19** | 100% |
| marine | 5 | **5** | 100% |
| plat_index | 3 | **3** | 100% |
| source_water_protection | 1 | **1** | 100% |
| environmental_overlay | 8 | 7 | 88% |
| flood | 53 | 24 | 45% |
| subdivisions | 30 | 11 | 37% |
| land_use | 52 | 14 | 27% |
| zoning | 43 | 7 | 16% |
| contamination (all), gwca, brownfield, institutional_controls | 15 | **0** | **0%** |

**Sinkhole is 100% unregistered across all 59 counties.** **CAMA is 100%** — the parcel record itself. **Marine is 100%** — the layer behind 15,801 improvements and the unpermitted-dock cross-examination the plan calls the moat.

**The contamination stack is fully registered and proves this is fixable.** Not systemic rot — this is what happens when registration is a step that *can* be skipped.

## 1.2 SRID_ZERO — one table is 16.7 GB

| table | rows | size |
|---|---|---|
| **`fl_cadastral_dor_statewide`** | **10,831,924** | **16.7 GB** |
| `school_attendance_zones` | 311 | 1.7 MB |
| `dea_clandestine_labs` | 0 | — |
| `fcc_asr_structures` | 0 | — |

The largest object in the database **cannot be spatially joined at all.** It is backlog item 16 — a genuine superset of `parcels_staging`, 122 columns against 44, and the only source of Section-Township-Range and the Clerk Official Records linkage (`or_book1/2`, `or_page1/2`, `clerk_no1/2`). Unusable, unregistered and unserved for weeks.

The registered defect class is exact: *the consequence of SRID 0 is not "geometry will not join" — it is that good layers get classified as unusable and shelved.*

## 1.3 DORMANT_UNREGISTERED — 1,602 tables, 50.7 GB

Pulled, never registered, never served. Overwhelmingly county GIS layers from the ArcGIS harness (1,362 tables, 42.9M rows).

**Do not bulk-register these.** A guessed `source_url` is worse than no entry — proven on 11 August, when two **fabricated** NRHP URLs (`services1.arcgis.com/NRHP/points` and `/districts`, hosts that do not exist) caused a duplicate NRHP dataset to be built and loaded alongside the real one.

---

# PASS 2 — Content: geometry validity

**All 279 served spatial layers. Every row. Actual `ST_IsValid` and `ST_NPoints` — not sampled.**

| | |
|---|---|
| layers audited | 279 (all) |
| **layers with invalid geometry** | **138 — 49.5%** |
| total invalid features | 2,234 |
| layers with NULL geometry | 14 |
| **total null geometries** | **1,966** |
| layers holding a >200,000-vertex feature | 29 |
| **worst single geometry** | **1,826,035 vertices** |
| errors | 0 |

**Every one of these layers is flagged `verified = true`.**

## 2.1 Half the served estate contains invalid geometry

Not the fourteen counties just pulled — layers **answering questions for users today**.

`collier_flood_zones` 170 · `escambia_flood_zones` 34 · `brevard_zoning` 30 · `duval_zoning` 13 · `duval_future_land_use` 13 · `clay_zoning` 9 · `citrus_zoning` 8 · `citrus_landuse` 7 · `columbia_flood_zones` 3 · `clay_future_land_use` 3.

Item 99 — *validate geometry once at ingest, never per call* — has never been run across the existing estate, only on the new NHD load. An invalid polygon is what makes `ST_MakeValid` fire per call, which took a Marion report from 4.98 s to a **27.7 s timeout**.

## 2.2 The vertex problem is already in production, and worse than the new data

Brevard's 594,198-vertex polygon was flagged as the reason to consider simplified serving geometry. It is not close to the worst thing held:

| layer | max vertices | |
|---|---|---|
| **`desoto_flood_zones`** | **1,826,035** | 3.3× the Marion polygon |
| `columbia_flood_zones` | 520,002 | |
| `citrus_flood_zones` | 469,277 | |
| `dixie_flood_zones` | 377,606 | |
| `bradford_flood_zones` | 241,274 | |
| `broward_fema_sfha_2024` | 204,480 | |

29 layers over 200k. **All served.** So the latency question is not whether the new flood load will cause a problem — it is why DeSoto has not already timed out, and the likely answer is that nobody has run a report there. **Measure DeSoto first, not Brevard.**

## 2.3 1,966 null geometries — and one is a contamination layer

A null geometry in a served spatial layer cannot intersect anything. The row exists, is counted, and can never be found by any query.

| layer | rows | null | |
|---|---|---|---|
| **`fdep_stcm_tanks`** | 74,262 | **1,905** | **2.6%** |
| `fdep_clm` | 10,185 | 26 | 0.3% |
| `martin_flood_zones` | 3,289 | 9 | |
| `osceola_zoning` | 2,561 | 6 | |
| `pasco_subdivisions` | 5,971 | 5 | |
| `clay_zoning` | 6,972 | 4 | |
| `charlotte_future_land_use` | 7,518 | 3 | |
| `manatee_zoning` | 2,702 | 2 | |
| 6 more | | 1 each | |

**`fdep_stcm_tanks` is the serious one.** 1,905 storage tank records — a contamination concept — that no spatial query can ever return. Contamination containment is the top-ranked lead in the report's §0.1 hierarchy. Whether these are a source defect or ours changes the disposition, and it must be established rather than assumed. This is the Baker 33-null-geometry defect at sixty times the scale.

---

# What `verified` actually means

`verified = true` on all 302 `layer_resolution` rows currently asserts **three separate claims through one flag**:

1. the layer resolves to a table
2. the source is known and refreshable — **false for 57%**
3. the geometry is valid — **false for 49.5%**

That is one field serving three lifecycles. The two-lifecycle version of this mistake is what silently retired the Volusia missing-geometry disclosure. **A flag read as assurance while being false half the time is worse than no flag.**

---

# Order of work

1. **Run `repair_geometry_once` across all 138 invalid layers.** Per layer, before/after counts, stop if any layer still has invalid rows. This is item 99 applied to the estate rather than to one new table.
2. **Measure DeSoto latency** — 1.8M vertices is the worst case and settles the simplified-geometry question properly.
3. **Report the 14 null-geometry layers**, starting with `fdep_stcm_tanks`; establish source-vs-ours.
4. **Split `verified` into three flags.**
5. **Register the 170 served-unregistered** — sinkhole and CAMA first. **Recover** each source from the pull scripts, migration history, or the county ArcGIS hosts in `geo_reference`. Never invent one. Record `unknown_source` honestly where it cannot be recovered.
6. **Fix `fl_cadastral_dor_statewide`'s SRID.**
7. **Make registration a condition of a load completing**, not a step that follows it.

---

# What is still NOT audited

Named so the gap is visible rather than assumed closed.

- **Column profiling across 2,167 tables** — all-null columns, single-value columns, sentinels. Three real defects were found this way by hand on three layers (`ELEVATION` 0/5,776 populated, `-9999` BFE, `INNETWORK` carrying the string `'None'`). Untouched on the other 2,164.
- **Content-matches-name.** Santa Rosa zoning served *rezoning petition numbers* where district codes belonged; a school board layer held *member names* rather than attendance zones. Both caught by reading value cardinality. Unchecked estate-wide.
- **Per-county coverage per layer.** The septic layer stops short of the panhandle; zero-because-not-covered must never render as a negative.
- **Freshness against live sources.** Needs a network call per source. The cadence sweep does this — for 287 of 2,063 populated tables.
- **Geometry validity on the 1,602 dormant layers.** Only served layers were checked.
- **Non-spatial content.** Duplicate keys, fan-out, orphaned foreign keys across the relational tables.

## Method note — three wrong findings, one cause

Reported as findings on 11 August and retracted the same day:

- **FUDS "never pulled"** — all four tables hold data (1,273 rows), loaded 25 July.
- **Six Volusia layers "never pulled"** — all populated, including `volusia_flood_zones` at 11,061 rows.
- **A "fourth coverage state"** for withheld archaeological sites — already solved; `restriction_authority` holds `archaeological` → s.872.02 → FL Division of Historical Resources, and spec §0.1 already routes universal statutory notices to the end of §2.

All three came from reading an artifact — a metadata column, a script header — instead of the thing itself.
