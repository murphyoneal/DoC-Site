# Client-Facing Data Audit — Specification

**Drafted 2026-07-23.** The audit that turns internal verification into a claim a customer can check.

Four components:

1. **Defect registry** — every known failure mode, with a detection query that runs forever
2. **Two-tier sampling** — rate estimation vs rare-defect discovery, deliberately separated
3. **Spatial resolution taxonomy** — which "board" each field is played on
4. **Peer-review agent** — independent verification by a different route

---

## 0. Governing principle

Every failure this project has hit is the same shape: **a false negative that renders as a clean result.**

- Empty `returnIdsOnly` read as "the source has no rows"
- A table that exists but is empty read as "loaded"
- `\d{4}` against `MM/DD/YY` returning zero rows, read as "never sold"
- A boundary lookup returning zero rows, read as "zero violations"
- `in_flight_path` never computed, rendered as `false`
- 32,860 personal-property accounts counted as parcels

**The audit's first duty is to prove its own zeros.** Every check must assert a non-zero denominator and record what it examined, not only what it found.

---

## 1. Defect registry

Not machine learning — **rule accumulation**. Each rule came from a specific failure, is explainable, testable, and cannot silently drift. The system "calls itself out" by running every historical rule against every new pull.

### `data_defect_registry`

| Column | Purpose |
|---|---|
| `defect_id` | stable key, e.g. `DEF-014` |
| `name` | short handle |
| `discovered_on`, `discovered_via` | the case that found it (e.g. "Hardee parcel_id contained an `<a href>` tag") |
| `class` | see taxonomy below |
| `severity` | `blocking` / `material` / `cosmetic` |
| `detection_sql` | the query that finds it, parameterised by county/table |
| `expected_denominator` | what "examined N" should look like — **a check that examines nothing must fail, not pass** |
| `false_positive_notes` | known benign matches |
| `status` | `active` / `retired` / `superseded` |
| `remediation` | what to do when it fires |

### `data_defect_findings`

One row per detection run: `defect_id`, `county`, `table`, `examined_count`, `hit_count`, `sample_keys`, `run_at`, `run_id`. **`examined_count = 0` is recorded as `ERROR`, never as a pass.**

### Defect classes — seeded from what's already known

| Class | Seeded examples |
|---|---|
| **Key integrity** | wrong column chosen (Baker `pin` vs `parcelno`); duplicate keys (Manatee 29%); HTML in identifier (Hardee); format variance requiring transform (Glades punctuation) |
| **Geometry** | null geometry (Baker 33); invalid geometry; out-of-county centroid; out-of-Florida bbox; SRID 0 (Seminole ~20 layers) |
| **Completeness** | table exists but empty; row count short vs source; page-boundary truncation; stale (source shrank — Santa Rosa) |
| **Entity confusion** | roll type mixed (32,860 PP accounts as parcels); lot vs interest key (Sarasota `account` vs `id`); stacked footprints (Sarasota 19%, Manatee 39%) |
| **Temporal** | date parse failure (`MM/DD/YY` vs `\d{4}`); vintage mismatch (DOR Jan-2025 vs CAMA Jul-2026); stale beyond cadence |
| **Null-as-value** | uncomputed boolean rendering as `false` (5 fields × 313,578 rows); absence indistinguishable from failure |
| **Fan-out** | multiple polygons on one parcel (Glades 10 zoning; Duval 6+6; evacuation zones A+DE); duplicate plat rows |
| **Resolution mislabelling** | county/block-group facts rendered as property facts (§3) |

**When a new defect is found, it becomes a registry row.** That is the entire learning mechanism.

---

## 2. Two-tier sampling

**Do not sample 10% for rate estimation.** Sample size for a proportion depends on required precision, not population size. ±1% at 95% confidence needs ~9,600 records whether the population is 100K or 10.8M. 10% of 10.8M is ~1.08M parcels ≈ **115 hours** at the measured 383 ms median — buying ±0.1% precision nobody will act on.

### Tier 1 — rate estimation (stratified)

**Strata:** 67 counties × property class (`single_family`, `condo`, `vacant`, `commercial`, `agricultural`, `government`).

**~250 per occupied cell → 50,000–100,000 parcels.** Runs in hours.

Produces: per-county and per-class error rates with confidence intervals. This is the number that goes on the website.

Deliberately over-samples small counties relative to population — Liberty's 6,293 parcels get the same scrutiny as Miami-Dade's 941,434, because per-county claims are what customers check.

### Tier 2 — rare-defect sweep (census, structural)

Single-pass SQL across **100% of every table**. No per-parcel pairing, so cost is a rounding error next to Tier 1.

Catches defects too rare for any sample: format anomalies, embedded markup, null/empty geometry, out-of-boundary centroids, duplicate keys, orphaned rows, roll-type contamination, uniform-value columns (the null-as-false signature).

**Tier 2 finds the classes. Tier 1 measures the frequency.** Run Tier 2 first — its findings become Tier 1's checklist.

---

## 3. Spatial resolution taxonomy — "which board"

**This is a category error running through the current report.** It prints *"Median household income $91,190"* as a property fact. It is a **block-group** fact — 1,646 people, 826 housing units — rendered as an attribute of one house. Same for AQI (county monitor), hurricane direct hits (county), solar (regional model), wind design speed (zone), radon (county), "flood events 14" (area).

### Every field carries a resolution

| Level | Fields |
|---|---|
| `parcel_exact` | geometry, land area, owner, RRR, assessed value, exemptions, permits, sales, plat |
| `sub_parcel` | building footprint, structure components |
| `adjacent` | nearest runway 310 m, nearest water 412 m, nearest hospital 3.6 mi |
| `block_group` | population, median household income, housing units |
| `zcta` | some economic and insurance data |
| `school_zone` | attendance area |
| `district` | fire response, patrol, mosquito, hospital, solid waste, school board |
| `county` | AQI, radon, hurricane hits, lightning density, wildfire risk, insurance premiums, BEBR estimates |
| `region` | water management district, NOAA climate normals, solar irradiance |
| `state` | statewide regulatory layers |

### Resolution method — how the value was obtained

`contains` · `intersects` (fan-out risk) · `nearest` · `centroid` · `area_weighted` · `inherited` (county/regional value applied to parcel) · `derived` · `not_computed`

### Render rules — binding

1. **Never present a non-`parcel_exact` value without its level.** *"Median household income — block group 121270832102: $91,190."*
2. **`inherited` must be labelled as area context**, never as a property attribute.
3. **`not_computed` withholds.** It never renders as a value, a zero, or `false`.
4. **`intersects` returning >1 must show the conflict or withhold** — never silently pick.
5. **`nearest` always states the distance.** A nearest-value without distance is meaningless.

This is the same discipline as provenance and vintage: a field is not a value, it is **value + source + vintage + resolution + method**.

**Precedent:** the existing report already does this correctly in places — *"Not within — nearest 1.6 mi"*, *"area FEMA repetitive-loss figures are county context, not a claim about this parcel"*. The rule generalises what's already working.

---

## 4. Peer-review agent

### Principle

**Two independent methods, reconcile, and the disagreements are the signal.** Proven repeatedly here: Prong 1 contradicted Prong 2 and Prong 2 was right; the link-crawler and the search-driven survey failed differently; the land-area anchor test was rigorous and wrong.

**The reviewer must not re-run the primary's checks with the primary's code.** It must reach the same field by a **different route** and report only divergence.

### Divergence routes

| Field | Primary route | Reviewer route |
|---|---|---|
| Owner | county CAMA | DOR NAL + Clerk deed |
| Land area | CAMA `GIS_EST_SF` | `ST_Area(geom)` |
| Parcel identity | key join | point-in-polygon from centroid |
| County assignment | `co_no` attribute | spatial join to `fl_county_boundaries` |
| Year built | NAL `ACT_YR_BLT` | permit completion date |
| Situs address | CAMA situs | address-point spatial join |
| Flood zone | county layer | FEMA statewide |
| Geometry | county GIS | statewide cadastral |

### Output

`peer_review_findings`: `parcel_key`, `field`, `primary_value`, `primary_route`, `reviewer_value`, `reviewer_route`, `divergence_type`, `severity`, `run_at`.

`divergence_type` ∈ `agree` · `differ` · `primary_null` · `reviewer_null` · `both_null` · `not_comparable`

**`both_null` is a finding, not a pass** — it means neither route can answer, which is exactly the gap a customer will hit.

### Access

Service-role, internal, non-user-facing. The §13 access controls govern *customer* access to the platform; they do not bind an internal verification process. But the reviewer's queries are logged like everything else.

---

## 5. Client-facing output

What actually gets published:

**Per-county coverage matrix** — which layers exist, row counts, vintage, last verified.

**Per-county, per-field accuracy** — Tier 1 rates with confidence intervals. *"Owner of record: 99.4% agreement between county CAMA and DOR roll across 250 sampled Volusia parcels, ±1.4% at 95% confidence."*

**Known defect list, published.** Not hidden. *"Manatee County: 29% duplicate parcel identifiers in the county GIS layer. We deduplicate on load; the source defect is upstream."* Publishing defects is the trust signal — every competitor has them and none disclose them.

**Field resolution legend** — so a reader knows which facts are about their property and which are about their county.

**Last-verified timestamp per county per layer.**

### The claim this supports

Not *"our data is accurate."* That is unfalsifiable and everyone says it.

**"Here is what we hold, here is how we tested it, here is where it fails, and here is the date we last checked."**

That is a claim no competitor in this market makes, and it is the only one that survives a customer checking it.

---

## 6. Build order

1. **Defect registry schema** + seed from known defects (§1)
2. **Tier 2 structural sweep** — cheap, 100% coverage, populates the checklist
3. **Field resolution taxonomy** applied to the product tables — the metadata columns
4. **Tier 1 stratified sample** — the rate numbers
5. **Peer-review agent** — divergence routes
6. **Client-facing renderer** — the published audit

Steps 1–2 are cheap and immediately useful. Step 3 blocks the PIR rewrite and should land with it. Steps 4–6 are the client-facing product.
