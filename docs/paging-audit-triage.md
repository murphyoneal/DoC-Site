
=========================================================
## PAGING-CORRUPTION AUDIT - RE-TRIAGE + FIRST REMEDIATION WAVE (2026-07-20)
Harness: ~/repull_fix.py (ogr2ogr paging) and ~/repull_chunked.py (explicit resultOffset).
Both gate on a returnIdsOnly set-diff BEFORE touching the live table, and swap via
TRUNCATE+INSERT from <t>_stg so dependents/indexes survive (never -overwrite).

### *** THE AUDIT'S PRONG 1 HAS ~50% FALSE POSITIVES ***
Prong 1 compared count(*) vs count(distinct **objectid**). But `objectid` is NOT necessarily the
layer's OID. Whenever an ArcGIS layer is built from a join/export, the real OID becomes
OBJECTID_1 (or OBJECTID_12 / ESRI_OID) and the ORIGINAL `objectid` survives as a plain,
legitimately-duplicable attribute.
PROOF - gadsden_parcels_govt_source, the audit's worst case at "50.0% dupes":
   objectid    34,690 rows / 17,345 distinct   <- the flagged column, an ATTRIBUTE
   objectid_1  34,690 rows / 34,690 distinct   <- the REAL OID, perfectly clean
   returnIdsOnly = 34,690 = exactly what is loaded => NO paging corruption at all.
   (It does have a real but DIFFERENT problem: each parcel appears twice, once with real area
    and once as a ZERO-AREA degenerate polygon. A source data-quality issue; re-pulling it
    would have been pure wasted work and would not have fixed anything.)
RE-TRIAGE of the 61 Bucket A tables (cheap internal test, no source needed: does ANY
source-derived column hold a distinct value for every row?):
   32 LIKELY FALSE POSITIVES  (row-complete; audit flagged a non-OID column)
   29 GENUINE SUSPECTS
SECOND-ORDER TRAP inside the re-triage itself: "a unique column exists" is only evidence if the
column is SOURCE-derived. fema_flood_zones.id, hydrology_waterbodies.id and broward_ev_charging.fid
are LOCAL SERIALS (default nextval) - unique by construction, proving nothing. Those 3 plus
school_attendance_zones (matched only on geom_wkt, a geometry string, not an id) were DOWNGRADED
back to suspect. Always check pg_attrdef for nextval before trusting a uniqueness test.

### REGISTRY COVERAGE IS THE REAL BLOCKER
Of 62 Bucket A tables only 17 are in data_source_registry with a source_url.
45 UNREGISTERED, holding 1,231,074 rows - including the top targets fema_flood_zones (101,200),
traffic_aadt (158,403), walton_parcels, bay_parcels, columbia_parcels. These cannot be re-pulled
mechanically; each needs source re-resolution first (resolver ladder in county-source-resolution).
Bucket B: only 3 of 13 registered.

### REMEDIATED THIS WAVE (9 tables, gate-verified 0 missing / 0 extra)
   bay_zoning                877 dupes -> 0
   bay_future_land_use       889 dupes -> 0
   martin_zoning             716 dupes -> 0
   martin_future_land_use    698 dupes -> 0
   palmbeach_subdivisions    169 dupes -> 0
   palmbeach_future_land_use 147 dupes -> 0
   gulf_flood_zones          110 dupes -> 0
   franklin_zoning            98 dupes -> 0
   franklin_flood_zones        7 dupes -> 0
   = 3,711 real features recovered. Row counts unchanged; the dupes were REPLACING real features.
Registry rows stamped with last_count + remediation note.

### HARNESS LESSONS
* HONOUR THE REGISTERED TECHNIQUE. franklin_zoning is geojson_paged for a reason: ESRIJSON types
  its OID `fid` as numeric(4) and 11451 overflows the COPY. Forcing f=json reproduced the old bug.
* VERIFY AGAINST THE LAYER'S REAL OID, read from layer metadata (objectIdField, else the
  esriFieldTypeOID field, else returnIdsOnly.objectIdFieldName) - never a column named "objectid".
  Note palmbeach/others declare objectIdField=null while still HAVING an OID-typed field.
* The gate works: it refused 3 bad swaps and left every live table intact.

### WALL: palmbeach_zoning - INCONSISTENT SERVER, NOT FIXABLE BY RE-PULL
Live table is TRUNCATED: 1,597 rows vs source 2,178 (581 missing), on top of 236 dupes.
Four attempts returned 2,088 / 1,493 / 1,577 distinct - and one run produced 316 objectids that
are ABSENT from the same server's own returnIdsOnly list. Ids and features therefore come from
DIFFERENT backends => maps.co.palm-beach.fl.us is load-balanced over replicas holding different
data. Pure-python ordered paging once got a clean 2,178, so a sticky-session/retry-until-stable
strategy might work, but this is not a paging-parameter bug and must not be forced.
Logged as a WALL in the registry notes. palmbeach_zoning/subdivisions/future_land_use share this
host - the other two gated clean, so the instability is intermittent, not constant.

### STILL OPEN
Prong 2 (returnIdsOnly set-diff vs live source) is the only check for CLEAN TRUNCATION - and
palmbeach_zoning proves truncation is real and invisible to Prong 1 (it had dupes AND was 581
rows short). Run Prong 2 across the registered 261 first, since those need no re-resolution.
