# THE LENS — Living Reference for Table Conformity

**Living document. Updated 2026-08-16.** This is the reference every table is read through. When it disagrees with the database, the database wins and this document gets corrected.

---

## 0 — What this is for

Sixty-seven counties publish the same facts sixty-seven different ways. Mapping them to each other is 2,211 mappings. Mapping each to a standard is 67. **One key per dataset, not one per pair.**

The standard already exists: **ISO 19152, the Land Administration Domain Model.** Its core is four classes — `LA_Party` (who), `LA_RRR` (what right, restriction or responsibility), `LA_BAUnit` (the bundle held), `LA_SpatialUnit` (where). LADM is a conceptual model; a country or state implements it as a **profile**. Florida is a profile. Arkansas will be another. The model does not change.

**Two things the standard does not do, and both are ours:**
- It does not say which of four flood layers to believe. *(We do not choose — see §3.)*
- It does not read itself. Nothing happens until a served function consults it.

---

## 1 — The four questions, and where each answer lives

Every table gets read through four questions. Three are **properties of the table** and belong on the table. One is a **relation between tables** and belongs in a registry.

| question | kind | where it lives |
|---|---|---|
| **What is this?** LADM class, register, agency | attribute | on the table |
| **What does each column mean?** which column answers which role | attribute | on the table |
| **How does it join?** key column, transform, geometry column | attribute | on the table |
| **Which table answers this concept, for this place?** | **relation** | `layer_resolution` — the only registry |

**A label on the card cannot be separated from the card. A notebook about the cards can.** On 16 August the notebook and the deck came apart five ways: `table_inventory` drifted on 328 rows, 48 `geom_column` values pointed at columns that do not exist, 7 column-map entries pointed at row identifiers, `palmbeach_zoning` was labelled zoning and was not, and 54 municipal layers sat registered and unread for weeks. **Every one of those was in the ledger, none in a table comment.**

---

## 2 — The declaration line

One structured line per table, in the PostgreSQL table comment. Machine-readable, travels with the object, cannot drift from it.

```
PROVENANCE: <agency> | <register> | <ladm_class> | <authority> | <as_of>
KEY: <column> [transform] | GEOM: <column> | ROLES: <role>=<column>, ...
NOTE: <anything a human needs>
```

Worked example:

```
PROVENANCE: FEMA | regulatory | PART2_spatialunit | originator | 2026-07
KEY: — | GEOM: geom | ROLES: zone=fld_zone, bfe=static_bfe, subty=zone_subty
NOTE: NFHL. in_sfha derives from the ZONE CODE, not from sfha_tf.
```

**Agency abbreviation only — never the URL.** FEMA, FDEP, FWC, USFWS, DOR, USGS, EPA, NPS, SFWMD, SJRWMD, or the county name. A report that prints a hyperlink hands the sourcing to whoever reads it. The URL lives in `data_source_registry` for the refresh job and never leaves the database.

**Warning, live:** `sync_table_provenance_comments()` **overwrites the whole comment**. It ran eleven times on 16 August. Until it merges rather than replaces, anything written into a comment by hand is destroyed on its next run. **That function must be taught to merge before the declaration line is adopted.** Current state: 988 of 2,112 populated tables carry a comment; 55 columns carry one.

---

## 3 — Authority is a LABEL, not a ranking

**We report every layer. We do not pick a winner.** Four flood layers means four reported findings, each carrying who published it. The tier is disclosure, not selection.

| tier | meaning |
|---|---|
| `originator` | the agency that created the determination — FEMA for NFHL, FDEP for contamination |
| `republisher` | a county or agency serving someone else's data back, often at an older vintage |
| `derived` | computed by us from something else |
| `unestablished` | source not recorded — **cannot support a negative finding** |

Derivable today from the existing `source_url`, no research:

```
republisher     341 tables   49.1M rows
unestablished   108 tables   11.8M rows      ← this is a pull list, not a tier
originator       84 tables   12.8M rows
derived          16 tables    2.6M rows
```

**A tier derived from a URL is a claim about the URL.** `dep.state.fl.us` is the originator for FDEP's own layers and a republisher for anything FDEP mirrors. Mark the tier `derived_from_url` until confirmed — a badly-derived tier treats unequal things equally in a new costume.

`precedence` in `layer_resolution` is **jurisdiction level** — municipal beats county beats state for the same concept. It is not authority and must never be conflated with it. All 67 flood layers sit at precedence 2 and that is correct: they are all county-level, and all four authority tiers are represented among them.

---

## 4 — The relation registry

`layer_resolution` keeps only what is genuinely relational: `geo_id`, `concept`, `precedence`, `resolution_mode`, `variant`. Everything else on that table is attribute that should fold down onto the table itself.

`concept_registry` is **the skeleton key and it does not grow per state.** "What is the flood zone" is the same question in Florida, Arkansas and British Columbia. 65 rows today. Adding a state adds zero.

**A concept is only honest if every member shares the same obligation.** If two layers under one concept oblige a buyer to do different things — hire a biologist and file a federal permit, versus nothing — it is a bucket, not a concept, and it will render a false finding. `environmental_overlay` was retired on 16 August for exactly this: it rendered a $30,650-per-acre federal take permit and a 29-year-old unfunded wish list identically.

---

## 5 — Reading a table before declaring it

Never from the name. Six tests, in order, each of which has caught a real defect:

1. **Distinct values on the answer column.** Zero means it answers nothing. Equal to the row count means it is an identifier — six column-map entries pointed at `objectid` or `ogc_fid`. *Exception:* a district-level layer legitimately has one polygon per value.
2. **Sample the values.** `rezone` had twelve plausible values and was the ordinance field, not the district.
3. **Row count against the population.** 15 rows for a city's zoning is a district map or a defect; 17,249 is parcel-joined. 1,597 polygons for 682,984 parcels is a generalised map.
4. **Look for the history column.** Nine found so far: `originalzone`, `rezone`, `prevflum`, `previouszoning`, `previous_zoning`, `flupy_zone_from`, `priorusety`, and St Lucie's `previouszo` / `previous_1` / `previous_2` / `previous_3`. **A zoning table very often carries its own history and the history column is named plausibly.**
5. **Single-valued flag is a sentinel, not clearance.** `cor_status='A'` on all 436. `confidential='NO'` on all 527,837. Either the county filtered at source or the column is dead — ask, never assume.
6. **Negative control on the subset where the field varies.** A 99.94% agreement had a 94.23% chance rate because 97% of parcels had one address. On the subset that varies: 98.02% against 37.77%. **Run the control where the value carries information, not over a population dominated by one value.**

---

## 6 — Coverage today

```
concept                  layers  join  col_map  provenance  verified   counties
sinkhole                     59    59       59          59        59     59
subdivisions                 30    30       30          30        30      —
flood                        67    67       18          67        67     67
zoning                       77    77       70          45        45     47
land_use                     91    91       78          51        52     62
parcel_geometry_county       37    37        0          37         0     37
address_points               28    28        0          28         1     28
```

**Complete and routable now: sinkhole, subdivisions, flood** (flood's column map is thin but `flood_col` falls back to NFHL standard names and resolves zone on 54 of 54).

**Not routable: `parcel_geometry_county` and `address_points`** — 65 layers with no column map and `verified=false`. Routing unread layers is the 54-municipal-layer mistake at larger scale.

**The gap that cannot be closed any other way: 20 counties have no zoning layer.** FLU went 31 → 62 counties on 16 August.

---

## 7 — The acquisition system

**County layers: the ArcGIS Hub DCAT-US feed.** Every county hub publishes `…/api/feed/dcat-us/1.1.json`, which lists every dataset with its REST endpoint. Parse title and `accessURL` where format is `ArcGIS GeoServices REST API`. This is how Putnam and Lake were enumerated.

**Read the service directory, never probe a guessed layer path.** `…/MapServer?f=json` lists every layer with its name and ID. Compare against what is already held and report the gap.

**For the 20 zoning-gap counties, two regional servers cover 14:** SRWMD covers 8, ARPC covers 6. Two directories to enumerate, not twenty.

**Parcels usually are not on the county hub** — they sit on the Property Appraiser's own server. That is expected, and the statewide spine already covers them.

Standing acquisition rules, each bought with a failure:
- **`returnIdsOnly` set-diff is the only completeness check.** A page loop cannot detect its own truncation. Citrus at exactly 6,000 rows and Sumter at exactly 4,000 are open suspects.
- **FDEP publishes EPSG 6439** (NAD83 Florida GDL Albers, metres). Pull with `outSR=4326` or geometry silently misplaces. Treat it as the FDEP default, not an exception.
- **Page size**: NPS caps at 250; the NHD service `MaxRecordCount` is 1000, not 2000.
- **NPS NRHP filters on `State='FLORIDA'`**, not `'FL'`.
- **Abort on zero.** An empty return is a sentinel for a wrong filter, not an answer.
- **`reltuples` rounds** for large tables. Only exact `count(*)` proves a round number is truncation.

---

## 8 — The thing that makes all of it real

**One of 75 served functions calls the resolver.** `get_pir_report` reaches its data through 33 helper calls and 20 hardcoded table names; it never asks the resolver anything.

So every number in §6 is **provenance and reachability, not serving.** Registered 419 → 557 and in-resolver 375 → 492 on 16 August are real gains in what is *described*. They changed no report.

**The test of success is not a count.** Add a 60th sinkhole layer to `layer_resolution` and confirm a report for that place changes **without a deploy.** Until that is true, wiring is bookkeeping.

Route the one-layer-per-place concepts only — flood, zoning, land_use, sinkhole — and start with sinkhole, because it is complete, verified, and the concept nobody would notice if it broke. Leave the CAMA roles hand-wired; they are compose-shaped and `resolve_layers` is a day old.

---

## 9 — Standing rules that govern reading

- **Names lie, contents don't.** Four tables on 16 August wore a label their contents contradicted.
- **Search for the artefact before describing the gap.** Five times on 16 August something declared missing already existed: Polk relational CAMA, `table_inventory`, `layer_column_map`, `ladm_declaration`, and the inbox itself.
- **A guard that errors is not a guard that fails.** `run_defect_detections` records `error_text` separately and a red summary line hides the difference.
- **A plant that silently fails to plant is a green light for nothing.**
- **`limit N` without `ORDER BY` is not a sample.** It produced a 36-point error against a verified figure.
- **`statement_timeout = 0`** is for a load you have decided to wait for. On an exploratory query it removes the only signal that the design is wrong.
- **Join `geo_reference` on county name. Never write a county number by hand.** Four FIPS-versus-DOR errors on 16 August alone — Polk is 63 not 105, and 20 is Clay not Columbia.
- **A county is not loaded until its key joins, the join is indexed, and a served function reads it.**
- **Registering a table is not finished until `sync_table_provenance_comments()` has run.**
- **Read the served function before ruling on the data.** Three rulings on 16 August were withdrawn or softened because the serving code already handled what the ruling assumed it did not.

---

## 10 — Open, in priority order

1. **Teach `sync_table_provenance_comments()` to merge**, or the declaration line cannot be adopted.
2. **Derive `authority_tier` for 549 tables**, marked `derived_from_url`, turning 108 unestablished into a pull list.
3. **Route sinkhole through the resolver as the pilot**, then prove it with a 60th layer and no deploy.
4. **Enumerate SRWMD and ARPC** for the 20 zoning-gap counties.
5. **Fold attribute columns down** from `layer_resolution` onto the tables; keep only geo_id, concept, precedence, resolution_mode, variant.
6. **Read the 65 unverified layers** — 37 `parcel_geometry_county`, 28 `address_points` — before either concept is routed.
