# Data Tree — Full Definition

**Recorded 2026-07-27.** 1,226 populated tables. Every figure derived by query; nothing inferred.

The live definition is `nr_master` in Supabase — one row per table, joinable, re-derivable. This document is the readable form plus the defects the survey exposed.

---

## 1. What was measured, per table

| property | source | method |
|---|---|---|
| Row count | `table_inventory` | stored |
| Geometry type | **probed** | `ST_GeometryType` on live rows |
| SRID | **probed** | `ST_SRID` on live rows |
| **Own keys** | `pg_stats.n_distinct = -1` | every column unique across rows |
| **Join keys** | `information_schema` | columns matching the key vocabulary |
| **Cardinality** | counted | distinct key values vs total rows |
| Constant columns | `pg_stats.n_distinct = 1` | one value across all rows |
| Class | `nr2_final` / `ladm_declaration` | content-verified where possible |

**A table has two kinds of key and they are not the same thing.** Its *own key* identifies its rows. Its *join key* links it to something else. A table can have several of each, and 919 of 1,226 have more than one own key.

---

## 2. The tree by class

| class | tables | rows | no own key | >1 own key | >1 parcel key | no geometry | one-to-many |
|---|---|---|---|---|---|---|---|
| **REG** — restrictions | 305 | 2,353,485 | 7 | 262 | 1 | 11 | 1 |
| **PART5** — spatial plan | 215 | 5,654,300 | 1 | 164 | 19 | 2 | 6 |
| **LOC** — location context | 203 | 2,045,302 | 18 | 140 | 2 | 12 | 3 |
| **EXT** — external stereotype | 156 | 12,361,015 | 3 | 136 | 4 | 1 | 4 |
| **PART4** — valuation | 150 | 24,423,347 | 29 | 78 | **74** | 138 | 10 |
| **PART2** — land registration | 129 | 44,988,848 | 18 | 90 | 20 | 29 | 11 |
| unclassified | 41 | 2,088,905 | 0 | 31 | 1 | 1 | 2 |
| SYSTEM | 18 | 291,313 | 4 | 11 | 2 | 17 | 1 |
| **BUILT** — the product | 9 | 2,538,158 | 0 | 7 | 3 | 9 | 0 |

**PART2 holds 45 million rows in 129 tables** — a third of everything, in a tenth of the tables.
**PART4 carries multiple parcel keys on 74 of 150 tables** — the DOR roll ships both `PARCEL_ID` and `ALT_KEY`, which is the statewide crosswalk.
**REG is 305 tables and only 2.3 million rows** — restrictions are many small layers, not few large ones.

---

## 3. Join topology — how each table reaches a parcel

| route | tables | rows | mechanism |
|---|---|---|---|
| J1 parcel key + geometry | 138 | 38,635,579 | key join, geometry available for verification |
| J2 parcel key only | 170 | 38,501,445 | key join, no spatial fallback |
| J2b `property_id` FK | 3 | 631,440 | internal FK to `properties.id` |
| **J3 containment** | **544** | 6,110,445 | polygon contains parcel |
| J4 proximity | 265 | 8,242,543 | point within distance |
| J5 frontage | 57 | 976,882 | line adjacent to parcel |
| J6–J9 area key | 26 | 2,611,598 | county / census / zip / place name |
| J10 no path | 5 | 533,197 | no key, no geometry |
| **J11 broken load** | **2** | 3,369 | one column only |
| J0 system | 16 | 498,175 | internal |

**866 tables join spatially. 311 join by key.** But the 311 hold **77 million rows** against the spatial set's 15 million — few tables, most of the data.

---

## 4. Key vocabulary — 22 names in use

| key name | tables | rows | note |
|---|---|---|---|
| `parcel_id` | 166 | 53,675,492 | **format varies by county** — see §5 |
| `co_no` | 149 | 45,931,113 | DOR county number |
| `alt_key` | 74 | 33,044,024 | DOR roll alternate key |
| `fld_ar_id` | 61 | 423,688 | FEMA flood area id |
| `parcelid` | 36 | 2,791,928 | |
| `site_id` | 36 | 1,142 | FDEP brownfield |
| `altkey` | 30 | 1,866,802 | county CAMA key |
| `folio` | 30 | 6,168,103 | Miami-Dade, Broward |
| `parcelno` | 25 | 22,324,575 | |
| `pid` | 23 | 1,799,570 | |
| `strap` | 20 | 4,461,321 | Lee, Pinellas, Sarasota |
| `parid` | 20 | 7,751,743 | CAMA vendor key |
| `subnum` | 10 | 319,258 | subdivision group key |
| `geoid` | 8 | 14,743 | census |
| `property_id` | 6 | 2,024,413 | internal FK |
| `instrument_number` | 5 | 1,441,948 | recorded document |
| `account` | 5 | 1,039,537 | Charlotte, Sarasota |
| `license_number` | 4 | 1,138,057 | DBPR |
| `fullpid` | 4 | 356,253 | Volusia geographic |
| `dor_parcel_id` | 2 | 380,989 | |
| `cndcmplx` | 1 | 23,191 | **condo complex group key** |
| `block_group` | 1 | 13,239 | |

---

## 5. `parcel_id` is not one key

Same column name, four different formats:

```
properties.parcel_id                  2000058         7  AltKey
properties.dor_parcel_id              372400000020   12  geographic
volusia_cama_owner.PARID              4545948         7  AltKey
volusia_nal_dor_source.ALT_KEY        2948736         7  AltKey
volusia_parcel_centroids.fullpid      473600000020   12  geographic
alachua_nal_dor_source.PARCEL_ID      00002-000-000  13  hyphenated
fl_cadastral_dor_statewide.parcel_id  07702-000-000  13  hyphenated
broward_parcels_govt_source.folio     474135010091   12  folio
sarasota_parcels_govt_source.account  0049020011     10  account
```

**166 tables use `parcel_id` and the value format depends on the county.** A join across counties on that column name is wrong by construction.

**And `properties.dor_parcel_id` is not unique** — 313,578 rows, 309,104 distinct, **4,474 duplicates**. `properties.parcel_id` is unique; `dor_parcel_id` is not. Any join on it fans out.

---

## 6. Broken keys — columns named as keys that hold one value

| table | column | distinct values | rows | source |
|---|---|---|---|---|
| `santarosa_nal_dor_source` | `ALT_KEY` | **1** | 120,501 | DOR |
| `jackson_parcels_govt_source` | `altkey` | **1** | 39,266 | ARPC |
| `franklin_parcels_govt_source` | `altkey` | **1** | 17,780 | ARPC |
| `gulf_parcels_govt_source` | `altkey` | **1** | 17,478 | ARPC |
| `calhoun_parcels_govt_source` | `altkey` | **1** | 10,985 | ARPC |
| `liberty_parcels_govt_source` | `altkey` | **1** | 5,646 | ARPC |
| `hernando_subdivisions` | `alt_key` | 3 | 1,348 | county |
| `baker_future_land_use` | `parcel_id` | 65 | 16,446 | county |
| `flagler_beach_flu` | `parcel_id` | 3 | 342 | city |

**Five of the nine are ARPC-sourced.** The same regional server that returns 265,114 features for a 14,000-parcel county. The `altkey` column came through dead — a join on it returns the whole county as one parcel, silently.

`legal_historical_term` records that `reservation` appears on 70 parcels and `grant` on 10,422 — the same discrimination test applied to keys would have caught all nine of these at load time.

---

## 7. Tables with no own key — 80

These have no unique column. Their identity is composite.

**Every Volusia CAMA table is in this group:** `volusia_cama_owner`, `_sales`, `_permits`, `_exemptions`, `_res_area`, `_res_bldg`, `_comm_area`, `_comm_bldg`, `_condo_bldg`, `_land`, `_misc`, `_nonadvalorem`, `_situs`, `_agland`.

Their real key is **`PARID` + `TAXYR` + line sequence**. A single-column join to any of them returns every year and every line item at once.

That is the direct cause of the report defects in §9.

---

## 8. Cardinality — how many rows each table holds per parcel

**235 of 339 keyed tables are one-to-many — 69%.**

The five largest Volusia CAMA tables:

| table | parcels | rows | **per parcel** |
|---|---|---|---|
| `volusia_cama_sales` | 329,294 | 1,613,504 | **4.90** |
| `volusia_cama_res_area` | 215,188 | 1,012,512 | **4.71** |
| `volusia_cama_permits` | 240,264 | 992,313 | **4.13** |
| `volusia_cama_exemptions` | 345,215 | 714,792 | **2.07** |
| `volusia_cama_owner` | 343,841 | 483,754 | **1.41** |

**129,123 of 343,841 parcels have more than one owner — 37.6%. One has 27.**

Others worth noting: `volusia_address_multipoint` 6.77 per parcel, `volusia_cama_comm_area` 6.41, `volusia_current_permits_history` 4.87, `miamidade_building_footprints_area` 19.23, `volusia_cama_misc` 2.74, `volusia_cama_nonadvalorem` 1.73.

**`volusia_cama_nonadvalorem` covers 178,076 parcels and is unwired.** Non-ad-valorem assessments — CDD levies, fire and solid-waste charges that transfer with the property.

---

## 9. Worked failure — 3013 S Atlantic Ave Unit 9020

Parcel `532713099020`, AltKey `4990518`. **Eleven tables hold this parcel. The report showed almost none of it.**

| table | holds | report showed |
|---|---|---|
| `volusia_cama_owner` | **2 rows** — Catarino Charles R, Catarino Denise A | `owners: 0`, and one name in the property section |
| `volusia_cama_sales` | **4 rows** — 1990 $108,900 · 1993 $109,000 · 2016 $100 · **2019 $245,000** | `transactions: 0` |
| `volusia_cama_condo_bldg` | `BATH 2 · BEDRM 2 · CONDOLVL 9 · CNDCMPLX 022301 · OCEANS ATRIUM ONE` | `bathrooms: null` |
| `volusia_parcel_school_assignment` | Longstreet Elem · Silver Sands Middle · Atlantic High | `schools: []` |
| `volusia_cama_permits` on assoc parcel `4988688` | **11 permits** incl. **concrete restoration 2022, $589,750** | `permits: 0` |
| `volusia_cama_res_bldg`, `_parcel`, `_exemptions`, `_situs`, `nal_dor_source`, `address_multipoint` | rows present | not read |

**`CNDCMPLX = 022301` groups all 78 units and the association parcel.** The link to the building's permits was in the data the whole time.

---

## 10. What this defines

**Every parcel record must be assembled by discovery, not declaration.** The tables that hold a parcel are knowable at query time — the probe that produced §9 is eleven lines of SQL.

**Cardinality decides the render.** `ONE_PER_PARCEL` is a value. `MANY_PER_PARCEL` is a list with a count. 69% are lists.

**A parcel's record includes the parcels it belongs to.** `CNDCMPLX` for condos, `SPLT_COMB` for split and combine history, `subnum` for subdivision. Labelled separately, never merged.

**And a key must be tested before it is trusted.** Nine columns named as keys hold one to sixty-five distinct values. Testing `count(distinct key) vs count(*)` at load time catches every one.

---

## 11. Live tables

| table | contents |
|---|---|
| `nr_master` | **1,226 rows — the definition.** class, geometry, srid, own keys, parcel keys, other keys, cardinality, join type |
| `nr_index` | probed geometry and SRID, key/date/status/code columns |
| `nr_keys` | 39,223 columns classified: own key, near-unique, high cardinality, constant, repeating |
| `nr_cardinality` | rows per key for 344 keyed tables |
| `nr_jointype` | join route per table |
| `nr_content` | 27,012 actual column value sets |
| `nr_fam` | source family, 21 families |
| `nr_failures` | 68 logged failures |
| `jurisdiction_prefix_map` | 46 prefixes — 7 county aliases, 39 municipalities |
