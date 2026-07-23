
=========================================================
## us_ar REBUILD - clean reference implementation, FL's template (2026-07-20)
schema `us_ar`; box `us_ar.crittenden_parcels_raw` (27,620 / 27,620 distinct, native 26915);
plug `us_ar.parcels` MATERIALIZED (27,157 parcels, 12 MB, GiST+btree). Old `ar` schema DROPPED
(no external dependents). All 5 validations PASS.

### CORRUPTION CONFIRMED AND REPAIRED
Old ar box: 27,620 rows / 27,420 distinct objectid = 200 duplicated, 200 REAL PARCELS MISSING.
My original AR report said "source=27620 loaded=27620 MATCH=True" -- that check was incapable
of seeing it. Same failure as BC. Root cause: ArcGIS paging with no explicit sort.
FIX: orderByFields=objectid ASC. Gate: returnIdsOnly set-diff -> 0 missing / 0 extra.
Set-diff NEW vs OLD: 200 recovered, 0 lost. Recovered rows are real (named owners in West
Memphis / Marion, incl. a $4,480,950 commercial parcel). distinct parcelid 27,127 -> 27,157.

### *** NEW LESSON: SAME CONTRACT FIELD, OPPOSITE AGGREGATION PER JURISDICTION ***
land_area_acres:
  us_ar -> MAX(taxarea).  taxarea is the PARCEL's area REPEATED on every multipart piece
                          (verified: all 426 multipart parcels have exactly 1 distinct taxarea).
                          SUM would multiply acreage by the part count.
  ca_bc -> SUM(feature_area_sqm). That one IS per-polygon geometry area.
Do NOT copy an aggregation rule between jurisdictions. Verify per source.
Multipart composition also verified before unioning (ratified "union verified splits only"):
  426 multipart parcelids = 117 genuine disjoint splits + 323 duplicate geometries + 4 partial
  overlaps. ST_Union is correct for all three (duplicates collapse, splits combine).

### *** MATERIALIZED VIEWS ARE NOT IN information_schema.columns ***
Validation 3 reported FAIL with zero column rows. The plug was fine -- matviews are not
SQL-standard objects so information_schema.columns returns NOTHING for them. Any contract
conformance check against a materialized plug MUST read pg_attribute/pg_class instead, or it
silently "fails" every matview. This will hit FL's plug immediately (it must be materialized).

### CONTRACT PARITY PROVEN ACROSS COUNTRIES AND OBJECT TYPES
column signature of ca_bc.parcels (plain VIEW, Canada, SGC) == us_ar.parcels (MATVIEW, US,
FIPS), all 16 fields identical in name/type/order. This is the actual proof the contract works.

### AR COVERAGE (contrast with BC's partial-coverage box)
FULL: parcel_id, owner_name, land_use_code, market_value, land_value, improvement_value,
      value_currency, land_area_acres, geometry, source_provider, source_extract_date, admin1_abbr
partial: situs_address 98.2%, postal_code 98.5%, situs_city 100.0% (10 rows null)
AR fills every field BC leaves empty (owner/value/address) -- the two boxes together exercise
both the full-coverage and partial-coverage paths of the contract.

### PERF (confirms the ratified materialization decision)
single-parcel lookup on the materialized+indexed plug: 0.066s, plan = Index Scan on the matview
itself, touching NO underlying table and NO geo_reference (the join is resolved at refresh time).
Compare ca_bc.parcels as a PLAIN view: 2.87s for the same shape of lookup.
=> materializing also makes VALIDATION 1 (isolation) trivially true: the plan reads one relation.

### REFRESH CAVEAT CARRIED FORWARD
ogr2ogr -overwrite on a box DROPS dependent plugs (CASCADE), it does not just invalidate them.
So a box reload = re-pull, then RECREATE plug, then reindex. REFRESH MATERIALIZED VIEW alone is
not enough after an -overwrite reload. Must be wired into ~/master_refresh.py before FL plugs.
