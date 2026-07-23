
=========================================================
## PRONG 2 COMPLETE - authoritative completeness audit, all 261 registered sources (2026-07-20)
Script ~/prong2.py, results persisted to public.paging_audit_prong2 (durable, re-runnable).
Method: read the layer's REAL OID from metadata (objectIdField -> esriFieldTypeOID field ->
returnIdsOnly.objectIdFieldName), pull the uncapped returnIdsOnly set, set-diff vs the load.
Immune to Prong 1's wrong-column error, and the ONLY check that sees clean truncation.

### RESULT: 188 clean / 52 missing / 4 extra / 1 truncated / 5 no_oid_column / 2 source_dead / 9 non-arcgis

### *** DO NOT QUOTE "229,346 MISSING" - THAT NUMBER CONFLATES TWO DIFFERENT THINGS ***
The raw sum of `missing` is 229,346, but most of it is NOT data loss. Split by whether the row
count is actually short (shortfall = source_ids - loaded_rows):
  A) GENUINE SHORTFALL - 41 tables, **20,519 rows actually missing**
  B) OID CHURN - 9 tables, row counts INTACT, source reassigned OIDs since our pull.
     e.g. highlands_zoning 116,942 = 116,942 rows but 10,743 different OIDs;
          marion_future_land_use 259,022 = 259,022 with 5,681 different;
          leon_address_points loaded 154,932 > source 154,445.
     Counties reassign OBJECTIDs when they reload a layer, so OID drift = STALE EXTRACT, not loss.
     Real signal there is "your copy is older than the source", i.e. a refresh trigger.
  C) FULL OID MISMATCH (4 tables) - missing ~= extra ~= entire table: bay_address_points
     (150,785 vs 150,826), manatee_zoning, osceola_zoning, sumter_parcels (source returns 0 ids).
     Whole-layer republish or wrong endpoint; needs source re-resolution, not a re-pull.

### *** THE HEADLINE: PRONG 1's "CONFIRMED CLEAN" PARCEL CORE IS SHORT ***
Six of the major-county parcel tables Prong 1 listed as clean are missing rows:
   orange_parcels_govt_source     15,000 short of 496,798   <- 73% of all genuine loss
   manatee_parcels_govt_source     1,130 short of 338,349
   lee_parcels_govt_source           294 short of 564,721
   volusia_parcels_govt_source       188 short of 286,001
   pinellas_parcels_govt_source        8 short of 437,085
   sarasota_parcels_govt_source        3 short of 308,079
Prong 1 could never have seen these: clean truncation leaves NO duplicate behind. This is the
whole justification for Prong 2 and it paid off on the property core specifically.
orange's 15,000 is suspiciously round (15 x 1,000 = maxRecordCount pages) - a page-boundary loss.

### SHORTFALL BY CATEGORY (20,519 total)
   parcels        10 tables  16,695 rows      address_points 10 tables   2,392
   flood_zones     7 tables     803           zoning          5 tables     603
   future_land_use 6 tables      17           subdivisions    3 tables       9

### NON-ACTIONABLE BUCKETS
  no_oid_column (5): leon_parks, santarosa_{flu,subdivisions,zoning}, seminole_subdivisions -
     the layer's OID isn't stored in our table, so Prong 2 can't verify. Needs a natural-key check.
  source_dead (2): hendry_parks (non-JSON response), miamidade_code_enforcement_requests
     (registry stores a {2015,2019,2023} brace-expansion pattern, not a real URL - it's a
     multi-service source the harness can't probe as one layer).
  skipped_not_arcgis (9): duval_{flood,flu,zoning} (materialized_from_parcels), EPA/FEMA APIs,
     burn detection, PDF sources - these belong to Prong 3.

### REMEDIATION WAVE 2 LAUNCHED
~/repull_fix.py on orange, manatee(parcels+address), lee, volusia, indianriver, baker parcels.
Same returnIdsOnly gate + TRUNCATE/INSERT swap. Log ~/repull_wave2.log.
