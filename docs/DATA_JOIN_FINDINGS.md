# Florida Property Data — Join, Verification & Source Findings

**Recorded 2026-07-23.** Findings are empirical unless marked otherwise; sample sizes and measured rates are given so claims can be re-tested rather than trusted.

---

## 1. The verification protocol (use this; match rate alone is not evidence)

A crosswalk is **not** verified by a high match rate. Match rate only proves *a row came back*, not that the *right* row came back. Four tests, in order:

| # | Test | What it proves | Measured example (Seminole) |
|---|---|---|---|
| 1 | **Match rate** | A row exists for the key | 994/1000 (99.4%) |
| 2 | **Independent corroboration** | The matched row describes the same property | owner 920/994, house number 898/994 |
| 3 | **Negative control** | The corroboration isn't coincidence | deliberately wrong join → **0/1000 agree** |
| 4 | **Cardinality** | Exactly one match, no fan-out | 994 exactly-one, 0 multiple, worst fan-out 1 |

**Test 3 is the one people skip and it is the one that matters.** Without it, test 2 produces a number with no meaning. Run the negative control per county — entropy varies by county.

---

## 2. Anchor hierarchy — what to verify a join *with*

Measured agreement vs chance agreement (control):

| Anchor | Agreement | By chance | Lift | Verdict |
|---|---|---|---|---|
| **Year built** (`ACT_YR_BLT`) | 350/350 = 100% | 1.0% | 100× | **Primary** |
| **Land area** (`LND_SQFOOT` vs `ST_Area(geom)`) | 872/874 = 99.8% | 3.7% | 27× | **Primary** |
| **Legal description + owner corroboration** | 22.9% | 0.4% | **57×** | **Primary — encumbrance joins** |
| Township (`TWN`) | 99.1% | *untested* | — | Weak — low entropy |
| Section (`SEC`) | 95.2% | *untested* | — | Weak — low entropy |
| Owner name | 92.6% | 0% | high | **Rejected** — volatile |
| Living area (`TOT_LVG_AREA`) | 77.7% | — | — | Comparison field, not anchor |
| Just value (`JV`) | 64.5% | — | — | Comparison field, not anchor |

**Why year built wins:** immutable (a 1974 house is still 1974 after it sells), independently recorded by two processes, enough spread to discriminate.

**Why land area wins:** the only anchor where the two values come from genuinely different physical processes — a surveyed polygon vs. an assessor's land record. Nothing in the pipeline can make them agree by accident.

**Why legal+owner corroboration wins (added 2026-07-26):** legal description alone matched at 36.2% against a deliberately-shifted 31.4% — only 4.9 points of discrimination, because lot N and lot N+1 are both real parcels in the same subdivision. Match-alone silently attaches an encumbrance to the *neighbour*. Requiring the recorded party to corroborate the resolved parcel's owner collapses the wrong-join to 0.4% while the correct join holds at 22.9%. **Second instance in this project of a control overturning a plausible join, after the Sarasota `account` vs `id` failure in §3.**

**Why township/section are traps:** a county contains only a handful of townships, so a *wrong* join also agrees most of the time. **High agreement on a low-entropy field is weak evidence, not strong evidence.**

**Why owner name is rejected:** it fails two independent ways at once — noisy from data entry *and* legitimately changes over time. Normalization fixes only the first.

---

## 3. CRITICAL — the anchor must belong to the entity level you are identifying

**This is the most important lesson of the session, and it was discovered by getting it wrong.**

Sarasota parcel `id` vs `account` both matched DOR at ~99.7%, but returned **different DOR records for 36% of parcels**. A land-area corroboration test scored `account` at 100% and `id` at 0%, and declared `account` verified.

**That conclusion was wrong.** Example — one condo unit, two valid records:

| joined via | owner | just value | land sqft |
|---|---|---|---|
| `id` | the actual unit owner | $208,800 | — |
| `account` | the homeowners association | $0 | 108,052 |

Both records are real. They describe **different entities**. The land-area anchor only exists on the *complex* record, so the test selected the key that matched the anchor rather than the key correct for ownership. Joining on `account` and printing the owner would name the HOA as the owner of a private condo — affecting ~58,000 Sarasota parcels (19% of the county).

**Rule: a verification protocol can be internally rigorous and still confidently wrong if the anchor doesn't belong to the entity being identified.**

---

## 4. The two-level property model (lot vs. interest)

A single-family home collapses these into one row. Condo/townhouse counties do not.

**Lot level** — geometry, land area, flood zone, zoning, soils, everything spatial.
Verify with: geometry, land area.

**Interest level** — the unit: owner, assessed value, homestead, unit address, sale history.
Verify with: year built, living area. **Never land area** (units own no land).

**Neither is "the" parcel.** The crosswalk needs **two keys per county**, plus a rule for which field comes from which level.

### Measured stacking (parcels sharing a footprint)

| County | Rows | Shared footprints | Notes |
|---|---|---|---|
| Sarasota | 308,079 | **58,549 (19%)** | 1,458 distinct footprints; largest stack **489 parcels** |
| Manatee | 338,349 | **132,257 (39%)** | plus 97,323 duplicate `parcel_id` (29%) |
| Seminole | 181,195 | 0 | single-family dominant — do **not** generalize from this |

Expect the same in Pinellas, Lee, Collier, Monroe, Miami-Dade.

**Independent confirmation:** UF GeoPlan documents this exact problem statewide — some counties store condo units as stacked polygons, others store the building as one polygon with units in a separate file. GeoPlan creates stacked polygons to force a 1:1 spatial-to-attribute relationship, **adding ~370,000 condo owners** to the statewide dataset. A remediated version exists; we should evaluate it before building our own.

---

## 5. Geometry as identity — verified capability and its limit

Tested on Seminole:

- **Centroid uniqueness:** 181,195 parcels, 181,195 distinct centroids, 0 duplicates.
- **Overlap:** 3,000 sampled, **0** overlapping >10% with any other parcel — footprints tessellate cleanly.
- **Point-in-polygon:** 2,000 probes from parcel centroids → **2,000 returned exactly one parcel**, 0 ambiguous, 0 misses.

**Limit:** fails wherever interests stack (§4). Geometry identifies the **lot**, never the **interest**.

**Gotcha:** `ST_Centroid` of a NULL geometry produces a false "duplicate centroid" reading. Baker showed 34 apparent duplicates = **33 NULL geometries + 1 genuine collision**. Always exclude NULL/empty geometry before uniqueness testing.

---

## 6. Measured crosswalk keys (10 counties)

Ten counties, ten different names for "parcel id." **The obvious-sounding column is often wrong.**

| County | Correct key | Transform | Match rate | Trap |
|---|---|---|---|---|
| Baker | `parcelno` | none | 1990/2000 (99.5%) | **`pin` matches 0/2000** |
| Glades | `parcelno` | strip punctuation | 1990/2000 (99.5%) | raw = 0% |
| Hardee | `parcel_id` | **strip HTML tags**, then punctuation | 1984/2000 (99.2%) | see below |
| Indian River | `pp_pin` | none | 1982/2000 (99.1%) | — |
| Sarasota | `account` (lot) / `id` (interest) | none | ~99.7% both | **different records — see §3** |
| Seminole | `parcel` | none | 994/1000 (99.4%) | — |
| Manatee | `parcel_id` | none | 907/1000 (90.7%) | 29% duplicate keys |
| Volusia | `pid` / `altkey` | — | untested | no owner/address columns |
| Duval | `re` | — | untested | DOR NAL was empty at test time |
| Lee | `strap` | — | untested | DOR NAL was empty at test time |

**Hardee's `parcel_id` contains an HTML anchor tag**, not an identifier:
`<a href="https://qpublic.schneidercorp.com/...">09-34-25-0290-00007-0016</a>`
The county publishes it that way. Stripping markup recovers a 99.2% match. *(Side benefit: this is how we learned the domain hides the CAMA vendor.)*

**Volusia (added 2026-07-26):** three identifiers for the same parcel — `parcel_id` (AltKey, 7 char, e.g. `3671058`) used by CAMA/permits/sales/building records; `dor_parcel_id` (geographic, 12 char, e.g. `633001001890`) used by DOR NAL and parcel GIS; `state_parcel_id` (e.g. `C74-000-927-2211-5`). **`properties` is the crosswalk**, scored 0.98 in `data_confidence_scores` via `cross_source_match`. Querying the wrong column returns zero rows silently.

---

## 7. Source hierarchy — authority runs OPPOSITE to aggregation

### Provenance chain

1. **Licensed surveyor (PSM)** — measures land, sets monuments. *The only step touching the ground.*
2. **Plat** — drawn and certified by the surveyor, approved by local government, then recorded. Ch. 177 F.S.
3. **Clerk of Circuit Court** — records plats, deeds, surveys. **Latency: days.**
4. **Property Appraiser** — *draws* the parcel polygon by interpreting deeds, plats, condo declarations, and recorded/unrecorded surveys. **Latency: weekly.**
5. **DOR PTO** — collects GIS each April, joins to NAL, publishes August (maintenance May/November). **Latency: annual.**
6. **FGDL/GeoPlan** — cleans and standardizes DOR.

### Consequences

- **Parcel geometry is a TAX MAP, not a boundary.** County GIS parcel maps are approximate and can be off by several feet from the legal boundary. **Never represent parcel geometry as a survey.** This is both an accuracy rule and a liability fence.
- **The parcel ID is itself a tax artifact** — assigned by the appraiser, reassigned on split/merge/replat. This is *why* there are ten formats and no statewide property identifier: nobody was identifying properties, they were identifying payers.
- **DOR is NOT independent ground truth.** DOR data *is* county data, submitted by the same appraiser, delayed and flattened. Measuring county vs. DOR measures **drift**, not accuracy.
- **DOR's real value** is as a fixed, reviewed, deduplicated annual baseline. It caught Manatee: 229,193 certified rows vs 338,349 county rows with 97,323 duplicate keys.
- **FGDL is the only tier not downstream of county tax data** — LiDAR elevation, soils, hydrology are independently measured. It is the only source capable of genuinely independent verification.

### Corrected role per layer

| Layer | Role | Cadence |
|---|---|---|
| Clerk official records | **Change detection** — new plats, deeds, splits | Days |
| County CAMA / GIS | **Primary working record** — owners, values, geometry, relational | Weekly |
| DOR NAL / cadastral | **Schema standard + annual audit checkpoint** | Annual |
| FGDL | **Independent science layer** | Varies |

### Regulatory layers record what was regulated, never what exists (added 2026-07-26)

A recurring failure class, measured four times:

- **WACS solid waste facilities** — a compliance system, so dumps that closed before the permitting regime were never in it
- **STCM contamination monitoring** — monitored tanks, not all contamination
- **CLM cleanup sites** — sites in the cleanup programme, not all contaminated sites
- **FUDS property boundaries** — 142 polygons against 711 point records; USACE maps boundaries only for *investigated* properties, so 80% of Florida sites have a point and no extent
- **FCC ASR** — structures over 200 ft AGL or near an airport flight path; rooftop arrays and small cells absent by design

**Any layer sourced from an enforcement, remediation or permitting system needs a stated coverage caveat. Absence in such a layer is never absence in the world** — and the un-regulated case is exactly the population a buyer is least protected against.

---

## 8. DOR update cycle — why owner names go stale

- **January 1** — legal assessment date. Ownership snapshotted here.
- **July 1** — preliminary roll (NAL, NAP, SDF) submitted.
- **Sept/Oct** — first final submission.
- **After VAB** — post-VAB final. PTO review/publication can take a further month.

Loaded file is `NAL12F202502VAB.csv` = 2025 post-VAB final → **owner as of 2025-01-01**, i.e. ~19 months stale as of this writing, and structurally never fresher than ~6 months.

**This quantitatively explains the Seminole owner disagreement.** Florida had ~343,805 existing-home sales in 2025 against ~10.8M parcels ≈ 3.2% turnover/yr. Over 19 months ≈ 5%. Measured: ~6–7%. **Those were not errors or bad joins — they were sales after the snapshot.**

**Precedence for owner name:** Clerk (deed) > County appraiser > DOR NAL.
DOR remains authoritative for assessed value, exemptions, homestead status, use codes — the things it certifies.

---

## 9. The tax roll loses real property information

The DOR NAL carries **one** `OWN_NAME` per parcel — a tax roll needs only one addressee for the bill. Co-owners are flattened out.

Verified: VCPA Real Property Search returns **two owner rows** for one AltKey. Every bulk export we held returned one — `volusia_parcel_centroids` (single `owner`, 12 chars, no separator) and `volusia_parcels_staging` (306,889 rows / 306,706 distinct alt_keys).

**Resolution:** the county publishes its full **relational** CAMA database weekly at
`https://vcpa.vcgov.org/files/database/CAMA_DATA_EXPORT.zip` (layout: `/files/download/newLayout.pdf`), current within days.

**Consequence:** the ownership model must allow **multiple owners per parcel**. Joint ownership is the norm for married couples — a single `owner_name` field silently misrepresents a large share of the state.

---

## 10. Harness invariants (each cost a real failure)

1. **Probe the OID field from layer metadata — never hardcode `objectid`.** Baker stored it as `fid`; Orange's `objectIdField` was `None` and the OID had to come from `returnIdsOnly`.
2. **Abort and touch nothing if `returnIdsOnly` returns empty.** A down service reporting zero IDs must never be read as "the source has no rows."
3. **Rename indexes when quarantining a table by rename.** Postgres renames the table but not its indexes; the old index name then collides with the next same-named staging table.
4. **Any process-liveness interlock must avoid self-matching.** `pgrep -f script.py` matches its own shell. Use the `[s]cript` bracket trick and test it from a file. *A guard that fails closed on a false positive becomes the outage.*
5. **Chunk large COPY operations (50k rows).** A single oversized COPY exceeds `statement_timeout` and dies mid-stream. Also set `statement_timeout=0`.
6. **`empty ≠ done`.** Skip/resume predicates must test `count(*) > 0`, never table existence. Assert non-zero after every load and maintain an explicit FAILED list. **Never print a summary that implies success.**
7. **Round numbers are suspect.** `fdep_stcm_tanks` at exactly 20,000 was a `maxRecordCount` paging cap; the true count is 74,262. No real-world inventory lands on a round figure.
8. **Uniform values are suspect.** No genuine per-parcel measurement is constant across a county. This rule found 61 placeholder fields, including four contamination-proximity zeros reporting an all-clear on 313,578 parcels that had never been calculated.
9. **A sentinel coordinate is not a geocode.** 1,905 STCM tanks sat at exactly (−87.930, 23.942) — one point in the Gulf of Mexico meaning "location unknown." It passed `geom IS NOT NULL` at 100%.
10. **Two-digit year pivots produce future dates.** `MM/DD/YY` text parsed with a fixed pivot put permits in 2068 and sales beyond the current year. A date in the future is the tell.

---

## 11. Known data defects

| Defect | Where | Detail |
|---|---|---|
| Duplicate parcel keys | Manatee | 97,323 dupes (29% of 338,349) — joins fan out |
| HTML in identifier field | Hardee | `parcel_id` contains an `<a href>` tag |
| SRID 0 (no spatial reference) | 54 layers statewide | incl. `sjrwmd_wells` — **cannot be spatially joined until reprojected** |
| NULL geometry | Baker | 33 parcels with no location |
| No owner/address columns | Baker, Broward, Palm Beach, Volusia, Wakulla | Owner data must come from DOR or county CAMA |
| Owner but no address | DeSoto, Gadsden, Hamilton | |
| Uppercase quoted columns | all `*_nal_dor_source`, all `volusia_cama_*` | Requires `"PARCEL_ID"` quoting in every query |
| Stale (source shrank) | Santa Rosa FLU / zoning / subdivisions | We hold 74 / 61 / 16 *more* than source — refresh trigger, not corruption |
| Duplicate plat records | Volusia | 1,647 duplicate `subnum` groups (5,791 rows); same map book/page, geometries differing up to 16% |
| Fixture count read as bathroom count | Volusia CAMA | `FIXBATH4-7` ignored, undercounting any 4+-fixture bath. Correct: `(FIXBATH + FIXBATH4..7) + 0.5×FIXHALF` |

### State vs county count deltas (largest)

Both directions — no systematic bias. Manatee +109,156 (+32%, explained by duplication); Suwannee −6,944 (−22%); Calhoun −2,252 (−21%); Gadsden +6,807 (+20%); Indian River −11,770 (−14%); Gulf −2,480 (−14%). Within ~1%: Glades, Madison, Levy, Okeechobee, Union.

---

## 12. Performance

Per-parcel pairing across 4–5 layers: **75 ms – 1,210 ms**, median 383 ms.

Extrapolated to a 30+ layer PIR, request-time joins land in the multi-second range. **The parcel record must be precomputed, not assembled on demand.**

Measured 2026-07-26 with ~19 findings and 165 restriction layers wired: **36 s average, 76 s worst case** end to end including the model call. Confirms the conclusion.

---

## 13. Key sources

| Source | URL | Notes |
|---|---|---|
| Statewide cadastral (file) | `https://publicfiles.dep.state.fl.us/otis/gis/data/Cadastral_Statewide.zip` | 10,831,924 parcels, **EPSG 6439** — reproject to 4326 |
| All 67 PA websites | `.../Florida_Statewide_Cadastral/FeatureServer/0/metadata?f=html` | Authoritative directory, published by DOR |
| Volusia CAMA (relational, weekly) | `https://vcpa.vcgov.org/files/database/CAMA_DATA_EXPORT.zip` | Layout: `/files/download/newLayout.pdf` |
| DOR tax roll files | SharePoint PTO Data Library | NAL 165 fields, SDF 23; CSV with header (**not** fixed-width) |
| DOR prior-year rolls | By emailed request | NAL/NAP from 2002, sales from 2009 |
| FGDL | `https://fgdl.org/explore-data/` | 480+ layers; parcel archive to 2007 |
| FGIO | `https://geodata.floridagio.gov` | State GIS office portal |
| USACE FUDS | `services7.arcgis.com/n1YM8pTrFmm7L4hs/arcgis/rest/services/fuds/FeatureServer` | Layer 4 = property boundaries, 142 FL. Projects layer classifies HTRW / MMRP / BD-DR |
| FCC ASR bulk | `data.fcc.gov/download/pub/uls/complete/r_tower.zip` | Pipe-delimited, RA+EN+CO join, NAD83. **Akamai blocks programmatic access** |
| NAHB component lifespans | Study of Life Expectancy of Home Components | Material-specific: asphalt shingle ~20yr, tile 50+, metal 20–50+ |

---

## 14. Open items

1. **Manatee's ~9% non-matching parcels** — population question, not a key question.
2. **Fan-out resolution rule** — Glades returned 10 zoning polygons for one parcel; Duval 6 zoning + 6 FLU. No rule yet for choosing among them.
3. **"No coverage" vs. "not in a zone"** — addressed by the `field_status` enum (2026-07-26): `present | null_at_source | layer_not_loaded | county_not_covered | stale | conflicting_sources | not_computed | assumed`.
4. **Prong 3** — 9 non-ArcGIS sources still lack declared natural keys.
5. **Volusia OR duplicate check** — 1,267,929 rows never scanned for duplicates. Note: the pull covers only four doctypes — JUDGMENT/ORDER, LIEN, LIS PENDENS, RESTRICTIONS. Deeds and satisfactions were never searched.
6. **SRID 0 layers** — 54 statewide, need reprojection before they can be joined at all.
7. **Weekly snapshot archive** — cannot be backfilled. Every uncaptured week is change history permanently lost.
8. **`parcels_staging`** — 10.7M rows, ~21 GB, proven a strict key-subset of `fl_cadastral_dor_statewide`. Repoint and drop.

---

## 15. Method notes

- **Two independent methods beat one, and the disagreements are the signal.** Prong 1 contradicted Prong 2 and Prong 2 was right. The land-area anchor test was rigorous and wrong. "Not recoverable from bulk" was wrong — the CAMA export existed. Every one of these was caught on a second pass by a different route.
- **Run surveys by more than one method and reconcile.** A link-following crawler and a search-driven survey fail differently: the crawler misses orphaned pages, the search misses poorly-indexed or JS-rendered ones. Neither is a subset of the other. Where they disagree, look by hand.
- **Report, never reconcile.** Where two authorities disagree — FEMA's current NFHL against a county's 2014 FIRM extract, CAMA's sinkhole risk band against FDEP's recorded-incident count — return both with their sources and dates. Reconciliation is a determination, and that is the work of a surveyor, engineer or floodplain manager, not a data pipeline. `conflicting_sources` is reserved for the narrower case of one authority and one document appearing twice.
- **The funnel terminates at the parcel.** Layers are clouds casting shadows; a polygon has no idea which county it is "in." Never filter on a county attribute before a containment test — Avon Park AAF is 116,576 acres recorded under Okeechobee and sits largely in Polk and Highlands.
