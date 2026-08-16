# Department of Property — the system, rebuilt from the journey

*Written 2026-08-13. Reconstructed from the defect registry, the build backlog, the ruling bus, and the conversation record.*

---

## 0. What this document is

Murphy asked me to rebuild the system on paper from day one and find where the keys are. This is not a status report. It is an attempt to say **what was actually learned**, in the order it was learned, and what the system became as a result.

The short version: **this was never a data acquisition project. It is a truth-maintenance project that happens to need data.** Everything that has gone right follows from that, and every serious defect has come from forgetting it.

---

## 1. The founding measurement

The Volusia CAMA relational export was loaded. It revealed that **41.5% of Volusia real-property parcels have more than one owner.**

Every flattened source used until then — including the DOR statewide tax roll, which carries one `OWN_NAME` — had silently dropped co-owners.

This is the origin of everything. Not because ownership is the most important field, but because of what it proved:

> **A source can be complete, authoritative, current, and wrong — because of what it cannot express.**

The DOR roll wasn't lying. It has one owner column. The defect was in believing a single column could hold a set. Once you have seen that once, you cannot un-see it, and it recurs in every layer of the system:

- One `verified` flag holding three claims
- One `status` column serving two lifecycles
- One `zone` value on a parcel that spans two districts
- One parcel row for a parcel that has 1,215 fragments
- One registry that could express "pulled from" but not "derived from"

**Key #1: the shape of the container decides what truths can survive it.** Most defects in this system are shape defects, not value defects.

---

## 2. Roz was the instrument, not the product

Murphy tested Roz adversarially — with Gemini and Google alongside, deliberately trying to break it. That is what surfaced almost everything.

This is worth stating plainly because it inverts the usual reading: **Roz's failures were the project's most valuable output.** The AI assistant was a probe that could reach every corner of the data and report what it found in natural language, which made errors legible in a way a SQL result never is.

The two findings that defined the system:

### St Petersburg — 501 Park St N

Roz told a user the parcel was *"outside a mapped Special Flood Hazard Area… no federal flood-insurance mandate."*

It is **24.2% Zone AE, BFE 10–11 ft NAVD88**, plus 62% in the 0.2% annual chance zone.

Cause: `get_site_intelligence` read only `fema_flood_zones`, where `county_name` held **pull-batch labels** — `swcoast`, `central1` — not county names. Pinellas did not exist in it. Zero polygons within twelve miles.

**A coverage gap was narrated as a finding, and an insurance conclusion was attached to it.**

### The elevation

Roz fabricated *"2024 USGS lidar-derived, ±0.96 ft vertical accuracy, NAVD88"* for a ground elevation. No such column existed anywhere in the schema. It did this **seven times**, with escalating false precision, over a field whose `source_url` was null.

Two prompt-level guards failed to stop it.

**Key #2: absence is the failure mode, not error.** A wrong number gets caught. A missing number gets *filled in* — by a model, by a default, by a reasonable-looking join — and the filling is fluent and confident. The system's entire architecture is a response to this single observation.

---

## 3. What was built in response

Each mechanism below exists because of a specific failure. None of them was designed in advance.

| mechanism | the failure that caused it |
|---|---|
| **Three coverage states** — `present` / `none_recorded` / `not_available` | St Petersburg: a gap rendered as a negative |
| **Fact index** — every rendered field traces to subject/predicate/value/source/tier/as_of | The elevation fabrication |
| **Defect registry with live detection SQL** | Defects being fixed and silently recurring |
| **Golden parcel suite** — 10 parcels × 28 sections, structural and value hashes | No way to know a fix broke something else |
| **Registration-time contract trigger** on `detection_sql` | Predicates that were never executed |
| **`repair_geometry_once`** at ingest | `ST_MakeValid` per call: Marion 4.98 s → 27.7 s timeout |
| **`_parcel_geom_agg`** | 97,380 fragmented parcels read one fragment |
| **`layer_resolution`** unified on one precedence primitive | Five fragmented registry tables |
| **`source_observation`** append-only cadence | 207 sources carrying an invented 90-day refresh interval |
| **DDL event trigger** auto-revoking on SECURITY DEFINER | 36 anon-callable functions; the manual revoke was a no-op |
| **`restriction_authority`** — statute, agency, consequence, who-can-answer | Findings with no legal meaning attached |
| **`derived_from`** on the registry | 59 sinkhole splits appearing unsourced |
| **`is_coastal`** on `geo_reference` | Coastal concepts returning false inland |

Read that table as a curriculum. **Every row is a lesson that cost something.**

---

## 4. The keys

These are the things that, once understood, explain the rest of the system. If someone had to rebuild this from nothing, these are what they would need.

### Key A — Zero is a sentinel, never a result

An empty return is a signal to abort and investigate. It is not an answer.

This one rule caught: the flood pull returning empty bodies (treated as errors, retried — four counties would otherwise have loaded silently empty); the Pinellas endpoint returning `Array` (a five-byte body that looked like success); truncation at exact multiples of page size.

### Key B — Names lie, contents don't

Every significant source decision has been made by reading contents, never names:

- **NHD vs FHD**: FHD's description claimed 1:5,000 scale, five times finer. Measured: it is 0.5% *smaller*. The claim was inherited boilerplate.
- **`fema_flood_zones.county_name`** held batch labels.
- **Santa Rosa zoning** served rezoning petition numbers where district codes belonged.
- **A school layer** held board member names, not attendance zones.
- **NRHP "district polygons"**: 298 of 306 are `MAP_METHOD = 'Derived by XY event point'` — circles around a point, not boundaries. Only **5 digitized districts in all of Florida** support a containment test.
- **`miamidade_municipal_zoning`** contains `zone='NONE'` jurisdiction outlines, one of them 2,076 sq mi — larger than the county.

### Key C — A guard must be able to fail

**Three guards in this system could not fire.** All three were found by testing them with a deliberate violation:

1. The anon `EXECUTE` revoke — the grant came via `PUBLIC`, so revoking from `anon` did nothing.
2. `repair_geometry_once` — repairing 10.7M geometries that were already 100% valid.
3. The fragment detection predicate — blind to `select p.geom into g`, the ordinary form of its own defect.

> **A green predicate with no negative control is an assertion, not evidence.** Plant the violation, show red, remove it, show green, paste both.

### Key D — Self-consistent checks lie

The metadata disagrees with the data, and the data wins. Every time.

- `last_successful_pull_date IS NULL` said FUDS was never pulled. It holds 1,273 rows.
- `county_coverage_status` has been wrong repeatedly.
- An internal `objectid` sweep produced ~50% false positives by keying on a column *named* `objectid` rather than the layer's real OID.
- The `dataset_coverage` table said flood covered 49 counties; the business plan said 52; neither was true.

**Verify against live data, never stored summaries.** Set-diff against the source is the authoritative check.

### Key E — The query direction is the privacy line, not the column list

Murphy's ruling, and it is better than the rule it replaced:

> **Load complete. Scrub at render.**

The database holds the whole record — grantor, grantee, reporter, violator names. The *report* filters them. Because:

- Deciding per-column at ingest is a judgement repeated hundreds of times, each one a chance to drop something that later matters
- A truncated record cannot be un-truncated (Palm Beach is 11 months stale; Miami-Dade needs a Chapter 119 request)
- A deed chain without parties is not a deed chain
- One rule at one boundary is auditable; hundreds of ingest decisions are not

And the actual line: **property-keyed, never person-keyed.** Holding a grantee name on a parcel record is property-keyed. Letting someone type a name and get every parcel they touched is the assembled personal profile — a different product with a different legal character.

This is also a **liability position**: *"we hold these records, we don't distribute them."* That only holds if the boundary is demonstrable, which is why the report snapshot with a payload hash matters more than it looks.

### Key F — Acquisition outran resolution

The single largest structural problem, and it is not a data problem.

| | |
|---|---|
| populated tables | 2,063 |
| registered sources | 292 |
| **served layers with no registry entry** | **172 → 94** |
| concepts registered | 41 |
| concepts actually wired | 30 |
| city zoning layers held | 59 |
| city zoning layers wired | 3 |
| statutes documented in `restriction_authority` | 12 |
| statutes that could join to a concept | **1 → 11** |

For weeks, data was pulled and never wired. 798,851 wetland features sat unreachable. 8,935 sinkhole susceptibility polygons — the layer that gives an incident count its *meaning* — sat unreachable. FUDS unexploded-ordnance sites, loaded 25 July, never surfaced.

**The database was not short of data. The resolver was short of concepts.**

### Key G — Coverage is the product, not the caveat

This is the commercial key and it is counter-intuitive.

RPR is free with NAR dues and holds 147M parcels. It cannot be beaten on volume. But its flood layer is FEMA NFHL only, and it has no contamination, no institutional controls, no wetlands, no permit-versus-improvement cross-examination.

So the product is not "more data." It is:

> **"We cannot tell you X, and here is exactly who can."**

A checklist item routed correctly is a service. A confident wrong answer is a liability. The three coverage states, the `who_can_answer` column, and `restriction_authority` are not compliance furniture — **they are the differentiator.**

---

## 5. Where the journey actually got to

### The two demonstrable findings

**1440 Riverside Dr, Holly Hill.** A 1,022 sq ft boat dock and 220 sq ft boat house, both recorded 2008. Six permits on file — hurricane protection, HVAC changeout, shingle reroof, addition, garage — **all readable, none marine.** Two carry the Holly Hill municipal code, proving the register captures city permits for this parcel.

Getting to a defensible version of that required establishing **three coverage boundaries**:
- **temporal** — the permit register begins 1988; 5,014 of 6,097 "unpermitted" improvements simply predate it
- **authority** — the file is county-*aggregated*, not county-issued; municipal permits are in it
- **descriptive** — 20.0% of permits have a null or generic description and cannot support an absence claim

1,589 findings survive all three. Not 6,097.

**3251 S Miami Ave — Vizcaya.** County-owned, built 1916, $106.5M just value. **Inside the Vizcaya National Historic Landmark district** — one of only five digitized boundaries in Florida where containment is defensible. **Two on-parcel FDEP contamination facilities**, one status OPEN, with a live document link. Biscayne Bay **adjacent, 1,989 ft of shoreline**. Flood 27.1% Zone AE / 14.0% VE, in SFHA. Zone CI at 84.9%.

Neither of those is producible by any competitor.

### The correction rate

Defects registered by date: 17 on 24 July, 7 on 30 July, 13 on 8 August, 13 on 11 August. By class: 25 completeness, 10 entity confusion, 9 geometry, 9 key integrity, 8 access control, 8 null-as-value, 5 temporal, 5 resolution mislabelling.

**This looks like decay and is the opposite.** Every one of those defects was already in production before it was registered. The rate reflects how hard we are looking, not how fast things are breaking. And each one now leaves a predicate behind — the registry is not a list of what is broken, it is **a list of what is watched.**

---

## 6. What I got wrong, and the pattern

I made the same error at least six times in a single day:

- Reported FUDS as never-pulled — read `last_successful_pull_date`, not the table
- Reported six Volusia layers as never-pulled — same
- Presented an archaeological caveat as a new coverage state — it was already in `restriction_authority` and the spec
- Said `environmental_overlay` was contamination content — it is conservation and species
- Said "15 mining tables," "12 CHHA tables" — both were `LIKE`-pattern counts, actually 5 and 3
- Checked parcel IDs CC never sent, and twice told it its work was untraceable
- Ran a truncated copy of CC's own predicate and reported a blindness that did not exist

**One cause: reading an artifact and reporting it as a fact about the thing.** It is precisely the failure the whole system is built to prevent, committed by the person supervising the system.

Which is the real argument for the machinery. Not that people are careless — that *everyone* substitutes the label for the thing under load, and only a check that runs catches it.

---

## 7. Where the keys are for completion

Not a task list. The four things that, if true, mean the system is done in the sense that matters.

### 1. Every rendered number traces (items 79 + 95)

Roughly a third of rendered fields still have no provenance — the whole §1 identity block (14 of 32), tax and exemptions, economic zones, ground elevation. §1 is what a reader trusts *first*. Item 95 is still a seven-string blocklist rather than a validator.

**`parcel_elevations` holds 10,739,881 rows, 100% populated, max 341.8 ft against Britton Hill's true 345 ft — and zero provenance.** The elevation was not fabricated because no data existed. It was fabricated because data existed *with no source*.

### 2. The render boundary is a checked thing

"Load complete, scrub at render" currently lives in judgement. It needs a person-name field list in a table, a check over the **rendered payload** not function source, and a negative control.

### 3. The report is reproducible

`assistant_query_log` already has `payload_hash` and `roz_version` — the pattern exists and is correct. `pir_access_event` records *that* access happened, not *what was returned*. There is no PIR snapshot.

Zero PIRs have been sold. **This is the cheapest moment it will ever be to add**, and it must exist before the first paid report.

### 4. The city rung is wired

412 municipalities are now in `geo_reference`. 56 city layers holding 473,043 rows are still unreachable. Every incorporated parcel in Florida — Tampa, Orlando, Miami, Hialeah, Fort Lauderdale, St Pete — returns `not_established` for zoning.

That is where most Floridians live and where property sells.

---

## 8. The one-sentence version

> **The product is a defensible answer, and the defence is the coverage statement — so the system's real asset is not the 99 million rows, it is the machinery that knows what it does not know and says so.**

Everything else — the pulls, the concepts, the indexes, the guards — exists to keep that sentence true.
