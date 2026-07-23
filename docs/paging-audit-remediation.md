
=========================================================
## REMEDIATION WAVES 2-3 + PRONG 3 (2026-07-20)

### RECOVERED SO FAR (all gate-verified 0 missing / 0 extra before swap)
wave 1 (9 tables, dupe corruption)      3,711 features
wave 2  manatee_parcels        +1,130   manatee_address_points +1,391
        lee_parcels              +294   volusia_parcels          +188
wave 3  indianriver_parcels       +37   baker_parcels             +33
        hamilton_parcels           +1   jefferson_parcels          +1
        (pinellas/sarasota parcels + 4 address-point tables still running)
orange_parcels (+15,000 expected) relaunched after its service came back.

### HARNESS BUG FOUND BY baker_parcels
The before/after stats hardcoded `count(distinct objectid)`. baker's table stores the layer OID
as `fid` (layer objectIdField='FID') -> UndefinedColumn, job aborted. Same wrong-column family
as the Prong 1 flaw, committed inside the tool built to fix it. FIXED: probe the layer FIRST,
then use the real OID for before/after; if that column isn't in the table, report n/a rather
than crash. Also added a guard: if returnIdsOnly comes back EMPTY, refuse to touch the live
table (a down service returning 0 ids would otherwise look like "source has no rows").

### TRANSIENT SOURCE OUTAGE - orange_parcels
ocgis4.ocfl.net AGOL_Open_Data/MapServer returned `code 500 service unavailable` on EVERY
request (metadata + all offsets) minutes after prong2 had successfully read 496,798 ids from it.
It came back up ~20 min later. Lesson: a source that fails wholesale right after succeeding is
an OUTAGE, not a corrupt endpoint - diagnose before rewriting the puller. The gate did the right
thing: pull failed, live table untouched.

### PRONG 2 no_oid_column BUCKET RESOLVED (count-only fallback)
The layer OID isn't stored in these 5 tables, so a set-diff is impossible; fell back to the
source's returnCountOnly. Weaker (cannot see swapped rows) but catches gross truncation:
   leon_parks              source 245   loaded 244    SHORT 1
   seminole_subdivisions   source 4,254 loaded 4,252  SHORT 2
   santarosa_future_land_use 6,567 vs 6,641  -> we hold 74 MORE than the source
   santarosa_zoning          6,938 vs 6,999  -> 61 more
   santarosa_subdivisions    1,095 vs 1,111  -> 16 more
The santarosa "extra" is the mirror image of OID churn: the SOURCE SHRANK since our pull
(features consolidated/retired). Our copy is stale, not corrupt. Recorded in paging_audit_prong2.

### PRONG 3 - HONEST ASSESSMENT: MY GENERIC CHECK IS TOO WEAK TO CONCLUDE ANYTHING
Ran a natural-key duplicate scan over the 9 non-ArcGIS sources. The heuristic picked
`county_name` for several tables where it is NOT a key, so the "dupes" it reports are
meaningless by construction:
   epa_superfund_facilities      646 rows / 56 counties  -> "590 dupes" = many sites per county
   fl_burn_detection_history   1,809 rows / 67 counties  -> "1,742 dupes" = many years per county
   fl_citizens_policies_by_county 220 / 67               -> multiple products per county
Genuine readings from it:
   fl_insurance_avg_premiums    67 rows / 67 counties, 0 dupes  -> clean 1:1
   martin_parcels               19 parcelid dupes -> multipart parcels (benign; its real OID
                                objectid_1 is unique, already re-triaged as a false positive)
   duval_{zoning,flu,flood}     materialized_from_parcels, 3 cols, no independent source to
                                check against - their integrity is inherited from duval parcels
   fema_disaster_declarations   30 cols, no key matched my list - needs a table-specific key
PRONG 3 THEREFORE REMAINS OPEN. A generic scan cannot do it: each batch source needs its own
declared natural key (e.g. disaster_number+fips_code, epa registry_id, county+product+year).
Do not read the above dupe counts as defects.
