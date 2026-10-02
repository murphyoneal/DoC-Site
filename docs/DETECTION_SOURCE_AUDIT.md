# Detection source audit — ruling 932 (2026-10-02)

**Rule (932).** A control must not learn what counts as wrong from the thing it guards. It needs a second, independent
definition, and when the two disagree, the disagreement is itself the alarm. And: a detection whose population drops to
zero reads red, not green.

**Why.** The public-surface gate's red run removed the ZZ fixture's `test_fixture` row on production, and the gate
still passed (150/150, "0 contractor fixtures"). It read its definition of "fake" from the same registry the control
reads. Fixed by adding an independent source, the reserved ZZ licence range (ruling 723). A reserved row missing from
the registry is now itself a failure.

## Item 1: population zero reads red (migration 203a, applied)

The runner records `population` and `population_state` for every detection:

- **declared:** the detection returned a positive population.
- **zero:** it examined nothing. The runner records it as errored, never green.
- **undeclared:** it returned no population, so an empty population cannot be told from a clean one.

Red run (rolled back, real detections paused):

| Synthetic detection | Result |
|---|---|
| `ok true, population 0` | errored, EMPTY POPULATION |
| `ok true, population 5` | green, declared |
| `ok true` | green, undeclared |

Meta-detection `detection-population-undeclared` is red by design until each detection declares its population.

First full run with 203a (run `e41a6134`), 201 active detections:

| population | green | red | errored |
|---|---|---|---|
| declared | 4 | 9 | |
| undeclared | 112 | 74 | |
| (did not run) | | | 2 |

**112 detections report clean without saying they examined anything.** This is the class the gate fell into.

## Item 2: where each detection learns what "wrong" is

**Method:** each active detection's SQL is read and classified by the sources it touches.

- **registry:** a deletable registry row (`data_source_registry`, `layer_resolution`, `layer_column_map`,
  `test_fixture`, `trade_code_registry`, `derived_table_asof`, `geo_reference`, …).
- **catalog:** the system catalogue (`pg_proc`, `pg_class`, `information_schema`, …).
- **served_path:** calls a served function on fixed inputs.
- **data_only:** reads the data tables themselves.

**This is a lead, not a verdict.** A detection that reads a registry may use it only to scope or join, not to define
"wrong". Whether an independent definition exists has to be decided per detection, by reading it.

| source class | n |
|---|---|
| registry only | 56 |
| registry + catalog | 15 |
| registry + served_path (+catalog) | 7 |
| catalog only | 22 |
| catalog + served_path | 8 |
| served_path only | 23 |
| data_only | 70 |
| **total** | **201** |

Detections that read a registry number 78. Of those, the riskiest are the 39 that are green with no declared
population: delete the registry row they read and they go quietly green.

### The 78 registry-reading detections (riskiest first)

| detection | latest | population | registries read |
|---|---|---|---|
| absence-claim-source-missing-temporal-extent | green | undeclared | data_source_registry |
| business-name-cardinality-unruled | green | undeclared | trade_code_registry |
| business-register-integrity | green | undeclared | trade_code_registry |
| cama-table-loaded-but-unregistered | green | undeclared | data_source_registry |
| chha-not-wireable-as-one-concept | green | undeclared | layer_resolution |
| coastal-only-concept-on-inland-parcel | green | undeclared | geo_reference |
| column-map-points-at-a-column-that-answers-nothing | green | undeclared | layer_column_map |
| contractor-status-vocabulary-and-shape | green | undeclared | test_fixture |
| cross-jurisdiction-layer-leak | green | undeclared | geo_reference, layer_resolution |
| DEF-016 | green | undeclared | layer_resolution |
| DEF-024 | green | undeclared | table_inventory |
| disposition-vocabulary-contradicts-the-unchanged-record-rule | green | undeclared | data_defect_registry |
| fgs-subsidence-voluntary-register | green | undeclared | data_source_registry |
| flood-column-map-points-at-an-internal-id-not-a-zone-code | green | undeclared | layer_column_map |
| flood-zone-value-domain-is-not-uniform-across-67-layers | green | undeclared | layer_column_map |
| golden-report-within-production-timeout | green | undeclared | golden_parcel_run |
| handoff-status-pair-disagrees | green | undeclared | agent_handoff |
| i-declared-six-keys-unsolvable-and-all-six-were-solvable | green | undeclared | layer_column_map |
| layer-trust-flags-stale | green | undeclared | data_source_registry, layer_resolution |
| live-false-statement-finding-unactioned | green | undeclared | agent_handoff |
| miamidade-zoning-wired-to-unincorporated-only | green | undeclared | layer_resolution |
| municipal-boundary-annexation-lag | green | undeclared | data_source_registry |
| municipal-zoning-layers-hold-something-other-than-zoning | green | undeclared | layer_resolution |
| none-intersecting-renders-false-for-any-partial-coverage-layer | green | undeclared | layer_resolution |
| one-firm-published-as-two-tables-sfha-and-non-sfha-split | green | undeclared | layer_resolution |
| parcel-govt-source-two-schemas-two-different-keys | green | undeclared | layer_column_map |
| party-bearing-column-not-declared-in-the-column-map | green | undeclared | layer_column_map, layer_resolution |
| pii-in-amenity-and-parcel-layers-found-by-reading | green | undeclared | layer_column_map |
| registry-derivation-unexpressed | green | undeclared | data_source_registry, layer_resolution |
| registry-page-size-zero | green | undeclared | data_source_registry |
| registry-rowcount-stamp-unreliable | green | undeclared | county_layer_registry |
| relational-layer-key-does-not-reach-the-spine | green | undeclared | layer_resolution |
| reserved-test-fixture-in-public-search | green | undeclared | test_fixture |
| served-table-with-no-registry-entry | green | undeclared | data_source_registry, layer_resolution |
| statute-without-concept | green | undeclared | concept_registry |
| test-fixture-reachable-from-public-search | green | undeclared | test_fixture |
| trade-code-unmapped-must-surface-not-drop | green | undeclared | trade_code_registry |
| trade-display-category-unlabelled | green | undeclared | trade_display_category |
| unverified-layer-activates-on-rowcount-backfill | green | undeclared | layer_resolution |
| active-source-never-fetched | red | undeclared | data_source_registry, source_observation |
| bfe-missing-column-served-as-not-recorded | errored | none | geo_reference, layer_resolution |
| bfe-null-where-the-column-is-absent-not-where-fema-published-none | red | undeclared | layer_resolution |
| cadence-dead-source | red | undeclared | source_observation |
| cama-is-a-table-set-resolved-as-a-single-layer | red | undeclared | layer_resolution |
| cama-role-concept-must-resolve-exactly-one-table | red | undeclared | layer_resolution |
| citrus-sumter-firm-exact-thousand-truncation-suspect | red | undeclared | layer_resolution |
| compat-views-pending-retirement | red | undeclared | flood_layer_column_map |
| concept-registered-but-unwired | red | undeclared | concept_registry, layer_resolution |
| confidentiality-flag-on-six-address-layers-undeclared | red | undeclared | layer_column_map |
| county-name-saint-vs-st | red | undeclared | geo_reference |
| county-parcel-keys-declared-without-measurement-six-of-ten-join-at-zero | red | undeclared | layer_column_map |
| county-parcel-layer-disagrees-with-the-statewide-spine-both-ways | red | undeclared | data_source_registry, geo_reference |
| declared-role-omits-an-ordinal-sibling-column | red | undeclared | layer_column_map |
| DEF-001 | red | declared | county_layer_registry |
| DEF-005 | red | declared | county_layer_registry |
| DEF-006 | errored | none | layer_resolution |
| DEF-007 | red | undeclared | layer_resolution |
| DEF-008 | red | undeclared | layer_resolution |
| DEF-009 | red | undeclared | data_source_registry |
| DEF-017 | red | declared | county_layer_registry |
| derived-deed-chain-behind-source | red | undeclared | derived_table_asof |
| derived-permit-history-behind-source | red | undeclared | derived_table_asof |
| detection-population-undeclared | red | declared | data_defect_registry, defect_detection_runs |
| erp-easement-type-is-technician-notes-not-a-classification | red | undeclared | layer_column_map |
| hialeah-parcel-layer-loaded-twice-as-zoning-and-flu-carrying-owner-pii | red | undeclared | layer_resolution |
| layer-resolution-row-unverified | red | undeclared | layer_resolution |
| listed-species-habitat-is-three-counties-of-sixty-seven | red | undeclared | layer_resolution |
| miamidade-municipal-zoning-inert-on-null-rowcount | red | undeclared | layer_resolution |
| one-parcel-layer-loaded-twice-as-zoning-and-land-use | red | undeclared | layer_resolution |
| R281_CENSUS_ZERO_COLUMN_WIRED_TO_A_CONCEPT | red | undeclared | column_claim, layer_column_map |
| registry-entry-without-table | red | undeclared | data_source_registry |
| resolve-layer-cannot-compose | green | declared | layer_resolution |
| resolver-picks-one-of-many-silently | red | undeclared | layer_resolution |
| resolver-single-county-geometry-assumptions | red | undeclared | layer_resolution |
| table-inventory-is-a-snapshot-that-drifts | red | undeclared | data_source_registry, layer_resolution, table_inventory |
| table-provenance-comment-missing | red | undeclared | data_source_registry |
| verification-baseline-header-off-by-one | red | undeclared | data_source_registry |
| zoning-code-is-a-composite-carrying-a-jurisdiction-prefix | red | undeclared | layer_column_map |

## Already fixed this way

- **Public-surface gate:** registry UNION the reserved ZZ range, and a disagreement fails (PR #134).

## Next (932 item 2)

For each of the 39 green-and-undeclared registry readers, find an independent definition (the data, the catalogue,
or a served call), add a population, and make the two sources' disagreement the alarm. Where no independent source
exists, the detection's own notes must say so.
