# Data Tree — Full Definition

**Version 2 · 2026-07-27.** Supersedes v1 of the same date.

1,226 populated tables. Every figure derived by query against live data; nothing inferred. The live definition is `nr_master` in Supabase — this document is the readable form plus the defects the survey exposed.

**Changes in v2:** §6 parcel-to-parcel relation keys (new class, two keys found) · §7 the `comm_` correction · §10 three things tested and found not to be keys · §11 broken-key register expanded.

---

## 1. What was measured, per table

| property | source | method |
|---|---|---|
| Row count | `table_inventory` | stored |
| Geometry type | **probed** | `ST_GeometryType` on live rows |
| SRID | **probed** | `ST_SRID` on live rows |
| **Own keys** | `pg_stats.n_distinct = -1` | every column unique across rows |
| **Join keys** | `information_schema` | columns matching the key vocabulary |
| **Relation keys** | read + counted | parcel-to-parcel group codes |
| **Cardinality** | counted | distinct key values vs total rows |
| Constant columns | `pg_stats.n_distinct = 1` | one value across all rows |
| Class | `nr2_final` / `ladm_declaration` | content-verified where possible |

**A table has three kinds of key, and they are different things.** Its *own key* identifies its rows. Its *join key* links it to a parcel. A *relation key* links one parcel to another parcel. 919 of 1,226 tables have more than one own key.

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
**REG is 305 tables and 2.3 million rows** — restrictions are many small layers, not few large ones.

---

## 3. Join topology — how each table reaches a parcel

| route | tables | rows | mechanism |
|---|---|---|---|
| J1 parcel key + geometry | 138 | 38,635,579 | key join, geometry available to verify |
| J2 parcel key only | 170 | 38,501,445 | key join, no spatial fallback |
| J2b `property_id` FK | 3 | 631,440 | internal FK to `properties.id` |
| **J3 containment** | **544** | 6,110,445 | polygon contains parcel |
| J4 proximity | 265 | 8,242,543 | point within distance |
| J5 frontage | 57 | 976,882 | line adjacent to parcel |
| J6–J9 area key | 26 | 2,611,598 | county / census / zip / place name |
| J10 no path | 5 | 533,197 | no key, no geometry |
| **J11 broken load** | **2** | 3,369 | one column only |
| J0 system | 16 | 498,175 | internal |

**866 tables join spatially. 311 join by key.** The 311 hold **77 million rows** against the spatial set's 15 million — few tables, most of the data.

---

## 4. Key vocabulary — 22 names in use

| key name | tables | rows | note |
|---|---|---|---|
| `parcel_id` | 166 | 53,675,492 | **format varies by county** — §5 |
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
| `subnum` | 10 | 319,258 | subdivision group |
| `geoid` | 8 | 14,743 | census |
| `property_id` | 6 | 2,024,413 | internal FK |
| `instrument_number` | 5 | 1,441,948 | recorded document |
| `account` | 5 | 1,039,537 | Charlotte, Sarasota |
| `license_number` | 4 | 1,138,057 | DBPR |
| `fullpid` | 4 | 356,253 | Volusia geographic |
| `dor_parcel_id` | 2 | 380,989 | |
| `cndcmplx` | 1 | 23,191 | **condo complex — §6** |
| `block_group` | 1 | 13,239 | |

---

## 5. `parcel_id` is not one key

Same column name, four different value formats:

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

**166 tables use `parcel_id`. The format depends on the county.** A cross-county join on that column name is wrong by construction.

**`properties.dor_parcel_id` is not unique** — 313,578 rows, 309,104 distinct, **4,474 duplicates**. `properties.parcel_id` is unique; `dor_parcel_id` is not. Any join on it fans out.

---

## 6. Parcel-to-parcel relation keys — NEW IN v2

Every key in §4 links a **table to a parcel**. These link a **parcel to another parcel**. The funnel has never had this route. Recorded in `parcel_relation_key`.

### 6.1 `CNDCMPLX` — condo complex group

**Held in** `volusia_cama_condo_bldg`. **338 complexes, 23,191 member rows.**

Verified: `CNDCMPLX = 022301` is `OCEANS ATRIUM ONE (5327-13)` and groups **all 78 unit parcels together with association parcel `4988688`**. Both carry the same code.

This is the only link from a unit to its building. The association's 11 permits — including **concrete restoration 2022, $589,750** — reach a unit through this key and no other. Without it, a condo report shows zero permits on a building holding 255.

### 6.2 `LUC = 0900` — common-element role marker

**Held in** `volusia_cama_parcel`. **4,317 Volusia parcels.**

```
LUC        0900  "Residential Common Elements/Areas"
owner      OCEANS ATRIUM ONE CONDO ASSOC
just value $0
legal      COMMON AREA UNIT 101 UNIT OCEANS ATRIUM ONE CONDO
           PER OR 2980 PGS 0806 TO 0874 INC MB 41
land code  0904
```

Two uses, opposite in direction:

**It finds the building record.** The association parcel holds the permits, the recorded declaration and the common-element legal description.

**It must never be returned as anyone's property.** $0 value, association-owned. That is the Sarasota `account`-versus-`id` failure of `DATA_JOIN_FINDINGS` §3, and 4,317 Volusia parcels are the loaded case.

### 6.3 Area groupings already present and unused

| key | held in | groups | coverage |
|---|---|---|---|
| `NBHD` / `NBHD_DESC` | `volusia_cama_parcel` | 2,938 | all 313,619 Volusia parcels |
| `NBRHD_CD` | `*_nal_dor_source` | — | **all 67 counties** |
| `MKT_AR` | `*_nal_dor_source` | — | **all 67 counties** |

`NBHD_DESC` example: *"Spruce Creek Fly, Beech Blvd and Cessna"*. The DOR equivalents make neighbourhood grouping available statewide, not only where CAMA is loaded.

---

## 7. `comm_` is commercial, not common — CORRECTION IN v2

v1 listed `volusia_cama_comm_area` and `_comm_bldg` without saying what they hold. Tested:

**Column evidence.** `comm_bldg` carries `BUSLA` — business area. `comm_area` carries `SPRINKLER`, `WALLHGT`, `EXTWALL`, `EXTWALLPCT`, `FLRFROM`/`FLRTO`, `USETYPE` — commercial appraisal fields.

**Decisive evidence.** Neither the Oceans Atrium association parcel `4988688` nor unit `4990518` appears in `comm_bldg`. If `COMM` meant common elements, the association would be its first row.

**Sample row:** `STRUCTURE_DESC "Wood, Open Steel"`, `BUSLA 90`, `TOTAL_AREA 171`, `RCN 9446` — a small commercial canopy.

`COMM` pairs with `RES` as commercial-versus-residential, the standard CAMA split. **Common elements are §6.2, not a separate table.**

---

## 8. Tables with no own key — 80

No unique column; identity is composite.

**Every Volusia CAMA table is in this group:** `_owner`, `_sales`, `_permits`, `_exemptions`, `_res_area`, `_res_bldg`, `_comm_area`, `_comm_bldg`, `_condo_bldg`, `_condo_misc`, `_land`, `_misc`, `_nonadvalorem`, `_situs`, `_agland`.

Their real key is **`PARID` + `TAXYR` + line sequence**. A single-column join returns every tax year and every line item at once — the direct cause of §12.

---

## 9. Cardinality — rows per parcel

**235 of 339 keyed tables are one-to-many — 69%.**

| table | parcels | rows | **per parcel** |
|---|---|---|---|
| `volusia_cama_sales` | 329,294 | 1,613,504 | **4.90** |
| `volusia_cama_res_area` | 215,188 | 1,012,512 | **4.71** |
| `volusia_cama_permits` | 240,264 | 992,313 | **4.13** |
| `volusia_cama_exemptions` | 345,215 | 714,792 | **2.07** |
| `volusia_cama_owner` | 343,841 | 483,754 | **1.41** |

**129,123 of 343,841 parcels have more than one owner — 37.6%. One has 27.**

Also: `miamidade_building_footprints_area` 19.23 · `volusia_address_multipoint` 6.77 · `volusia_cama_comm_area` 6.41 · `volusia_current_permits_history` 4.87 · `volusia_cama_misc` 2.74 · `volusia_cama_nonadvalorem` 1.73.

**`volusia_cama_nonadvalorem` covers 178,076 parcels and is unwired** — CDD levies, fire and solid-waste assessments that transfer with the property.

---

## 10. Tested and found NOT to be keys — NEW IN v2

| candidate | evidence | verdict |
|---|---|---|
| `SPLT_COMB` | values `1 \| 2` across 355 rows | **flag**, split or combine. Records that it happened; does not identify source or result. Cannot link parcel history. |
| `MP_ID` | 309,344 distinct across 309,344 rows, hex e.g. `008B61A1` | **unique identifier**, DOR internal master parcel ID. Not a group. |
| `GRP_NO` | 6 distinct across 293,949 rows | **roll administration**, not a relation. |

---

## 11. Broken keys — columns named as keys holding one value

| table | column | distinct | rows | source |
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

**Five of nine are ARPC-sourced** — the same regional server returning 265,114 features for a 14,000-parcel county. The `altkey` column arrived dead. A join on it returns the whole county as one parcel, silently.

**Test at load: `count(distinct key) vs count(*)`.** Catches all nine.

---

## 12. Worked failure — 3013 S Atlantic Ave Unit 9020

Parcel `532713099020`, AltKey `4990518`. **Eleven tables hold this parcel.**

| table | holds | report showed |
|---|---|---|
| `volusia_cama_owner` | **2 rows** — Catarino Charles R, Catarino Denise A | `owners: 0`, one name in the property section |
| `volusia_cama_sales` | **4 rows** — 1990 $108,900 · 1993 $109,000 · 2016 $100 · **2019 $245,000** | `transactions: 0` |
| `volusia_cama_condo_bldg` | `BATH 2 · BEDRM 2 · CONDOLVL 9 · CNDCMPLX 022301` | `bathrooms: null` |
| `volusia_parcel_school_assignment` | Longstreet Elem · Silver Sands Middle · Atlantic High | `schools: []` |
| assoc parcel `4988688` via **`CNDCMPLX`** | **11 permits**, incl. concrete restoration 2022 **$589,750** | `permits: 0` |
| `_res_bldg`, `_parcel`, `_exemptions`, `_situs`, `nal_dor_source`, `address_multipoint` | rows present | not read |

---

## 13. What this defines

**Assemble by discovery, not declaration.** The tables holding a parcel are knowable at query time — the probe producing §12 is eleven lines of SQL.

**Cardinality decides the render.** `ONE_PER_PARCEL` is a value. `MANY_PER_PARCEL` is a list with a count. 69% are lists.

**A parcel's record includes the parcels it relates to.** `CNDCMPLX` for condo buildings, `LUC 0900` for common elements, `NBHD`/`NBRHD_CD` for market area. Labelled separately, never merged.

**And a key must be tested before it is trusted.** Nine columns named as keys hold between one and sixty-five distinct values.

---

## 14. Live artifacts — all re-derivable

| table | rows | contents |
|---|---|---|
| `nr_master` | 1,226 | **the definition** — class, geometry, srid, own keys, parcel keys, other keys, cardinality, join type |
| `nr_keys` | 39,223 | every column classified: own key, near-unique, high cardinality, constant, repeating |
| `nr_content` | 27,012 | actual column value sets |
| `nr_index` | 1,226 | probed geometry and SRID, key/date/status/code columns |
| `nr_jointype` | 1,226 | join route per table |
| `nr_fam` | 1,226 | source family, 21 families |
| `nr_cardinality` | 344 | rows per key |
| `nr_failures` | **72** | logged failures with phase, table, detail |
| `parcel_relation_key` | 5 | **new in v2** — parcel-to-parcel keys with verified examples |
| `ladm_declaration` | 51 | signed classifications with rationale |
| `jurisdiction_prefix_map` | 46 | 7 county aliases, 39 municipalities |
| `ladm_map_fault_register` | 21 | fault classes from runs 1–3 |
