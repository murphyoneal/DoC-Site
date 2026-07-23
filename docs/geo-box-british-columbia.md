
=========================================================
## CA / BC / CAPITAL RD TEST BOX - globalized backbone PROVEN (2026-07-20)
schema `ca_bc`; box `ca_bc.crd_parcels_raw` (182,971 rows, native EPSG:3005 BC Albers);
plug `ca_bc.parcels` (182,969 contract rows); demo matview `ca_bc.parcels_mat`.
All 4 validations PASS.

### SOURCE
maps.gov.bc.ca/arcgis/rest/services/whse/bcgw_pub_whse_cadastre/MapServer/0 (authoritative;
found via AGOL item ce7fd87476b54100a3b158c9dae7e9b7). The briefed bc-er.ca mirror returns a
metadata stub with NO fields/geometryType - unusable. Province total 2,490,965.
CRD FILTER RESOLVED BY ATTRIBUTE, no spatial clip needed: REGIONAL_DISTRICT='Capital Regional
District' -> 182,971. (The brief warned the fabric might lack an admin attribute; it has one.)

### *** THE BIG ONE: A MATCHING ROW COUNT THAT WAS A LIE ***
First pull returned EXACTLY 182,971 rows = source count. It was still wrong.
  distinct OBJECTID = 182,946 -> 25 rows duplicated, 25 REAL PARCELS MISSING.
OBJECTID is unique by definition in ArcGIS, so distinct(objectid) < rowcount is proof of
paging corruption. ArcGIS paging WITHOUT an explicit sort has no stable order: pages overlap
and skip. The totals matched by coincidence.
FIX: add &orderByFields=OBJECTID ASC to the query URL. Re-pull -> 182,971 rows / 182,971
distinct, and a full set-diff against the source's own returnIdsOnly list = 0 missing, 0 extra.
GROUND TRUTH TECHNIQUE: `returnIdsOnly=true` returns the COMPLETE objectid list in one response
(not capped by maxRecordCount). Diff that set against the loaded set. This is the only real
verification for a paged ArcGIS pull - row-count equality proves nothing.
KNOCK-ON: the bogus dupes also inflated apparent multipart parcels (27 collapsed -> really 2).

### OTHER FINDINGS
* BBOX CAUGHT 2 SOURCE ATTRIBUTE ERRORS: 2 of 182,971 rows are labelled Capital Regional
  District but sit at 51.5N/52.1N in the Cariboo ~400km away; one carries plan PGP38273
  (PGP = Prince George prefix). Retained (source asserts CRD) + flagged in the view comment.
  Clean extent -124.503..-123.008 / 48.300..49.082 = true CRD.
* COVERAGE GAP IS WIDER THAN BRIEFED. Brief predicted owner/value NULL. Reality: PMBC has NO
  civic address or postal field AT ALL -> situs_address and postal_code are ALSO 0%.
  Only locational attribute is MUNICIPALITY. Contract coverage for BC:
     FULL   : land_use_code, value_currency, land_area_acres, geometry, source_provider,
              source_extract_date
     PARTIAL: parcel_id 91.0% (16,437 untitled fabric rows have no PID),
              situs_city 89.7% ('Rural' = unincorporated -> NULL)
     EMPTY  : owner_name, situs_address, postal_code, market_value, land_value, improvement_value
* OWNER_TYPE IS A TRAP: it exists and looks like ownership, but it is a CLASSIFICATION
  (Private / Crown Provincial / Federal / Local Government / ...), NOT an owner name.
  Deliberately NOT mapped to owner_name. Same class of error as AR's assessvalue.
* Oracle-backed BCGW: `PID <> ''` matches NOTHING because Oracle treats '' AS NULL. Use IS NULL.
  A naive "populated" check returns 0 and reads as "no PIDs exist".
* No publication-date field (unlike AR CAMP pubdate) -> source_extract_date = per-row
  WHEN_UPDATED. Contract friction: per-extract provenance is not universally available.
* MUNICIPALITY is a legal entity name ("Victoria, The Corporation of the City of") ->
  split on first comma in the plug.

### ANSWERS THE GATED §11 QUESTION: MATERIALIZED SPATIAL PLUGS ARE REQUIRED
Parcel-grain GROUP BY means the predicate CANNOT push down: parcel_id is max(pid), an
aggregate, not the group key, so the plan aggregates all 183k rows (ST_Union + ST_Transform)
BEFORE filtering. Measured on ca_bc.parcels:
     single-parcel lookup  2.866s -> 0.050s   58x    (matview + btree)
     spatial bbox query    2.821s -> 0.104s   27x    (matview + GiST)
     filter by city        0.331s -> 0.061s    5x
     materialize 4.3s + index 1.6s, 109 MB for 182,969 rows.
FL is ~56x larger (10.3M) => a plain-view single-parcel lookup extrapolates to ~160 SECONDS.
VERDICT: do NOT build us_fl.parcels as a plain view. Materialize + index, refresh on box reload.

### OPERATIONAL: RELOADING A BOX DESTROYS ITS PLUG
ogr2ogr -overwrite drops+recreates the raw table, CASCADE-dropping the dependent view. The
re-pull silently deleted ca_bc.parcels. Any box refresh must recreate plugs afterwards (or use
a staging-swap like ~/master_refresh.py). This will bite the monthly refresh once FL has plugs.

### AR PLUG IS BROKEN BY THE RE-KEY (pre-existing, found while here)
ar.parcels still emits bare geo_id '05035'; geo_reference now holds 'US-05035'.
  ar.parcels JOIN geo_reference ON geo_id  ->  ZERO ROWS. Silent: a join returning nothing
  does not error. AR's validation #2 would now FAIL.
  Joining on (country_iso, national_code) instead returns the correct 27,620 -> confirms the
  BC brief's rule change is the right fix. Feeds §11 open item "rebuild ar.parcels -> us_ar.parcels".
