# DoP System Index

**Built 2026-08-11 from the live database.** This is a lookup, not a narrative. If a question below has an answer here, do not search for it — read it.

**Regenerate any section**: every table in this document has the query that produced it. Run the query rather than trusting the number if more than a week has passed.

---

## 0. The four audit artifacts — query these first

| artifact | what it answers | query |
|---|---|---|
| `dataset_audit` (view) | Is a table registered / served / spatial? What's its verdict? | `select * from dataset_audit where table_name='x'` |
| `dataset_content_audit` | Geometry validity, nulls, max vertices per served layer | `select * from dataset_content_audit order by geom_invalid desc` |
| `column_profile_audit` | All-null / single-value / nearly-empty columns | `select * from column_profile_audit where table_name='x'` |
| `audit_layer_content(text)` | Re-audit one layer's geometry | `select audit_layer_content('nfhl_flood_zones')` |
| `profile_table_columns(text)` | Re-profile one table's columns | `select profile_table_columns('rp_property_info')` |

**`column_profile_audit` is a SCREEN, not a verdict.** Two of two flagged candidates were clean on inspection (Flagler zoning, Okaloosa flood). Every row is a question, never a defect.

---

## 1. Database shape — as of 2026-08-11

```sql
select verdict, count(*), sum(est_rows) from dataset_audit group by verdict;
```

| verdict | tables | rows | size |
|---|---|---|---|
| DORMANT_UNREGISTERED | 1,602 | 65.7M | 50.7 GB |
| OK | 334 | 14.9M | 14.8 GB |
| SERVED_UNREGISTERED | 170 | 8.5M | 4.2 GB |
| EMPTY | 56 | 0 | — |
| SRID_ZERO | 4 | 10.8M | 16.7 GB |
| **total** | **2,167** | **~99.9M** | **~86 GB** |

- Registry: **292 active entries** against **2,063 populated tables**
- `layer_resolution`: **318 rows, 302 with a table, ALL flagged `verified`**
- `concept_registry`: **26 concepts**
- Spatial layers (`geometry_columns`): **1,952**

---

## 2. County → ArcGIS host map

**This is the lookup that makes source recovery mechanical.** 168 of 172 unregistered served layers have a registered sibling here.

```sql
select split_part(table_name,'_',1) prefix,
       string_agg(distinct substring(source_url from 'https?://[^/]+'),' | ') hosts
from data_source_registry where active and source_url<>'' group by 1;
```

| county | host |
|---|---|
| alachua | services1.arcgis.com |
| baker | services6.arcgis.com |
| bay | gis.baycountyfl.gov |
| brevard | gis.brevardfl.gov · services2.arcgis.com |
| broward | services.arcgis.com |
| calhoun | gis.arpc.org · hazards.fema.gov |
| charlotte | agis3.charlottecountyfl.gov |
| citrus | services7.arcgis.com |
| clay | maps.claycountygov.com |
| collier | services2.arcgis.com |
| columbia | gis.columbiacountyfla.com |
| desoto | services3.arcgis.com |
| dixie · gilchrist · lafayette · levy · madison · suwannee · taylor · union | **gis.srwmd.org** (Suwannee River WMD consolidator) |
| duval | maps.coj.net |
| escambia | gismaps.myescambia.com |
| flagler | services3.arcgis.com |
| franklin · gadsden · gulf · jackson · liberty | **gis.arpc.org** (Apalachee RPC consolidator) |
| glades | services6.arcgis.com |
| hamilton | services6.arcgis.com |
| hardee | gis.hardeecounty.net |
| hendry | services7.arcgis.com |
| hernando | services2.arcgis.com |
| highlands | services2.arcgis.com |
| hillsborough | services.arcgis.com |
| indianriver | gisportal.ircgov.com |
| jefferson | services5.arcgis.com |
| lake | gis.lakecountyfl.gov |
| lee | services2.arcgis.com |
| leon | intervector.leoncountyfl.gov |
| manatee | services1.arcgis.com |
| marion | services1.arcgis.com |
| martin | geoweb.martin.fl.us · pamartinfl.gov |
| miamidade | gisweb.miamidade.gov |
| monroe | services.arcgis.com |
| nassau | maps.ncpafl.com |
| okaloosa | okgis.myokaloosa.com |
| okeechobee | services3/7.arcgis.com |
| orange | ocgis4.ocfl.net |
| osceola | services6.arcgis.com |
| palmbeach | maps.co.palm-beach.fl.us |
| pasco | services6.arcgis.com |
| pinellas | services.arcgis.com |
| polk | gis.polk-county.net |
| putnam | pamap.putnam-fl.gov |
| santarosa | services.arcgis.com |
| sarasota | ags3.scgov.net |
| seminole | map.scpafl.org |
| sjc (St Johns) | services1.arcgis.com |
| stlucie | slcgis.stlucieco.gov |
| sumter | gis.sumtercountyfl.gov · swfwmd |
| volusia | maps5.vcgov.org |
| wakulla | services9.arcgis.com |
| walton | services1.arcgis.com |

**Three regional consolidators cover 14 counties**: SRWMD (8), ARPC (5), SWFWMD (Sumter).

**Municipal prefixes exist and break county lookups**: `daytonabeach_city_*`, `ormondbeach_city_*`, `lake_fruitlandpark_*`, `charlotte_punta_gorda_*`.

---

## 3. Statewide / federal sources — the answers

| what | source |
|---|---|
| **Sinkhole incidents** | `ca.dep.state.fl.us/arcgis/rest/services/OpenData/FGS_SUBSIDENCE/MapServer/0` — 4,417 rows. **The 59 `*_sinkhole_incidents` tables are a county SPLIT of this.** Not unsourced. |
| **Flood (federal)** | `hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer/28` — filter `DFIRM_ID LIKE '<fips>%'`. SR **4269**, MaxRecordCount 2000. |
| **NHD hydrography** | `ca.dep.state.fl.us/arcgis/rest/services/OpenData/NHD/MapServer` — layer **4** Flowline (480,792), **5** Area (5,776). EPSG **6439**, MaxRecordCount **1000**. |
| **NRHP historic** | `mapservices.nps.gov/arcgis/rest/services/cultural_resources/nrhp_locations/MapServer` — layer 1 polygons (306), 0 points (1,440). Filter `State='FLORIDA'` (full name). Page cap **250**. |
| **Coastal / CCCL** | `ca.dep.state.fl.us/arcgis/rest/services/OpenData/COASTAL_ENV_PERM/MapServer` — 12 layers, 219,132 features. |
| **Septic** | `ca.dep.state.fl.us/arcgis/rest/services/OpenData/SEPTIC_SYSTEMS/MapServer/0` |
| **Volusia CAMA** | `vcpa.vcgov.org/files/database/CAMA_DATA_EXPORT.zip` · layout `/files/download/newLayout.pdf` · **weekly** |
| **Pinellas CAMA** | POST `www.pcpao.gov/dal/databasefile/downloadDatabaseFile` with `hdn_tbl_name=<TABLE>&hdn_ftype=csv` — **requires a browser User-Agent** (403 otherwise). Nightly 02:00–03:30. |
| **Statewide cadastral** | `publicfiles.dep.state.fl.us/otis/gis/data/Cadastral_Statewide.zip` — 10,831,924 parcels, **EPSG 6439** |
| **All 67 PA websites** | `.../Florida_Statewide_Cadastral/FeatureServer/0/metadata?f=html` |
| FUDS (defense sites) | `services7.arcgis.com/n1YM8pTrFmm7L4hs/arcgis/rest/services/fuds/FeatureServer` — **already loaded**, 1,273 rows |
| DOR tax roll | SharePoint PTO Data Library — NAL 165 fields, CSV with header |
| FGDL | `fgdl.org/explore-data/` — 480+ layers |

---

## 4. Data facts you keep re-deriving

| fact | value |
|---|---|
| Florida parcels | **10,739,881** (67 counties) |
| `parcels_staging` geometry validity | **0 invalid, 0 null** — verified full scan 2026-08-11, 138 s |
| `fl_cadastral_dor_statewide` | 10,831,924 rows, 16.7 GB, **SRID 0**, 122 cols vs staging's 44 — **DO NOT DROP** (item 16) |
| `parcel_elevations` | 10,739,881 rows, 100% populated, −9.16 m to 104.19 m — **NO PROVENANCE** |
| Volusia CAMA | 306,889 parcels · 992,313 permits · 15,801 marine improvements · **41.5% multi-owner** |
| Pinellas CAMA | 437,568 parcels · 1,654,923 permits · 681,923 owners (1.56/parcel) · 16,336,708 rows total |
| Relational CAMA depth | Volusia + Pinellas = 744,457 = **6.9% of Florida** (was 2.86%) |
| Flood (new) | `nfhl_flood_zones` 175,728 rows / 14 counties, **0 invalid after repair** |
| NHD | flowline 480,792 (29.2% synthetic: FTYPE 558+334) · area 5,776 |
| NRHP | 1,440 points · 306 polygons · **only 5 districts have a real boundary** |
| Sinkhole | 4,417 incidents / 59 counties · depth 68% · date 96% |
| Pre-1978 residential (lead paint) | 2,323,819 |
| Pre-1981 (asbestos era) | 2,949,619 |
| Built since 2019 (s.95.11 window) | 813,971 |
| Florida licensed agents (DBPR) | 312,291 |

---

## 5. Known traps — per source

| source | trap |
|---|---|
| **FDEP (all)** | EPSG **6439** (metres), not 4326. `outSR=4326` mandatory or geometry silently misplaces. |
| FEMA NFHL | `-9999` in BFE/DEPTH = **not determined**, not an elevation. Single features up to **14.7 MB / 594,198 vertices**; batch requests 500 at scale. Empty body ≠ zero — retry. |
| NHD | FTYPE **558 ArtificialPath** + **334 Connector** = 140,392 synthetic (29.2%). Never a watercourse. `ELEVATION` column is **0/5,776 populated** — dropped. |
| NRHP | 298 of 306 polygons **derived from a point** (`MAP_METHOD`). Only 5 digitized districts support containment. `NRIS_Refnum` **is not unique** (7 repeats, two different causes). |
| PCPAO | JSON exports have an **invalid trailing comma**. Excel/XML formats go stale independently — **take CSV**. `RP_PROPERTY_INFO` has **`YEAR_BUILT` twice** in the real header. `PERMIT_YEAR` ≠ `ISSUE_DT`. |
| PCPAO flags | `SEAWALL`, `CONTAMINATION_YN`, `SUBSIDENCE_YN`, `ELEVATION_CERT`, `WATERFRONT_YN`, `DLHL_YN` are **presence-only**. Blank ≠ negative. `ELEVATION_CERT` is **not an elevation**. |
| Coastal CCCL | Carries **person names** (`FIRST_VIOLATOR_FULLNAME`, `FIRST_OWNER_FULLNAME`). Load, never render on consumer tier. Located by **monument, not parcel**. |
| Santa Rosa zoning | Served **rezoning petition numbers** where district codes belonged. |
| School board layers | Contained **member names**, not attendance zones. |
| NWI wetlands | Exclude `Estuarine and Marine Deepwater` and `Lake` — including them reports 60% of Florida as wetland. |
| DOR NAL | 1 January snapshot, ~19 months stale at worst. One `OWN_NAME` — **co-owners flattened out**. |
| Manatee | 97,323 duplicate parcel keys (29%) |
| Hardee | `parcel_id` contains an **HTML anchor tag** |
| St Johns | 26.7% duplicate `parcel_id` — **genuine fragments, aggregate never dedupe**. One parcel has 1,215. |
| Sarasota | `account` (lot) vs `id` (interest) return **different entities** — 19% stacked |

---

## 6. Open defects — ranked

| # | defect | scale |
|---|---|---|
| 1 | **Per-call `ST_MakeValid`/`ST_IsValid` in 6 served functions** | 97.5% of a 19,183 ms flood lookup. `resolve_parcel_geometry` is called by every concept. |
| 2 | 138 of 279 served spatial layers hold **invalid geometry** | 2,234 features |
| 3 | `fdep_stcm_tanks` — **1,905 null geometries** of 74,262 | contamination layer, structurally invisible |
| 4 | `verified` asserts **3 claims through 1 flag** | false for 57% (source) and 49.5% (geometry) |
| 5 | Registry has no **`derived_from`** | makes 59 sinkhole splits look unsourced |
| 6 | `fl_cadastral_dor_statewide` **SRID 0** | 10.8M rows unusable |
| 7 | ~32 rendered fields with **no fact-index coverage** | §1 identity block, tax, economic zones, elevation |
| 8 | NRHP duplicate pair (`nrhp_points` vs `nrhp_points_fl`) | caused by two **fabricated** source URLs |
| 9 | `lands_available_for_taxes` registered **3× , all empty** | |

---

## 7. Standing invariants

- `SET statement_timeout = 0` — the pooler default is shorter
- `outSR=4326` on every ArcGIS pull
- `returnIdsOnly` set-diff is the completeness check, **never the loop tally**
- **Abort on zero** — an empty return is an ERROR, never "no rows"
- A count on an exact multiple of the page size is a **truncation suspect**
- Validate geometry **once at ingest**, never per call
- All figures reported to Murphy in **US units**; canonical metric stays in the data
- **Self-consistent checks lie** — verify against live data, never stored summaries
- A guard that cannot fire is not free: it costs, and it manufactures confidence

---

## 8. Method failures on record (2026-08-11)

Five wrong statements in one morning, all one cause — reading an artifact instead of the thing itself:

1. "FUDS never pulled" — holds 1,273 rows since 25 July. Read `last_successful_pull_date IS NULL`.
2. "Six Volusia layers never pulled" — all populated, `volusia_flood_zones` at 11,061.
3. "A fourth coverage state is needed" — already in `restriction_authority` and spec §0.1.
4. "Sinkhole is 100% unregistered" — it is 100% *derived from a registered source*.
5. "Vertex counts are the latency risk" — the validity guard was 97.5% of it.

**The counts were real every time. The interpretation was wrong.** Query the thing, not the label on the thing.
