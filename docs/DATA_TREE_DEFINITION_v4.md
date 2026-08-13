# Data Tree — Full Definition

**Version 4 · 2026-07-27.** Supersedes v3, v2, v1 (same date).

1,226 populated tables. The live definition is `nr_master` in Supabase — this document is the readable form plus the defects the survey exposed.

**Every table in this document is a roll-up of a live artifact.** Where a figure is not derivable from a table, it is marked **[declared]** and names who declared it. That convention exists because v3 §3 contained a fabricated number, found on verification — §14.

**Changes in v4:** §3 join topology rebuilt in the artifact and recounted · §14 the v3 fabrication recorded · every section marked derived or declared.

*v3 added orphan resolution and the negative-control finding. v2 added parcel-to-parcel relation keys and the `comm_` correction.*

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

**A table has three kinds of key.** Its *own key* identifies its rows. Its *join key* links it to a parcel. A *relation key* links one parcel to another. 919 of 1,226 tables have more than one own key.

---

## 2. The tree by class — derived from `nr_master`

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

`nr_master.class` stores finer subclasses (`REG_flood`, `PART2_cama`). This table is a prefix roll-up and sums exactly.

**PART2 holds 45 million rows in 129 tables** — a third of everything, in a tenth of the tables.
**PART4 carries multiple parcel keys on 74 of 150 tables** — the DOR roll ships both `PARCEL_ID` and `ALT_KEY`.

---

## 3. Join topology — derived from `nr_jointype`, rebuilt in v4

| route | tables | rows | mechanism |
|---|---|---|---|
| J1 parcel key + geometry | 138 | 38,635,579 | key join, geometry available to verify |
| J2 parcel key only | 170 | 38,501,445 | key join, no spatial fallback |
| J2b `property_id` FK | 3 | 631,440 | internal FK to `properties.id` |
| **J3 containment** | **544** | 6,110,445 | polygon contains parcel |
| J4 proximity | 265 | 8,242,543 | point within distance |
| J5 frontage | 57 | 976,882 | line adjacent to parcel |
| J7 zip area | 6 | 34,727 | area key |
| J8 place name | 4 | 801,924 | area key |
| J9 county | 16 | 1,774,947 | area key |
| **J12 indirect key** | **5** | **40,301** | joins via another table — §11 |
| J13 non-parcel domain | 1 | 493,556 | correctly has no parcel path — §11 |
| **J14 genuine orphan** | **1** | 2,709 | no path exists — §12 |
| J0 system | 16 | 498,175 | internal |
| | **1,226** | | |

**Key routes (J1+J2+J2b): 311 tables, 77,768,464 rows.**
**Spatial routes (J3+J4+J5): 866 tables, 15,329,870 rows.**
**Area keys (J7+J8+J9): 26 tables, 2,611,598 rows.**

Few tables carry most of the data; many tables carry the containment.

**J6 has no members** — census-keyed tables resolved to other routes on rebuild.

---

## 4. Key vocabulary — 22 names, derived from `information_schema`

| key name | tables | rows | note |
|---|---|---|---|
| `parcel_id` | 166 | 53,675,492 | **format varies by county** — §5 |
| `co_no` | 149 | 45,931,113 | DOR county number |
| `alt_key` | 74 | 33,044,024 | DOR roll alternate key |
| `fld_ar_id` | 61 | 423,688 | FEMA flood area id — **also an indirect join, §11** |
| `parcelid` | 36 | 2,791,928 | |
| `site_id` | 36 | 1,142 | FDEP brownfield |
| `altkey` | 30 | 1,866,802 | county CAMA key |
| `folio` | 30 | 6,168,103 | Miami-Dade, Broward |
| `parcelno` | 25 | 22,324,575 | |
| `pid` | 23 | 1,799,570 | |
| `strap` | 20 | 4,461,321 | Lee, Pinellas, Sarasota, St Johns |
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
sjc_parcels.strap                     0000200010     10  6-digit prefix + 4-digit lot
```

**166 tables use `parcel_id`. The format depends on the county.** A cross-county join on that column name is wrong by construction.

**`properties.dor_parcel_id` is not unique** — 313,578 rows, 309,104 distinct, **4,474 duplicates**. Any join on it fans out.

---

## 6. Parcel-to-parcel relation keys — `parcel_relation_key`

### 6.1 `CNDCMPLX` — condo complex group

`volusia_cama_condo_bldg`. **338 complexes, 23,191 member rows.**

`CNDCMPLX = 022301` is `OCEANS ATRIUM ONE (5327-13)` and groups **all 78 unit parcels with association parcel `4988688`**.

The only link from a unit to its building. The association's 11 permits — including **concrete restoration 2022, $589,750** — reach a unit through this key and no other.

### 6.2 `LUC = 0900` — common-element role marker

`volusia_cama_parcel`. **4,317 Volusia parcels.**

```
LUC        0900  "Residential Common Elements/Areas"
owner      OCEANS ATRIUM ONE CONDO ASSOC
just value $0
legal      COMMON AREA UNIT 101 UNIT OCEANS ATRIUM ONE CONDO
land code  0904
```

**It finds the building record** — permits, declaration, common-element legal.
**It must never be returned as anyone's property** — $0 value, association-owned. The Sarasota `account`-vs-`id` failure of `DATA_JOIN_FINDINGS` §3, with 4,317 loaded cases.

### 6.3 Area groupings already present and unused

| key | held in | groups | coverage |
|---|---|---|---|
| `NBHD` / `NBHD_DESC` | `volusia_cama_parcel` | 2,938 | all 313,619 Volusia parcels |
| `NBRHD_CD` | `*_nal_dor_source` | — | **all 67 counties** |
| `MKT_AR` | `*_nal_dor_source` | — | **all 67 counties** |

---

## 7. `comm_` is commercial, not common

`comm_bldg` carries `BUSLA` — business area. `comm_area` carries `SPRINKLER`, `WALLHGT`, `EXTWALL`, `FLRFROM`/`FLRTO`, `USETYPE`.

**Decisive:** neither association parcel `4988688` nor unit `4990518` appears in `comm_bldg`. If `COMM` meant common elements, the association would be its first row.

`COMM` pairs with `RES`. **Common elements are §6.2.**

---

## 8. Tables with no own key — 80

Identity is composite. **Every Volusia CAMA table:** `_owner`, `_sales`, `_permits`, `_exemptions`, `_res_area`, `_res_bldg`, `_comm_area`, `_comm_bldg`, `_condo_bldg`, `_condo_misc`, `_land`, `_misc`, `_nonadvalorem`, `_situs`, `_agland`.

Real key is **`PARID` + `TAXYR` + line sequence**. A single-column join returns every tax year and every line item at once — the direct cause of §13.

---

## 9. Cardinality — derived from `nr_cardinality`

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

## 10. Not keys — tested and rejected

| candidate | evidence | verdict |
|---|---|---|
| `SPLT_COMB` | values `1 \| 2` across 355 rows | **flag**. Records that a split or combine happened; does not identify source or result. |
| `MP_ID` | 309,344 distinct across 309,344 rows, hex `008B61A1` | **unique identifier**, DOR internal. Not a group. |
| `GRP_NO` | 6 distinct across 293,949 rows | **roll administration**. |
| **`sjc_parcels` STRAP prefix** | 8.6% overlap with `sub_number`; **negative control kills it** — §12 | **coincidence**. |

---

## 11. Orphan resolution — six of seven resolved by testing

| table | rows | first classed | tested | actual |
|---|---|---|---|---|
| `well_gwca_flag` | 2,803 | broken load | **2,803 of 2,803** match `sjrwmd_wells.oid` | **complete flag table** |
| `well_icr_flag` | 566 | broken load | **566 of 566** match | **complete flag table** |
| `clay_flood_zones` | 1,239 | no path | **1,236 of 1,239** match `fema_flood_zones.fld_ar_id` | indirect key, 99.8% |
| `pasco_zoning_data` | 18,093 | no path | 9,390 match `pasco_zoning_area.objectid` | indirect, 52% |
| `pasco_zoning_petitions` | 17,600 | no path | 9,969 match | indirect, 57% |
| `agent_license_status` | 493,556 | no path | joins 1:1 on `license_number` | **correctly parcel-less** |
| **`sjc_plat_index`** | **2,709** | no path | **§12** | **genuine orphan** |

**The two "broken loads" were complete by design.** A one-column table of `oid` values is an ID list carrying a boolean meaning — the single column is the entire point. Column count is not a quality signal.

**`agent_license_status` was never an orphan.** It describes people, not land. The classifier only searched for parcel routes.

**One genuine orphan in 1,226 tables.**

---

## 12. `sjc_plat_index` — the negative control

**Not corrupted.** `objectid` runs 1 to 2,709 with **zero gaps**. 2,709 rows, 2,709 distinct `sub_number`. Real plat names: *Treaty Oaks Phase 1*, *Celestina Phase 4C*, *Palencia North Phase III A-2*, *Julington Lakes Phase 1*.

**No join exists in what we hold.** `sjc_parcels` has nine columns — `objectid, pin, use_desc, acres, use_code, strap, shape__length, shape__area, geom`. No subdivision reference.

**The STRAP hypothesis, tested and rejected.** STRAP is 10 digits: 6-digit prefix + 4-digit lot (`PIN` shows the split: `000020 0010`). 232 of 2,709 `sub_number` values match a prefix — 8.6%.

**First test was invalid.** Four matched prefixes clustered tightly — but held 1, 1, 2 and 5 parcels. **A single parcel is always clustered.** The test could not fail.

**Negative control, prefixes with 20+ parcels:**

| group | prefixes | avg parcels | avg cluster | clustered under 3 km |
|---|---|---|---|---|
| Matches a plat `sub_number` | 9 | 40.9 | 542 m | **9 of 9** |
| **Control — no plat match** | 40 | 115.9 | 720 m | **40 of 40** |

**Clustering proves nothing.** Every STRAP prefix is a geographic grouping in the county's own numbering. The 8.6% is two numeric ranges intersecting.

**No plat polygon layer is published.** St Johns serves parcels, zoning, future land use, address sites and a land-use boundary. The Clerk holds the authoritative plats under Ch. 177 F.S. with no bulk route.

**It is a text index by design.** The route in is `plat_name` as a searchable string, not a key.

---

## 13. Worked failure — 3013 S Atlantic Ave Unit 9020

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

## 14. Errors in this survey and in these documents

Recorded because the method matters more than the result. All in `nr_failures`.

**v3 §3 described a topology the artifact did not contain.** The J12/J13/J14 categories were hand-written into the document; `nr_jointype` still held `J10_NO_PATH` and `J11_BROKEN_LOAD`. Found on verification by asking which sections were derived and which were written. **The artifact has been rebuilt in v4 and §3 now sums to 1,226.**

**v3 §3 contained a fabricated number.** J12 was stated as 531,061 rows. The five tables total **40,301**. The figure was not derived from anything.

**Column count is not a quality signal.** Two complete flag tables were classed as broken loads for having one column.

**Domain assumption.** `agent_license_status` was classed as having no join path because the classifier only searched for parcel routes.

**A test that could not fail.** The first STRAP clustering check used samples of 1 to 5 parcels and confirmed the hypothesis. A negative control on adequately sized samples reversed it — 40 of 40 unmatched prefixes clustered as tightly as the matched ones.

**That last one is `DATA_JOIN_FINDINGS` §1 test 3, and it is the test people skip.** Without it, test 2 produces a number with no meaning.

---

## 15. What this defines

**Assemble by discovery, not declaration.** The tables holding a parcel are knowable at query time — the probe producing §13 is eleven lines of SQL.

**Cardinality decides the render.** `ONE_PER_PARCEL` is a value. `MANY_PER_PARCEL` is a list with a count. 69% are lists.

**A parcel's record includes the parcels it relates to.** `CNDCMPLX`, `LUC 0900`, `NBHD` / `NBRHD_CD`. Labelled separately, never merged.

**A key must be tested before it is trusted.** Nine columns named as keys hold between one and sixty-five distinct values — §16.

**A match rate is not evidence.** Run the negative control.

**And a figure in prose is not a figure.** Every number in this document rolls up from a named artifact. Where one didn't, it was wrong.

---

## 16. Broken keys — columns named as keys holding one value

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

**Five of nine are ARPC-sourced.** The `altkey` column arrived dead. A join on it returns the whole county as one parcel, silently.

**Test at load: `count(distinct key) vs count(*)`.**

---

## 17. Live artifacts — all re-derivable

| table | rows | contents |
|---|---|---|
| `nr_master` | 1,226 | **the definition** — class, geometry, srid, own keys, parcel keys, other keys, cardinality, join type |
| `nr_keys` | 39,223 | every column classified: own key, near-unique, high cardinality, constant, repeating |
| `nr_content` | 27,012 | actual column value sets |
| `nr_index` | 1,226 | probed geometry and SRID, key/date/status/code columns |
| `nr_jointype` | 1,226 | **rebuilt in v4** — join route per table, J12/J13/J14 applied |
| `nr_fam` | 1,226 | source family, 21 families |
| `nr_cardinality` | 344 | rows per key |
| `nr_failures` | **79** | logged failures with phase, table, detail |
| `parcel_relation_key` | 5 | parcel-to-parcel keys with verified examples |
| `ladm_declaration` | 51 | signed classifications with rationale |
| `jurisdiction_prefix_map` | 46 | 7 county aliases, 39 municipalities |
| `ladm_map_fault_register` | 21 | fault classes from the earlier classification runs |
