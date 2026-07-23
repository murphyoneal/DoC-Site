
=========================================================
## AR / CRITTENDEN TEST BOX - modular box/plug pattern PROVEN (2026-07-20)
schema `ar`; box `ar.crittenden_parcels_raw` (27,620 rows, native EPSG:26915); plug view `ar.parcels`.
All 4 validations PASS (isolation / router join / contract conformance / cross-state safety).

### SOURCE (resolved by direct probe, not from the task's documented path)
gis.arkansas.gov/arcgis/rest/services/FEATURESERVICES/Planning_Cadastre/FeatureServer/6
  = PARCEL_POLYGON_CAMP (layer 0 = PARCEL_CENTROID_CAMP, same 37 attrs, point geom)
  statewide 2,117,780 parcels; countyfips='05035' -> 27,620 (loaded count matched exactly)
  maxRecordCount 200, supportsPagination true, native SRID 26915 (NAD83/UTM 15N)
  geostor.arkansas.gov resolves to the SAME server. The FTP path in the task was not needed.
BBOX VERIFIED: -90.507..-90.071 lon, 34.835..35.442 lat = eastern AR across from Memphis. Correct.

### DELIBERATE DEVIATIONS FROM ~/fast_pull.py (required by the box/plug rules)
* NO -t_srs. Reprojection is normalization -> belongs in the plug. Box keeps native 26915.
  This turned out to be the pattern's best proof: the plug absorbed a CRS difference between
  states with zero change to the raw box.
* f=json (ESRIJSON) NOT geojson. GeoJSON is ALWAYS WGS84 -- using it would have silently
  reprojected on ingest and destroyed the "raw as delivered" property. Non-obvious trap.

### THE HEADLINE MAPPING FINDING
`assessvalue` -- the CAMP column whose NAME matches the contract's assessed_value -- is
**100% NULL** (0/27,620). The real money column is `totalvalue`, which equals landvalue+impvalue
for ALL 27,620 rows and shows NO 20% Arkansas assessment ratio => it is MARKET value, i.e.
semantically FL "just value", NOT statutory assessed value.
A naive name-matching mapping would have produced a 100%-NULL column and looked like
"Arkansas has no values", when AR actually has complete value data.
=> PROPOSED CONTRACT CHANGE: rename assessed_value -> market_value, and add land_value +
   improvement_value (both 100% populated in AR natively).

### OTHER FRICTION (the real findings)
* NO land-use field exists in CAMP. `parceltype` (2-char) is the real classification.
  VERIFIED EMPIRICALLY that the 2nd letter = improved/vacant for R/A/C/I classes: every one of
  RV(4160)/AV(3863)/CV(481) has impvalue=0, while CI/AI/II have zero such rows. For E (exempt)
  the 2nd letter is a subtype instead (EG/ER/EC/ES/EH/EB). Did not invent a decode table.
* parcel_id IS NOT UNIQUE: 455 ids span multiple rows = multi-part parcels stored as separate
  polygons (owner/value/address identical across parts). (geo_id,parcel_id) is NOT a PK.
* adrzip5 is a native INTEGER (structurally cannot hold leading-zero zips -- fine for AR which
  has none, but the CONTRACT must be text). 419 rows are 0 = missing sentinel -> mapped to NULL.
  ~12 more are out of range incl. a LODI **CA** row => the "physical address" fields occasionally
  carry mailing addresses. Passed through rather than silently scrubbed.
* subdivision 100% NULL. sourcedate has 2 sentinel rows < 1900. 6 rows invalid geometry (passed
  through unrepaired). adrlabel has doubled internal spaces -> collapsed in the view.
* camadate/pubdate/dataprov are single-valued (2026-03-11 / 2026-04-01 / 'EDGE') => provenance is
  per-extract, not per-parcel. source_extract_date <- pubdate.

### PATTERN VERDICT
The box/plug separation held. Everything AR threw at it (different CRS, different value
semantics, a null-sentinel integer zip, no land-use field, non-unique parcel ids) was absorbed
in the view without reshaping the raw table. Isolation is real: the EXPLAIN plan for an
ar.parcels lookup touches exactly one relation, ar.crittenden_parcels_raw, and no FL object.
COST NOTED: st_transform runs per-query. For production scale, either store a 4326 column in
the box (breaks "raw") or materialize the plug. Not an issue at 27k rows.
