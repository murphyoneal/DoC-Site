# The PIR System — Architecture and Goal State

**Recorded 2026-08-08.** Every figure below was measured against the live database on the day of writing. Where a number is quoted from another document it is labelled as such.

---

## Part 1 — What this system is

**An automated system that produces Property Intelligence Reports for any Florida parcel.**

That is the whole purpose of the Florida dataset. Every pull, every table, every schema decision serves one output: a report a buyer or an agent can act on before a property is listed or purchased.

**AddressFolder is a parallel consumer, not a downstream product.** It reads a subset of the same tables — permits, contractors, recorded improvements, building records — and produces a different output for a different reader. The land is the PIR's subject; the structure is AddressFolder's. One anchor, the parcel; two outputs; shared substrate.

Nothing else is a product. The registries, the coverage tables, the defect suite, the geographic backbone — all of it exists to make those two outputs correct and keep them correct as sources change.

---

## Part 2 — The architecture, stated plainly

The system was designed around a principle that is worth restating because it is the thing that has not been carried through:

> **A report must resolve which layers apply to a parcel, rather than knowing which tables to read.**

Sixty-seven counties publish the same concepts under different table names, different column names, different key formats, different projections. A function that names its tables is a function that must be edited every time a county republishes. A function that *resolves* its tables reads a row.

The mechanism was built. `county_layer_registry` holds the index: **1,678 rows**, keyed on `county` and `concept`, carrying `table_name`, `key_column`, `bridge_key`, `key_transform`, `srid`, `row_count`, `verified_at`. That is the wiring — file by jurisdiction and concept, so a query touches only the layers that shadow the parcel.

Above it sits `geo_reference` — **74 rows**, ISO-namespaced (`US-12`, `US-12095`, `CA-5917`), abstract `admin_level` 0–3 so "state/county/place" vocabulary does not leak into the schema. Built after Nova Scotia's SGC `12` was found to collide with Florida's FIPS `12` on bare keys.

---

## Part 3 — Current state, measured

### 3.1 The resolver pattern is adopted by one concept out of sixteen

Six served functions were inspected on 2026-08-08:

| function | resolves via a table | hardcodes tables |
|---|---|---|
| `get_parcel_flood_zone` | ✅ `flood_layer_selection` | — |
| `get_pir_report` | ✗ | ✅ (16 `volusia_*` references) |
| `get_nearby_amenities` | ✗ | ✅ |
| `get_parcel_econzone_facts` | ✗ | ✅ |
| `get_parcel_values` | ✗ | ✅ |
| `resolve_parcel_geometry` | ✗ | ✅ |

**None reference `county_layer_registry`. None reference `geo_reference`.**

### 3.2 The one resolver-driven concept proved the pattern

Flood and economic overlays failed the same week, in the same defect class — asserting a definite negative over data never queried.

**Flood**, resolver-driven, was fixed by updating rows: eight junk layers de-selected, seven counties recovered, Pasco re-pointed. No function edit, no deploy, no front-end coupling. Result: 53 of 67 counties serving a correct determination, 8 false negatives eliminated, 4 report crashes eliminated.

**Economic overlays** (item 112), hardcoded, required transcribing a 16KB function and diffing 27 per-section md5 hashes to prove nothing else moved.

Same problem. One took a migration; the other took a day and a verification harness.

### 3.3 Consequence for refresh

This is not a snapshot dataset. Sales occur, rolls are certified annually, counties republish weekly, layer names change, domains migrate (`polkpa.org` → `polkflpa.gov`, observed 2026-08-08).

In the current shape, **every one of those events is a code change and a deploy** for fifteen of sixteen concepts. In the resolver shape, each is a row.

---

## Part 4 — Coverage today

### 4.1 Statewide layers — complete, and the basis of the product's unique value

| layer | rows |
|---|---|
| NWI wetlands | 798,851 |
| FDEP petroleum tanks | 74,262 |
| FDEP STCM contamination | 72,357 |
| FDEP contaminated site cleanup | 10,185 |
| FDEP source water protection | 9,513 |
| FDEP institutional controls | 2,637 |
| NRHP points / district boundaries | 1,437 / 306 |
| FDEP dry cleaning sites | 1,293 |
| FDEP brownfield areas | 624 |
| FDEP groundwater contamination areas | 376 |
| Phosphate mining units | 301 |

Plus DRASTIC aquifer vulnerability across three aquifers and sinkhole incidents across ~45 counties.

### 4.2 County-partitioned layers — the gap

From `dataset_coverage` (derived 2026-07-29, therefore stale; flood corrected from the live selection table):

| dataset | counties |
|---|---|
| parcels / parcel_record / parcel_elevation | 67 |
| flood_zones | 53 |
| airport_proximity | 4 |
| water_service | 3 |
| wind_design | 3 |
| storm_surge | 2 |
| marine_improvements | 1 |
| tax_deed_lands_available | 1 |

**Wind design, storm surge and airport proximity do not require 64 further county pulls.** FBC/ASCE wind contours, NHC SLOSH surge zones and FAA airport data are published once, statewide or nationally. Three pulls, not ~190.

### 4.3 Absent entirely

- **NHDArea and NHDFlowline.** `hydrology_waterbodies` holds 41,087 NHDWaterbody rows (LakePond, SwampMarsh, Reservoir), loaded 2026-07-05. Florida therefore has lakes and swamps but **no rivers, canals, estuaries or coastal water**.
- **SSURGO soils.** Identified in spec v5, never pulled.
- **Zoning and future land use** beyond Volusia — the layers are held for 64 counties, unwired.

### 4.4 CAMA relational depth

Measured 2026-08-08 by schema probe: **Lee (111 distinct columns), Duval (24), Pasco (17)** — all relational, **none iasWorld**.

The loader-reuse hypothesis does not hold. Statewide CAMA depth is per-county mapping work. Eight of the twelve largest counties publish a free relational export; four are gated behind ASP.NET postbacks, authenticated sessions, JavaScript-driven downloads, or a fee.

---

## Part 5 — Correctness instrumentation

`data_defect_registry` holds **37 entries**, every one with a `detection_sql`. Until 2026-08-08 none had ever been executed as a set.

First full run (`run_defect_detections()`, results in `defect_detection_runs`):

| status | count |
|---|---|
| clean | 4 |
| defect present | 9 |
| **errored — cannot produce a verdict** | **24** |

Of the 24 errored: 12 are un-substituted templates containing literal `{table}` / `{county}` / `{col}` and have never executed; 1 is a blind spot returning `examined=0`; 11 return a bare count or text with no declared pass condition.

**Only 3 of 37 predicates exercise the served path.** The remainder check tables, schemas or registry rows. A table-level check passes green while the function reading it lies — which is exactly what happened with flood: the Pinellas layer was healthy and the report still returned "not in a Special Flood Hazard Area."

---

## Part 6 — The goal state

### 6.1 The target, defined

**Coverage and correctness are separate numbers and must not be conflated.**

- **Coverage** — how much data is held. Currently partial and rising. No report depends on it being complete.
- **Correctness** — whether the report correctly serves what is held and honestly discloses what is not. **This is the number that must reach 99%.**

A parcel in a county where nothing is held can still produce a correct report, provided every gap says so and names who can answer. What breaks correctness is a false statement, never a missing one.

Correctness rises on its own as coverage rises. Coverage does not fix correctness.

### 6.2 What the system must do

1. **Resolve, never hardcode.** Every served function selects its layers from `county_layer_registry`, keyed on `(geo_id, concept)`. Adding a county, replacing a layer, or absorbing a renamed source is a row, not a deploy.
2. **Three coverage states, never two.** `present` · `none_recorded` · `not_available`. A `not_available` returns null, never false, and never a downstream conclusion.
3. **Every claim traces to a fact record** — subject, predicate, value, source, source_tier, as_of, corroborators, contradictors, derivation. The model narrates around facts it cannot originate.
4. **Detections exercise the served path**, not the table beneath it, and run on a schedule rather than on request.
5. **Absorb change without code.** Sources update daily, weekly, monthly, annually. The system must ingest a refresh and re-resolve without a function edit.

### 6.3 Migration path

**Stage 1 — extend the resolver to the remaining concepts.** `flood_layer_selection` is the working template. Generalise it to a single resolution mechanism reading `county_layer_registry`, then migrate concepts in order of consequence: contamination, zoning and future land use, amenities, values, geometry.

**Stage 2 — wire the geographic spine.** `geo_id` onto the registries and coverage tables so defects and coverage roll up to county, state and country. Currently only `county_coverage_status` carries it.

**Stage 3 — bring the detection suite to a contract.** One result shape, served-path form for the high-consequence concepts, then schedule it.

**Stage 4 — report structure.** The nine-section flow, once the payload beneath it is trustworthy.

---

## Part 7 — AddressFolder, and why it is parallel

AddressFolder reads the structure half of the same substrate: permits, named contractors, recorded improvements, building records. Volusia alone holds **992,313 permits across 240,264 parcels, 147,113 named contractors, and 363,677 recorded improvements**; statewide, **8,485,822 parcels carry a building record** (figures from the business plan, not re-measured here).

It is not downstream of the PIR and does not wait on it. It differs in three ways that matter architecturally:

- **The owner is a source.** The PIR forbids originating a value; AddressFolder's premise is that a homeowner asserts things about their own house. That needs its own tiers — `owner_asserted`, `contractor_asserted`, `device_captured` — which **never corroborate a record fact**.
- **It works where no register exists.** The chain `parcel ← permit ← contractor ← job` is register-dependent. The chain `product ← manufacturer ← recall` is not: a data plate reads the same anywhere. Build the cold-jurisdiction case first; pre-population is an enrichment layer over the same structures.
- **Its records are append-only and separately authored.** A homeowner's log and a contractor's response are distinct streams. Neither may edit the other. A record the accused party can alter is worthless as evidence.

The same three-coverage-state discipline applies: an unpopulated folder must render *"no permit register held for this jurisdiction"*, never a blank page that reads as a property nothing ever happened to.

---

## Part 8 — The recurring failure, named once

Three independent surfaces produced the same defect within one week:

- An elevation figure fabricated seven times with escalating specificity over a field whose `source_url` was NULL
- A flood layer asserting "not in a Special Flood Hazard Area" for eight counties whose layers held ~0 polygons inside the county
- A CAMA vendor classification returned from **zero columns read**

**Absence gets filled with a confident answer rather than reported as absence.** Every guard in this system exists against that one failure. The correct first question at any new surface is not "does this work" but **"what does this return when it has nothing."**

Two corollaries, both earned:

- **Names lie; contents do not.** The flood selector matched column names and silently skipped nine counties whose FIRMs named their fields differently. A slug match missed St. Johns because it publishes as `sjc_`. `ST_Intersects` against a county polygon false-positived because a Volusia HUBZone edge crossed the Marion line. Resolve by reading contents — interior points, value distributions, extents.
- **An empty result is a sentinel, not a finding.** If a filter returns nothing, assume the filter is wrong until proven otherwise.
