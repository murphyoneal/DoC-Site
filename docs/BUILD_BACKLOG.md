# DoP Build Backlog

**Compiled 2026-07-26. Every status below verified against the database, not recalled.**

This exists because tasks were being issued in chat and losing track between prompts. **It should become a table or a file in `docs/`, not live here.** Anything not written down gets dropped — that's how the area feed, the listing search and the lien classification all went missing.

---

## ✅ DONE — verified

| item | evidence |
|---|---|
| Encumbrance findings wired, 6% ceiling stated | 4,598 corroborated; 128 Logenberry returns the lis pendens, 152 Springberry Ct (521704003140, same Bayberry Lakes subdivision, no filing) returns `not_evaluated`. Earhart stays the environmental/FUDS example |
| Route 3 + Route 1 corroboration protocol | Control 4: 22.9% vs 0.4%, 57× lift |
| GWCA + institutional controls wired | 953 Volusia parcels, 33 IC polygons, Ch. 62-524 caveat travelling |
| Bath count fixed | `FIXBATH + FIXBATH4..7 + 0.5×FIXHALF` |
| `component_lifespan` — NAHB, material-specific | table exists |
| 5 Volusia restriction layers loaded | critical erosion 5, CCCL 2, env core 13, gopher tortoise 1, CHHA 8 |
| `fuds_projects` pulled | 281 rows |
| Compliance cases wired | `consumed_by` set |
| Planned works, parcel-level filter | 6,818 parcels (2.2%), withdrawn/complete excluded |
| Glossary + rule scoping | 48 terms, `roz_glossary_hit` |
| Address normalisation | progressive fallback, county inference |
| `STEB_DESC` / `SALETYPE` | in payload |
| Outbound links, new tab, `.tif` labelled | `roz_document_click` |
| `layer_role` compartmentalisation | foundation 1,986 / plumbing 24 |
| 165 of 193 restriction layers wired | from 4 |
| Sonnet 5 + no-determinations rule | deployed |

---

## 🔴 P1 — dropped, and shouldn't have been

### 1. Area context feed + click telemetry — **never built**
`roz_feed_item` **does not exist.** Full spec in `docs/CC_BUILD_AREA_FEED.md` Parts 2 and 3. Parallel fetch off `find_parcels`, government + local news, allowlist as data, rendered straight to the user, never into model context. `rank` mandatory.

### 2. "Is this property for sale?" — **never built**
Parcel-anchored search, allowlisted to listing portals. **Link, matched address, retrieval date only** — never price, photos or listing text. Absence is a finding. Answers Star's *"maybe pic of property"* by exit rather than by hosting.

### 3. Contractor search — **never wired**
`contractors` = 114,104 rows with `trade_code`, `license_status`, `city`, `in_volusia`, `service_radius_km`, `complaint_count`, insurance and bond currency. Star asked for an electrician in Port Orange; the site advertises this.

### 4. Codes carry their consequence — **not done**
Star: *"Flood Zone A and X — what does it mean? Would it need flood insurance?"* Zone A = SFHA = required with a federally-backed mortgage. Zone X = not required. Same for homestead, just-vs-assessed, PUD.

### 5. Property photo — **not done**
Second time visual has come up. VCPA photos or street-level. Verify the URL resolves before surfacing.

### 6. `lien_type_classification` — **missing**
Lienor name classifies the lien and the distribution is known: municipal ~20,000 (**runs with the land**), medical ~9,500 (runs with the person), tax ~9,500, timeshare/HOA several thousand, **PACE 541 — transfers with the property and blocks some conforming mortgages.** Carry runs-with-land versus runs-with-person into the finding.

---

## 🔴 P1 — encumbrance coverage, 4,598 of 75,946

**Instrument-level populations, measured:**

| population | instruments |
|---|---|
| **`other_legal` — has legal, no LOT/UNIT/metes** | **40,524 (53%)** |
| has LOT | 25,896 |
| no legal at all | 5,036 |
| condo/unit | 3,881 |
| metes and bounds | 609 |

**7. Sample 200 `other_legal` descriptions and report the shapes.** No code first. 53% of the corpus and nobody has looked. ~20,000 liens are city-filed and likely templated.

**8. Loosen the LOT subdivision match.** 25,896 instruments, 4,598 matched — the parser fails on ~82% of the format it was built for. Corroboration gives 57× discrimination, so it can carry a looser match. **Re-run Control 4 after loosening; ship only if discrimination holds above ~20 points.**

**9. Add SATISFACTION, RELEASE and DEED to the weekly doctype pull.** The pull only covers JUDGMENT/ORDER, LIEN, LIS PENDENS, RESTRICTIONS. `RS` is *restrictions*, not releases — satisfactions were never searched. This turns *"can't confirm if live"* into *"this is live."* Deeds give the ownership chain, letting a 2019 lien corroborate against the 2019 owner.

**10. Condo route** — 3,881 instruments against `volusia_cama_condo_bldg` (23,191). Run all four controls; the residential result doesn't transfer.

**11. Owner-only tier** for the 5,036 with no legal. Negative control first — 354,464 distinct party names. If discrimination is thin, don't ship.

*Metes and bounds is 609. Ignore.*

---

## 🟠 P2 — latency and cost

**12. Prompt caching is not working.** `cache_read_tokens = 0` on every exchange. Logenberry's 4-call, 62,969-token run paid full input price. Fixing it roughly halves cost and cuts latency.

**13. Streaming.** Answers appear as written rather than after a 36-second wait. Doesn't reduce total time, changes the experience.

**14. Precompute the parcel record.** The real latency fix — minutes to under a second. G2 chose lazy-with-cache for the alpha; this is the production shape.

---

## 🟠 P2 — data integrity

**15. 54 SRID-0 layers.** Cannot be spatially joined at all. Includes `sjrwmd_wells`, which is why `well_gwca_flag` (2,803) and `well_icr_flag` (566) can't attach to parcels.

**16. `parcels_staging` — 10,739,881 rows, ~21 GB, still there.** Proven a strict key-subset of `fl_cadastral_dor_statewide`. Repoint the app, drop it, recover a quarter of the database.

**17. `orange_parcels_govt_source_abandoned_20260722`** — 725 MB quarantine, purpose served.

**18. `fema_flood_zones`** — 1,210 MB index on 232 MB table, unregistered, no source URL.

**19. Elevation accuracy metadata.** `parcel_elevations` is four columns, 10.7M rows, no method or vertical accuracy. USGS 3DEP publishes NVA 0.64 ft / VVA 0.96 ft at 95% confidence per acquisition. `elevation_above_bfe_ft` is stated without its uncertainty.

**20. `WORK_TYPE` / `STATUS` code table** — still unsourced. Raw codes suppressed, which is right, but the labels are missing.

**21. Trade classification** — 576,254 permits (58.6%) in `other/other`.

---

## 🟡 P3 — acquisition

**22. Tax deed and certificate sales** — LienHub, `volusia.realtaxdeed.com`, Clerk calendar. `county_tax_deed_systems` is empty. **Star's stated need, and the one thing ChatGPT can't assemble.**

**23. Calls for service** — noise and disturbance, block-aggregated, with the county distribution as denominator. Volusia Sheriff plus municipal agencies publish separately. No CFS data loaded; the arrest table is 47 rows and person-level.

**24. FCC ASR** — `fcc_asr_structures` exists, **0 rows.** Blocked on `r_tower.zip`; Akamai blocks both CC and me. Needs a browser download.

**25. FDOT Five Year Work Program + River to Sea TPO TIP** — the structured statewide version of planned works.

**26. Remaining 28 restriction layers.**

**27. Part 77 flight-path surfaces** — five nested containment tests from `volusia_runway_lines`. `in_flight_path` is currently `assumed`.

**28. Active military** — MIRTA boundaries, AICUZ/APZ, DoD PFAS, FAA special use airspace.

**29. Absence signal** — parcels with no roofing permit against `ACT_YR_BLT`. Stronger agent lead than a documented roof.

**30. `fl_zctas` (1,013)** loaded and unwired; USPS ZIP+4 for the postal-versus-municipal mismatch.

---

## 🟢 P4 — housekeeping

**31.** `env_layer_catalog.level` CHECK to allow `parcel` (currently worked around with `site`)
**32.** Field naming: `recorded_encumbrance` vs `recorded_encumbrances`
**33.** `DATA_JOIN_FINDINGS.md` — merge the corroboration anchor into the **original**, don't replace it
**34.** Permit `directLink` and VCPA deep-link — held pending browser test
**35.** ~45 unregistered tables blocking valid `field_status`
**36.** 40 fields still `not_computed`

---

## The process fix

**This backlog needs to live in the database or `docs/`, with status maintained by CC as work lands.** Six items above were specced and silently dropped because the only record was a chat message. That will keep happening until the list is somewhere durable and gets re-read before each batch.

Suggested: a `build_backlog` table — id, title, priority, status, spec reference, verified_at — that CC updates on completion and reports against.
