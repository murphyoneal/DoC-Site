# DoP — Table Inventory and Wiring Target

**Measured 2026-08-15 against the live database** (Supabase `eaifqorwmgayiqmbtzcg`). Every figure below is a query result, and the query is given so it can be re-run rather than trusted.

**This document exists because four different table counts were quoted in a single working session — 2,050, 2,110, 2,167 and 2,215 — with no statement of what each measured.** They were all approximately right and none of them was comparable to the others. That is a reporting defect, not a data defect, and this document is the fix.

---

## Part 1 — Why the numbers disagreed

They count different things. All four are correct under their own definition:

| figure | what it actually counts | value today |
|---|---|---|
| **2,216** | every base table in `public`, populated or not | 2,216 |
| **2,111** | base tables with rows (`reltuples > 0`) | 2,111 |
| 2,167 / 2,215 | earlier snapshots of the 2,216 line, taken on different days | superseded |
| 2,050 | an earlier snapshot of the 2,111 line (business plan v2/v3, 3 August) | superseded |
| **2,616** | every *relation* — tables plus views plus matviews | 2,616 |

Plus the ones nobody had separated out:

| | |
|---|---|
| empty tables (`reltuples = 0`) | **59** |
| never analysed (`reltuples < 0`, so genuinely unknown) | **46** |
| views | **399** |
| materialised views | **1** |
| registered spatial columns | **1,948** |
| database size | **91 GB** |

**Standing rule from this point: no table count is quoted without its definition.** The canonical figure for all planning is **2,111 populated base tables**. Anything else must say which line it is.

### The reproducing query

```sql
SELECT
 count(*) FILTER (WHERE relkind='r')                      AS all_base_tables,
 count(*) FILTER (WHERE relkind='r' AND reltuples > 0)    AS populated_tables,
 count(*) FILTER (WHERE relkind='r' AND reltuples = 0)    AS empty_tables,
 count(*) FILTER (WHERE relkind='r' AND reltuples < 0)    AS never_analyzed,
 count(*) FILTER (WHERE relkind='v')                      AS views,
 count(*) FILTER (WHERE relkind='m')                      AS matviews
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace AND n.nspname='public';
```

---

## Part 2 — The three registries, and what each one means

A table is only useful to the product if it appears in all three. Most do not appear in any.

| registry | rows | what it asserts |
|---|---|---|
| `data_source_registry` | 463 (419 active) | **Provenance.** Where this came from, when it was pulled, how often it changes, who owns the refresh. |
| `layer_resolution` | 449 | **Reachability.** Which concept this answers, for which place, with what key. |
| served function reference | — | **Use.** Some `get_*` function actually reads it. |
| `concept_registry` | 57 | the questions a report can ask |
| `data_defect_registry` | 99 active | the known ways each answer can be wrong |

---

## Part 3 — THE NUMBER THAT MATTERS

Every populated table, cross-tabbed against all three:

| registered | in resolver | served | tables | rows | reading |
|---|---|---|---|---|---|
| no | no | no | **1,425** | 31,414,489 | dark — inert, no code touches them |
| yes | yes | no | 220 | 22,949,500 | tracked and reachable, nothing calls it |
| yes | no | no | 167 | 19,743,278 | provenance only |
| no | yes | no | 141 | 1,216,897 | **in the resolver with no provenance** |
| no | no | **yes** | **102** | 15,693,578 | **served and untracked — the danger** |
| **yes** | **yes** | **yes** | **30** | 10,814,969 | **fully wired** |
| no | yes | yes | 13 | 851,636 | |
| yes | no | yes | 13 | 24,188,529 | |

**30 of 2,111 tables are fully wired. That is 1.4%.**

Totals: 430 in the source registry, 404 in the resolver, 158 referenced by any served function.

### Why the 102 are the priority and the 1,425 are not

The 1,425 dark tables are **inert**. No code reads them. They cost storage and nothing else. They are a backlog, not a risk.

The 102 are read by served code and tracked by nothing — no source, no pull date, no cadence, no refresh owner, no defect coverage, and no mechanism to notice one has gone stale. **Every incident found on 15 August came from this category.**

---

## Part 4 — The ten that `get_pir_report` reads and nobody tracks

| table | rows | what it does |
|---|---|---|
| **`parcels_staging`** | **10,739,881** | **the parcel spine of every report ever sold** |
| `properties` | 313,578 | |
| `volusia_parcel_school_assignment` | 308,092 | |
| `volusia_parcel_centroids` | 276,606 | centroid and lat/lng — drives every spatial concept |
| `hydrology_waterbodies` | 41,087 | |
| `fema_nfip_multiple_loss_fl` | 33,547 | repetitive-loss context |
| `volusia_schools` | 193 | |
| `dor_use_code` | 100 | |
| `county_registry` | 67 | |
| `fl_county_boundaries` | 67 | |

**`parcels_staging` is unregistered.** There is no recorded source, pull date or cadence for the table that resolves the parcel in every report. We cannot answer *"how old is this parcel record"* for any report we have produced, on any parcel, in any county — while the spec requires every rendered claim to carry a source and an `as_of`.

Registered as defect `served-table-with-no-registry-entry`, blocking, with the predicate scoped to `get_pir_report` so it is cheap and unambiguous. It goes green when the report reads nothing untracked.

---

## Part 5 — Where the tables are, by subject

| bucket | tables | rows | tracked | untracked |
|---|---|---|---|---|
| other / unclassified | 907 | 24,996,997 | 121 | **786** |
| zoning / FLU | 213 | 3,801,708 | 172 | 41 |
| DOR roll / parcel spine | 175 | 30,116,050 | 36 | **139** |
| emergency services | 168 | 95,209 | 21 | **147** |
| schools | 144 | 315,731 | 25 | **119** |
| hazard | 129 | 758,619 | 54 | 75 |
| parks / conservation | 81 | 26,470 | 29 | 52 |
| addresses | 65 | 11,735,750 | 28 | 37 |
| **CAMA relational** | **64** | **38,541,218** | **63** | **1** |
| statewide environmental | 63 | 12,658,524 | 34 | 29 |
| transport | 53 | 801,662 | **0** | 53 |
| governance | 35 | 24,216 | 1 | 34 |
| permits / contractors | 10 | 2,011,909 | **0** | 10 |
| platform / accounts | 4 | 988,813 | **0** | 4 |

**Read this against the product, not the totals.**

- **CAMA is 63 of 64 tracked** — the deepest and best-governed part of the database, and the most recent work.
- **Zoning/FLU is 172 of 213** — good coverage, but 54 of those resolutions are unverified municipal layers (see `layer-resolution-row-unverified`).
- **Permits and contractors: 0 of 10 tracked, 2.0M rows.** This is the cross-examination moat and none of it has provenance.
- **Transport: 0 of 53.** Nothing tracked at all.
- **Emergency, schools, parks: 387 tables, 33 tracked.** Amenity data, low row counts, low urgency.
- **The 907 "other" is not a category, it is the absence of one.** Classifying it is the single largest inventory task remaining.

*(Bucketing is by table-name pattern and is indicative, not authoritative. A name-based classification is exactly the thing this project has repeatedly proven unreliable — treat it as a map of where to look, never as a finding.)*

---

## Part 6 — The target

**A table is DONE when all five hold:**

1. **Provenance.** A `data_source_registry` row with a real source URL, pull date, cadence and refresh owner.
2. **Contents read.** Someone opened it and confirmed what the columns actually contain — not what the name implies. `verified = true` set in the same transaction that reads it.
3. **Key joins, and the join is indexed.** Measured on the full population, with a negative control.
4. **A `layer_resolution` row** naming the concept, place, key column and any transform.
5. **A served function reads it**, or it is explicitly recorded as held-not-served.

Rules that follow from the failures of 15 August:

- **Registry entry before serving, not after.** A function reading an unregistered table should not pass review.
- **Never bulk-register.** Contents first, one at a time, highest row count first. Bulk registration on faith is how 54 unverified municipal layers entered the resolver.
- **Never backfill `row_count` as a bulk operation.** Set it in the same transaction that sets `verified = true`. A NULL `row_count` currently makes a layer inert — which accidentally protected us from 54 unread layers and accidentally suppressed Miami-Dade municipal zoning. The null is not a safety property.
- **`limit N` without `ORDER BY` is not a sample.** It produced a 36-percentage-point error against a verified figure.
- **A table is not registered until `sync_table_provenance_comments()` has run.**

---

## Part 7 — Sequence

**Now — the 102 served-and-untracked, 15.7M rows.** Ten of them are `get_pir_report` dependencies and `parcels_staging` is first. This is where every incident has come from.

**Next — the 141 in-resolver-without-provenance.** The resolver will serve a layer whose source nobody recorded.

**Then — the 220 tracked-but-uncalled.** Not a risk; it is duplicated effort, and it tells us which concepts were built and never wired.

**Eventually — the 1,425 dark tables, 31.4M rows.** Inert. Classify the 907 "other" first so the rest can be triaged rather than opened one at a time.

**Standing, not a task: this inventory becomes a view, not a query run once.** Every session so far has rediscovered the same gap from a different direction. A one-off measurement that has to be re-derived is why four incompatible table counts were in circulation on the same day.

---

## Appendix — The reproducing cross-tab

```sql
WITH alldefs AS (
  SELECT string_agg(pg_get_functiondef(p.oid), E'\n') AS blob
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.prokind = 'f'
    AND p.prolang <> (SELECT oid FROM pg_language WHERE lanname = 'internal')
), t AS (
  SELECT c.relname AS tbl, c.reltuples::bigint AS est_rows,
    EXISTS (SELECT 1 FROM data_source_registry d WHERE d.table_name = c.relname) AS reg,
    EXISTS (SELECT 1 FROM layer_resolution   l WHERE l.table_name = c.relname) AS res,
    position(c.relname IN (SELECT blob FROM alldefs)) > 0 AS srv
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
  WHERE c.relkind = 'r' AND c.reltuples > 0
)
SELECT reg, res, srv, count(*) AS tables, sum(est_rows) AS rows
FROM t GROUP BY 1,2,3 ORDER BY tables DESC;
```

**Known limitation, stated because it is load-bearing.** The `srv` test is a substring match of the table name against the concatenated function bodies. A short name that is a substring of a longer one **over-reports**. It cannot **under-report** — which is the direction a guard requires, since the failure being guarded against is *served but untracked*. Replacing it with a real dependency walk (`pg_depend`, or parsing `regclass` references) would tighten it and is worth doing before the figure is used for anything other than triage.
