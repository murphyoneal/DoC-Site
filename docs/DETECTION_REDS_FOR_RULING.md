# Unacknowledged reds, for ruling (ruling 936)

Run of 2026-10-02 14:29 UTC, measured after 205a and 205b were applied.

**The headline is 0 blocking reds.** 20 of the 76 are blocking at launch, and 1 of the 76 is disclosed. There are 18 blocking detections, and all 18 are green. 76 reds are unacknowledged, down from 79:
- 2 blocking detections were red, and both turned out to be detection defects. 205b fixed them and they went green.
- defect-detection-suite-not-completing went green.
- municipal-boundary-annexation-lag went red as designed (204c), and it is acknowledged.

Severity, re-rated by consequence across 201 active detections (205a):

| Severity | Count | Note |
|---|---|---|
| blocking | 18 | all green |
| material | 151 | 58 of these are blocking at launch |
| cosmetic | 32 | |

Blocking at launch means the defect is a false statement, but only on the paid report or Roz alpha. Neither can be bought today, because checkout is parked. Each of these turns blocking the day checkout opens.

## The fields

One line per red:

`defect_id · name · class · severity · what it reads · last magnitude · disclosed? · discovered_on`

- **What it reads** is parsed from the detection's SQL:
  - `served` means it calls a served function;
  - `catalogue` means pg_* or information_schema;
  - `registry` means our own registers;
  - `data` means anything else.

  It is a regex classification, so read it as a lead, not a measurement.
- **Last magnitude** is the `row_count` the latest run returned. 70 of the 76 return none, because they predate the magnitude and population contract. That is itself the R2 gap.
- **Disclosed** means `disclosure_status='active'`, `disposition='disclose'` and the row has text. That is what `get_parcel_disclosures` serves, and it serves it on the paid report only. No disclosure from this register appears on any surface reachable today.

## Order

Riskiest first:
1. blocking (none);
2. blocking at launch;
3. by what it reads: served, then data, then registry, then catalogue;
4. by magnitude.

## Decision rule (936)

- disclosed → acknowledged;
- undisclosed on a served surface → live false statement;
- the county's data really is that way → retire it in favour of a coverage statement;
- nobody can justify it → retire it (standing authority, recorded with what it checked and why).

## Batch 1 (rows 1-20)

1. `restrictions-bare-array-has-no-field-status` · get_parcel_restrictions returns a bare JSON array with no envelope and no field_status - an empty [] is served identically whether a sour... · null_as_value · material (blocking at launch) · served · none returned · no · 2026-08-26
2. `duval-flood-zone-is-a-comma-separated-multi-zone-string` · duval_flood_zones.flood_zone holds several zones in one string on 22,606 of 65,827 parcels (34.3%) - 22,587 of them contain an SFHA zone ... · resolution_mislabelling · material (blocking at launch) · data · none returned · no · 2026-08-16
3. `empty-encumbrance-array-reads-as-no-liens` · field_status reads none_recorded where the register was never searched - it should be not_available · null_as_value · material (blocking at launch) · data · none returned · no · 2026-08-22
4. `floodway-flag-column-holds-jurisdiction-names` · lee_firm_floodways.floodway holds six city names alongside FLOODWAY and OUTSIDE - a regulatory flag column carrying jurisdiction values · resolution_mislabelling · material (blocking at launch) · data · none returned · no · 2026-08-17
5. `fourteen-getters-emit-no-field-status` · 14 of 47 parcel getters return no field_status key at all - six of them return a bare [] on nearly every parcel (attestations, planned_wo... · null_as_value · material (blocking at launch) · data · none returned · no · 2026-08-26
6. `named-owners-recorded-at-zero-percent-while-the-parcel-sums-to-unity` · Polk: 38,134 owner rows hold a zero share and 15,455 parcels have every owner but one at zero, while the shares still sum to exactly 1.0000 · null_as_value · material (blocking at launch) · data · none returned · no · 2026-08-16
7. `one-third-of-contractor-permit-matches-carry-their-own-ambiguity-flag` · permit_contractor_match_resolved flags 65,760 of 191,536 matches (34.3%) as ambiguous, and the first row sampled is one of them · entity_confusion · material (blocking at launch) · data · none returned · no · 2026-08-16
8. `pcpao-permit-date-sentinel-years` · Pinellas permit issue dates include placeholder years - 1899, 1900 and 1800 - that are not real dates · null_as_value · material (blocking at launch) · data · none returned · no · 2026-08-14
9. `pinellas-permit-signoff-null-on-98-percent-cannot-mean-unclosed` · Pinellas sign_off_dt was recorded at 8-9% through 2008 and is HARD ZERO from 2009 onward - the column died in a system change, so it is n... · null_as_value · material (blocking at launch) · data · none returned · no · 2026-08-16
10. `served-sum-multiplies-value-by-fragment-count` · search_properties_stats runs statewide and returns count(*) rows and avg(jv) fragment-weighted - Broward average value overstated 10.11% · fanout · material (blocking at launch) · data · none returned · no · 2026-08-22
11. `test-rows-left-in-a-published-production-layer` · deerfieldbeach_city_parks contains a row whose comments field reads "Test 2 (Delete)" · completeness · material (blocking at launch) · data · none returned · no · 2026-08-19
12. `bfe-null-where-the-column-is-absent-not-where-fema-published-none` · Four county FIRM layers carry no BFE column, so an AE-zone parcel renders base_flood_elevation_ft as a bare null - indistinguishable from... · null_as_value · material (blocking at launch) · registry · none returned · no · 2026-08-16
13. `citrus-sumter-firm-exact-thousand-truncation-suspect` · Citrus and Sumter FIRM layers hold exactly 6,000 and 4,000 rows - the page-truncation signature - and cover a materially smaller share of... · completeness · material (blocking at launch) · registry · none returned · no · 2026-08-15
14. `DEF-007` · out-of-county centroid · geometry · material (blocking at launch) · registry · none returned · no · 2026-07-24
15. `layer-resolution-row-unverified` · A layer_resolution row wired into the resolver whose contents were never read - selected by name, not by contents · resolution_mislabelling · material (blocking at launch) · registry · none returned · no · 2026-08-15
16. `miamidade-municipal-zoning-inert-on-null-rowcount` · Miami-Dade municipal zoning holds 4,606 polygons but carries row_count NULL, so resolve_layer excludes it and every incorporated Miami-Da... · null_as_value · material (blocking at launch) · registry · none returned · no · 2026-08-15
17. `zoning-code-is-a-composite-carrying-a-jurisdiction-prefix` · alachua_zoning.zonecode and alachua_future_land_use.flucode are jurisdiction-prefix + district composites - "0103SF" is not a district an... · resolution_mislabelling · material (blocking at launch) · registry · none returned · no · 2026-08-16
18. `inferred-hazard-flagged-as-requiring-disclosure` · All 5,919 site_hazard_installations rows are INFERRED from a generator permit, none confirmed and none located, yet every one carries req... · null_as_value · material (blocking at launch) · catalogue · none returned · no · 2026-08-15
19. `R3_SENTINEL_NOT_NORMALISED_AT_SERVE` · NODATA sentinels unhandled in 49 of 50 served functions - but measured exposure today is 2 rows · null_as_value · material (blocking at launch) · catalogue · none returned · no · 2026-08-20
20. `get-pir-report-inline-volusia-coalesce` · get_pir_report resolves subdivisions and boat ramps via the resolver only as the ELSE branch of COALESCE(inline-Volusia, resolver). The i... · entity_confusion · cosmetic · served · none returned · no · 2026-08-08

## Batch 2 (rows 21-40)

21. `served-field-status-vocabulary-not-three-states` · The served report emits 13 distinct field_status values where the three-state rule allows three, and nothing marks which assert absence a... · resolution_mislabelling · material · served · none returned · no · 2026-08-25
22. `single-county-table-served-as-universal` · DETECTION GAP: a report-path function can read a single-county table where statewide data exists, and no predicate catches it (co_no-lite... · completeness · material · served · none returned · no · not recorded
23. `permit-completion-date-precedes-issue-date` · Volusia permits serve a completion date EARLIER than the permit issue date; 13 by over 50 years, an artefact of a two-digit year resolved... · temporal · material · data · 1226 · no · 2026-08-16
24. `dor-use-code-descriptions-truncated-at-40-chars` · The sourced DOR use-code descriptions are cut mid-word by a 40-character fixed-width source field · completeness · material · data · 16 · no · 2026-08-15
25. `amenity-features-null-co-no-keytypes` · amenity_features.co_no is NULL for every school/fire_station/police_station/hospital row (7,107) — a value that means absence; any branch... · key_integrity · material · data · none returned · no · 2026-08-07
26. `amenity-school-type-includes-non-k12` · amenity_features.amenity_type='school' includes non-K-12 facilities (juvenile detention, post-secondary/technical colleges, district admi... · entity_confusion · material · data · none returned · no · 2026-08-07
27. `assistant-log-records-nothing` · assistant_query_log writes NULL user_query, response_text and roz_version - it records that a query happened and nothing about what it was · completeness · cosmetic · data · none returned · no · 2026-08-15
28. `cadence-dead-source` · Source has failed 3 consecutive cadence sweeps (dead, not flaky) · completeness · material · data · none returned · no · not recorded
29. `cama-key-hygiene-sweep-five-counties` · Standing key-hygiene guard across all five CAMA counties - ragged length, untrimmed whitespace and zero-loss on every child-table key · key_integrity · material · data · none returned · no · 2026-08-15
30. `collier-child-table-parcelid-leading-zeros-stripped` · Collier CAMA child tables lost leading zeros on parcelid - 5.9% to 18.0% of every child table silently fails to join its parent folio · key_integrity · material · data · none returned · no · 2026-08-15
31. `compat-views-pending-retirement` · Resolver migration leaves compatibility views standing in for migrated bespoke tables (flood_layer_selection, flood_layer_column_map over... · entity_confusion · cosmetic · data · none returned · no · 2026-08-08
32. `contractor-name-truncated-at-30-characters` · property_permit_history.contractor_name is cut at exactly 30 characters on 51,152 rows - a display string that can never be a join key · entity_confusion · material · data · none returned · no · 2026-08-16
33. `county-name-saint-vs-st` · county_registry.county_name spells two counties "Saint Johns"/"Saint Lucie" while geo_reference.name and the layer registries spell them ... · entity_confusion · material · data · none returned · no · 2026-08-08
34. `DEF-013` · duplicate plat rows · fanout · cosmetic · data · none returned · no · 2026-07-24
35. `elevation-single-point-sample-unrepresentative` · Stored parcel elevation is a single interior-point 3DEP sample; unrepresentative on heterogeneous (coastal/water-adjacent/large/landfill)... · resolution_mislabelling · material · data · none returned · no · not recorded
36. `fema-flood-zones-page-truncated` · fema_flood_zones is page-truncated: county_name holds pull-BATCH labels (swcoast/spacecoast/central1/...), not counties, and every batch ... · completeness · cosmetic · data · none returned · no · 2026-08-08
37. `fixed-width-padding-loaded-intact-across-the-served-spine` · parcels_staging carries whitespace-only values in phy_addr1, phy_city and own_addr1 - a fixed-width source loaded with its padding, defea... · null_as_value · material · data · none returned · no · 2026-08-21
38. `key-column-holds-prose-and-delimited-lists-not-one-key` · lee_parks_preserves.strap holds "n/a (easement)", "Multiple", and semicolon-delimited lists of up to seven parcel ids - only 37% is a sin... · key_integrity · cosmetic · data · none returned · no · 2026-08-20
39. `lens-same-topic-under-two-sections` · Two lens sections carried the same topic suffix under different numbers (98-absence-vocabulary and 100-absence-vocabulary, three entries ... · entity_confusion · cosmetic · data · none returned · no · 2026-08-26
40. `licence-status-and-expiry-date-contradict-each-other` · contractor_name_index marks 74 licences active whose expiry_date has already passed, and status is TODAY status regardless of when the wo... · temporal · material · data · none returned · no · 2026-08-16

## Batch 3 (rows 41-60)

41. `owner-and-contractor-names-truncated-across-three-derived-tables` · Name fields are cut at fixed widths in properties (24 ch), property_permit_history (30 ch) and nal_staging s_legal - a systematic loader ... · entity_confusion · material · data · none returned · no · 2026-08-16
42. `pasco-per-file-staleness` · Pasco publishes its CAMA files on independent schedules; extrafeatures.csv is a week behind its siblings · temporal · material · data · none returned · no · 2026-08-15
43. `pii-named-private-individual-in-a-neighbourhood-association-layer` · clearwater_city_neighborhood_assoc carries a named officer, residential address, phone and personal email · access_control · material · data · none returned · no · 2026-08-17
44. `pinellas-strap-format-mismatch` · Pinellas parcel_id is SPACE-FORMATTED in parcels_staging and UNSPACED 18-char STRAP in the CAMA tables - every CAMA join silently returns... · key_integrity · material · data · none returned · no · 2026-08-15
45. `restrictions-are-recorded-against-the-subdivision-not-the-parcel` · The RESTRICTIONS register cannot be matched parcel-by-parcel because most declarations are recorded against a whole subdivision - lot-lev... · entity_confusion · material · data · none returned · no · 2026-08-16
46. `verified-encumbrance-candidates-held-back-from-the-served-match` · encumbrance_parcel_candidate holds 10,900 unpromoted single-parcel instruments that agree with the confirmed match 6,052 of 6,052 times a... · completeness · material · data · none returned · no · 2026-08-16
47. `DEF-001` · untested parcel key · key_integrity · cosmetic · registry · 51 · no · 2026-07-24
48. `DEF-017` · completeness check without a distinctness assertion · completeness · cosmetic · registry · 44 · no · 2026-07-24
49. `cama-is-a-table-set-resolved-as-a-single-layer` · concept=cama holds a whole relational TABLE SET but resolution_mode=pick returns exactly one table with LIMIT 1 - eighteen of nineteen Vo... · resolution_mislabelling · material · registry · none returned · no · 2026-08-15
50. `cama-role-concept-must-resolve-exactly-one-table` · A cama_* role concept resolves more than one table for a geo - the LIMIT 1 collision rebuilt inside the split · resolution_mislabelling · material · registry · none returned · no · 2026-08-15
51. `concept-registered-but-unwired` · A concept exists in concept_registry with ZERO layer_resolution rows - a promise the report cannot keep · completeness · cosmetic · registry · none returned · no · 2026-08-11
52. `county-parcel-keys-declared-without-measurement-six-of-ten-join-at-zero` · Ten county parcel layers were declared by column-name pattern; measuring found SIX joining the spine at ZERO, three recoverable by transf... · key_integrity · material · registry · none returned · no · 2026-08-16
53. `county-parcel-layer-disagrees-with-the-statewide-spine-both-ways` · The 37 county parcel layers and parcels_staging disagree on parcel count in both directions - Broward and Palm Beach are 200k SHORT in th... · completeness · material · registry · none returned · no · 2026-08-16
54. `DEF-009` · stale beyond cadence · completeness · material · registry · none returned · no · 2026-07-24
55. `erp-easement-type-is-technician-notes-not-a-classification` · fl_erp_conservation_easements.TYPE holds free-text GIS working notes, not an easement classification - "eyballed in", "looks odd on doq",... · resolution_mislabelling · material · registry · none returned · no · 2026-08-16
56. `listed-species-habitat-is-three-counties-of-sixty-seven` · Protected-species habitat is a federal development restriction with a measurable dollar cost, and we hold it for three counties - Marion,... · completeness · material · registry · none returned · no · 2026-08-16
57. `R281_CENSUS_ZERO_COLUMN_WIRED_TO_A_CONCEPT` · A column measured 0% populated on a full census is mapped to a col_role and could render a negative · null_as_value · material · registry · none returned · no · 2026-08-20
58. `resolver-picks-one-of-many-silently` · resolve_layer returns ONE table where several are registered for the same geo and concept, choosing by row_count and reporting nothing · resolution_mislabelling · material · registry · none returned · no · 2026-08-15
59. `resolver-single-county-geometry-assumptions` · Resolver helpers derived from one county's inline read carry that county's geometry/SRID/column/value conventions and misfire on other co... · geometry · material · registry · none returned · no · 2026-08-08
60. `verification-baseline-header-off-by-one` · A load verification baseline derived from wc -l counts the CSV header row, making every correct load look one row short · completeness · cosmetic · registry · none returned · no · 2026-08-14

## Batch 4 (rows 61-76)

61. `DEF-005` · SRID 0 (unjoinable geometry) · geometry · material · catalogue · 6 · no · 2026-07-24
62. `DEF-025` · FIRM flood layer held with no geometry column · geometry · material · catalogue · 1 · no · 2026-07-30
63. `column-default-asserts-unasked-fact` · No literal column default may assert a fact about a subject (business, property, county) that nobody checked · null_as_value · material · catalogue · none returned · no · 2026-09-26
64. `confidentiality-flag-on-six-address-layers-undeclared` · Six county and city address-point layers carry a confidentiality or redaction flag and none was declared - the fourth PII surface found t... · access_control · material · catalogue · none returned · no · 2026-08-16
65. `declared-role-omits-an-ordinal-sibling-column` · A column role is declared on one numbered column while its numbered siblings on the same table are left undeclared - so anything reading ... · completeness · material · catalogue · none returned · no · 2026-08-16
66. `DEF-008` · table exists but empty · completeness · material · catalogue · none returned · no · 2026-07-24
67. `fdep-clm-no-contaminant-field` · fdep_clm records a cleanup site category/status but not the substance in the ground · completeness · material · catalogue · none returned · yes (paid report) · not recorded
68. `hialeah-parcel-layer-loaded-twice-as-zoning-and-flu-carrying-owner-pii` · One Hialeah PARCEL layer is loaded twice under two names, registered as zoning and as future land use, and carries owner names and mailin... · entity_confusion · material · catalogue · none returned · no · 2026-08-15
69. `one-parcel-layer-loaded-twice-as-zoning-and-land-use` · The same parcel layer is loaded under two names and registered as two concepts because layer_resolution cannot record WHICH COLUMN answer... · entity_confusion · cosmetic · catalogue · none returned · no · 2026-08-15
70. `parcels-staging-geometry-read-not-aggregated` · a function reads parcels_staging GEOMETRY directly instead of via _parcel_geom_agg/resolve_parcel_geometry (fragment undercount, DEF-003) · geometry · material · catalogue · none returned · no · 2026-08-12
71. `payload-speaks-sixteen-absence-dialects` · The served payload uses 16 distinct absence values across 50 getters, and nothing marks which assert absence versus admit ignorance · resolution_mislabelling · material · catalogue · none returned · no · 2026-08-22
72. `race-and-ethnicity-counts-in-a-parcel-joinable-layer` · orange_census_tracts_2020 carries white/black/asian/amindian/hawaiian/hispanic/other counts and is spatially joinable to a parcel - a fai... · access_control · material · catalogue · none returned · no · 2026-08-17
73. `registry-entry-without-table` · A source is registered as loaded while its table does not exist - the registry asserts something false · completeness · cosmetic · catalogue · none returned · no · 2026-08-14
74. `table-inventory-is-a-snapshot-that-drifts` · table_inventory is a hand-populated snapshot last verified 2026-07-30, not a live view - it disagrees with measured reality on 397 tables... · temporal · cosmetic · catalogue · none returned · no · 2026-08-15
75. `table-provenance-comment-missing` · A registered table with no PROVENANCE comment on it - provenance exists only in the registry and does not travel with the table · completeness · cosmetic · catalogue · none returned · no · 2026-08-11
76. `the-resolver-is-documentation-not-plumbing` · ONE of 75 served getter functions calls resolve_layer. The resolver describes the system; the functions bypass it and hardcode tables. Ev... · resolution_mislabelling · cosmetic · catalogue · none returned · no · 2026-08-16
