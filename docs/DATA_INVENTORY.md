# Data Inventory & LADM Mapping

**Generated 2026-07-25** from `table_inventory` (re-runnable; `~/inv_build.py`). Read-only against the data; the only writes were `table_inventory` and this document. Spec: `docs/DATA_INVENTORY_SPEC.md`.

Row counts are `pg_class.reltuples` **estimates** (exact `count(*)` over 2,012 tables is impractical); the total reconciles to within 0.0002% of the exact baseline.

---

## Reconciliation against the spec baselines (rule 10)

| Metric | Baseline | Measured | Note |
|---|---|---|---|
| Tables | 2,012 | **2,012** | ✓ (excludes `table_inventory` itself) |
| Rows | 97,038,354 | 97,038,160 | est. vs exact, Δ194 |
| Size | 82 GB | **82 GB** | ✓ |
| Geometry | 1,546 | **1,546** | ✓ |
| parcel_key | 175 | 176 | ✓ (+1; added `property_id` which joins via `properties`) |
| latlon | 2 | **2** | ✓ |
| area_key | 239 | 246 | +7 (broader county/city/district detection) |
| geocodable | 6 | 3 | −3 (address+area tables classed area_key first, the stronger join) |
| unpairable | 44 | 39 | −5; **all 39 are genuine system/config tables** (registries, logs, `spatial_ref_sys`, calibration) |
| Registry tables | 282 | **282 live / 288 registered** | **6 registry entries point to tables that no longer exist** |
| Comments | 527 | 506 | Δ from view/table filtering |
| Consumed by a function | 91 (unreliable) | **92 (proper, SQL-context match)** | the over-match fear did not materialise — real consumption is 92/2,012 = **4.6%** |
| Families (≥2) / members / singletons | 114 / 1,391 / 621 | 109 / 1,400 / 612 | small method delta (shared-remainder derivation) |

**Method for family (Axis 2):** `data_source_registry.category` when registered; else the name-remainder if it recurs under ≥2 geo-prefixes; else singleton. A few non-geo-prefixed spine tables split imperfectly (`parcels_staging` → remainder "staging") and were given a judgment LADM override.

---

## LADM class distribution (Axis 3 — assigned per family, inherited)

| LADM class | Tables | What it means for Roz |
|---|---|---|
| `external_thematic` | 1,663 | context only, **never phrased as a constraint** |
| `LA_Restriction` | 194 | **binding constraint — requires a source document before Roz states it** |
| `LA_SpatialUnit` | 125 | the extent (parcels, plats, PLSS, buildings, cadastral) |
| `LA_Right` | 22 | permits, easements, wells as authorisations |
| `LA_Party` | 4 | owners |
| `LA_SourceDocument` | 2 | recorded instruments |
| `LA_BAUnit` | 1 | the property as a rights bundle (`properties`) |
| `LA_Responsibility` | 1 | plugging/maintenance liability |

`external_thematic` is 83% of the database and that is correct — most of it is legitimately outside LADM. The 194 `LA_Restriction` tables are dominated by regulatory `zoning` (50) and `flood_zones` (60) plus city variants — binding land-use/regulatory layers. (One false positive: `gwca_parcel_match` is a derived cross-reference, not a restriction layer — keyword-matched on "gwca"; re-class on next run.)

---

## Families ranked by rows (top 20, ≥2 members)

| Family | Members | Est. rows | LADM | Registered |
|---|---|---|---|---|
| nal_dor_source | 67 | 10,998,343 | external_thematic | 0 |
| (parcels_staging etc.) | 3 | 10,704,012 | LA_SpatialUnit | 0 |
| parcels | 59 | 7,806,021 | LA_SpatialUnit | 38 |
| address_points | 30 | 6,680,565 | external_thematic | 28 |
| city_address_points | 26 | 2,368,448 | external_thematic | 0 |
| sdf_dor_source | 67 | 2,122,122 | external_thematic | 0 |
| future_land_use | 55 | 1,266,424 | external_thematic | 50 |
| zoning | 50 | 1,219,651 | LA_Restriction | 47 |
| parcels_govt_source_abandoned_20260722 | 2 | 667,843 | LA_SpatialUnit | 0 |
| building_footprints | 2 | 569,036 | LA_SpatialUnit | 0 |
| flood_zones | 60 | 515,134 | LA_Restriction | 32 |

**1,057 of the 1,546 geometry tables belong to 98 families** — each wireable by a single per-family resolver. Only 489 geometry tables are singletons. That is the leverage: ~98 resolvers cover 68% of all geometry tables.

---

## The four questions

### 1. Families with no resolver, by rows — the work queue by leverage

Not consumed by any function and not registered, largest first:

| Family | Members | Est. rows |
|---|---|---|
| **nal_dor_source** | 67 | 10,998,343 |
| **city_address_points** | 26 | 2,368,448 |
| **sdf_dor_source** | 67 | 2,122,122 |
| parcels_govt_source_abandoned_20260722 | 2 | 667,843 |
| building_footprints | 2 | 569,036 |
| existing_land_use | 2 | 337,000 |
| city_parcels | 4 | 304,762 |
| city_future_land_use | 28 | 267,996 |
| road_centerlines | 4 | 207,571 |
| city_zoning | 29 | 199,814 |

The **DOR tax roll (`nal_dor_source`, 67 counties, 11M rows)** is the single highest-leverage unwired family — statewide assessment data, one resolver.

### 2. Is `parcels_staging` redundant against `fl_cadastral_dor_statewide`?

**Yes — `parcels_staging` is a strict key-subset of `fl_cadastral`.** Measured:
- `parcels_staging`: 10,327,257 rows, 67 `co_no`, has geometry, **consumed** (the RPCs — `find_parcels`, `get_site_intelligence`, `parcels_in_view` — all read it).
- `fl_cadastral_dor_statewide`: 10,831,924 rows, 68 `co_no` (67 + the `co_no=0` orphan), has geometry, **not consumed → the #1 orphan by rows.**
- **`in parcels_staging NOT in cadastral` = 0** — every staging `(co_no, parcel_id)` exists in cadastral. Cadastral is the superset (~504k more rows + the `co_no=0` block).

**Verdict:** they are redundant; `parcels_staging` is the load-bearing active spine, `fl_cadastral` is the unconsumed statewide superset. **Do not drop either yet** — repointing the app's functions from `parcels_staging` to the superset `fl_cadastral` and retiring `parcels_staging` is the clean end-state, but that is a wiring change (out of scope here) and must first account for the ~504k delta and the `co_no=0` orphan.

### 3. Tables that can never be refreshed (no source recorded)

**1,104 tables (23.1M rows) resolve through no provenance route** (not in `data_source_registry`, no comment, not in a migration). Largest: `polk_sales` (3.0M), `miamidade_pa_parcel` (941k), `miamidade_property_boundaries` (939k), `palmbeach_situs_addresses` (790k), `polk_owners` (676k), `miamidade_geoaddress` (607k). These are county-scraped layers with no recorded source URL or technique — **they cannot be refreshed and cannot produce a valid `field_status`.** Register or exclude from the payload; full list in `table_inventory WHERE provenance_route='unresolved'`.

### 4. `LA_Restriction` layers requiring a source document before Roz may state them

194 tables. The ones **missing a source document** (`source_url IS NULL`) are the immediate blockers — Roz may not state them until a source is attached:
- **`city_zoning` (29 tables), `city_flood_zones` (8)** — 0 registered, 0 source URLs.
- `gwca_parcel_match` (derived — reclass, not a real restriction), `miamidade_zoning_hearings/resolutions`, `pasco_zoning_*`, `sumter_wildwood_zoning`, `lee_zoning_cases`, `broward_flood_zones_2014`, `marion_fema_flood_zones_2017`.
- `wellfield_protection` (2), `palmbeach_wellfield_zones`, and the Volusia/Collier/Charlotte/Orange overlays (`coastal_high_hazard_area`, `fdep_critical_erosion`, `construction_control_lines`, `*_overlay`) — several **empty (0 rows) and unsourced**.

The `zoning` (47/50) and `flood_zones` (32/60) county families mostly **do** carry a registry source URL — those are stateable; the county coverage gaps and all of `city_*` are not.

---

## Status distribution

| status | tables | est. rows |
|---|---|---|
| orphan (unconsumed + unregistered) | 1,621 | 52.3M (54% of all rows) |
| reachable | 346 | — |
| system (unpairable) | 39 | — |
| staging | 4 | — |
| superseded | 2 | — |

Top orphans: `fl_cadastral_dor_statewide` (10.8M — see Q2), `polk_sales` (3.0M), `volusia_official_records_private` (1.26M), `volusia_cama_res_area` (1.0M), `miamidade_pa_parcel` (941k). **Consumption is 4.6% of tables; collection ran far ahead of wiring.**

---

## Reconciliation note — `derived_field_status`

The spec cites **46 `not_computed`** fields. Current state is **37** — the count moved this session as the work queue was worked (the seven CLM/HIFLD fields, then flood/BFE/elevation/power/sinkhole were derived; computed rose 8 → 18). Re-read against addressability: of the remaining `not_computed`, several are now `work_queue` (a loaded source exists) rather than genuine gaps. The inventory confirms the addressable ones have sources in `table_inventory` (e.g., transmission lines, flood zones, parcel elevations, `volusia_sinkhole_incidents`); the genuine gaps (cell_tower [blocked], pfas_level_ppt [no ppt source], military/pollen/mold/first-street factors) have **no table in the inventory to draw from** — consistent between the two artifacts.

---

## LADM re-class pass (2026-07-25, follow-up)

The first pass left `LA_SourceDocument` = 2, making the spec's "every `LA_Restriction` needs a source document" rule structurally unsatisfiable while the DB held 1.26M recorded instruments and ~2M permits classed as something else. Re-classed at family level with dual-role capture (`ladm_dual`, `source_document_ref` columns added).

| LADM class | Before | After |
|---|---|---|
| external_thematic | 1,662 | 1,675 |
| LA_Restriction | 194 | 193 |
| LA_SpatialUnit | 126 | 118 |
| **LA_SourceDocument** | **2** | **11** |
| LA_Right | 22 | 7 |
| LA_Party | 4 | 4 |
| LA_BAUnit | 1 | 3 |
| LA_Responsibility | 1 | 1 |

**Moved:** recorded instruments/permits/plats → `LA_SourceDocument` (`official_records`, `cama_permits`, `property_permit_history`, wells, `subdivision_plats`, `final_platting`, `plat_index`); CAMA property records `volusia_cama_parcel`/`polk_parcels_cama` (no geometry) → `LA_BAUnit`; `parcel_elevations`/`parcel_school_assignment`/`subsidence_parcels` (thematic-by-parcel) and `gwca_parcel_match` (derived) → `external_thematic`; 0-row app-workflow `permit_*` → `external_thematic`.

**Dual roles (10):** 6 permits are `LA_SourceDocument` + `LA_Right`; 3 plats are `LA_SourceDocument` + `LA_SpatialUnit`; `fdep_institutional_controls` is `LA_Restriction` + `LA_SourceDocument` (`source_document_ref = volusia_official_records_private`).

**Ownership confirmed correct:** `volusia_cama_owner`, `polk_owners`, `charlotte_ownership`, `broward_renter_owner_units` are all `LA_Party` — the multi-owner model was **not** collapsed into `LA_SpatialUnit`.

**Restriction blocker, revised:** of 193 `LA_Restriction`, **80 satisfy** the source-document rule (registry `source_url`), **113 still cannot** — including `city_zoning` (29) + `city_flood_zones` (8) confirmed. Correct classing made the rule *satisfiable in principle* but the residual 113 are a **data-coverage gap** (no registry URL, no recorded-instrument coverage), not a classification gap. `source_document_ref` is null for all but the ICR — and **that null is the thing Roz must respect** before stating those restrictions.

**Declined:** `volusia_cama_sales` (assessment view of sales, references but isn't the instrument), building records (kept `LA_SpatialUnit` per spec), `cama_legal`/`cama_land`/`cama_exemptions` (descriptive detail).

## Known gaps in this pass (rule 10 — what was skipped/failed)

- **`purpose` column left null** across all rows — per-table "the question it answers" is judgment at 2,012-table scale; deferred, not fabricated.
- The reverse overlap count (`in cadastral NOT in parcels_staging`) did not finish in the report run (slow 10M anti-join); it is ~504k + the `co_no=0` block by arithmetic (staging ⊆ cadastral is proven).
- Family derivation is mechanical (shared-remainder); a handful of non-geo-prefixed tables split imperfectly and carry a judgment LADM override rather than a clean family.
- Provenance route 4 (OID sequence) gives creation order for all 2,012 but is **not** a source; tables resolving only by OID are reported as `unresolved` (Q3), not "resolved."
