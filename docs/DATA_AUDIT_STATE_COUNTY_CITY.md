# Florida Property Data — Full Audit: State → County → City

**Compiled 2026-07-23.** Every figure measured directly against the database. Where a claim is inference rather than measurement, it is marked.

**Headline: 1,976 tables. 1,659 county-scoped across all 67 counties, 191 city tables across 41 cities, the remainder state/federal/platform. The single biggest structural problem is naming — 540 distinct layer names for roughly 40 real concepts.**

---

## TIER 1 — STATE

### Statewide parcel spine

| Table | Rows | Notes |
|---|--:|---|
| `fl_cadastral_dor_statewide` | **10,831,924** | DOR statewide cadastral, EPSG 6439→4326. Exact match to source count. **68 distinct `co_no`** = 67 counties + orphan bucket |
| `parcel_elevations` | 10,740,539 | Near-complete statewide elevation. 99.2% of cadastral |
| `parcels_staging` | 10,327,257 | Statewide staging — **provenance unconfirmed**, 504,667 short of cadastral |
| `nal_staging` | 309,344 | Single-county sized — likely Volusia-era artifact |
| `sdf_staging` | 67,411 | Same |

**The `co_no = 0` orphan bucket: 92,043 parcels (0.85%)** unattributed to any county by the source. Spatial attribution queued, not run.

### State datasets

`fl_county_boundaries` (67) · `fl_zctas` (1,013) · `fl_burn_detection_history` (1,809) · `fl_historical_aqi_by_area` (25,698) · `fl_citizens_policies_by_county` · `fl_insurance_avg_premiums` (67) · `hydrology_waterbodies` (41,087) · `traffic_aadt` (158,403) · `fgs_subsidence_incidents_raw` (4,417)

### Federal — HIFLD (18 tables)

colleges, courthouses, dams (1,080), dialysis centers, fire stations (1,744), FRS relevant (12,649), FUDS sites, gas pipelines, hospitals, mobile home parks (5,926), nursing homes (4,336), police stations, private schools (1,913), public schools (4,337), RCRA TSD sites, shelters (2,712), superfund sites, transmission lines (3,739)

### Federal — other

`fema_flood_zones` (101,200) · `fema_disaster_declarations` (2,794) · `fema_nfip_multiple_loss_fl` (33,547) · `census_block_groups` (13,239) · `census_acs_data` (13,239) · `bls_qcew_county` (2,260) · `bls_laus_county` (335) · `bebr_county_projections` (1,020) · `bebr_county_estimates` (68)

### Professional registry

`agent_license_roster` (493,556) · `agent_license_status` (493,556; **355,622 Active**) · `contractors` (114,104)

### Product tier

| Table | Rows |
|---|--:|
| `properties` | 313,578 |
| `property_permit_history` | 983,991 |
| `property_environmental` | 313,580 |
| `property_hazard_risk` | 313,519 |
| `property_transaction_history` | 67,289 |
| `data_confidence_scores` | 427,682 |

**Note:** `properties` at 313,578 is ~2.9% of the statewide cadastral. The product tier is built for roughly one county's worth of parcels, not the state.

---

## TIER 2 — COUNTY

**1,659 tables · 67 counties · 540 distinct layer names.**

### Core layer coverage (67 counties)

**Corrected 2026-07-24 from `county_layer_registry` (systematic concept→table crosswalk, St. Johns now included).** Counts are distinct counties per concept.

| Layer | Counties | Gap |
|---|--:|---|
| DOR NAL | **67** | — |
| DOR SDF | **67** | — |
| Statewide cadastral geometry | **67** | — |
| Schools | **67** | — |
| County parcel layer | **63** | 4 missing |
| Flood / FEMA | **65** | Hernando, Osceola |
| Land use / FLU | **62** | 5 counties |
| **Zoning** | **47** | **20 counties** |
| **Address points** | **38** | **29 counties** |
| Plat index (change-detection) | **3** | Miami-Dade, St. Johns, Volusia |

**True missing county parcel layer (4):** Holmes, Osceola, St. Lucie, Washington.
*(St. Johns was hidden by the `sjc_` prefix — now resolved; it has a 139k-parcel layer. See Orphans.)*

**Missing zoning (20):** Bradford, Broward, Calhoun, DeSoto, Dixie, Gadsden, Gilchrist, Gulf, Holmes, Jackson, Jefferson, Lafayette, Levy, Liberty, Madison, Polk, Suwannee, Taylor, Union, Washington.
**Broward missing zoning is notable** — 754,415 NAL rows, second-largest county.

**Address points is the weakest core layer at 37/67 (55%).** Address is a primary user entry path.

### Naming fragmentation — the structural problem

**540 distinct layer names for ~40 concepts.** Variants per concept:

| Concept | Counties | Distinct names |
|---|--:|--:|
| Zoning | 46 | **29** |
| Flood | 64 | **28** |
| Parcels | 62 | **16** |
| Schools | 66 | 16 |
| Land use | 59 | 9 |
| Address | 37 | 9 |
| Subdivisions | 28 | 6 |

**The 16 parcel-table names:**
`parcels` · `parcels_govt_source` · `parcels_gis` · `parcels_cama` · `parcels_staging` · `pa_parcel` · `cama_parcel` · `ownership` · `tax_parcels` · `own_parcels` · `county_owned_parcels` · `non_recognized_parcels` · `parcel_centroids` · `parcel_school_assignment` · `subsidence_parcels` · `parcels_govt_source_abandoned_20260722`

Some are genuinely different things (`county_owned_parcels` ≠ `parcels`), but the primary-parcel-layer name alone varies across `parcels`, `parcels_govt_source`, `parcels_gis`, `pa_parcel`, `ownership`.

**Address:** `address_points` (Alachua) vs `addresses` (Charlotte) vs `address_records` (Columbia) vs `address_sites` (St. Johns).
**Land use:** `future_land_use` vs `flu` (Brevard) vs `landuse` (Citrus) vs `land_use` (Alachua) vs `existing_land_use` (Charlotte).

---

## TIER 3 — CITY

**191 tables · 41 cities · 69 layer types.**

Cities identified include: Apopka, Boca Raton, Bonita Springs, Boynton Beach, Bradenton, Cape Coral, Clearwater, Coral Springs, and 33 more.

**City layers have no county-tier equivalent** and are the most granular data held: stormwater (inlets, mains, manholes, pressurized main), police geography (beats, districts, grids, sectors, zones, RD, marine grids), seawall, sidewalks (2015, budgeted, current), streetlights, parking (garages, pay stations), hydrants, elevation certificates, LOMAs/LOMRs, historic districts (local + national), CRA, opportunity zones, neighborhood associations.

**`clearwater_city_parcels` (80,266)** — a city-level parcel layer, meaning parcel data exists at all three tiers for that area.

**Coverage is opportunistic, not systematic.** 41 of Florida's ~410 municipalities. No city-tier completeness standard exists.

---

## VERIFIED ALIGNMENTS

Measured this session on Volusia (1,000-parcel sample):

| From | To | Key | Match |
|---|---|---|--:|
| `fl_cadastral_dor_statewide` | `*_nal_dor_source` | `parcel_id` = `"PARCEL_ID"` | **100%** |
| `fl_cadastral_dor_statewide` | `volusia_parcels_govt_source` | `parcel_id` = `pid` | **99.9%** |
| `volusia_parcels_govt_source` | `volusia_cama_*` | **`altkey` = `"PARID"`** | **100%** |
| `fl_cadastral_dor_statewide` | `volusia_cama_*` | direct | **0%** |

**The convergence path:**

```
cadastral.parcel_id ──100%──> NAL."PARCEL_ID"        values, exemptions, use codes
                    ──99.9%─> county_gis.pid          geometry
                                    │
                                 .altkey  ──100%──>  cama."PARID"   owners (multi), sales, permits
```

**Two traps in that path:**
1. **CAMA does not join on parcel number.** It is keyed on AltKey. The county GIS table is the only bridge — it alone carries both keys. A county whose GIS lacks a second key has no path to its CAMA data.
2. **Type mismatch at the bridge.** `altkey` is `double precision`; `PARID` is `text`. Requires explicit `::bigint::text`. Without the cast the join errors — this time. A silent coercion would have been worse.

### Geometry integrity (verified)

- Cadastral, Volusia, Orange, Sarasota: **0 parcels outside Florida bbox**
- Volusia parcels vs `fl_county_boundaries`: **3,000/3,000 inside Volusia County**
- `sjc_parcels` vs St. Johns boundary: **2,000/2,000 inside**

---

## ORPHANS

### 1. St. Johns County — 19 tables hidden by abbreviation ← RESOLVED HERE

`sjc_*` is St. Johns County. **Verified: 2,000/2,000 `sjc_parcels` fall inside the St. Johns County boundary.**

`sjc_parcels` (139,000) · `sjc_address_sites` (164,000) · `sjc_flood_zones` (9,322) · `sjc_zoning` (2,242) · `sjc_zoning_districts` · `sjc_future_land_use` (1,211) · `sjc_plat_index` (2,709) · `sjc_fire_hydrants` (12,876) · `sjc_fire_stations` · `sjc_parks` · `sjc_school_sites` · `sjc_school_zone_elementary/middle/high` · `sjc_evacuation_routes` · `sjc_evacuation_zones` · `sjc_code_enforcement_zones` · `sjc_library_zones` · `sjc_land_use_boundary`

**St. Johns is one of the best-covered counties in the database and was invisible to the audit.** Every county-prefixed query has been silently excluding it. This is the only county-level abbreviation orphan; `hifld_`, `fema_`, `fl_`, `data_` are legitimate.

**Also note `sjc_plat_index` (2,709)** — a plat index, the change-detection layer identified as valuable and believed absent. **Resolved 2026-07-24:** plat indexes exist for **3 counties** (Miami-Dade, St. Johns, Volusia), all now registered in `county_layer_registry` under `concept='plat_index'`.

**RESOLUTION (2026-07-24):** St. Johns is aliased in `county_layer_registry` (canonical `county='St. Johns'` maps both `sjc_*` and `stjohns_*` tables). No rename — the `sjc_` prefix is referenced by 4 active `data_source_registry` refresh rows, so renaming risked the harness re-creating `sjc_` tables; the registry crosswalk resolves the addressability non-destructively. All 29 St. Johns tables are now visible to concept-based lookups.

### 2. The 540-name problem ← RESOLVED HERE

Not orphaned data — orphaned *addressability*. No query could reliably find "the parcel layer for county X" without a lookup table mapping concept → actual table name per county.

**RESOLVED 2026-07-24:** `county_layer_registry` now provides exactly that crosswalk — **1,678 county tables mapped to 26 CHECK-constrained concepts across 67 counties.** A generic lookup is now `select table_name from county_layer_registry where county=$1 and concept=$2`. Parcel keys + transforms are measured (not guessed): 8 counties carry a tested `key_column` (Baker `parcelno`, Volusia `pid`+`altkey`→CAMA bridge, Glades/Hardee strip-punct, Indian River `pp_pin`, Sarasota `account`, Seminole `parcel`, Manatee `parent_parid`), all 98–99.7% verified against the cadastral. Untested counties carry `key_column = NULL` (never a guess). SRID 0 flagged on 25 tables.

### 3. `parcels_staging` (10,739,881) ← IDENTIFIED

**Corrected count: 10,739,881** (the 10,327,257 figure was stale). **Identified 2026-07-24: this is the active, central, app-facing parcel table — NOT superseded, do NOT quarantine.** Nine production RPCs depend on it (`get_pir_report`, `get_pir_map_geojson`, `get_pir_parcel_closeup`, `get_site_intelligence`, `find_parcels`, `parcels_in_view`, `search_properties`/`_stats`, `get_nearby_amenities`) — the PIR engine, the assistant, and cross-property search. `CLAUDE.md` designates it "the central dataset."

Provenance confirmed: a curated 44-column statewide spine (geometry `geom`+`geom_wkt` + owner/value/use/building attributes), loaded 2026-07-02..05, all 67 counties, 100% geometry, no orphan bucket. Its parcels are a strict subset of the DOR cadastral by key (5,000/5,000 sampled `parcel_id`s present in `fl_cadastral_dor_statewide`), and its row count = cadastral (10,831,924) − the co_no=0 orphan bucket (92,043) exactly. It complements the raw 122-column `fl_cadastral_dor_statewide` (loaded 2026-07-23/24 for completeness); it does not compete with it.

### 4. `co_no = 0` (92,043 parcels)

Unattributed to any county in the cadastral. Recoverable by spatial join to `fl_county_boundaries`. Queued, not run.

### 5. Product-tier scope mismatch

`properties` holds 313,578 rows against 10.8M statewide parcels. The product layer is built at single-county scale.

### 6. `fema_flood_zones` (101,200)

Previously flagged as unregistered with no recorded source URL. Still unconfirmed.

---

## PRIORITY FINDINGS

1. **St. Johns (19 tables) excluded from every audit by naming.** Fix the convention or add an alias table. Highest-value single fix.
2. **Address points at 37/67** is the weakest core layer, and address is a primary entry path.
3. **Zoning missing for 20 counties including Broward.**
4. **A concept→table name registry does not exist.** 540 names, no map. This blocks any generic per-county pipeline.
5. **The CAMA bridge depends on the county GIS carrying two keys.** Volusia does. Unknown for the other 66 — and where it fails, relational county data is unreachable.
6. **`parcels_staging` at 10.3M is unidentified** and large enough to matter.

---

## WHAT THIS AUDIT DID NOT COVER

- Column-level schema comparison within layer types (only table names)
- Row-count reconciliation per county against source
- Temporal currency per table (which are stale)
- The 13 counties whose export endpoint is still `pending`
- City-tier alignment to county or parcel
- Whether city layers overlap or conflict with county equivalents
