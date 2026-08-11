# Environmental Hazard & Contamination Layers — Ingestion Spec

**Drafted 2026-07-24.** Endpoints verified live unless marked otherwise.

Six sources. Two are **parcel-level legal restrictions** and must be modelled as encumbrances, not proximity context. Four are incident/site layers.

**Governing rule for every source in this spec:** these are safety and legal-status fields. **Absence of a record never means absence of the hazard.** Every field implements the three-state model in §7. A `false` or a green checkmark where nothing was checked is the failure mode that does real harm.

---

## 1. What is already held — do not re-pull

| Source | Table(s) | Rows |
|---|---|---|
| FDEP Brownfield areas | `fdep_brownfield_areas` | 624 |
| FDEP Brownfield sites | `fdep_brownfield_sites` | 571 |
| Per-county brownfields | `<county>_brownfield_areas` / `_sites` | ~40 counties |
| EPA Superfund | `epa_superfund_facilities` | 646 |
| HIFLD Superfund | `hifld_superfund_sites` | 603 |
| Formerly Used Defense Sites | `hifld_fuds_sites` | 711 |
| RCRA TSD | `hifld_rcra_tsd_sites` | 72 |
| EPA FRS | `hifld_frs_relevant` | 12,649 |
| Site hazard installations | `site_hazard_installations` | 5,919 |

**Skip:** Broward County contaminated-sites inventory (redundant against `fdep_*` statewide). Third-party advocacy aggregators (not citable in a paid report).

---

## 2. FDEP Contamination Locator Map (CLM) — PRIORITY 1

**Verified live 2026-07-24.**

```
https://ca.dep.state.fl.us/arcgis/rest/services/Map_Direct/Environment/MapServer/1
```

| Property | Value |
|---|---|
| Layer name | DEP Cleanup Sites — Contamination Locator Map |
| Geometry | Point |
| **OID field** | **`DEP_CLEANUP_SITE_KEY`** — captured from metadata, do not assume `objectid` |
| **Spatial reference** | **6439** (Florida GDL Albers) — reproject to 4326, same as statewide cadastral |
| MaxRecordCount | 1000 |
| Pagination | supported |
| Formats | JSON, geoJSON, PBF |

**Why this is worth having despite holding brownfield/Superfund already:** it carries **remediation status**, which the static site layers do not. A site's position in the cleanup process is the material fact for a buyer, not merely that a site exists.

### Cleanup categories (`CLCC_CLEANUP_CATEGORY_KEY`)

`PETRO` petroleum · `SUPER` Superfund · `BROWN` brownfield · `OTHCU` other waste cleanup · **`PFAS`**

**The `PFAS` category is a source for `property_environmental.pfas_detected`**, currently nulled across all 313,578 rows.

### Fields to preserve

**Identity & status:** `DEP_CLEANUP_SITE_KEY`, `SOURCE_DATABASE_NAME`, `SOURCE_DATABASE_ID`, `CPAC_PROGRAM_AREA_ID`, `CLCC_CLEANUP_CATEGORY_KEY`, **`RSC2_REMEDIATION_STATUS_KEY`**, `DATA_LOAD_DATE`

**Location:** `BUSINESS_NAME`, `ADDRESS1`, `ADDRESS2`, `CITY`, `ZIP5`, `ZIP4`, `CC2_COUNTY_ID`

**Positional quality — preserve all of these:** `CALC_COORD_ACCURACY_LEVEL_ID`, `CMC2_COORDINATE_METHOD_ID`, `DC4_DATUM_ID`, `VSC1_VERIFICATION_STATUS_ID`, `VERIFICATION_DATE`, `VERIFIER_AFFILIATION`, `MAP_SOURCE`, `MAP_SOURCE_SCALE`, `INTERPOLATION_SCALE`, `PC2_PROXIMITY_ID`

**Documents:** `DOCUMENTS` — links into DEP's OCULUS document system.

**This dataset publishes its own positional accuracy.** That is rare and valuable: a match can be filtered by how well-located the point is rather than treating every point as equally reliable. **Do not drop these fields as metadata** — they determine whether a spatial join is trustworthy for a given record.

**No parcel identifier.** Address + point only. See §6 for resolution.

---

## 3. FDEP Institutional Controls Registry (ICR) — PRIORITY 1

**This is not proximity data. It is a legally binding restriction recorded against a specific parcel.**

Deed restrictions limiting land use, prohibiting groundwater wells, barring residential conversion, requiring engineering controls be maintained. **It runs with the land and appears in the title.**

### Two hosting routes — probe both

| Route | Location |
|---|---|
| DEP open data (AGOL) | item `a8dedaa86ba4434bbe48b69686ad3c72`, `geodata.dep.state.fl.us` |
| **FGDL mirror** | `taurus.at.geoplan.ufl.edu/arcgis/rest/services/fgdl/FDEP_Waste_Groups/MapServer/16` |

**Pull both and compare counts and fields.** A free divergence check — same discipline as the peer-review protocol. If they disagree, that disagreement is the finding.

### Two caveats stated in the source metadata — carry both forward

**1. Positional data is self-reported by the polluter.**
> *"The locational data point of each deed restriction is provided by the responsible party and reviewed by the Florida Department of Environmental Protection (FDEP) agency staff."*

The responsible party supplies the coordinates; DEP reviews. That is a real accuracy limitation on a legally significant field, and it must reach the report — a control on the parcel next door is a materially different fact from a control on this one.

**2. The portal's displayed date is NOT the data date.**
> *"The data for this dataset is updated daily. The date(s) displayed in the details section on our Open Data Portal is based on the last date the metadata was updated and not the refresh date of the data itself."*

**Record `retrieved_at` from our own pull. Never present the portal's metadata date as vintage.** This is exactly the false-currency trap the provenance model exists to prevent.

### Modelling — LADM

An institutional control is **`LA_Restriction`** on the `LA_BAUnit` — the same class as a mortgage or lien. It is **not** an environmental context field.

Store in the restrictions model alongside liens and lis pendens, not in `property_environmental`.

---

## 4. FDEP Public Notice of Pollution (PNP)

```
https://ags.dep.state.fl.us/arcgis/rest/services/External_Services/PNP/MapServer
```

Statutory §403.077 pollution-incident notices. **A live incident feed, not a site registry** — complements CLM (sites under cleanup) with events as reported.

Self-reported by the reporting entity. Note the source's own caveat: submission of a notice does not relieve the reporter of separate State Watch Office obligations, so this is not a complete incident record.

---

## 5. FDEP Storage Tank & Contamination Monitoring (STCM)

Storage-tank facility information, sourced from the STCM database, **updated daily**, downloadable **by county**.

Underground and above-ground storage tanks, and petroleum contamination. Feeds `property_environmental.underground_storage_tanks_500m`.

**Endpoint not yet verified** — locate the per-county download and record the exact URL before ingesting.

---

## 6. DEA National Clandestine Laboratory Register

**Downloadable as CSV** (the map view is capped at 500 points; the CSV is not). Filter to Florida.

### Why this field is high-stakes

Meth residue exposure causes cancer, organ damage and other health effects, **particularly in children**. Contamination permeates walls, carpet and ductwork; remediation requires a hazmat team.

### Why it can never assert "clean"

- The DEA describes it as addresses of **some** locations that were **reported** by law enforcement
- **Florida has no state contaminated-property registry and no state cleanup standard**
- Florida disclosure falls only under the general "materially affects value" duty and **need not be in writing**
- Lab seizures fell from 23,700 (2004) to 60 (2023) — so present-day risk is overwhelmingly **old, unreported** contamination, precisely what a federal seizure database is least likely to contain

**Mandatory rendering** — the field carries this text, not the renderer:

> *"Not listed in the DEA National Clandestine Laboratory Register. This register contains federal seizure records only; absence does not indicate the property is uncontaminated."*

**Flag for the same legal review as the FCRA items.** A "not listed" that a buyer reads as "safe" is a reliance claim.

---

## 7. Absence semantics — binding on every field in this spec

Three states. Never two.

| State | Meaning | Renders as |
|---|---|---|
| `listed` / `present` | Positive finding in the source | The finding, with source and date |
| `not_listed` | Source loaded and checked; no record | **"Not listed in [source]"** + scope limitation |
| `not_checked` | Source not loaded for this county | **Withheld.** Never a value, never `false` |

**`not_listed` must never render as a green checkmark, "clear", "none", or `false`.**

This is the product-side application of the `empty ≠ done` invariant, on the fields where a false reassurance causes actual harm.

**Precedent already in the product:** `"Not within — nearest 1.6 mi (5811 Williamson Blvd)"` and `"area FEMA repetitive-loss figures are county context, not a claim about this parcel"`. Generalise that.

---

## 8. Spatial resolution — every field declares its level

Per `docs/CLIENT_FACING_DATA_AUDIT_SPEC.md` §3.

| Source | Resolution | Method |
|---|---|---|
| **ICR** | `parcel_exact` *(subject to self-reported coordinate caveat)* | address/point match → **verify against parcel** |
| CLM | `adjacent` | nearest, **always state distance** |
| PNP | `adjacent` | nearest, state distance |
| STCM | `adjacent` | nearest, state distance |
| DEA register | `address_match` | address match, state match confidence |
| NFIRS | `parcel_exact` or `adjacent` | geocoded point |

**None of these carry a parcel identifier.** All require address or spatial matching, and all inherit the address-matching risks already measured — situs vs mailing, format variance, renumbering. **A contamination record attached to the wrong parcel is worse than no record**, so match confidence must be stored and low-confidence matches withheld rather than shown.

---

## 9. NFIRS fire & hazmat history — separate, larger task

Noted here because it is the same domain; specify separately before building.

**Source:** NFIRS Public Data Release on OpenFEMA, **1980–2024**, free. **GeoPackage offerings are geocoded versions of the annual All Incidents file** — spatially joinable without doing the address matching.

**Pull the Hazmat module, not only incident types.** NFIRS 5.0 has 11 modules including a dedicated Hazardous Materials module, required *whenever hazardous materials are involved regardless of incident type*. Reference Guide Appendix D is an alphabetised chemical listing — records can name the substance.

**Relevant incident series:** 400 (hazardous condition, no fire — gas leak, chemical spill/leak, chemical hazard, refrigeration leak, CO, radioactive, biological), 200 (rupture/explosion), 471 (explosive/bomb removal), 100/110 (structure fire).

**The Basic Module carries Census Tract natively** — a resolution fallback when street address will not match a parcel.

**Three caveats:**
- **Voluntary system.** USFA: *"NFIRS is not a repository of all incidents… it includes only those incidents reported by fire departments that participate."* Absence ≠ no fire.
- USFA explicitly warns raw PDR is **not** a valid count of fires, deaths or loss.
- **Small hazmat spills are recorded in the Basic Module only**, not the Hazmat module — so substance-level detail correlates with severity.

**Time-sensitive:** NFIRS sunsets. From 1 Jan 2026 submission is exclusively **NERIS**; NFIRS goes unavailable from Feb 2026. The 1980–2024 PDR is a **closed, complete, free archive** that will never grow. Pull it while it is a single stable download.

**Value:** a per-property fire, explosion and hazmat history with substance identification — structural events that appear in no appraiser roll, no permit record, and no consumer property product.

---

## 10. Harness requirements

All four ArcGIS pulls use the hardened harness. Invariants from `CLAUDE.md` apply:

1. **Probe the OID field from layer metadata.** CLM's is `DEP_CLEANUP_SITE_KEY`, not `objectid`.
2. **Abort on empty `returnIdsOnly`.**
3. **Reproject 6439 → 4326** and verify centroids fall inside Florida.
4. **`orderByFields`** on the OID for stable paging.
5. **Chunk loads**, `statement_timeout=0` in session (the pooler strips startup options).
6. **`empty ≠ done`** — assert non-zero after every load.
7. Service-role only, RLS on with no policies, provenance comment recording source URL, **our** retrieval date, and the source's own stated vintage where one exists.

**Register every source in `data_source_registry`** with its refresh cadence: CLM and ICR daily, STCM daily, DEA periodic, NFIRS static archive.

---

## 11. Build order

1. **CLM** — verified endpoint, immediately useful, feeds the PFAS field
2. **ICR** — both routes, compare; model as `LA_Restriction`
3. **PNP** — small, verified host
4. **STCM** — locate endpoint first
5. **DEA register** — CSV, with the mandatory disclaimer text
6. **NFIRS** — separate spec, time-sensitive

**Legal review before publication:** the DEA field wording, and any rendering of ICR restrictions — a misstated land-use restriction is a reliance claim on a legally binding encumbrance.
