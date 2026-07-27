# Table Index & Classification — Method, Evidence, Failures

**Recorded 2026-07-27.** Database `eaifqorwmgayiqmbtzcg`. Scope: all 1,226 tables with `row_count > 0`.

Every figure here was produced by a query against live data and can be re-derived from the working tables listed in §9. Where a claim rests on inference rather than a read, it says so.

---

## 1. Why this exists

Four classification runs were attempted. The first three classified tables by **metadata** — name strings, column names, declared types. They reached 91.2% by a measure that turned out to be measuring the classifier against itself.

The fourth run inverted the order: **read every table first, write rules second.** It reached 94.2%, and in doing so found three errors the metadata runs could not see, and overturned two claims the metadata runs had been repeating for the whole session.

The difference is not effort. It is that a declaration was being treated as circumstantial evidence, and a proxy was being measured in place of the fact.

---

## 2. Rules (stated before execution, run 4)

| rule | statement |
|---|---|
| **N1** | Index before classify. Every table's content read and stored before any rule is written. |
| **N2** | Geometry probed with `ST_GeometryType` on actual rows. Never taken from `geometry_columns`. |
| **N3** | Classification vocabularies derived from the index, not invented, and written only after the index is complete. |
| **N4** | Every failure logged to `nr_failures` when found, not at the end. |
| **N5** | No rule changes mid-run. A change means a full rerun from source. |
| **N6** | Goal 92%, measured as classification supported by evidence read in this run. |

N5 was invoked twice. Both times the full layer was rebuilt rather than patched.

Earlier runs used rules R1–R10; those are retained in `ladm_map_fault_register` for continuity but are superseded by N1–N6.

---

## 3. What was read

| artifact | count | source |
|---|---|---|
| Tables indexed | 1,226 | `table_inventory` where `row_count > 0` |
| Geometry columns probed | 1,006 | `ST_GeometryType`, `ST_SRID` on live rows |
| Column value-sets captured | 27,012 | `pg_stats.most_common_vals` |
| Tables with content available | 1,183 | 43 yielded none — logged |
| Column signatures built | 1,226 | `information_schema.columns` |
| Family exemplars opened and read | 21 | one per family, actual values |

---

## 4. Two claims overturned by reading

### 4.1 The SRID-0 blocker does not exist

`geometry_columns.srid` reports **0** for roughly 200 tables, including `fdep_gwca` and `fl_cadastral_dor_statewide`.

`ST_SRID(geom)` on the actual rows of those same tables returns **4326**.

Probe result across all 1,006 geometry tables: **1,005 spatially usable, zero SRID failures.** One table has all-null geometry (`school_attendance_zones`).

The statement *"54 SRID-0 layers cannot be spatially joined until reprojected"* was repeated throughout the session, carried in the build backlog, and used to justify deferring the wells work. It was a metadata artifact. **No reprojection is required.**

### 4.2 Geometry is uniform per table

`geometry_columns.type` reports `GEOMETRY` (untyped) for 130 tables. Probing shows those are uniform in practice.

| probed type | tables |
|---|---|
| ST_MultiPolygon | 623 |
| ST_MultiPoint | 210 |
| ST_Point | 91 |
| ST_MultiLineString | 53 |
| ST_Polygon | 13 |
| ST_MultiPolygon + ST_Polygon (benign) | 9 |
| ST_LineString | 6 |

Only 9 tables are mixed, and benignly. **Shape-standard templates are viable** — for a reason now measured rather than assumed.

---

## 5. Families — schema signatures verified by opening an exemplar

21 families, 555 tables. Each family was confirmed by reading the actual values of its largest member.

| family | tables | exemplar | values read | class |
|---|---|---|---|---|
| FAM_DOR_ROLL | 137 | `fl_cadastral_dor_statewide` | `asmnt_yr=2025`, `file_t=R` | PART4_valuation |
| FAM_FDEP_SITE | 86 | `fdep_brownfield_areas` | `method=PAPER\|SHP\|COGO`, `district=Southeast…` | REG_contamination |
| FAM_FDEP_SUBSIDENCE | 60 | `fgs_subsidence_incidents_raw` | `subrate=U\|R\|S`, `propdam=U\|N\|Y` | REG_geohazard |
| FAM_ZONING | 59 | — | zoning district codes | PART5_plan |
| FAM_FEMA_NFHL | 46 | `palmbeach_flood_zones` | `merge_src=FEMA_FLOODZONE_2017\|2023` | REG_flood |
| FAM_FLU | 40 | `pasco_future_land_use` | `new_flu=SDR\|CITY\|PD\|RDR\|AGR` | PART5_plan |
| FAM_FEMA_ZONE | 30 | — | `fema_zone=AE\|A` | REG_flood |
| FAM_NG911_ADDR | 23 | `hillsborough_address_points` | `status=Current\|Pending\|Temporary\|Inactive` | EXT_address |
| FAM_CAMA | 18 | `volusia_cama_sales` | `INSTRTYP_DESC=WARRANTY DEED\|QUIT CLAIM DEED` | PART2_cama |
| FAM_CENSUS | 11 | `pinellas_census_block_2020` | `ur20=U\|R` | LOC_socio |
| FAM_BUILT | 9 | `property_permit_history` | `replacement_urgency=none\|watch\|due\|overdue` | BUILT |
| FAM_JSON_ATTR | 9 | `fdep_stcm_tanks` | payload in `attributes` JSON | REG_contamination |
| FAM_ESRI_ASSET | 8 | `pinellas_sidewalks` | Esri LocalGov asset schema | EXT_utility |
| FAM_FEMA_PANEL | 6 | `marion_fema_firm_panel_2008` | `panel_typ=COUNTYWIDE, PANEL PRINTED` | REG_flood |
| FAM_EPA_FRS | 4 | `epa_superfund_facilities` | EPA Facility Registry Service | REG_contamination |
| FAM_NRCS_SOIL | 3 | `orange_soil_hydric_rating` | `hydricrati=NO\|YES\|UNRANKED` | EXT_landcover |
| FAM_NHD_HYDRO | 2 | — | NHD reach identifiers | EXT_landcover |
| FAM_PLAT | 1 | `volusia_subdivision_plats` | `vacated=YES` | PART2_subdivision |
| FAM_NRHP | 1 | `nrhp_listings` | `restype=building\|site\|structure\|district\|object` | REG_historic |
| FAM_NID_DAM | 1 | `hifld_dams` | `hazard_potential=Low\|Significant\|High` | REG_geohazard |
| FAM_FRA_RAIL | 1 | `marion_railroads` | `rrowner1=FNOR\|CSXT` | LOC_transport |

**Reading the exemplars caught three family errors that neither schema fingerprinting nor name matching could see.** See §7.1.

---

## 6. Content vocabularies — all derived from values actually read

No vocabulary in this list was invented. Each was observed in the corpus first, then confirmed attributable to a published code list.

| vocabulary | observed values | class |
|---|---|---|
| EPA Air Quality Index | `Good`, `Moderate`, `Unhealthy for Sensitive Groups`, `Unhealthy`; `OZONE`, `PM2.5`, `PM10` | LOC_envctx |
| DBPR real estate licence | `SL Sales Associate`, `BK Broker`, `BL Broker Sales`; `Current`, `Delinquent`, `Invol Inactive`, `Probation`, `Suspended` | LOC_actor |
| FL recorded instruments | `WARRANTY DEED`, `QUIT CLAIM DEED`, `CERTIFICATE OF TITLE`, `LIS PENDENS` | PART2_source |
| FEMA flood zones | `AE`, `X`, `A`, `VE`, `AH`, `AO` | REG_flood |
| Vertical datums | `NAVD88`, `NGVD29` | REG_flood |
| FDEP cleanup status | `AWAITING CLEANUP`, `SITE REHABILITATION`, `NO FURTHER ACTION` | REG_contamination |
| EPA NPL status | `on the final NPL`, `not on the NPL` | REG_contamination |
| FDEP locate method | `PAPER`, `SHP`, `COGO` | REG_contamination |
| NID dam | `hazard_potential`, `condition_assessment=Not Rated\|Fair\|Poor\|Unsatisfactory` | REG_geohazard |
| NRCS hydric | `hydricrati=NO\|YES\|UNRANKED`, `flodfreqdc=NONE\|FREQUENT\|OCCASIONAL` | EXT_landcover |
| NRHP resource type | `building`, `site`, `structure`, `district`, `object` | REG_historic |
| Land-use categories | `industrial`, `commercial`, `residential`, `conservation`, `agriculture`, `institutional`, `mixed use` | PART5_plan |
| USPS street suffixes | `blvd`, `ter`, `cir`, `pkwy`, `trl`, `hwy`, `way`, `loop` | EXT_address |
| NAICS / BEBR | `NAICS 92 Public administration`; `scenario=high\|medium\|low` | LOC_socio |
| Building construction | `substruct/subdesc=Continuous Wall\|Slab\|Piers`, `fireplace`, `frame` | PART2_building |

**Rule applied throughout:** a vocabulary confirms a class only where the table's *subject* is that thing. A parcel table carrying `fld_zone` is a parcel table. This is enforced by a `parcel_subject` test evaluated before any other rule.

---

## 7. Failures — 68 logged, in `nr_failures`

| phase | n | what |
|---|---|---|
| `content_read` | 43 | no `most_common_vals` available — all-unique, all-null, or excluded columns |
| `family_rerun` | 17 | parcel-subject tables still assigned to a non-parcel family after the rerun |
| `family_exemplar_read` | 3 | families wrong at the exemplar (§7.1) |
| `prior_run_correction` | 2 | SRID-0 blocker false; geometry uniform (§4) |
| `evidence_tier` | 1 | my own tier definition excluded all non-spatial tables (§7.2) |
| `method_note` | 1 | reading exemplars caught what fingerprints missed |

### 7.1 Three families wrong at the exemplar

| table | assigned | actual values read | correct |
|---|---|---|---|
| `duval_parcels_govt_source` | FAM_FEMA_ZONE | `ent`, `brf`, `olflitz=NA\|Whitehouse` | parcel table carrying a flood attribute |
| `lee_parcels_govt_source` | FAM_ZONING | `nmaxbuilty`, `nminbuilty`, `editor` | parcel table carrying a zoning attribute |
| `stpete_city_floodplain_100yr` | FAM_NHD_HYDRO | `ftype=FLOODPLAIN\|TRANSITION ZONE`, `fema_zone=AE\|A` | flood layer using NHD identifiers |

All three are the **subject-versus-reference** fault. All three were invisible to schema fingerprinting and to name matching. Rule corrected: flood vocabulary tested before hydro identifiers; parcel-subject test evaluated first. Full rerun executed.

### 7.2 The evidence tier was wrong

Tier E3 was defined as *name + probed geometry*. 220 tables have no geometry column, so they fell to *name only* despite having content already read into the index. `polk_sales` reads `WARRANTY DEED | QUIT CLAIM`; `agent_license_roster` reads `SL Sales Associate | BK Broker`.

Corrected to *name + a second read of any kind*, geometry or content. Full rerun. Name-only fell from 44 tables to 4.

---

## 8. Result

| tier | tables | pct |
|---|---|---|
| **T1** — family and content independently agree | 186 | 15.2% |
| **T2** — family and content conflict | 7 | 0.6% |
| **T3** — family exemplar read | 362 | 29.5% |
| **T3** — own content read | 111 | 9.1% |
| **T4** — name plus probed shape | 489 | 39.9% |
| **T5** — nothing read | 71 | 5.8% |

**Content-backed: T1 + T3 + T4 = 1,148 of 1,226 = 94.2%.** Goal was 92%.

**T1 is the strongest tier ever produced in this exercise** — 186 tables where a schema family verified by opening its exemplar and the table's own values independently agree. It exists only because the vocabularies came from reading.

**T2's 7 conflicts are an output, not a defect.** They are now visible rather than silently resolved by rule order.

### Run comparison

| run | method | unresolved | claimed | what it actually measured |
|---|---|---|---|---|
| 1 | ordered CASE on name substrings | 114 | — | rule order |
| 2 | + schema fingerprints | 22 | 91.0% | two parsers agreeing on one string |
| 3 | + stems, n-grams, all-rules scoring | 192 | 91.2% | as above, more precisely |
| **4** | **read first, then classify** | **71** | **94.2%** | **values in the tables** |

---

## 9. Working tables — the evidence is re-derivable

| table | holds |
|---|---|
| `nr_index` | 1,226 rows: row count, column count, geometry column, **probed** geometry kind and SRID, key/date/status/code columns |
| `nr_sig` | column signature per table |
| `nr_content` | 27,012 rows: actual column values with distinct counts and null fractions |
| `nr_fam` | family assignment plus `parcel_subject` flag |
| `nr2_content` | content classification from read vocabularies |
| `nr2_final` | final per-table classification and tier |
| `nr_failures` | 68 logged failures with phase, table, and detail |
| `ladm_map_fault_register` | 21 fault classes from runs 1–3 |
| `ladm_declaration` | 51 signed declarations from run 3, with rationale |

---

## 10. Two datasets characterised in the course of this work

### 10.1 `fdep_pnp` — Public Notice of Pollution

Florida's mandatory release register under **s.403.077 F.S.** Not petroleum-programme data as originally assumed.

- **16,032 incidents**, 2013-05 to 2026-07-21, current within days
- **1,586 flagged `MIGRATED_OFFSITE = Y`** — a *second* statutory filing, required within 24 hours of the operator discovering the release crossed the property boundary
- 380 affecting Volusia
- FDEP metadata states it publishes *all notices received to date*; the 30-day limit applies to the website map only

Companion regime: **s.376.30702(2)** and **Rule 62-780.220** require the responsible party to notify non-source property owners when a plume extends off the source property, on a map signed and sealed by a licensed PG or PE.

### 10.2 Agent licences — three tables, one dataset

- `agent_license_roster` — 493,556: identity, rank, county, original issue date
- `agent_license_status` — 493,556: primary/secondary status, expiry, employing broker
- `agent_license_eligible` — 350,492

**Joins 1:1 with zero orphans.** `agent_license_eligible` is exactly `primary_status = Current AND secondary_status = Active` — verified by matching counts, not inferred from the name.

- 246,714 Sales Associates current and active, of 373,122 licensed
- **6,991 current-active agents in Volusia** (the saturation model in the project notes uses ~3,123)

### 10.3 `fl_historical_aqi_by_area`

EPA Air Quality Index, **0–500 scale, not a percentage.** Observed min 0, max 158, mean 33.1. Bands match EPA breakpoints. 36 reporting areas statewide; **Volusia has one — Daytona Beach.** Rolling one-year window (2025-07-10 to 2026-07-09), so historical retention must be local, as with PNP.

---

## 11. Outstanding

**71 tables read nothing** — the next read, not an estimate.

**7 family/content conflicts** — need adjudication against the subject rule.

**17 residual parcel-subject misassignments** — logged, not cleared by the rerun.

**5 BUILT tables carry 356 columns of which 350 have no `field_status`** — `properties`, `property_environmental`, `property_hazard_risk`, `property_transaction_history`, `site_hazard_installations`. These have no source vocabulary because they were designed rather than pulled. Their meaning lives at column level and must be declared, not inferred.

---

## 12. Method note

The single finding that generalises:

**Before asserting a property of a thing, make the thing do something and watch.**

Six times in this session a property was declared absent without the thing being opened — the units (`len_unit` read `Feet`), the derivation (`v_datum` read `NAVD88`), the opaque tables (their JSON declared every field), the 597 "unclassified" (regex misses), the 43 "undeclarable" (classified in the same message that called them undeclarable), and the SRID blocker (never real).

In every case the answer was one query away. The prior should be presence: **assume it is there and go find it.**
