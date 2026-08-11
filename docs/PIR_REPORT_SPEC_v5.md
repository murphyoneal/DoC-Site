# PIR Report — Definitive Specification (v5)

**Supersedes v1–v4.** Recorded 2026-08-03.

v4 was written on 23 July and was right about nearly everything. Ten days later most of it is **built**, some of it is **superseded by a better mechanism**, and three claims are **measurably wrong**. This document says which is which, because a spec that describes intentions rather than the running system is a historical document.

**Read Part 0 first.** It is the only part that has changed in kind rather than degree.

Evidence for every claim is reproducible: `data_defect_registry` (32 classes), `restriction_authority` (12 citations), `statewide_metrics` (method SQL per figure), `build_backlog` (51 open items), and `DATA_JOIN_FINDINGS.md`.

---

## Part 0 — The report is no longer five pages, and the model is no longer "fields with provenance"

Two structural changes supersede v4's Parts A3, D and I.

### 0.1 Nine sections, ordered by what a buyer must act on

The five-page print structure has been retired. Page breaks were determining content order, which put a regulatory obligation and a nearby-amenities list on the same sheet because that is where the break fell.

The report is now a **single continuous flow in nine sections**:

| § | Section | Rule |
|---|---|---|
| 1 | **What this is** | Identity and frame first. "1930 house inside two National Register historic districts" before any use code. |
| 2 | **What legally binds this property** | `federal_regulatory` and `state_regulatory` only. No distances appear in this section. |
| 3 | **What is on or under this parcel** | `contains` relation only. |
| 4 | **What is nearby** | Everything with a distance. Ranked by status first, distance second. |
| 5 | **The record** | Values, ownership, transactions, permits, zoning — facts with their `as_of`. |
| 6 | **Open questions** | The due-diligence payload. What does not add up, who to ask, what to request. |
| 7 | **What we could not tell you** | Every `not_available` and `not_established`, with who can answer. A service, not an apology. |
| 8 | **Further due diligence** | Web findings, tier-separated. `.gov` first as findings; market status second as dated observations. |
| 9 | **Sources** | Jurisdiction-level citation. |

**Two hard rules.** Nothing above §4 carries a distance — if it has a distance it is proximity, and proximity is §4. And statutory notices that apply to every parcel in Florida (the burial statute, s.872.02) go last in §2, marked universal, so they do not read as findings about this property.

**The lead** is the frame plus the single most consequential regulatory fact, ranked: contamination containment → SFHA → GWCA → institutional control → lead-paint duty → historic district. First present one wins; contamination and GWCA causally combine, two clauses maximum. Where none is present the report says so and points at §7 — silence must never read as clearance.

### 0.2 The fact index — every rendered claim traces to a record

v4's Part D said "every field carries four attributes." That was right and insufficient. **The model is now a fact record, and the renderer is deterministic:**

```
subject · predicate · value · source · source_tier · as_of · corroborators · contradictors · derivation
```

**The model may not originate a field value.** Rendering is code. The model narrates *around* facts it cannot alter — synthesis over records is the product; originating a number is prohibited.

**Why this is not a refinement.** An elevation figure was fabricated **seven times** with escalating specificity — ending at *"USGS 3DEP lidar-derived, vertical accuracy 0.64 ft NVA / 0.96 ft VVA at 95% confidence"* — over a field whose `source_url` is NULL. Two prompt-level guards failed. The failure mode is that **absence, not wrong data, is what gets fabricated over**. Clean data would not have prevented it.

**A null renders a fixed string authored in code**, never a sentence the model composes.

**Source tiers:**

| tier | meaning |
|---|---|
| `federal_regulatory` / `state_regulatory` | binds the property (FEMA SFHA, Ch. 62-524) |
| `primary_instrument` | deed, plat, permit as filed |
| `government_register` | DOR roll, FDEP, NPS, DBPR, Clerk index |
| `county_assessor_record` | a professional observation made for taxation |
| `federal_statistical` | ACS — a sample estimate, with a published margin |
| `government_derived` | computed from a register |
| `analysis_inference` | **ours**, never borrowing another authority |
| `tier 4` | internet, non-record — never a record fact, never a corroborator |

**No confidence score.** Show source count, tiers, independence and dates. A 0–100 number is the next fabrication.

**Independence is computed, not asserted.** `roz_sources_lineage_disjoint` traverses a `derives_from` graph and **fails closed** — an unmapped pair returns *not established*, never *independent*. RealtyTrac reporting the same square footage as the DOR roll is one fact wearing two hats. Volusia CAMA and the NAL roll are the same lineage at different freshness. Verified independent: DOR year built and the NPS nomination form.

---

## Part A — What v3 and v4 got right (do not change)

1. **Individual badge-compasses**, one per amenity. Absence of a badge is informative.
2. **Maximal default population.** Hiding is a display toggle, never a generation decision.
3. **Counts must match lists.** 14 permits means 14 listed.
4. **Never invent a status.** "Completed — final status not on file" where the county records none.
5. **Honest absence** beats a blank or a guess.
6. **Jurisdiction-level citation only.** Never name the portal.
7. **Crime category filtering** is a hard requirement before anything ships.

---

## Part B — Ownership is a set ✅ BUILT

`get_parcel_owners_facts` emits **one fact per owner**, plus `owner_count` as its own fact.

**Percentages are never normalised.** Under tenancy by the entirety each spouse holds 100%; `PCTOWN` summing to 200 across two names is **correct**, not a data error. Any code that divides, sums or "fixes" it is wrong.

**Owner name is a reported fact, never a join key.** Rejected as an anchor — volatile and legitimately time-varying. Where name-stem matching is used for holdings, report *related by name*, never *same owner*.

Measured: 41.5% of Volusia real-property parcels have multiple owners.

---

## Part C — Two-level property model (lot vs interest) ⚠️ PARTIALLY BUILT

The lot/interest distinction is correct and unchanged. Sarasota 19% stacked, Manatee 39%, Seminole 0%.

**What was learned since:** the same failure has a second form. `parcels_staging` carries **duplicate `parcel_id` within county** — St. Johns 26.7%, 205,773 rows for 150,880 parcels. Verified across 3,443 fragment groups in six counties: **100% one owner, one address.** These are genuine geometry fragments of one parcel.

**Aggregating is correct. Deduplicating would be wrong.** One parcel had 1,215 fragments; reading one gave 0.057 acres, the union gives 90.169 against a roll figure of 94.480 — a **1,580× error**.

`resolve_parcel_geometry` aggregates, guarded by the owner/address invariant.

**Still open:** condo unit-vs-complex resolution. Untested end to end.

---

## Part D — Provenance and vintage ✅ SUPERSEDED BY PART 0.2

Per-field provenance is now the fact record. Two vintage rules survive verbatim:

**`as_of` is the winning branch's date, per field** — not per block. `justValue` may come from CAMA 2026 while `improvementValue` falls through to NAL 2025.

**The DOR roll is a 1 January snapshot**, ~19 months stale at worst. Measured: Volusia CAMA 2026 says $2,094,505; NAL 2025 says $2,064,178 — same parcel, 1.5% apart, twelve months apart. **Not an error. One is last year's.**

Correct display: *"Owner of record — Florida DOR 2025 certified roll, as of January 1, 2025."*

---

## Part E — Source precedence ✅ BUILT, with one correction

The precedence table stands. **Correction to v4:** *"Flood — county layer preferred over statewide FEMA"* was right and the implementation was wrong.

`fema_flood_zones` holds **pull-batch labels** in `county_name` — `swcoast`, `spacecoast`, `central1` — coverage stops at ~27°N, and every batch count is an exact multiple of 200 (page truncation). A user was told a St Petersburg parcel was **outside a Special Flood Hazard Area with no insurance mandate**. It is 24% Zone AE, BFE 10–11 ft NAVD88.

`flood_layer_selection` now resolves the county NFHL layer **by reading each layer's own contents**, never by matching names. Six counties were recovered that had been silently returning "not established" while holding a full FIRM — including St. Johns, which publishes as `sjc_` and was missed by a slug match.

Leon and Lee publish split **by zone** (`_a`, `_ae`, `_x500`) and require a merge, not a pick.

---

## Part F — Geometry is a tax map ✅ UNCHANGED, LEGAL REQUIREMENT

Every rendered parcel outline carries: *"Approximate parcel outline from county records. Not a survey."*

**Extended in v5 to three more layers**, each with its own caveat:

- **NPS historic district boundaries** derive from nomination bounding coordinates, not survey. NPS states transcription errors permeate that part of the dataset. Membership is *an indication requiring confirmation*.
- **NWI wetlands** are a regional inventory. USFWS states the intended use is regional and watershed analysis, **not project analysis**. A hit is *mapped as wetland*, never *is a wetland* — a jurisdictional determination requires a delineation.
- **Cattle dipping vats** resolve to a PLSS section (~1 sq mi), never to a parcel.

---

## Part G — Withhold rules ✅ BUILT AND ENFORCED

v4's most important requirement, now mechanical.

**Three coverage states, never two:**

| status | meaning | what may be said |
|---|---|---|
| `present` | queried, found | report the value |
| `none_recorded` / `none_intersecting` | queried, nothing for this parcel | a real negative |
| `not_available` | **not queried — we do not hold it** | **never a negative, and never a downstream conclusion** |

A `not_available` field must return **null, not false**. A non-Volusia parcel returns `waterfront_indicator: null` — absence of coverage can never render as absence of a dock.

**Verification protocol unchanged** — match rate, independent corroboration, negative control, cardinality. The negative control is not optional: an acreage corroboration matched 184/184 while random values matched **84.8%**. A check that cannot fail is not a check.

**Anchors:** year built (100%, 1% by chance) and land area vs geometry — **but note the correction**: land-area agreement measures 12.7% at scale, so it is a *lead*, not a guard. Township and section are low-entropy traps. Owner name is rejected.

**The anchor must belong to the entity level being identified.**

---

## Part H — Compliance ✅ UNCHANGED

Property-keyed, never person-keyed. The assembled personal profile is a separate access class and never on the consumer tier. Compilation of individually-public records into a sold report creates a new regulated artifact; "the inputs are public" is not a defence.

**Added in v5:** every finding carries its **authority** and **who can answer** — `restriction_authority` holds 12 citations with agency, what is restricted, the consequence, and the remedy path. That is what makes this due diligence rather than description.

---

## Part I — Precompute ⚠️ PREMISE CHANGED, DECISION REOPENED

v4 concluded the parcel record must be precomputed, from a measurement of 75 ms – 1,210 ms across 4–5 layers.

**That measurement was contaminated** — it was end-to-end including the model call, over un-aimed layers.

The real bottleneck was different and is fixed: `ST_MakeValid` running **per call** on a 550,457-vertex invalid polygon. Repaired once at the data layer, a Marion report went from a **27.7 s timeout to 4.98 s**.

**Precompute is therefore undecided, not settled.** Measure an aimed live query — jurisdiction-scoped, model call excluded — before committing. A precomputed stack that goes stale invisibly is worse than a live query that is honest.

**What is settled:** validate geometry **at ingest**, never per call. A repair in the data is not a rule; a reload silently reintroduces every invalid polygon.

---

## Part J — Data quality caveats ✅ SUPERSEDED

`data_defect_registry` holds **32 classes** with `detection_sql`, `attribution` (`ours` / `source` / `mixed` / `undetermined`) and `disposition` (`repair` / `transform_on_ingest` / `disclose` / `substitute`).

**Attribution is what decides the action**, and three of four dispositions are not fixes:

- Hardee's HTML in `parcel_id` → `source` / transform on ingest
- Duplicate keys → `source` / **disclose and aggregate, never dedupe**
- A county publishing fewer polygons than it assesses (Volusia, 8.8%) → `source` / **disclose** — that text belongs in every report for that county
- SRID 0 → `ours` / repair. Consequence is not "geometry will not join" — it is that **good layers get classified as unusable and shelved.** It shelved three real layers, one proposed for deletion.

**The sentinel class is the single most repeated defect in this data** — a value that means absence, or a category that looks like what you are measuring and is not. Six instances: `999 INCORPORATED`, `-9999` BFE, `null` cleanup status, an opaque `STATUS` code with no crosswalk, closeout-not-recorded, and *Estuarine and Marine Deepwater* inside a "wetlands" layer (15.3M acres of open water; counting it reports 60% of Florida as wetland).

---

## Part K — Open items

**From v4, still open:** fan-out resolution rule · condo unit-vs-complex · septic · pollen · crime feeds.

**Closed since v4:** "no coverage" vs "not in a zone" (Part G) · co-owner recovery (Part B) · soil omission — SSURGO identified, statewide pull pending.

**New and blocking:**

1. **CAMA relational export is Volusia only — 2.86% of Florida's parcels.** Everything that makes this *intelligence* rather than a lookup (marine improvements, permit cross-examination, deed chain, improvement timeline, multi-owner) is one county. **The single highest-information unknown on the board** is whether the top ten counties run Tyler iasWorld; if four do, the existing loader takes rich coverage to roughly a quarter of the state.
2. **NHD is missing NHDArea and NHDFlowline.** Florida has no rivers, estuaries or canals in the water layer. Roz diagnosed this itself on a $110M Biscayne Bay estate: *"nearest mapped water feature 3.2 mi — in tension with this being a Biscayne Bay address."*
3. **Numeric-provenance validation is in shadow mode**, pending ten real reports across several counties. The current guard is a seven-string blocklist — a tourniquet. The model can invent an eighth.
4. **Roz narration is not restructured.** The report page is nine sections; Roz still emits prose in payload order.

---

## Part L — What the product actually is

Positioning, settled since v4: **a due-diligence check before a property is listed or purchased.** Not a listing service, not a feasibility screen, not a description.

**B2B is pre-listing.** *"Know it before you list it."* An agent who finds the seawall, the unpermitted dock or the groundwater restriction first controls it. One who learns it from the buyer's inspector has lost the deal.

**PIR is pre-purchase.** Same data, different question: not "how do I manage this" but "should I proceed, and what do I ask for."

**Three consequences:**

- **Findings must be actionable.** *"402 sq ft dock, built 2009"* is a fact. *"No county permit in that year — a question for the seller and the building department"* is due diligence.
- **Coverage gaps are part of the service.** *"We cannot tell you the flood zone here — msc.fema.gov can"* is a checklist item routed correctly, not a failure.
- **The moat is cross-examination, not coverage.** Every physical change should leave a trace in more than one register, and they should agree on date, scope and actor. Measured: of 15,801 Volusia marine improvements, **9,704 (61.4%) have a permit within a year of the recorded build year. 6,097 do not** — and 5,725 of those sit on parcels that *do* have permits. That is not a value; it is a question the buyer must ask, with the evidence attached, and it is not searchable.

---

## Instruction to the builder

**Do not simplify.** If a category is confirmed real in the database, it appears by default.

**Extend, do not rebuild.** The nine-section structure, the fact index and the coverage-state discipline are live and correct.

**And the discipline that produced all of it:** check the serving reality, not the artifact. The map before the tables. The payload before the page — the payload is the security boundary; a guard at the render protects the page and nothing else. The call graph before the `done` flag. The distribution before the blocklist. And treat a verification null as a claim about your query until proven otherwise.

Five relayed assertions were wrong on the day this was written, and querying caught every one.
