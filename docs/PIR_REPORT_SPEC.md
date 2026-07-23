# PIR Report — Definitive Specification (v4)

**Supersedes v1, v2, v3.** Recorded 2026-07-23.

v3 was correct about *structure* and has been built — the 5-page engine, individual badge-compasses, honest absence handling, real geometry. **v4 does not change the page structure or the visual concept. Keep them.**

What v4 adds is everything discovered since v3 about *what the data actually is*: the two-level property model, multi-owner ownership, per-field provenance and vintage, source precedence, and the compliance constraints. v3 assumed a parcel has one owner, one source, and one identity. None of those are reliably true.

Evidence for every claim below is in `DATA_JOIN_FINDINGS.md`.

---

## Part A — What v3 got right (do not change)

1. **Individual badge-compasses**, one per amenity type — not one shared map with pins. Absence of a badge is informative.
2. **Maximal default population.** Every confirmed-real category appears by default. Hiding is a display toggle, never a generation decision.
3. **Five-page structure**, running header on every page with property reference:
   - Page 1 — Property facts (basics, values, tax, amenities)
   - Page 2 — Property history (own page; permits + ownership)
   - Page 3 — Environmental (Air, Land, Water; flood folded into Water; real 5-mile map + windrose)
   - Page 4 — Neighborhood (Economic zones, Zoning, Census; real zoning map + legend)
   - Page 5 — Supporting (completeness summary first, then crime/safety, news, citations)
4. **Counts must match lists.** 14 permits means 14 listed. Never summarise to a sample.
5. **Never invent a status.** "Completed — final status not on file" is correct where the county records none.
6. **Honest absence.** "Not yet in the county coverage layer" beats a blank or a guess.
7. **Jurisdiction-level citation only** — "County GIS," "State DOR," "Federal." Never name the portal.
8. **Crime data category filtering is a hard requirement** — sex offences, domestic disturbance and similar are excluded before anything reaches a report.

The built report already does 4, 5 and 6 well. Preserve that behaviour exactly.

---

## Part B — Ownership is a set, not a field ← BREAKING CHANGE

**The defect:** the built report shows one owner. The county's own Real Property Search returns **two owner rows** for that same parcel (AltKey `3671058`). The second owner was never dropped by our code — it was never in the source we read.

**Why:** the DOR NAL roll carries exactly one `OWN_NAME` per parcel. A tax roll needs one addressee for the bill. Co-owners are flattened out at source. Every flattened export we hold has the same limitation (`volusia_parcel_centroids`: single `owner`, 12 chars, no separator; `volusia_parcels_staging`: 306,889 rows / 306,706 distinct alt_keys).

**Requirements:**

- The data model must support **1..n owners per parcel**. A single `owner_name` string is prohibited.
- Owners come from the **county CAMA export** (relational, weekly) or the **deed** (Clerk official records), never from a flattened roll where a relational source exists.
- Where only a flattened source is available, the report must state: *"Roll shows one owner of record; the deed may list additional parties."* Silence is not acceptable — joint ownership is the norm for married couples, so a single-owner display silently misrepresents a large share of the state.
- Ownership is **temporal**: "who owned this on this date." A transfer is a new entry on a timeline, not a correction. This dissolves the apparent conflict where two sources disagree on owner — usually they are two points in time.

---

## Part C — Two-level property model (lot vs interest) ← BREAKING CHANGE

A single-family home collapses these into one row. **Condo and townhouse counties do not.**

| Level | Carries | Verify with |
|---|---|---|
| **Lot** | geometry, land area, flood zone, zoning, soils, topography — everything spatial | geometry, land area |
| **Interest** | owner, assessed value, homestead, unit address, sale history | year built, living area. **Never land area** |

**Measured stacking:** Sarasota 58,549 parcels share a footprint (19% of county; largest stack 489 parcels on one footprint). Manatee 132,257 (39%). Seminole 0 — single-family dominant, do not generalise from it.

**The failure this prevents:** in Sarasota, joining on `account` returns the *complex* record — the HOA as owner, $0 value, 108,052 sq ft of land. Joining on `id` returns the *unit* — the actual owner, $208,800, no land. Both records are real. Printing the wrong one names the homeowners association as the owner of a private condo.

**Requirements:**

- The report must know, per field, **which level it came from**. Geometry and land area from the lot; owner, value and homestead from the interest.
- The crosswalk stores **two keys per county** where levels are distinct, plus a rule for which field resolves at which level.
- On a stacked parcel the report must show the **unit**, not the complex, for all interest-level fields — and must not display the complex's land area as if it were the unit's.
- **Evaluate UF GeoPlan's standardised statewide parcel dataset before building our own remediation.** GeoPlan already normalises condo stacking across counties, adding ~370,000 condo owners statewide.

---

## Part D — Per-field provenance and vintage ← NEW REQUIREMENT

**Every field carries four attributes, not one value:**

1. **value**
2. **source** — the authoritative jurisdiction for *that field*
3. **vintage** — the as-of date of that source
4. **resolution method** — exact key match / spatial intersect / centroid / nearest / derived

Different counties supply the same field from different sources. Provenance is stored **per parcel per field**, never declared once per report.

**Why this is not optional:** five counties — Baker, Broward, Palm Beach, Volusia, Wakulla — have **no owner or address columns at all** in their parcel GIS. For those, owner data comes from DOR or CAMA. A report citing "Volusia County Property Appraiser" for an owner field sourced from the state roll is a provenance error.

**Vintage must be shown where it materially affects trust.** The DOR roll is a **January 1 snapshot** published months later. The loaded file (`NAL12F202502VAB.csv`, 2025 post-VAB final) reflects ownership as of **2026-01-01 minus one year — i.e. 2025-01-01, ~19 months stale**, and structurally can never be fresher than ~6 months.

Correct display: **"Owner of record — Florida DOR 2025 certified roll, as of January 1, 2025."**

This is measurable, not theoretical: ~3.2% of Florida parcels transfer per year; over 19 months ≈ 5%; measured owner disagreement between county and DOR was ~6–7%. **Those were not errors. They were sales after the snapshot.**

---

## Part E — Source precedence per field

Authority runs **opposite** to aggregation. The most aggregated source is the least current.

| Field | Precedence (best first) |
|---|---|
| Owner, co-owners | Clerk deed → County CAMA (weekly) → DOR NAL (annual) |
| Assessed value, exemptions, homestead, use code | **DOR** (it certifies these) → County CAMA |
| Geometry, land area | County GIS → statewide cadastral |
| Sales | Clerk official records → DOR SDF → County CAMA |
| Flood | County layer preferred over statewide FEMA; **state explicitly if they disagree** |
| Elevation, soils, hydrology | FGDL / federal — the only genuinely independent measurements in the stack |

**DOR is not independent ground truth.** DOR data *is* county data, submitted by the same appraiser, delayed and flattened. County-vs-DOR measures **drift**, not accuracy. DOR's real value is as a fixed, reviewed, deduplicated annual baseline — it is what caught Manatee's 97,323 duplicate keys.

---

## Part F — Geometry is a tax map, not a boundary ← LEGAL REQUIREMENT

The parcel polygon is the property appraiser's *interpretation* of deeds, plats, condominium declarations and recorded/unrecorded surveys — drawn for assessment. County GIS parcel maps are approximate and **can be off by several feet from the legal boundary**.

- **Never represent parcel geometry as a survey or a legal boundary.**
- Every rendered parcel outline carries: *"Approximate parcel outline from county records. Not a survey."*
- This is both an accuracy rule and a liability fence.

The parcel ID is itself a tax artifact — assigned by the appraiser, reassigned on split, merge or replat. That is *why* there is no statewide property identifier: nobody was identifying properties, they were identifying payers.

---

## Part G — Withhold rules (the 100% standard, made operational)

The standard is not "every field is correct." No sampled audit can prove that. The standard is: **the report never asserts a field it has not verified for that specific property.**

- A field that fails verification is **withheld or flagged — never guessed**.
- **"No coverage" and "not in a zone" are different statements** and must never be rendered identically. Currently indistinguishable in the data; this distinction *is* the withhold rule and must be resolved before any layer using it ships.
- A parcel whose identity anchors agree but whose owner disagrees across sources is a **verified parcel with a contested owner field** — show the property data, flag ownership as needing confirmation.
- Fan-out is unresolved and must not be silently collapsed: Glades returned **10 zoning polygons** for one parcel, Duval **6 zoning + 6 FLU**. Until a resolution rule exists, show the conflict or withhold — do not pick arbitrarily.

**Verification protocol** (four tests; match rate alone is not evidence):
1. Match rate — a row came back
2. Independent corroboration — the row describes the same property
3. **Negative control** — a deliberately wrong join must *not* corroborate
4. Cardinality — exactly one match, no fan-out

Primary anchors: **year built** (100% agreement, 1% by chance) and **land area vs geometry** (99.8%, 3.7% by chance). Owner name is **rejected** as an anchor — volatile and noisy. Township and section look strong (99.1%, 95.2%) but are **low-entropy traps**: a wrong join agrees nearly as often.

**And the anchor must belong to the entity level being identified** — the Sarasota land-area test was internally rigorous and selected the wrong key.

---

## Part H — Compliance constraints on the report ← NEW

Full framework in `PROVIDER_REASONABLE_PROCEDURES.md`. Constraints that bind the report itself:

- **The consumer PIR is property-keyed, not person-keyed.** No person-search interface. Owner of record appears as an attribute *of the parcel*, never as a "who lives here" lookup.
- **The assembled personal profile** — criminal/booking + liens + lis pendens + cross-property + location fused around a named individual — is a separate access class. **Never on the consumer tier.**
- Owner research at the B2B tier requires verified professional licence, a purpose attestation, and logging.
- Compilation of individually-public records into a sold report creates a new regulated artifact. "The inputs are public" is not a defence.
- Standard disclaimer: *"This report reflects public records as drawn on [date]. This is not a certified or verified record of ownership or title."*

---

## Part I — Architecture: precompute, never assemble on demand

Measured per-parcel pairing across **4–5 layers**: 75 ms – 1,210 ms, median 383 ms. A full PIR spans 30+ layers.

**Request-time joins land in the multi-second range. The parcel record must be precomputed.**

The precomputed row stores, per field: value, source, vintage, resolution method, and status (verified / corroborated / conflicting / unresolved). **Building that table *is* the pairing audit** — every field that fails to resolve is an audit finding recorded as a byproduct of assembly. Do not build the audit and the report separately.

---

## Part J — Data quality caveats that affect rendering

| Issue | Effect on report |
|---|---|
| Seminole ~20 layers at **SRID 0** | Cannot be spatially joined. Render as "not available," not "none found." |
| Manatee **29% duplicate parcel_id** | Joins fan out. Must dedupe before display. |
| Hardee `parcel_id` contains an **HTML anchor tag** | Strip markup before any display or join. |
| Baker **33 NULL geometries** | No map render possible; state it. |
| DOR columns are **uppercase-quoted** | `"PARCEL_ID"` in every query. |
| Santa Rosa FLU/zoning/subdivisions | We hold more than source — stale, refresh before relying. |

---

## Part K — Open items blocking "complete"

1. **Fan-out resolution rule** — no rule yet for choosing among multiple intersecting polygons.
2. **"No coverage" vs "not in a zone"** — must be distinguishable before those layers ship.
3. **Soil type and drainage** — omitted for Volusia rather than guessed. Correct call; still unsourced.
4. **Septic** — may only be inferable from permit history, not a dedicated dataset.
5. **Pollen/allergen** — no source identified.
6. **Crime feeds** — Volusia Sheriff active-calls access method unconfirmed; CrimeMapping ArcGIS endpoint not located; category filtering mandatory before any of it ships.
7. **Co-owner recovery** — pending the Volusia CAMA export load and its acceptance test.
8. **Condo handling** — pending evaluation of GeoPlan's standardised parcel set.

---

## Instruction to the builder

**Do not simplify this list.** If a category is confirmed real in the database, it appears by default.

**The v3 report structure is built and correct — extend it, don't rebuild it.** The changes that matter are Parts B, C, D and G: ownership becomes a set, the lot/interest distinction becomes explicit, every field carries provenance and vintage, and unverified fields are withheld rather than guessed.

When uncertain whether something is real or illustrative, **query the database** rather than assume. That discipline is why the built report is honest about what it doesn't have, and it is the single most valuable property this product has.
