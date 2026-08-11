# Property Data Map — 1778 Earhart Ct, Port Orange FL 32128

**Worked reference example. Compiled 2026-07-23.** Every value below was queried directly from the database. Nothing is inferred.

**Identifiers**

| Key | Value | Source |
|---|---|---|
| AltKey / CAMA `PARID` | `3671058` | county CAMA |
| Parcel ID / DOR `PARCEL_ID` | `633001001890` | county GIS, DOR NAL, statewide cadastral |
| `properties.id` | `2e18ffef-88bf-49b9-922d-990ebd2bab79` | product tier |
| State parcel ID | `C74-000-927-2211-5` | DOR |
| Subdivision number | `633001` — **encoded in the parcel ID** | plat layer |
| PLSS | Section 30, Township 16S, Range 33E | `volusia_public_land_survey` |
| Census block group | `121270832102` | `census_block_groups` |
| Centroid | 29.08177, −81.03880 | derived |

---

## 1. Temporal chain — 45 years, unbroken

| Date | Event | Dataset |
|---|---|---|
| **5 Oct 1981** | **Plat recorded** — Spruce Creek Sub Unit IIB, MB 038 pp. 056–059, **113 lots**. Scan: `maps5.vcgov.org/Plats/0038/00380056.tif` | `volusia_subdivision_plats` |
| 31 Dec 1981 | CAMA parcel record created (12 weeks after platting) | `volusia_cama_parcel.DTCREATED` |
| 15 Apr 1983 | Warranty Deed — **$28,900** — OR 2437/0169 | `volusia_cama_sales` |
| 15 Dec 1983 | Warranty Deed — **$34,400** — OR 2539/0485 *(the deed cited in the legal description)* | `volusia_cama_sales` |
| 1 Nov 1988 | Permit 49010D — "SINGLE FAMILY-DETACH **W/HANGAR**/SCRN. PORCH/ENTRY" — $200,000 | `volusia_cama_permits` |
| 1 Jul 1989 | Construction complete | `volusia_cama_permits.COMPL_DATE` |
| 1989 / 1992 | Actual / effective year built | `volusia_nal_dor_source` |
| 27 Oct 2005 | Roofing — Dal Mar Roofing | `volusia_cama_permits` |
| 30 Sep 2009 | Roofing — $10,200 | `volusia_cama_permits` |
| 3 Jan 2020 | HVAC changeout — $4,000, completed 11 Feb 2020 | `volusia_cama_permits` |
| 29 Jun 2026 | Hazard/environmental baseline computed | `property_hazard_risk`, `property_environmental` |
| **22 Jun 2026** | **Generator + 250-gal LP tank — $23,440 — ISSUED, NO COMPLETION** | `volusia_cama_permits` |
| 11 Jul 2026 | **PIR generated** (pre-dates CAMA load) | product |
| 20 Jul 2026 | CAMA export currency | `volusia_cama_*` |

---

## 2. Ownership — LADM structure

**Two owners**, `volusia_cama_owner`, TAXYR 2026:

| OWNSEQ | PCTOWN | OWNTYPE1_DESC |
|---|---|---|
| 0 | 100 | Tenancy in the Entirety |
| 1 | 100 | Tenancy in the Entirety |

**Both at 100% — not a share.** Under LADM this is one `LA_GroupParty` holding a single `LA_RRR`, not two rights. Percentages do not sum to 100 and must not be validated as if they do.

Homestead exemption on file (`HX_FLAG = Y`), 3 exemption rows.

---

## 3. Physical / legal

| Attribute | Value | Source |
|---|---|---|
| Legal | LOT 189 UNIT II-B SPRUCE CREEK SUB MB 38 PGS 56-59 PER **OR 2539 PG 0485** | `volusia_cama_legal` |
| Lot area (GIS-computed) | **31,358 sq ft** | geometry |
| Lot area (CAMA) | **31,354.55 sq ft** / 0.72 ac | `GIS_EST_SF` |
| **Agreement** | **0.01%** | — |
| Use code | 0100 Single Family / DOR 001 | CAMA + NAL |
| Buildings | **2** (`NO_BULDNG`) — house + hangar | NAL |
| Living area | 2,592 sf (CAMA) vs 5,112 sf (NAL `TOT_LVG_AREA`) | **definitional variance** |
| Components | Main 1,860 · Upper 732 · Garage 528 · Screened porch 420 · Open porch 102 | `volusia_cama_res_area` |
| Neighborhood | SPRUCE CRK HANGAR NBHD | CAMA |
| Community | **SPRUCE CREEK FLY-IN** | `volusia_communities` |

---

## 4. Valuation & tax (external classes — attach to BAUnit)

| Field | Value | Source |
|---|---|---|
| Just value | $1,109,506 | `volusia_nal_dor_source` (2025 roll, as of 1 Jan 2025) |
| CAMA appraised total | $1,062,775 | `volusia_cama_parcel` (2026) |
| Land / building | $539,550 / $523,225 | CAMA |
| Tax district | 600 — Unincorporated Southeast | CAMA |

**Note the vintage divergence: DOR $1,109,506 (Jan 2025) vs CAMA $1,062,775 (Jul 2026).** Different dates, both correct.

---

## 5. Spatial layers — 28 intersecting, 14 verified empty

### Identity & survey
`volusia_subdivision_plats` (2 rows — duplicate) · `volusia_public_land_survey` (30-16-33; `surveylink` **null**) · `volusia_parcels_govt_source` · `fl_cadastral_dor_statewide` · `volusia_parcel_centroids`

### Regulatory
| Layer | Value |
|---|---|
| `volusia_zoning` | **PUD · SPRUCE CREEK** |
| `volusia_future_land_use` | **ULI** (Urban Low Intensity) |
| `volusia_impact_fee_zones` · `volusia_tax_districts` · `volusia_advertising` | present |

### Hazard
| Layer | Value |
|---|---|
| `volusia_flood_zones` / `fema_flood_zones` | **Zone X** — not in SFHA |
| `parcel_elevations` | **6.68 m / 21.9 ft** |
| `volusia_wind_speed_zones` | **120 / 130 / 140 / 150 mph** (Cat 1–4) |
| `volusia_hurricane_storm_surge_5ft` | 2 polygons |
| `volusia_emergency_evacuation_zones` | **A and DE** — fan-out, unresolved |
| `volusia_gopher_tortoise_overlay` | **present** — protected species constraint |
| `volusia_sinkhole_incidents` | 2 within 5 mi, **0 on this parcel** |

### Service jurisdictions
`volusia_fire_response_zones` · `volusia_leo_patrol_zones` · `volusia_patrol_zones` · `volusia_solid_waste_zones` · `volusia_hospital_districts` · `volusia_mosquito_district_boundary` · `volusia_school_board_districts`

### Political
`volusia_congress` · `volusia_house_districts` · `volusia_senate_districts` · `volusia_county_council_districts` · `volusia_election_precincts` · `volusia_zip_codes`

### Verified ABSENT (examined, not unqueried)
brownfield areas · coastal high hazard · conservation corridor · environmental core overlay · natural resource management areas · opportunity zones · compliance cases · development projects · county permits · local plans · waterbodies (on-parcel) · interlocal service boundary · city limits · basemap changes

---

## 6. Environmental & climate (precomputed, county-level baseline)

`property_environmental` — retrieved 2026-06-29

| Field | Value |
|---|---|
| AQI annual avg | 46.2 (Good) |
| PM2.5 / ozone | 7.1 µg/m³ / 38.2 ppb |
| Wildfire smoke days | 4/yr |
| Noise (day) | 52.3 dB |
| Light pollution index | 3.8 |
| **Radon zone** | **2** |
| **Sinkhole risk** | **medium** |
| Water utility | Volusia County Water & Sewer, municipal |
| Lead service line risk | low |
| Superfund within 3 km / brownfield within 1 km | 0 / 0 |
| Former agricultural | false |

`property_hazard_risk` — retrieved 2026-06-29

| Field | Value |
|---|---|
| Wind design speed / zone | 130 mph / Zone II (FBC 7th Ed) |
| Prevailing wind | SE, avg 12.1 mph, gust 58 mph |
| Solar | 5.42 kWh/m²/day, 5.42 peak hrs (NREL PVWatts v8) |
| Temp / precip annual | 72.5 °F / 51.2 in (NOAA 1991–2020 Normals) |
| Hurricane direct hits | 5, last Cat 3 (NOAA NHC 1950–2024) |
| Lightning density | 11.2 flashes/km²/yr (Vaisala NLDN) |
| Extreme heat days | 95/yr |
| Wildfire risk | low-moderate (FDOF 2023) |
| Flood events (area, 10 yr) | 14 |

**Explicit caveat carried in the source table:** *"County-level baseline. Parcel-level FEMA flood zone, elevation, and coastal wind speed update pending geocoding."* — `fema_flood_zone` and `ground_elevation_ft` are **null here**; the report's Zone X and 21.9 ft come from the spatial join and `parcel_elevations`, not this table.

---

## 7. Demographics

`census_block_groups` + `census_acs_data`, BG 121270832102 — population 1,646 · median household income $91,190 · housing units 826.

---

## 8. Clerk official records

`volusia_official_records_private` — **0 hits** for Lot 189.

**Verified as a real zero:** `legal_description` populated on 865,725 of 1,267,929 rows; 963 mention Spruce Creek; format carries lot numbers (`LT 345 SPRUCE CREEK SUB UN II C`).

**Scope limit:** covers JUDGMENT/ORDER, LIEN, LIS PENDENS, RESTRICTIONS only, 2015→2026. **Says nothing about deeds or mortgages.**

---

## 9. DEFECTS FOUND

### 9.1 In the built report (11 Jul 2026 — pre-dates CAMA load)

| Section | Report | Actual | Gap |
|---|---|---|---|
| Owner | 1 | **2** | **1 owner dropped** |
| Sales | "1 ON RECORD" | **2** | 1 missing |
| Permits | "4 ON RECORD" | **5** | **open Jun-2026 permit missing** |
| Legal | "PER OR 25" | "PER OR 2539 PG 0485" | truncated |

Cause: read the flattened `volusia_parcel_centroids` (single 12-char `owner`), not `volusia_cama_*`.

### 9.2 `in_flight_path = false` — materially wrong

`property_environmental` records `airport_distance_m` **null** and `in_flight_path` **false**.

Measured: **nearest runway 310 m · two runways within 1 km · airport 752 m.**

This is a house **with an aircraft hangar in a residential airpark**. The field was never computed, and a null is being rendered as a negative assertion. **Absence presented as a finding** — the exact failure the withhold rule exists to prevent.

### 9.3 Duplicate plat records

`volusia_subdivision_plats` returns 2 rows for subnum 633001 — same map book/page, different name spelling, only one carrying `platted_date` and `lots`.

### 9.4 Evacuation zone fan-out

Two zones (A, DE) on one parcel. No resolution rule exists.

---

## 10. GAPS — the land itself

The land is the thinnest layer in the database.

| Layer | Status |
|---|---|
| **Soils / drainage** | Orange & Seminole only — **no Volusia** *(correctly disclosed in the report)* |
| **Wetlands (on-parcel)** | Orange, Seminole, Marion only — **no Volusia** |
| **Geology / surficial deposits** | **none anywhere** |
| **Aquifer / recharge / springshed** | **none anywhere** |
| **Watershed / drainage basin** | Lee County only |
| **Land cover / vegetation** | Pasco only |
| **Historical land use (pre-1981)** | **none** |
| **Contours / topography** | single elevation point per parcel only |
| **Original government survey** | `surveylink` **null** for this section |

**All of these are FGDL layers** — UF GeoPlan, 480+ layers, and the only tier in the stack not downstream of county tax data. Queued, not pulled.

---

## 11. Source inventory — 24 datasets

**County CAMA (relational, weekly, as-of 2026-07-20):** `volusia_cama_parcel` · `_owner` · `_legal` · `_sales` · `_permits` · `_res_area` · `_exemptions` · `_situs`

**County GIS:** `volusia_parcels_govt_source` · `volusia_subdivision_plats` · `volusia_public_land_survey` · `volusia_zoning` · `volusia_future_land_use` · `volusia_flood_zones` · `volusia_wind_speed_zones` · `volusia_emergency_evacuation_zones` · `volusia_hurricane_storm_surge_5ft` · `volusia_gopher_tortoise_overlay` · `volusia_communities` · `volusia_sinkhole_incidents` · `volusia_airports` · `volusia_runway_lines` · service/political districts (13 layers)

**State:** `volusia_nal_dor_source` (DOR roll, 1 Jan 2025) · `fl_cadastral_dor_statewide`

**Federal:** `fema_flood_zones` · `parcel_elevations` · `census_block_groups` · `census_acs_data` · `hydrology_waterbodies`

**Clerk:** `volusia_official_records_private`

**Product (precomputed 2026-06-29):** `properties` · `property_hazard_risk` · `property_environmental` · `amenity_features`

---

## 12. Provenance summary — what to cite per field

| Field group | Authority | Vintage |
|---|---|---|
| Plat, lot, subdivision | Clerk (recorded plat) via county GIS | 5 Oct 1981 |
| Owner, RRR type, sales, permits | **County CAMA** | 20 Jul 2026 |
| Geometry, land area | County GIS | weekly |
| Just value, exemptions, use code | **State DOR** | **1 Jan 2025** |
| Flood zone | County + FEMA | current |
| Elevation | USGS/state LiDAR | — |
| Climate, solar, hurricane, lightning | NOAA / NREL / Vaisala / FDOF — **county-level** | 2026-06-29 |
| Air, radon, water, noise | EPA / FDOH — **county-level** | 2026-06-29 |
| Demographics | US Census ACS | block group |
| Encumbrances | Clerk official records | 2015→2026, 4 doc types |
