# Autonomous county pull — running notes
Started:  (session 2026-07-13)
Mode: full-auto, step-gated escalation only for data-safety ambiguity.

## Stuck layers (county | layer | tried | real error)
(none yet)

## Manual-investigation flags
- St. Petersburg-major (county_coverage_status 0/10, priority_tier=major): NO county-level tables exist, only stpete_city_*. Likely a phantom/duplicate row (no "St. Petersburg county"; Pinellas is the county). HELD for human decision — do not pull or mark.

## Tracker reconciliations (stale rows corrected from real table counts)
(pending)

## Progress 
### Completed / corrected
- Citrus: verified existing import (148379 parcels = exact shp match, SRID 4326, correct bbox); LOGGED to tracker as 1/10 (parcels only).
- Lake: tracker was stale 1/10 -> RECONCILED to 8/10 (real counts: parcels 217858, FLU 103233, address 247851, subdivisions, schools, fire, hospitals, parks). Not-complete: countywide zoning (municipal only), countywide flood (lake_mack partial).
- Osceola: tracker was stale 1/10 -> RECONCILED to 6/10 (zoning 2561, FLU 842, schools, fire, hospitals, parks, +census). Missing: parcels, address points, subdivisions, flood.

### Data-error near-misses (caught by verify-first discipline)
- parcels_staging co_no is DOR ALPHABETICAL code: Broward=16, Duval=26, Citrus=19. Do NOT assume co_no=16 is Duval.

### Duval investigation
- COJ ArcGIS REST alive: https://maps.coj.net/coj/rest/services (v11.1). Folders are OPERATIONAL only (JFRD fire, Parks, EvacuationEdits, SolidWaste, Utilities, Geocode, Library). PAMO folder EMPTY. No cadastral parcels / zoning / FLU / address service on this server.
- opendata.coj.net/data.json and gisweb.coj.net -> no response (no hub there).
- Duval baseline parcels DO exist statewide: parcels_staging co_no=26 = 398063.
- OPEN: county-specific Duval parcels/zoning would need Duval County Property Appraiser bulk download (URL not yet located). Pending business-rule decision on whether statewide baseline suffices.

## Held for human decision
- St. Petersburg-major (0/10, major): phantom/duplicate row, no county-level tables. DO NOT act.
- BUSINESS RULE: does statewide parcels_staging satisfy the "parcels" category, or must each county have its own richer parcel table? Affects every remaining county.

## Sumter (logged to tracker 2/10: zoning+FLU)
### STUCK: Sumter parcels
- County REST gis.sumtercountyfl.gov: NO public parcels service (checked Interactive[FLU_Zoning,Tourism], Public[Cityworks], Operations[fire/geocoder/stormwater], DevelopmentServices[zoning/FLU/flood], Engineering[empty], RequestedServices[empty]).
- PA GIS app app.sumterpa.com/SCPA-GIS backed by portal gisweb.sumtercountyfl.gov/arcgis, webmap itemId 05f49459280b409a8a3510dce9bbb95c -> 403 not public.
- PA site sumterpa.com: interactive app + PDF download-forms only (parcels likely request-only).
- CONCLUSION: no automated parcels pull available. Statewide parcels_staging co_no baseline only. FLAG for manual follow-up (email PA / submit data request form). Not grinding further.
### Sumter AVAILABLE-but-not-yet-pulled (for a later pass, raise completeness):
- Flood: DevelopmentServices/Development_Services/MapServer layers 11 FEMA Flood Zones, 13 Flood Elevations.
- Fire stations: Operations/FireStations (FeatureServer).
- Parks: Parks_New (FeatureServer, root).

## Duval (tracker 1/10) - parcels STUCK
- COJ ArcGIS maps.coj.net/coj/rest: operational layers only, NO cadastral parcels/zoning (confirmed).
- duvalcad.org = TEXAS Duval CAD (wrong state! FL uses "Property Appraiser"). Avoided.
- FL Duval PA = City of Jacksonville (coj.net/jacksonville.gov). GIS dept page + duvalproperty viewer = legacy reCAPTCHA single-lookup tool, no bulk service. jacksonville.gov GIS page 404 via fetch.
- Third parties (TaxNetUSA/Regrid/Koordinates/Equator) = PAID. FGDL = stale 2018.
- CONCLUSION: no automated Duval parcel bulk download found. Baseline parcels_staging co_no=26=398063 only. FLAG: check COJ GIS dept page manually / request bulk data. Not grinding.
- Duval PULLABLE via working COJ REST (for later completeness): JFRD (Fire_Hexagons), Parks, EvacuationEdits, SolidWaste, Library folders.

## Operational learning: Sumter GIS server throttles
- gis.sumtercountyfl.gov intermittently returns http=000 (connection reset) under rapid requests -> ogr2ogr gets non-JSON, dumps driver list, chunked_pull.py aborts (no retry).
- Sumter flood zones (DevelopmentServices layer 11, 8437 rows): chunked_pull.py FAILED at offset 4000 (got 4000 rows clean). Recovering via chunked_resume.py from 4000 (that script continues past per-chunk failures + reports them).
- LESSON for this server: use chunked_resume.py (tolerant) not chunked_pull.py, or add inter-chunk sleep. Space out requests.

## STOP: Sumter server hard-throttled (backing off)
- Resume from 4000 ALSO failed: offsets 4000-8000 all "Missing features member" (throttle returning non-feature JSON). Even a single diagnostic curl now returns empty (http=000). IP is rate-limited.
- sumter_flood_zones = PARTIAL 4000/8437 (SRID 4326, 0 null geom). NOT counted as a complete category. Left in place for cheap resume-from-4000 after a cooldown (use chunked_resume.py, add inter-chunk sleep).
- Sumter fire/parks pulls NOT attempted (same throttled server) - deferred until cooldown.
- Sumter stays 2/10 (zoning+FLU verified). Do NOT trust sumter_flood_zones as complete.

## Citrus County: 1/10 -> 6/10 (all verified exact-match)
- parcels 148379 (local PA shp, prior), subdivisions 2496 (local PA shp), landuse 197501 (AGOL), zoning 197754 (AGOL, resumed from 162000), address_points 186836 (AGOL), parks 38 (AGOL).
- AGOL org G6NDVglwRcrz6l7N reliable (unlike Sumter county server). One transient blip on zoning@162000, fixed by chunked_resume.
- County hub EXHAUSTED for standard categories. Remaining 4 NOT in hub: flood, fire, hospitals, schools.
- Statewide coverage confirmed in Citrus bbox: fema_flood_zones=5995, hifld_fire_stations=16, hifld_hospitals=3, hifld schools(pub+priv)=37.
## BUSINESS-RULE FLAG (general, affects all counties):
- Do statewide FEMA/HIFLD clipped-to-county count as satisfying flood/fire/hospitals/schools categories, or (like parcels) must there be a county-specific source? Other counties have BOTH patterns in DB (e.g. pasco_fema_flood_zones county-specific vs statewide fema_flood_zones). NEED MURPHY DECISION before clipping for Citrus + remaining counties.

## Parallel batch (Highlands/Hernando/Osceola) + interop lesson
- INTEROP BUG: shell variables (e.g. B="..url.."; "/layer") get BLANKED in backgrounded  jobs -> chunked_pull got "/Zoning/..." with no host, all failed "unknown url type". FIX: always inline FULL URLs in background pull jobs, never shell vars. (Highlands 1st attempt failed this way; nothing partial created; relaunched inline.)
- Hernando: parks=43 verified (AGOL x5zvhhxfUuRDntRe). Has parcels/subdivisions/hospitals/evacuation already. Schools+flood behind Experience Builder apps (no direct REST) - deferred.
- Highlands: relaunched inline - zoning/FLUM/fire/parks(Sebring, maybe city-only)/schools from org xEhz4K4uxbjGXOPE.
- Osceola: address points (Situs_Points, services6 9zKHLCgIwu2HFA5O) pulling. Parcels/subdivisions NOT in county hub (PA hub data-ocpagis 500ed, retry later). Flood = Historic_FEMA on flaky gis.osceola.org/hosting.

## Highlands: real 1/10 -> 6/10 (parallel round, all exact-match)
- Was tracker 3/10 but only parcels actually loaded (zoning/FLUM claimed, not present). Corrected.
- Added (AGOL xEhz4K4uxbjGXOPE, all exact match SRID 4326): zoning=116942, flum=116946, fire_stations=20, parks=17 (Sebring - likely city-only, flagged), schools=19 (HCSB).
- Hub has no address points/subdivisions. Remaining hospitals/flood only via statewide-clip (HELD on business rule).

## Parallel-round summary (Highlands/Hernando/Osceola)
- Highlands 1->6/10 (5 layers). Hernando 6->7/10 (parks). Osceola blocked (empty address layer, PA hub 500).
- NOTE: pool of incomplete non-walled TRACKED counties nearly exhausted (most others marked COMPLETE at 7/10 or walled). Next frontier = statewide-clip categories (need business-rule decision) OR untracked FL counties (not yet in tracker).

## Statewide-clip method VALIDATED (Murphy approved for flood/fire/hospitals/schools; parcels still county-only)
- Built fl_county_boundaries (67 FL counties, TIGERweb State_County layer 1, STATE=12, small-chunk pull via /mnt script to dodge interop quoting + TIGER response-size limits). basename = clean county name. SRID 4326.
- fema_flood_zones.county_name is EMPTY/unusable -> clip flood spatially too. HIFLD points only have state=FL -> spatial clip by boundary.
- METHOD: create {county}_flood_zones/_fire_stations/_hospitals/_public_schools/_private_schools = statewide table JOIN fl_county_boundaries on basename + st_intersects.
- Boundary-clip MORE ACCURATE than bbox (Citrus fire 12 vs bbox 16; schools 33 vs 37 -- bbox wrongly grabbed neighbor-county features).
- CITRUS = 10/10 (first this session): flood 6000, fire 12, hospitals 3, schools 28+5. All SRID 4326, 0 null.
## SCALE-UP PLAN (next):
- Apply clip to fill gaps for tracked counties MISSING flood/fire/hospitals/schools -- must NOT overwrite existing county-specific tables (e.g. osceola_schools, hernando_hospitals, pasco_fema_flood_zones). Gap-fill only.
- Highlands: has county fire+schools already -> clip needs only flood+hospitals (->8/10; addr/subdiv unavailable).
- Hernando: has county hospitals already -> clip needs flood+fire+schools.
- Then untracked FL counties (boundaries ready for all 67).

## KEY FINDING: statewide fema_flood_zones has PATCHY county coverage
- Hernando clip flood = 2 polygons (should be thousands - Gulf coast). Boundary is valid (fire=17, schools=46 clipped fine). So fema_flood_zones does NOT cover Hernando.
- IMPLICATION for scale-up: do NOT blindly clip flood for every county. Must check per-county flood count > threshold; where ~0, flag as flood gap needing county-specific source (some already have it: pasco_fema_flood_zones, orange_fema_flood_zones, marion_fema_flood_*, etc.).
- Fire/hospitals/schools from HIFLD appear to have full FL coverage (statewide state=FL) - clip reliable for those.
## Clip-fill results so far:
- Citrus 10/10 (flood 6000, fire 12, hosp 3, schools 33). Highlands 8/10 (flood 22418, hosp 3 added). Hernando: fire 17, schools 46 added; flood GAP (dropped); corrected to 6/10.

## CLIP BATCH (tracked counties) DONE 2026-07-14
- 43 clip tables created (14,781 rows), 60 existing county-specific tables preserved (NOT overwritten), St Johns schools special-cased (sjc_ prefix), 0 errors.
- Big flood adds: Volusia 11061, Seminole 1245, Flagler 461. Fire/hospitals/schools filled for Brevard, Broward, Collier, Duval, Manatee, Martin, Palm Beach, Polk, Sumter, etc.
- FLOOD SOURCE GAPS (9 counties, fema_flood_zones lacks coverage -> flagged, NOT counted): Collier, Duval, Hernando, Martin, Miami-Dade, Osceola, Palm Beach, Pinellas, St. Johns. These need a county-specific flood source.
- Tracker counts incremented by genuinely-new categories (capped 10).
## UNTRACKED EXPANSION started: added 40 previously-untracked FL counties to tracker (tier=minor, 0/10). Next: run same clip for them (instant fire/hosp/school/flood baseline), then discover county hubs for top-population ones (Escambia/Leon/Alachua/Charlotte/Okaloosa/Bay/SantaRosa/IndianRiver/Clay/Monroe).

## MILESTONE 2026-07-14: all 67 FL counties tracked + clip-baselined
- Two clip runs: 43 (tracked) + 177 (untracked) = 220 clip tables, ~74k rows, 0 errors. Every county now has fire/hospitals/schools; flood where FEMA covers.
- 11 counties at 10/10. Avg completeness ~55%.
- MAJOR DATA FINDING: fema_flood_zones covers only ~30 of 67 counties. 37 flood source-gaps flagged (9 tracked + 28 untracked incl many coastal). RECOMMEND: re-pull statewide FEMA NFIP flood to cover all counties, OR county-specific flood pulls.
- REMAINING: untracked 40 counties need county-hub discovery for parcels/zoning/flu/address/subdivisions/parks (per-county GIS, like Citrus/Highlands). Priority order: Escambia, Leon, Alachua, Charlotte, Okaloosa, Bay, Santa Rosa, Indian River, Clay, Monroe, then rest.

## CORRECTIONS 2026-07-14 (honesty)
1. FEMA flood re-pull is NOT a clean one-liner:
   - pull_fema_nfip.py pulls NfipMultipleLossProperties (loss properties), NOT flood zones. Wrong tool.
   - No WSL script pulls fema_flood_zones. It came from FEMA NFHL DFIRM panels, only ~20 FL counties (fips 12xxx: 007,017,027,029,035,039,041,045,049,055,067,069,093,107,117,121,123,125,127,133) + AL/GA border spillover.
   - FEMA NFHL public endpoints (hazards.fema.gov, msc.fema.gov) return 403 from here.
   - REVISED PLAN: do NOT run a separate FEMA re-pull now. Close flood gaps opportunistically during per-county hub discovery (many county hubs carry flood), then FGDL statewide flood or FEMA S3 bulk NFHL for remaining counties as a cleanup pass.
2. Discovery per-county friction: Alachua real hub = org "acgm" (Growth Mgmt), NOT services2/V2PQwgZMTFfgM0Xu (that is a generic public AGOL org with unrelated content). Each untracked county needs its own hub resolution.

## DISCOVERY PHASE (untracked, population-first) 2026-07-14/15
- Alachua: hub=acgm (Alachua County Growth Mgmt). AGOL org self id 7a4aa667d61541c583d9a723c8b349da returned 0 feature-service items on content search; services.arcgis.com/{id} + services1 empty. Org/services host NOT cleanly auto-resolved. FLAGGED for deeper manual resolution (try the acgm hub DCAT domain / TLC-style server). MOVED ON per fail-safe.
- Lesson: {orgkey}.maps.arcgis.com/portals/self first "id" is not reliably the org id; need the hub DCAT feed or a known item url to get the real services host.

## Leon (shortlist) - FAIL-SAFE, moved on
- Hub geodata-tlcgis clean, but AGOL org ptvDyBs1KkcwzQNJ is a cluttered mix: ADDRESSPOINTS=736 (subset, dropped), Future_Land_Use=0, LCPA_POWERBI_TAX_PARCELS=0 (empty shells/views).
- Authoritative Leon layers are on custom servers intervector.leoncountyfl.gov / cotinter.leoncountyfl.gov (MapServer services, e.g. TLC_OverlayParks). Needs enumeration of those servers -> deeper work.
- Nothing bankable yet; got 0 real categories. FLAGGED for deeper resolution (enumerate intervector/cotinter MapServers). MOVED ON per fail-safe (2nd hard case after Alachua).

## Charlotte (shortlist) WIN: 2/10 -> 7/10
- agis3.charlottecountyfl.gov Essentials/CCGISLayers MapServer (f=pjson). All exact-match SRID 4326: addresses(0)=309517, flu(19)=7518, zoning(43)=2459, subdivisions(36)=2870, parks(47)=477. Fire Stations=72 available (could upgrade clip fire).
- REMAINING: parcels ("Accounts" layer not in CCGISLayers) -> try shapefile-gallery.stml direct download or a separate Parcels MapServer. FLAGGED.
- Shortlist so far: Charlotte WIN; Leon+Alachua fail-safe(flagged); Okaloosa needs AGOL/webgis dig.

## Indian River (shortlist) - FAIL-SAFE + SYSTEMATIC FINDING
- AGOL org ircgis (id 67ef75728f1c49dbb25b7a5593d044fb) has 0 hosted feature services (content search total=0); services/services1 empty. Portal facade only.
- SYSTEMATIC PATTERN across shortlist:
  * WIN when county has a discoverable OWN ArcGIS server: Charlotte agis3.charlottecountyfl.gov (CCGISLayers) -> clean masters. (Also Citrus AGOL-hosted, Sumter gis.sumtercountyfl.gov.)
  * RESIST when only an AGOL portal exists (Leon ptvDyBs = empty shells; Alachua acgm = unresolved; Indian River ircgis = 0 hosted services). Real data is on an UNADVERTISED county server that must be found per-county.
- Shortlist tally: Charlotte WIN (2->7/10). Leon/Alachua/Indian River FAIL-SAFE. Okaloosa likely same (AGOL facade + webgis.myokaloosa.com server). Bay/SantaRosa/Clay/Monroe/Nassau not started.
- NEXT best lever: Murphy likely knows the county server hostnames (he has prior-session knowledge). Getting those unblocks the facade counties far faster than blind hunting.

## Charlotte data-integrity thread RESOLVED 2026-07-15
- ROOT: Charlotte had ~25 pre-existing charlotte_* tables (prior run); my discovery pull did not check existing tables (treated untracked=fresh). Fixed discipline: always check existing <county>_* before pulling.
- DUP: dropped my redundant charlotte_flu (identical to prior charlotte_future_land_use, 7518, same bbox). Kept future_land_use (fuller, 12 cols, consistent name).
- REGRESSION (REAL, verified via source): charlotte_ownership was 183617, live source (agis3 CCGISLayers/27 Ownership) = 224615. Re-pulled -> 224615 exact match, 0 null, SRID 4326. Fixed.
- Lesson: verified against SOURCE rather than the relayed 224617 number -- turned out the number was right, but confirming via source is the correct standard.

## Fire hydrants/stations sweep 2026-07-15 (from Charlotte clip false-positive)
- Root: clip has_fire check used %fire% -> *_fire_hydrants falsely satisfied "fire", skipping fire_stations.
- Sweep result: ONLY Flagler affected (Lake had both; Charlotte fixed earlier). 
- flagler_fire_stations=13 via HIFLD clip (Flagler DCAT confirmed county has hydrants but NO fire-stations layer -> clip is the available source). Verified.
- BONUS FINDING: recounting Flagler by direct table check = genuine 7/10 (parcels, flu, schools, fire, hospitals, parks, flood), but tracker had 9/10 -> corrected to 7. Prior count loosely included evacuation_zones/fire_hydrants.
- IMPLICATION: categories_complete is loosely/inconsistently counted across counties -> a systematic recount (consistent 10-category taxonomy, direct table presence) would make the tracker trustworthy. Flagged for follow-up.

## SYSTEMATIC RECOUNT 2026-07-15 (capstone)
- Recomputed categories_complete for all 67 counties by verified table presence, consistent 10-cat taxonomy with naming-variant handling (flu/landuse/flum; parcels/ownership/tax_parcels/property_details; fire_station != fire_hydrants; sjc=St.Johns prefix).
- Verify-before-apply caught a blind spot: seminole_property_details is parcels (pattern missed it) -> added property_detail to parcels pattern. Broward/Polk/Duval decreases verified legitimate (old counts included non-standard layers: bus routes, canals, evacuation, hydrants).
- Result: 21 counties corrected (6 up incl Alachua 3->7, Putnam 3->8, Lake 8->10 -- had prior-run data; 15 down incl Seminole/Broward/Polk/Flagler that had inflated counts), 46 unchanged.
- HONEST corrected statewide picture (67 counties): 3 at 10/10, 19 at 7-9, 25 at 4-6, 20 at 1-3. Avg completeness 52.4% (was inflated ~55%). The tracker completeness numbers are now consistent + verified end-to-end.

=== AUTONOMOUS RUN (all-67 mission) 2026-07-15 ===
## County 1 ALACHUA (was missing flu, address, parks)
- Working org (from pull_alachua.sh): services1.arcgis.com/MiBZ4u97DWldovjI + maps.alachuacounty.us/server (parcels).
- Pulling: alachua_future_land_use (FluCountyWidePublic) = 4812 DONE/verified. alachua_address_points (AddressPointsPublic) + alachua_parks (ACGM_parks) still pulling -- verify on completion (watch address for subset; alt = AddressPoints).
## County 2 BREVARD (missing parcels, flu, subdivisions)
- Server: gis.brevardfl.gov/gissrv/rest/services (v10.91). AGOL org: services2/zfDSLldsAGQfwUz9.
- FOUND flu: Planning_Development/FLU_WKID2881/MapServer. parcels likely in MIRA folder (unconfirmed). subdivisions TBD.
- Brevard server threw http=000 (throttle) after rapid folder fetches -> BACK OFF, resume after cooldown. Do NOT hammer.

## METHOD BREAKTHROUGH 2026-07-15 (use for whole mission)
- chunked_pull.py (one ogr2ogr per 1000 rows) is TOO SLOW (~60s/chunk on some AGOL servers -> 2.5h for a 152k layer). Do NOT use it for large layers.
- USE fast_pull.py (scratchpad, run via /mnt path): single ogr2ogr with -oo FEATURE_SERVER_PAGING=YES = dramatically faster (152k in ~1-2 min).
- CRITICAL: fast_pull MUST include options=-c

## County 3 COLLIER done -> 9/10
- parcels=297410 EXACT (AGOL SlIq32SqARUHIhSx Parcels/FeatureServer/42, gt=500).
- flood=55999 of 57385 (97.6 pct; pooler timeout on one pathological FEMA multipolygon blocks last 1386).
- subdivisions BLOCKED (not in org; county server ags2 unreachable; no REST via search).
## TIMEOUT LIMIT: Supabase pooler enforces a hard statement_timeout that ALTER ROLE cannot override. Use fast_pull with gt=500 (default now). Very complex single polygons can still block the final rows of huge FEMA layers -> accept near-complete, record real count.

=== AUTONOMOUS RUN (resumed after Windows restart) 2026-07-16 ===
## Restart recovery
- All background pulls died in restart (confirmed no procs). notes file survived. fast_pull.py recovered from prior scratchpad -> copied to ~/fast_pull.py (stable).
- INTEROP re-confirmed: loop vars ($h) AND heredoc-written vars ($B,$1,$2) BLANK to empty through the wsl bash -lc double-shell layer, even with quoted <<"EOF". ROBUST FIX ADOPTED: write pull scripts with the Write tool (exact bytes, literal full URLs, zero shell vars) to scratchpad, run via /mnt path. All pulls below used this.
- Verified Alachua interrupted pulls DID land pre-restart: alachua_address_points=152142 (0 nullgeom, 4326, clean full pull not truncated), alachua_parks=161. Alachua genuinely 10/10.

## Starting-10 remaining gaps worked (verify-first, all SRID 4326, 0 null geom)
- BREVARD (was 9/10, missing parcels): found parcels at gis.brevardfl.gov Base_Map/Parcel_New_WKID102100/MapServer/4 (Parcels layer, 352848 src, pagination). -> brevard_parcels [PULLING, target 352848]. MIRA folder was raster-only (parcels not there). Server throttle had cooled.
- FLAGLER (was 7/10, missing zoning/address/subdivisions): services3.arcgis.com/hSKL9bYjhP4rHxSD. DONE exact-match: flagler_unincorporated_zoning 663, flagler_beach_zoning 360, flagler_bunnell_zoning 1034, flagler_marineland_zoning 7 (mirrors existing FLU municipal split), flagler_address_points 94063, flagler_subdivisions 502. -> Flagler now 10/10.
- MARION (was 7/10, missing parcels/address/subdivisions): real host = gis.marionfl.org/public/rest/services (found via web search; /arcgis and maps. hosts are dead). General/Parcels/MapServer layer0=Parcels(284702), layer1=Subdivisions(3469). marion_subdivisions DONE, marion_parcels [PULLING, target 284702]. Address points: NO situs layer (Addressing/0 = 209 grid quadrants; ParcelCentroids = appraisal centroids not addresses) -> LOG-AND-MOVE-ON, flag PA source. Marion -> 9/10.
- SARASOTA (was 8/10, missing flu/subdivisions): ags3.scgov.net/server Hosted folder. sarasota_future_land_use 826, sarasota_subdivisions 5476 (PlatBoundary). DONE. Sarasota -> 10/10.
- ST JOHNS (7/10): host www.gis.sjcfl.us/portal_sjcgis/rest/services. Hosted/subdivisions EXISTS but type=Table geomType=None (NON-SPATIAL plat index: plat_name/map_book/section/twp/rng, no geometry). Pulled 2709 rows then RENAMED sjc_subdivisions -> sjc_plat_index so it does NOT masquerade as / inflate the spatial subdivisions category. No spatial plat polygon layer exists (only Parcel/Parcel_PLSS/Parcel_Condo). St Johns subdivisions = UNAVAILABLE spatially. Flood still FEMA source-gap. No tracker change.
- PINELLAS (7/10): NO subdivisions layer anywhere (checked root, Planning, WebGIS/Parcels, WebGIS/SurveyHistoricalLandRecords, PublicWebGIS(+/Parcels), AGO folder on egis.pinellas.gov). LOG-AND-MOVE-ON, flag manual. Flood = FEMA source-gap. No change.
- HIGHLANDS (8/10): prior note says hub has no address/subdivisions. Not re-attempted this pass (deferred). Stays 8/10.
- COLLIER (9/10): subdivisions previously blocked; not revisited.

## Tracker updates pending (apply after Brevard+Marion parcels verified complete):
- Brevard 9->10, Flagler 7->10, Sarasota 8->10, Marion 7->9. (St Johns/Pinellas/Highlands unchanged.)

## VERIFY-FIRST CATCH 2026-07-16: clip point-category false-positives (SYSTEMATIC, bigger than the fire one)
- Prior session found the %fire% bug (fire_hydrants satisfied "fire", only Flagler affected). This session found the SAME bug class for SCHOOLS and HOSPITALS:
  * %school% matched *_school_zones / *_school_board_district (attendance boundaries) -> clip SKIPPED adding real school POINT layers. Affected: Brevard, Flagler, Sarasota (only had zones, no points).
  * %hospital% matched sarasota_hospital_district (MULTIPOLYGON service district) -> clip skipped sarasota_hospitals points.
- FIXED via HIFLD clip (basename join + ST_Intersects, all SRID-consistent, Murphy-approved method):
  * brevard_public_schools 113, brevard_private_schools 61
  * flagler_public_schools 13, flagler_private_schools 7
  * sarasota_public_schools 62, sarasota_private_schools 32
  * sarasota_hospitals 8
- Verified hospital point layers already OK for Brevard(POINT)/Flagler(MULTIPOINT)/Marion(POINT)/Clay(POINT). Only Sarasota had district-only.
- IMPLICATION (IMPORTANT, mission-wide): the statewide clip batch's has_X checks used loose LIKE %school%/%hospital%/%fire% -> ANY county that had a *_school_zones/_school_board/_hospital_district/_fire_hydrants table but no matching POINT table was silently NOT clipped and may be counted as complete in the tracker. Needs a SYSTEMATIC SWEEP across all 67: for each of {schools,hospitals,fire}, find counties with only the zone/district/hydrant variant and clip the real points. This is the same integrity work as the 2026-07-15 fire sweep but for schools+hospitals. FLAGGED for a dedicated pass.

## Final verified counts this session (all SRID 4326, 0 null geom):
- brevard_parcels 352848 (=src exact). Brevard -> 10/10 (tracker updated).
- marion_parcels 284702 (=src exact), marion_subdivisions 3469 (=src exact). Marion -> 9/10 (address unavailable; updated).
- Flagler 6 layers + schools clip -> 10/10 (updated). Sarasota flu+subdiv + schools/hosp clip -> 10/10 (updated).
- clay_parcels [pulling, target 103680] from maps.clayutility.org Parcels_LGIM/0 (real attrs: PIN/OWNER/USECD/address/legal). Clay 3->4/10 pending verify. Clay planning layers (zoning/flu/address/subdiv/parks) NOT on the utility server (clayutility=CCUA utility authority); need county GIS behind maps.claycountygov.com/clayview/ viewer -> deferred.
- sjc_subdivisions was non-spatial (type=Table) -> renamed sjc_plat_index; St Johns spatial subdivisions UNAVAILABLE. Pinellas subdivisions UNAVAILABLE (checked all folders). Both flood = FEMA source-gap.

## Next-phase breadth (untracked/low counties) 2026-07-16
- CLAY 3->4/10: clay_parcels 103680 (=src exact, 4326, 0 null) from maps.clayutility.org Parcels_LGIM/MapServer/0 (CCUA utility-authority server; real attrs PIN/OWNER/USECD/address/legal). Planning layers (zoning/flu/address/subdiv/parks) NOT on this utility server; need county GIS behind maps.claycountygov.com/clayview/ (viewer webmap not yet resolved). Flood = likely FEMA source-gap. Tracker updated.
- SANTA ROSA 3->8/10: +parcels 115828, zoning 6999, future_land_use 6641, subdivisions 1111, parks 61 (all =src exact, 4326, 0 null). Prefix santarosa_ (matches existing clip fire/hosp/schools). Missing: address (NOT in FL hub DCAT), flood (no table; FEMA source-gap). Tracker updated 8.
  * !!! DATA-INTEGRITY CATCH: top web-search hit for "Santa Rosa County FL parcels" was the Santa Rosa CALIFORNIA org services2.arcgis.com/BhTdzxiJkq4oXsPh (Sonoma Co - Glass/Kincade/Tubbs fire layers, Cotati, CA State Parks). Pulling "Santa_Rosa_Area_Parcels" from it would have injected CA parcels into the FL set. AVOIDED. Authoritative FL org = services.arcgis.com/Eg4L1xEv2R3abuQd, resolved via the FL county open-data hub DCAT feed (santarosagis). LESSON: for "Santa Rosa"/ambiguous names, resolve via the county's own .fl.gov hub DCAT, never trust a bare AGOL org from search. (cf. duvalcad.org=TEXAS earlier.)
  * METHOD REUSABLE: hub DCAT feed at https://<hub-domain>/api/feed/dcat-us/1.1 lists datasets + real rest/services accessURLs -> the reliable per-county org+layer resolver for facade counties.

## SESSION END STATE 2026-07-16 (clean; no in-flight pulls)
- Verified/advanced this session: Alachua confirmed 10, Brevard 9->10, Flagler 7->10, Sarasota 8->10, Marion 7->9, Clay 3->4, Santa Rosa 3->8. Plus schools/hospitals point-clip integrity fixes (Brevard/Flagler/Sarasota) and sjc_subdivisions->sjc_plat_index rename.
- All new tables verified: source-exact row counts, SRID 4326, 0 null geom. Tracker categories_complete set to TRUE verified values (completeness_pct is generated - do not UPDATE it).
- OPEN FOLLOW-UPS (priority order): (1) systematic schools+hospitals point-clip sweep across all 67 (see [[clip-point-category-bug]]); (2) Clay planning layers via clayview viewer; (3) continue untracked counties via hub-DCAT method (Nassau, Bay, Monroe, Walton, then Panhandle rurals); (4) address points for Marion (PA source) + Santa Rosa; (5) flood source-gap counties (St Johns, Pinellas, Osceola, Collier, Duval, Martin, Palm Beach, Miami-Dade, Hernando + untracked coastal) need county-specific or FEMA-NFHL flood.
- Skip-list still honored (not touched): Leon, Indian River, Duval, Escambia, Sumter parcels, Okaloosa.

## ITEM 1 DONE — schools/hospitals/fire point-clip integrity sweep (all 67) 2026-07-16
- Data-driven diagnostic on REAL point-table prefixes (boundary-derived prefixes fail: DB drops spaces -> santarosa/palmbeach/miamidade/indianriver/stlucie; StJohns = sjc+stjohns; Seminole schools = *_public_schools_points/_private_schools_points).
- Clip was ~98% effective. ONLY 2 genuine gaps found+fixed:
  * Lake: had lake_school_zones only -> clipped lake_public_schools 63, lake_private_schools 34.
  * Volusia: had volusia_fire_response_zones + volusia_hospital_districts only -> clipped volusia_fire_stations 53, volusia_hospitals 9. Corrected tracker 9->10 (now genuinely all 10).
- Lake stays 10/10 (schools now genuine points, was zone-only). CAVEAT (pre-existing, not this sweep): lake zoning is municipal-only (montverde/howey) not countywide — borderline category the recount counted.
- Every FL county now has genuine fire/hospitals/schools POINT layers. See [[clip-point-category-bug]] memory (marked DONE).

## ITEM 2 DONE — Clay planning layers (3->8/10) 2026-07-16
- Real Clay county server = maps.claycountygov.com/**server**/rest/services (v10.91), behind the clayview viewer (/arcgis path is 404; had to use /server).
- LOADED (=src exact, verified): clay_subdivisions 3487, clay_address_points 92728, clay_park_infrastructure 521 (Park_Infrastructure/10 - amenity pts, best parks proxy on server), clay_flood_zones 1239 (FEMA_Flood_Zones/1 DFIRM). clay_parcels 103680 kept (from clayutility).
- WALL: clay_zoning + clay_future_land_use. Pathological dense polygons (Zoning/0, FLUM/5): server 500s on large geometry pages (2000/page); small 250-chunks -> "COPY statement failed" (invalid/huge geoms). 5+ attempts across 3 methods (fast_pull default paging, retries, chunked_small 250). LOGGED as wall, dropped empty tables. Would need ST_MakeValid / geometry repair or a GDB download. Clay = 8/10 (parcels,subdiv,address,parks,flood,fire,hosp,schools). Missing zoning,flu.

## ITEM 3 — untracked counties via hub-DCAT
- NASSAU: WALL. PA (ncpafl.com/maps.ncpafl.com) = proprietary tax-map viewer, no open REST (/arcgis + /server = 404). gis.nassaucountyfl.com empty. AGOL "Nassau County Boundaries" hub item resolved to a junk test file (Test_File_GDB_3, personal acct) - FALSE LEAD, not authoritative. qPublic/Schneider elsewhere. No automated pull. FLAG manual (PA bulk request).
- MONROE (Keys): WALL + FALSE-LEAD TRAP. gishub-monroegis.hub.arcgis.com DCAT resolves to org services8/ToWOUVqNUhbTXzVc = **Monroe County OHIO** (verified: parcel coord -80.87,39.67; school "Switzerland of Ohio LSD"; Ohio CAUV field). Pulling would inject OH data. AVOIDED. Real Monroe FL hosts (mcpafl.org 302, gis/maps.monroecounty-fl.gov empty) not serving open REST; PA on qPublic. FLAG manual. (Add to the ambiguous-name trap list: Santa Rosa CA, Monroe OH, Duval TX.)
- BAY: WIN (pulling). gis.baycountyfl.gov BayView/BayView MapServer. bay_parcels 134543, bay_zoning 8393, bay_future_land_use 9602, bay_address_points 150826, bay_parks 107. No subdivision layer in BayView. Bay 4->9/10 expected (missing subdivisions).
- WALTON: WIN (pulling), VERIFIED FL (parcel coord -86.01,30.28; FL parcel# + DOR use code). Org services1/TaXHPwWfIMuzJ7Ov (webmap cad99cad55). walton_parcels 96142, walton_zoning 2735, walton_future_land_use 2733, walton_address_points 70843, walton_flood_zones 8890. No subdiv/parks found in webmap. Walton 3->8/10 expected (missing subdiv,parks).
- METHOD confirmed reusable: AGOL webappviewer -> app item /data -> webmap itemId -> webmap /data operationalLayers[].url = per-county service resolver (used for Walton). Hub DCAT feed = the other resolver (used for Monroe/SantaRosa). ALWAYS verify a sample parcel's lon/lat is in-county before pulling (ambiguous county names).

## BAY+WALTON — first pull mostly FAILED, consolidated retry in progress 2026-07-16
- ROOT CAUSE: ran Bay+Walton+Clay-chunked concurrently against flaky/limited servers -> connection resets (gis.baycountyfl.gov "Connection reset by peer") + pooler "canceling statement due to statement timeout" on complex-geom COPY batches (gt=500 too big). LESSON: pull ONE server at a time; use gt=100 for complex polygons; the pooler statement_timeout is NOT disabled by fast_pull's options='-c statement_timeout=0' -> must keep COPY batches small.
- ALSO: silent-partial risk — walton_future_land_use reported ogr "OK loaded" but only 2000/2733 rows (pagination stopped at maxRecordCount). ALWAYS verify loaded count == source count, never trust the "OK" line.
- CONFIRMED GOOD (verified =src): bay_parks 107; walton_zoning 2735, walton_address_points 70843.
- RETRY RUNNING (retry_bay_walton.sh, single-threaded, gt=100-300, spaced): bay_parcels(134543), bay_zoning(8393), bay_future_land_use(9602), bay_address_points(150826), walton_parcels(96142), walton_future_land_use(2733 re-pull), walton_flood_zones(8890). VERIFY each vs source after.
- EXPECTED FINAL: Bay 4->9/10 (parcels,zoning,flu,address,parks + clip fire/hosp/schools/flood; missing subdivisions). Walton 3->8/10 (parcels,zoning,flu,address,flood + clip fire/hosp/schools; missing subdivisions,parks). Trackers NOT yet updated for Bay/Walton — do after verify.

## BAY + WALTON DONE (verified) 2026-07-16
- BAY 4->9/10: bay_parcels 134543, bay_zoning 8393 (1 null geom in source), bay_future_land_use 9602, bay_address_points 150826, bay_parks 107 (+ clip fire/hosp/schools/flood). All =src, SRID 4326. Missing: subdivisions (no BayView subdiv layer). Tracker=9.
- WALTON 3->8/10: walton_parcels 96142, walton_zoning 2735, walton_future_land_use 2733, walton_address_points 70843, walton_flood_zones 8890 (+ clip fire/hosp/schools). All =src, SRID 4326. Missing: subdivisions, parks (not in webmap). Tracker=8.
- KEY FIX (pooler statement_timeout): fast_pull's options='-c statement_timeout=0' is NOT honored by the Supabase pooler. Dense-polygon layers (parcels/zoning/flu/flood with 100+ part polygons) TIME OUT the COPY at gt=500 -> use **gt=100** (works, slower). Simple point layers fine at gt=500. Run ONE server at a time (concurrency -> "Connection reset by peer").
- KEY FIX (offset-pagination duplication): walton_flood loaded 9681 vs src 8890 (791 dups) -- ArcGIS offset paging w/o stable sort double-fetches. CAUGHT by count!=src check. Deduped: DELETE a USING b WHERE a.ogc_fid>b.ogc_fid AND a.objectid=b.objectid -> 8890. LESSON: verify count==src (a partial is < src; a dup-load is > src). Also watch silent partials that stop at maxRecordCount (walton_flu first load = 2000/2733, ogr said "OK").
- Pre-drop leftover partial tables before re-pull (walton_parcels hit "geometry(...,1) SRID mismatch" from a leftover table; DROP first fixed it).

## SESSION SCORECARD (this multi-turn autonomous run) 2026-07-16
- 10/10: Alachua(confirmed), Brevard(9->10), Flagler(7->10), Sarasota(8->10), Volusia(9->10 via sweep).
- 9/10: Marion(7->9), Bay(4->9).
- 8/10: Clay(3->8), Santa Rosa(3->8), Walton(3->8).
- Integrity: point-clip sweep all 67 done (Lake+Volusia fixed). sjc_subdivisions->sjc_plat_index.
- WALLS logged (move-on): Clay zoning/FLU (pathological dense polygons break COPY). Nassau (qPublic facade). Monroe FL (hub=Ohio trap; qPublic). Pinellas/StJohns subdivisions + flood source-gaps.
## REMAINING QUEUE (for continuation):
- item3: more untracked low counties (mostly small rural Panhandle/N-FL, likely AGOL-facade "resist"; use hub-DCAT/webmap resolver + verify FL coords).
- item4: flood source-gap counties -> check each county's OWN server for a FEMA/SFHA flood layer (Clay/Bay/Walton all had own flood even where statewide fema_flood_zones didn't cover). address gaps: Marion, Santa Rosa (PA sources).
- Clay zoning/FLU via GDB download or ST_MakeValid geometry repair.

## CLAY NOW 10/10 (zoning/FLU was NOT a wall) 2026-07-16
- chunked_small.py (~/chunked_small.py, explicit resultOffset+resultRecordCount=250) SOLVED Clay zoning(6972, 4 null geom in src)+FLU(3316). Verified =src, no dups.
- KEY DISTINCTION (two different dense-polygon failure modes):
  * SERVER 500s on large geometry PAGES: fast_pull uses the layer maxRecordCount (2000) as page size -> 500. FIX: chunked_small with small resultRecordCount (250) = explicit small PAGES. (Clay zoning/FLU.)
  * POOLER statement_timeout on COPY: fix by small -gt (100) = small COMMIT batches. (Bay/Walton parcels.)
  Different causes, different fixes. Try chunked_small(250) when fast_pull dumps the ogr driver list / "Missing features member" / server 500.

## ITEM 4 flood source-gaps 2026-07-16 (county-own FEMA layers)
- St Johns: sjc_flood_zones = FIRM_Zone 9322 (=src, 0 null, 4326) from www.gis.sjcfl.us/portal_sjcgis/Hosted/FIRM_Zone. St Johns 7->9/10 (tracker was undercounting; true = missing only subdivisions[non-spatial]).
- Martin: martin_flood_zones = FEMAFloodZones 3289 (=src, 9 null geom in src, 4326) from services.arcgis.com/DlijwkpixeIOmhue. Martin 6->7/10 (still missing address/subdivisions/parks; Martin has own GIS geoweb.martin.fl.us + that AGOL org for later).
- Osceola flood = WALL-ish: gis.osceola.org SSL cert error (need curl -k / GDAL_HTTP_UNSAFESSL); only Historic_FEMA_Flood_Zones(1710) + current FIRM panels(grid), no current flood-zone polygons. Deferred (quality).
- Hernando flood = WALL: FloodData behind Experience Builder app, no direct REST.
- REMAINING flood-gaps to try (county-own server): Pinellas (FEMASupportData had no zones; try other folders), Palm Beach, Miami-Dade, Collier(already ~98%). Duval/Escambia on skip-list.
- METHOD for flood-gaps: each county's OWN server usually has a FEMA/FIRM flood-zone layer even where statewide fema_flood_zones doesn't reach (proven Clay/Bay/Walton/StJohns/Martin). Grep saved <county>_layers.txt first (martin/hernando/osceola/lake/flagler/highlands/manatee/pasco exist in ~).

## Palm Beach flood - DEFERRED (needs hub, not the dissolved MapServer)
- maps.co.palm-beach.fl.us/arcgis/rest/services/Flood/Flood_Effective/MapServer/0 = "PS - Flood Zone" but count=1, supportsPagination=false -> dissolved single-feature display layer, no per-zone attributes. NOT useful.
- Per-zone flood is likely in the "Palm Beach County Flood Mapping Repository" hub (palm-beach-county-flood-mapping-repository-pbcgov.hub.arcgis.com) or opendata2-pbcgov -> resolve via hub-DCAT next.

## ITEM 4 checkpoint 2026-07-16 — flood-gap fills so far
- DONE: St Johns sjc_flood_zones 9322, Martin martin_flood_zones 3289. (Clay/Bay/Walton flood done earlier this run.)
- WALLS/deferred: Osceola (SSL + historic-only), Hernando (Experience Builder), Palm Beach (dissolved layer -> use hub).
- STILL TO DO (flood-gaps): Pinellas, Miami-Dade, Palm Beach(via hub), Osceola(UNSAFESSL fallback). Collier already ~98%.
- ADDRESS-gaps to do: Marion (PA source), Santa Rosa (PA), Martin (has own GIS geoweb.martin.fl.us / AGOL DlijwkpixeIOmhue - also has address/subdiv/parks there for future).

## RUNNING SCORECARD (this multi-turn autonomous run) — all verified =src
- 10/10: Alachua, Brevard, Flagler, Sarasota, Volusia, Clay(!).
- 9/10: Marion, Bay, St. Johns.
- 8/10: Santa Rosa, Walton.
- 7/10: Martin(+flood).
- Integrity: 67-county point-clip sweep DONE (Lake+Volusia). sjc_subdivisions->sjc_plat_index.
- Walls logged: Nassau(qPublic facade), Monroe FL(OH hub trap), Clay zoning/FLU SOLVED via chunked_small, Osceola/Hernando/PalmBeach flood (see above), Pinellas/StJohns subdivisions.

## ITEM 4 round-2 (flood + Martin fills) 2026-07-16
- miamidade_flood_zones 3560 (=src, 0 null, 4326) from services.arcgis.com/8Pc9XBTAsYuxx9Ny/FEMAFloodZone_gdb/0 (via gis-mdc hub item ef3bdd04...). Miami-Dade direct-audit = 10/10 (recount had undercounted to 7 -- non-standard names pa_parcel/geoaddress/final_platting/existing_land_use). Tracker->10.
- martin_subdivisions 2121 (MC_Subdivisions2015), martin_parks 185 (Parks) from Martin AGOL org DlijwkpixeIOmhue. Martin 7->9/10 (only address left; Martin address = PA source, not in county AGOL/geoweb -> wall).
- Palm Beach + Pinellas flood: fast_pull FAILED (PB=HTTP 504, Pinellas="Missing features member") -- dense polygons, server can't return big pages. RE-RUNNING via chunked_small(250): palmbeach_flood_zones (FEMA_FLOODZONE_2024_New/45, src 31305), pinellas_flood_zones (PreliminaryFIRM/8, src 4436, PRELIMINARY firm). VERIFY on completion.
- Santa Rosa address: not in FL org Eg4L1xEv2R3abuQd -> PA source needed (wall). Marion address: wall (only grid pts/centroids).
## FLOOD-GAP STATUS: filled Clay,Bay,Walton,StJohns,Martin,MiamiDade (done) + PalmBeach,Pinellas(running). Walls: Osceola(SSL+historic), Hernando(ExB app). Collier ~98% already.
## SCORECARD UPDATE: 10/10 now = Alachua,Brevard,Flagler,Sarasota,Volusia,Clay,MiamiDade. 9/10 = Marion,Bay,StJohns,Martin. 8/10 = SantaRosa,Walton.

## ITEM 4 flood pass COMPLETE 2026-07-16
- palmbeach_flood_zones 31305 (=src, no dups, 0 null) via chunked_small(250) from services1.arcgis.com/ZWOoUZbtaYePLlPw/FEMA_FLOODZONE_2024_New/45 (found via opendata2-pbcgov hub DCAT; the maps.co.palm-beach Flood_Effective MapServer was a useless dissolved 1-feature layer). Palm Beach 9->10/10.
- pinellas_flood_zones 4436 (=src) via chunked_small(250) from egis.pinellas.gov PreliminaryFIRM/8 (PRELIMINARY firm - only queryable flood Pinellas serves; effective FIRM not published as a layer). One chunk (offset4250) failed transiently -> appended via resume_pinellas.py. Pinellas 7->9/10 (direct-audit; was undercounted; only subdivisions missing which genuinely doesn't exist).
- miamidade_flood_zones 3560 -> Miami-Dade 10/10. St Johns/Martin done earlier. martin subdiv2121/parks185 -> Martin 9/10.
- LESSON reinforced: for flood-gap counties, per-zone FEMA flood almost always exists on the county's OWN server/hub even when statewide fema_flood_zones doesn't reach. Dense flood polygons -> chunked_small(250), NOT fast_pull (504/"missing features" on big pages). Resolve org via hub DCAT (/api/feed/dcat-us/1.1) or AGOL item-info (watch false-lead traps: verify FL).

## FINAL SCORECARD this run (all verified vs source)
- 10/10 (9): Alachua, Brevard, Flagler, Sarasota, Volusia, Clay, Miami-Dade, Palm Beach.  [8 counties]
- 9/10 (5): Marion, Bay, St. Johns, Martin, Pinellas.
- 8/10 (2): Santa Rosa, Walton.
- Integrity: 67-county point-clip sweep DONE.
## REMAINING (next unit): low-completion RURAL counties (3-4/10: Calhoun, Columbia, Franklin, Hamilton, Hendry, Holmes, Jackson, Jefferson, Madison, Wakulla, Baker, Bradford, DeSoto, Dixie, Gadsden, Gilchrist, Glades, Gulf, Hardee, + others) via hub-DCAT+verify. Mostly small AGOL-facade "resist" pattern -> expect many walls; use hub DCAT resolver, verify FL coords, log-and-move-on. Also: Osceola flood (UNSAFESSL historic fallback), address-gaps (Marion/SantaRosa/Martin = PA-only walls).

=== RELAY LEADS 2026-07-16: PRIOR "WALLS" ARE FALSE — Leon/Nassau/Okaloosa/Columbia ALL ALIVE ===
## CORRECTION ACCEPTED (Duval): a research lead labeled "Duval County Property Appraiser Server Root" = clayutility.org. That is CLAY County's utility server (the same one clay_parcels 103680 came from tonight). NOT Duval. Using it under Duval would duplicate Clay data mislabeled. DO NOT USE for Duval. (Same false-lead class as Monroe-Ohio / Santa-Rosa-California.)

## LEON — UNBLOCKED (prior note "nothing bankable" was WRONG; the authoritative server is intervector)
- Server: https://intervector.leoncountyfl.gov/intervector/rest/services/MapServices (144 services!). BBOX VERIFIED = lon -84.71..-83.97, lat 30.19..30.62 = Leon FL.
- Layers (all /MapServer/0 unless noted): TLC_OverlayParcel_D_WM(113318), TLC_OverlayZoning_D_WM(1287), TLC_OverlayFutureLandUse_D_WM(487), TLC_OverlaySiteAddressPoints_D_WM(154932), TLC_OverlaySubdivision_D_WM(2380), TLC_OverlayParks_D_WM(/1 Park Areas=244), TLC_OverlayFEMA_D_WM(/1 floodway,/2 ZoneAE,/3 ZoneA,/4 ZoneX500 - flood is SPLIT BY ZONE TYPE).
- Also present: LCPA_OverlayParcel_WGS84 (PA parcels already WGS84 - alt source), TLC_OverlayRegionalParcel_D_SP/WM (REGIONAL - may span neighbors; DO NOT use as Leon-only without a county filter).
- DONE: leon_zoning 1287, leon_future_land_use 487, leon_subdivisions 2380 (=src).
- FAILED via fast_pull (server 500s on big pages): leon_parcels(113318), leon_address_points(154932) -> RE-PULL with chunked_small(250).

## NASSAU — UNBLOCKED (prior "qPublic facade" wall was WRONG path)
- Correct root: https://maps.ncpafl.com/ncflpa_arcgis/rest/services (NOT /arcgis or /server which 404). 113 services + folders.
- Service: nassau/NassauCountyPublicTaxMap/MapServer (81 layers). BBOX VERIFIED lon -82.05..-81.42, lat 30.19..30.77 = Nassau FL.
- Layer ids: 144 Land Parcels(60190), 151 Platted Subdivisions, 154 Unincorporated Zoning, 156 Unincorporated Future Land Use, 8 911 Address and Road Network / 231 911 Address Labels, 269 Flood Zones (Eff Aug2017/Dec2010). Also municipal zoning/FLU: 158/159 Hilliard, 297/164 Fernandina Beach, 299 Callahan.

## OKALOOSA — ALIVE
- ags.myokaloosa.com REDIRECTS -> https://okgis.myokaloosa.com/arcgis/rest/services. Folders: Land-Ownership, Planning-Development, Recreation, Natural-Features, Public-Safety, Admin-Boundaries, etc. + PA bulk shapefile FTP okaloosapa.com/gis-mapping (weekly).

## COLUMBIA — ALIVE
- https://gis.columbiacountyfla.com/hosting/rest/services (215 services). Parcels_and_Addresses/MapServer: 1 Addresses, 2 Parcels(37795), 5 Subdivisions. Zoning_Atlas/MapServer/1, Future_Land_Use/MapServer/1, Flood_Zones/MapServer/0. wkid 2238 (FL North State Plane) = FL verified. No parks service found.

## CONFIRMED DEAD ENDS (per relay research - do NOT search further; statewide cadastral is the parcel ceiling):
Jackson, Franklin, Calhoun, Holmes, Hamilton, Jefferson, Madison, Baker, Bradford, DeSoto, Dixie, Gadsden, Gilchrist, Glades, Gulf, Hardee, Lafayette, Levy, Liberty, Okeechobee, Suwannee, Taylor, Union, Washington -> no dedicated GIS; locked behind Axis Geospatial/qPublic webapps. Fallback: services9.arcgis.com/Gh9awoU677aKree0/.../Florida_Statewide_Cadastral/FeatureServer.
## STILL TO CHECK: Escambia (IMAGiNE/myescambia), Hendry (gis.hendryfla.net), Monroe (AGOL group 8587bed3e2fc4ea9be860a1b9e6d7f30 - APPLY FL COORD CHECK, Ohio near-miss), Indian River (hub), Wakulla (Leon regional address layer 12 - MUST verify genuinely Wakulla data not Leon's).

## MONROE FL — RESOLVED + FL-VERIFIED (prior "Ohio hub trap" wall cleared)
- The AGOL group 8587bed3e2fc4ea9be860a1b9e6d7f30 holds only web apps (no feature services), BUT it resolves the real org: owner=**MonroeCountyGIS**, org services host = **https://services.arcgis.com/D7K7hj5GW1YIVRiA** (56 feature services).
- HOW RESOLVED: group items -> item info -> owner=MonroeCountyGIS -> AGOL search `owner:"MonroeCountyGIS" AND type:"Feature Service"`. (portals/self gives no org id anonymously.) REUSABLE RESOLVER for facade counties.
- FL COORD CHECK PASSED: Current_Parcels bbox = lon -81.975..-80.208, lat 24.453..25.804 = Florida Keys (Key West->Key Largo + mainland Everglades). Genuinely Monroe FL, NOT Monroe Ohio.
- Layers: Current_Parcels(89548), Future_Land_Use, LUD_Zoning, MC_Address_Points_(View_Layer), Preliminary_Flood_Zones / Effective_Flood_Zones_02182005 / Flood_Hazard_Area. No subdivisions/parks found.
- NOTE: "Woods Hole Flood Zones"/"Woods Hole LiMWA" in this org = Woods Hole Group (coastal engineering firm that did Monroe FL flood studies), NOT Massachusetts data.

## LEON progress: zoning 1287, future_land_use 487, subdivisions 2380, parks 244, flood_zone_ae 522, flood_zone_a 2191, flood_zone_x500 808, flood_floodway 46 — all =src VERIFIED.
- leon_parcels(113318) + leon_address_points(154932) FAILED via fast_pull (intervector 500s on big pages) -> re-pulling via chunked_small(250/500). Leon expected 10/10 when done.

## LEON + NASSAU DONE (both former "walls") 2026-07-16
- LEON 10/10: leon_parcels 113318 (chunk=1000 -- layer maxRec=140000 so fast_pull tried ALL in one page and choked; explicit 1000-page fixed it), leon_address_points 154932 (chunk=2000, one chunk@78000 failed->resumed 4x500), zoning 1287, future_land_use 487, subdivisions 2380, parks 244, flood ae522/a2191/x500-808/floodway46 + clip fire/hosp/schools. All =src, 4326, 0 null.
- NASSAU 9/10: nassau_parcels 60190, nassau_address_points 54049 (layer 231 "911 Address Labels" pts; layer 8 is a Group Layer), zoning 671, future_land_use 587, subdivisions 1322, flood 1446 + clip fire/hosp/schools. Missing parks (no parks layer on tax map). All =src, 4326, 0 null.
- LESSON: check layer maxRecordCount! If it's huge (140000), fast_pull's FEATURE_SERVER_PAGING requests one giant page -> server chokes. Use chunked_small with chunk=1000. (Different from the maxRec=2000-but-dense-geom case which just needs small chunks for a different reason.)
- MONROE pulling next (parcels 89548, address 55915, FLU/36, LUD_Zoning/37, Preliminary_Flood_Zones/1). No subdiv/parks in org.
## SCORECARD: 10/10 now = Alachua,Brevard,Flagler,Sarasota,Volusia,Clay,MiamiDade,PalmBeach,Leon (9). 9/10 = Marion,Bay,StJohns,Martin,Pinellas,Nassau (6).

## MONROE + COLUMBIA + OKALOOSA 2026-07-16
- MONROE 3->8/10: monroe_parcels 89548, monroe_future_land_use 6706, monroe_zoning 6521 (LUD_Zoning/37), monroe_address_points 55915 (13 null geom in src), monroe_flood_zones 2669 (Preliminary_Flood_Zones/1). All =src, 4326. +clip fire/hosp/schools. No subdiv/parks in org. Tracker=8.
- COLUMBIA -> 8/10 (verify flood): columbia_parcels 37795, columbia_subdivisions 1126, columbia_zoning 520 (Zoning_Atlas/1), columbia_future_land_use 316 (Future_Land_Use/1), columbia_flood_zones 5304 (Flood_Zones/2 "2018", chunked_small - fast_pull 500'd) +clip fire/hosp/schools. 
  * COLUMBIA ADDRESS = NON-SPATIAL: source "Addresses" layer declares esriGeometryPoint but features have NULL geom (address records tied to parcels). Pulled table had no geom -> RENAMED columbia_address_points -> columbia_address_records. Address category NOT satisfied. No parks layer. So 8/10 (parcels,subdiv,zoning,flu,flood,fire,hosp,schools).
- OKALOOSA -> 7/10 (running): okaloosa_parcels 113801, okaloosa_zoning 939 (Zoning/28 County Zoning), okaloosa_future_land_use 952 (Zoning/29 County Future Landuse), okaloosa_flood_zones 2855 (Flood/8 FEMA FIRM Zones) +clip fire/hosp/schools. Server okgis.myokaloosa.com (ags. redirects). wkid 2238=FL. No address-point layer (addressing embedded in parcel attrs), no subdiv/parks.
- LESSON: a source layer can DECLARE point geometry but serve NULL geoms (attribute-only) -> pulled table ends up non-spatial. Always check the pulled table has a geom column + rename to *_records if not, don't count as the spatial category.
## REMAINING LEADS: Escambia (IMAGiNE joint system - myescambia), Hendry (gis.hendryfla.net hub), Indian River (hub w/ FLU/zoning/subdiv/address/parks), Wakulla (Leon regional addr layer 12 - verify Wakulla-specific). Then done with relay leads; rest = statewide-cadastral parcels ceiling only.

## ESCAMBIA — UNBLOCKED (was skip-list) 2026-07-16
- IMAGiNE system: https://gismaps.myescambia.com/arcgis/rest/services/Individual_Layers/... wkid 2883 (FL West SP)=FL. Comprehensive.
- Pulling (expect 9/10): escambia_parcels 163861, escambia_zoning 7800 (Zoning), escambia_future_land_use 5632 (FLU_2030), escambia_address_points 166330 (Structure_Addresses, real pts), escambia_parks 152 (lucity_parks), escambia_flood_zones 5303 (SFHA) + clip fire/hosp/schools. No subdivisions layer. VERIFY on completion.

## INDIAN RIVER — STILL WALLED (relay lead optimistic)
- AGOL org services9.arcgis.com/M0DpVhTwTZ42jNsw (owner gisptramel, 130 svcs) has only PARTIAL/departmental: County_Owned_Parcels (not full cadastral), FEMA_Flood_Zones_HFS(76 - too low), Curbside_Addressing(3233 - partial subset), Beach_Subdivisions(beach only). NO comprehensive parcels/zoning/FLU. Real cadastral on unadvertised county server (matches prior note). Did NOT pull partial subsets as full categories. FLAG: needs county-server discovery (indianriver.gov/services/it/gis) or PA (ircpa).

## HENDRY — hub resolved, org services7.arcgis.com/8l7Qq5t0CPLAJwJK
- gis.hendryfla.net hub DCAT (61 datasets): Hendry_County_Parcels/FeatureServer/0. Also Address Points, Flood Zones (accessURL empty in DCAT -> resolve layer urls directly from org). TO PULL next.

## RELAY-LEAD SCORECARD: WINS (were walls): Leon 10/10, Nassau 9/10, Monroe 8/10, Columbia 8/10, Okaloosa 7/10, Escambia ~9/10(pulling). STILL WALLED: Indian River (partial only), Duval (clayutility=Clay, NOT Duval - corrected). TODO: Hendry, Wakulla.

## WAKULLA — WALL confirmed (relay caution was right)
- No own server (gis/maps.mywakulla.com dead). Leon regional parcel layer (TLC_OverlayRegionalParcel_D_WM) has NO county field, and a Wakulla-bbox spatial query returns only ~4123 parcels vs Wakulla's actual ~25-30k -> only PARTIAL edge coverage, NOT genuine complete Wakulla data. Pulling it would be misleading. LOG as wall; genuine Wakulla parcels = PA/qPublic vendor (dead-end category). Wakulla stays at clip baseline.

## ESCAMBIA DONE 9/10 (verified =src, 0 null, 4326): parcels 163861, zoning 7800, future_land_use 5632 (FLU_2030), address 166330 (Structure_Addresses pts), parks 152 (lucity_parks), flood 5303 (SFHA) + clip fire/hosp/schools. Missing subdivisions (no layer). Tracker=9.
## HENDRY (running): hendry_parcels 35734, hendry_zoning ~35496 (parcel-level zoning, Zoning/1), future_land_use, address 34413, parks 31, flood (FEMA_Flood_2020). Expect 9/10. VERIFY.

=== RELAY-LEAD ROUND COMPLETE ===
WINS (all were logged "walls", now unblocked + verified): Leon 10/10, Nassau 9/10, Escambia 9/10, Monroe 8/10, Columbia 8/10, Okaloosa 7/10, Hendry ~9/10(pulling).
STILL WALLED: Indian River (AGOL partial only; real cadastral on unadvertised county server), Wakulla (Leon-regional partial only), Duval (clayutility=Clay NOT Duval - relay correction confirmed).
CONFIRMED DEAD-ENDS (per relay, not searched): Jackson,Franklin,Calhoun,Holmes,Hamilton,Jefferson,Madison,Baker,Bradford,DeSoto,Dixie,Gadsden,Gilchrist,Glades,Gulf,Hardee,Lafayette,Levy,Liberty,Okeechobee,Suwannee,Taylor,Union,Washington -> statewide-cadastral parcel ceiling only.

## FINAL STATEWIDE PICTURE 2026-07-16 (67 counties): 12 at 10/10, 26 at 7-9, 23 at 4-6, 10 at 1-3. AVG completeness 65.3% (session start recount was 52.4% w/ 3 at 10/10).
## Hendry 9/10 done (parcels35734,zoning35496,flu180,addr34413,parks31,flood8762). Relay-lead round fully complete.

## INDIAN RIVER — GENUINE WALL (final) 2026-07-16
- IRCPA bulk shapefile EXISTS (real county-specific, the Highlands/Martin/Citrus pattern): qpublic.schneidercorp.com/FileData/IndianRiverCountyFL/DataDownload/ShapeFiles.zip (from ircpa.org/site-links/downloads/). BUT gated behind a CLOUDFLARE bot-challenge (challenges.cloudflare.com "Just a moment..."). NOT automatable -- must not bypass bot-detection. A human CAN download it in a browser (then load locally via ogr2ogr). AGOL org partial-only; no open county server. => WALL for automation.
- Statewide DOR mirror services1.arcgis.com/nRHtyn3uE1kyzoYc/FDORCadastral_SouthDistrict exists = documented-partial fallback only (per business rule, same as parcels_staging) -- NOT pulled as a county win.
- ACTION FOR MURPHY: download ShapeFiles.zip manually from ircpa.org/site-links/downloads/ (browser), drop into WSL, then chunked_gdb_import.sh / ogr2ogr can load it -> Indian River parcels+subdiv+etc in one shot.

## GAP-CLOSER: santarosa_flood_zones 2180 (DFIRM svc = FloodZones_2021, FLD_ZONE/SFHA_TF attrs, =src, 0 null, 4326) -> SANTA ROSA 8->9/10. Only address left (PA source wall).
- Monroe parks = wall ("Public Lands" is a web app, no feature service in org). Monroe stays 8/10.

## REMAINING small gaps on successful counties are mostly confirmed-unavailable: subdivisions (Bay/Escambia/Hendry/Okaloosa/Walton/Monroe/Pinellas/StJohns - no layer or non-spatial), parks (Nassau/Monroe/Walton/Columbia/Okaloosa - no layer), address (Marion/Martin/Santa Rosa/Okaloosa/Columbia - PA-vendor or non-spatial). These are genuine data-availability limits, not search failures.

=== CITY EXPANSION 2026-07-16 (new directive: major FL municipalities, own GIS distinct from county) ===
- Convention: <city>_city_<layer>. Existing real city pulls: tampa_city(19), stpete_city(17), daytonabeach_city(35). Cities tracked by table presence (NOT county_coverage_status).
- Categories to grab per city: address_points, zoning, future_land_use, parks, police (districts/zones/stations), fire_stations, neighborhoods, flood. Bbox-verify FL + city-bounded (not countywide) before trusting.

## FORT LAUDERDALE — DONE (gis.fortlauderdale.gov/arcgis). bbox lon -80.26..-80.09 lat 26.06..26.24 = FTL FL.
- fortlauderdale_city_: address_points 237368, zoning 802 (ZoningGIS/15), future_land_use 609 (ZoningGIS/7), parks 768 (ParkandRecFinder/1), police_districts 3, neighborhood_assoc 86, flood_zones 2571 (FEMAFloodZones/4). All =src, 0 null, 4326.

## RUNNING: Clearwater (gis.myclearwater.com/arcgis ArcGISMapServices: address54229,zoning761,flu3878,parcels83772,parks126,neighborhood) + Orlando (services5/mMuoPCaIYD4wEgDl via orlando-open-data hub: address119598 Address_Point/22, zoning2091 OrlandoLUZoning, flu1852 OrlandoLUFutureLandUse, parks138 OrlandoParks, neighborhoods). Both bbox-verified FL.

## CITY RESOLVER NOTES:
- Jacksonville (COJ maps.coj.net/coj/rest): thin - Parks folder empty, JFRD=hexbins only, Geocode=geocoder. Real COJ data on open-data hub -> needs hub-DCAT/owner-search (TODO).
- Tallahassee: consolidated TLC (Tallahassee-Leon) -> core data = leon_* already pulled. City-specific extras (TPD zones) minor.
- Enterprise servers found: Fort Lauderdale gis.fortlauderdale.gov, Clearwater gis.myclearwater.com. Hub-only (no enterprise): Orlando (orlando-open-data-orl hub, org mMuoPCaIYD4wEgDl). Orlando/Gainesville/WPB dont answer gis.<city>.gov guesses -> use hub-DCAT.
## TODO CITIES (pop order): Jacksonville, Hialeah, Port St Lucie, Cape Coral, Pembroke Pines, Hollywood, Miramar, Gainesville, Coral Springs, Palm Bay, West Palm Beach, Lakeland, Pompano Beach, ...

## CITIES DONE this round (all bbox-verified FL, =src, <city>_city_ prefix) 2026-07-16
- FORT LAUDERDALE (gis.fortlauderdale.gov/arcgis): address 237368, zoning 802, future_land_use 609, parks 768, police_districts 3, neighborhood_assoc 86, flood_zones 2571. [7]
- CLEARWATER (gis.myclearwater.com/arcgis ArcGISMapServices): address 54229 (1 null in src), zoning 761, future_land_use 3878, parcels 83772, parks 126, neighborhood_assoc 85. [6]
- ORLANDO (services5/mMuoPCaIYD4wEgDl, orlando-open-data hub): address 119598 (Address_Point/22), zoning 2091 (OrlandoLUZoning), future_land_use 1852 (OrlandoLUFutureLandUse), parks 138 (OrlandoParks), neighborhoods 125. [5]
- CAPE CORAL (capeims.capecoral.gov/arcgis/OpenData) [PULLING]: address 191119, zoning 5478 (DCD/3), future_land_use 5203 (DCD/2), parks 115, fire_stations 13. bbox lon -82.10..-81.90 lat 26.51..26.77 = Lee FL.
## CITY RESOLVER SUMMARY: enterprise servers (gis.<city>.gov/arcgis) for Fort Lauderdale, Clearwater; hub-DCAT (/api/feed/dcat-us/1.1) for Orlando, Cape Coral. Guessed hosts that FAILED (use hub instead): gis.capecoral.gov, gisweb.coralsprings.org, ags.lakelandgov.net, gis.copbfl.com, gis.cityofpsl.com, gis.hollywoodfl.org, gis.cityoforlando.net, maps.cityofgainesville.org, gis.wpb.org.
## CITIES TODO (pop order): Jacksonville(COJ hub - thin enterprise), Hialeah, Port St Lucie(cityofpsl hub), Cape Coral(pulling), Pembroke Pines, Hollywood, Miramar, Gainesville(hub), Coral Springs(hub), Palm Bay, West Palm Beach(hub), Lakeland(hub), Pompano Beach, Miami Gardens, Brandon, Riverview, Deltona, ... Continue via web-search hub domain -> hub-DCAT -> bbox-verify -> pull.
## CAPE CORAL DONE 5 layers (=src, 4326): address 191119 (2 null in src), zoning 5478, flu 5203, parks 115, fire_stations 13. NOTE: capeims.capecoral.gov blocks Python-urllib UA (fast_pull count()=403) but ogr2ogr/libcurl works fine -> pull OK, just no source-count print; verify via a browser-UA curl count.
## CITY ROUND: Fort Lauderdale(7), Clearwater(6), Orlando(5), Cape Coral(5) DONE + verified. Continue pop list via hub-DCAT.

## JACKSONVILLE FL — WALL (city expansion) 2026-07-16
- maps.coj.net/coj/rest alive (34 folders) but NO clean parcels/zoning/address feature services (Parks empty, JFRD=hexbins, Geocode=geocoder, CommunityMapsESRI=updates only) - operational-only, consistent with Duval consolidated-gov thinness.
- AGOL TRAP: search City of Jacksonville Zoning -> owner hherrmann_coj, org p6AtkBQ0z2Evsivu (coj.maps.arcgis.com) = Jacksonville NORTH CAROLINA (Onslow County, cjaxgisweb.jacksonvillenc.gov, CAMA/UDO). NOT FL. Did NOT pull.
- Jacksonville FL = Duval (consolidated); partially covered by duval_* clip tables. Genuine wall; needs manual COJ data request.

## PORT ST LUCIE + HIALEAH (running) 2026-07-16
- PSL (services1/YdUP5V6WwzeG8T8r, data-pslgis hub): address 136089 (93% in tight PSL bbox -80.45..-80.20/27.20..27.38; ~7% source-error outliers spanning FL - genuinely PSL, pulled as-is), zoning 326, future_land_use 1317 (LandUse), parks 54, police_districts 24. VERIFY.
- HIALEAH (hgis.hialeahfl.gov/arcgis): address 77430 (EnerGov/Properties/0), zoning 37362 + future_land_use 37362 (parcel-level, Community_Development), parks 33, parcels 77430. bbox lon -80.37..-80.25 lat 25.81..25.93 = Miami-Dade FL. VERIFY.
## CITIES DONE: FortLauderdale,Clearwater,Orlando,CapeCoral + (running) PSL,Hialeah = 6 new. JACKSONVILLE=wall(NC trap+thin COJ).

## PSL + HIALEAH + LAKELAND DONE (verified =src, 4326) 2026-07-16
- portstlucie_city_ (services1/YdUP5V6WwzeG8T8r): address 136089 (79 null=source outliers), zoning 326, future_land_use 1317 (2 null), parks 54, police_districts 24.
- hialeah_city_ (hgis.hialeahfl.gov): address 77430, zoning 37362, future_land_use 37362, parks 33, parcels 77430 (all 0 null).
- lakeland_city_ (services1/mcbQY5xNGGGM1vBX + gismims.lakelandgov.net): address 77460, zoning 1397, future_land_use 673 (2 null), flood_zones 8137, fire_stations 7.

## CITY-EXPANSION SESSION TOTAL: 7 NEW cities = FortLauderdale(7 layers), Clearwater(6), Orlando(5), CapeCoral(5), PortStLucie(5), Hialeah(5), Lakeland(5). + prior Tampa/StPete/DaytonaBeach.
## RESOLVED CITY SOURCES (for continuation):
- Enterprise servers: Fort Lauderdale gis.fortlauderdale.gov, Clearwater gis.myclearwater.com, Hialeah hgis.hialeahfl.gov, Lakeland gismims.lakelandgov.net.
- AGOL/hub orgs: Orlando services5/mMuoPCaIYD4wEgDl (orlando-open-data-orl), CapeCoral capeims.capecoral.gov+capecoral-capegis hub, PSL services1/YdUP5V6WwzeG8T8r (data-pslgis / opendata-pslgis hub), Lakeland services1/mcbQY5xNGGGM1vBX (geohub-lakelandflorida).
## WALL: Jacksonville FL (thin COJ + AGOL org is NC).
## CITY QUEUE (pop order, TODO): Pembroke Pines, Hollywood, Miramar, Gainesville, Coral Springs, Palm Bay, West Palm Beach, Pompano Beach, Miami Gardens, Brandon(CDP), Riverview(CDP), Deltona, Boca Raton, Sunrise, Plantation, Deerfield Beach, Boynton Beach, Kissimmee, ... For Broward cities (Hollywood/CoralSprings/Pompano/Miramar/PembrokePines/Plantation/Sunrise) check own enterprise server first, else Broward GeoHub geohub-bcgis. Gainesville/PalmBay/WPB via hub-DCAT (web-search hub domain first).

## CITY BATCH 3 (2026-07-16) — verified =src
- HOLLYWOOD (maps.hollywoodfl.org/arcgis): hollywood_city_zoning 644 (Planning/Zoning/5), future_land_use 324 (Planning/Land_Use/6). Address/parcels are Broward County's (city server has only CityOwnedParcels + offender zones). bbox -80.25..-80.11/25.99..26.09 = Broward FL.
- PEMBROKE PINES (services6/OlJkQnf39yF1a7pM): pembrokepines_city_ address 68645 (1 null), zoning 228 (13 null geom in src), parcels 66646, parks 36. bbox -80.44..-80.21 = Broward FL.
- WEST PALM BEACH (running, wpbgisportal.wpb.org/server): address 45305, zoning 87, future_land_use 20, parks 56. (flood needs token=499 - skipped.) bbox -80.21..-80.04/26.65..26.81 = PB FL.
- MIRAMAR (running, smartcity.miramarfl.gov/server/Hosted): address 43680 (MiramarAddressPoints/1), zoning 49316 (parcel-level), future_land_use 108. bbox -80.43..-80.21/25.96..26.00 = Broward FL.
## CITIES THIS SESSION (11): FortLauderdale,Clearwater,Orlando,CapeCoral,PortStLucie,Hialeah,Lakeland,Hollywood,PembrokePines,WestPalmBeach,Miramar. + prior Tampa,StPete,DaytonaBeach.
## RESOLVED-BUT-NOT-YET-PULLED: Palm Bay (gis.palmbayflorida.org/arcgis enterprise), Gainesville (acgm org / dataGNV data.cityofgainesville.org). TODO: Coral Springs, Pompano Beach, Miami Gardens, Sunrise, Plantation, Deerfield Beach, Boynton Beach, Kissimmee, Boca Raton, Deltona, Fort Myers, Melbourne, ...
## GAINESVILLE city: ArcGIS Gainesville layers are actually Alachua County (owner AlachuaCountyGIS, org services1/MiBZ4u97DWldovjI = same as alachua_* county pull, already have). City-specific municipal data on dataGNV/Socrata (data.cityofgainesville.org) - NOT ArcGIS REST, outside proven resolvers; Socrata geojson test failed. Gainesville effectively covered by alachua_* county data. Logged, moved on.

## CITY BATCH 4 (2026-07-16)
- PALM BAY (running, gis.palmbayflorida.org/arcgis): palmbay_city_ address 102072 (Building/IMS/1), zoning 80447 (GrowthManagement/Zoning, parcel-level), future_land_use 79508 (GrowthManagement/FLU1), parks 40 (Building/IMS/15), parcels (Building/IMS/14). bbox -80.75..-80.53/27.82..28.06 = Brevard FL. VERIFY.
- CORAL SPRINGS (DONE): coralsprings_city_address_points 11541 (org services1/mXWZ2wsX9klsJAJY, LCR_Address - LOW count, likely partial; zoning via Broward). bbox -80.30..-80.20/26.26..26.30 = Broward FL. =src, 0 null.
- POMPANO BEACH (staged, org services.arcgis.com/HnPbdNoPBNAJ6Oel): address 28563 (Camino/0), zoning 459 (Zoning_Districts), future_land_use (Land_Use/1), parks 55 (ParksService2019), fire_stations 9, flood_zones 966 (CRSFEMAFloodZone). bbox -80.20..-80.08/26.21..26.30 = Broward FL.
## COUNTY-COVERED (no separate clean city ArcGIS org, use county data):
- MIAMI GARDENS: no city org; data = Miami-Dade County (MDPublisher) -> covered by miamidade_*.
- GAINESVILLE: ArcGIS layers owned by AlachuaCountyGIS (same org as alachua_*); city-specific on dataGNV/Socrata (non-ArcGIS). Covered by alachua_*.
## CITIES THIS SESSION now: 13 pulled (FTL,Clearwater,Orlando,CapeCoral,PSL,Hialeah,Lakeland,Hollywood,PembrokePines,WPB,Miramar,CoralSprings + PalmBay running) + Pompano staged.
## QUEUE: Sunrise, Plantation, Deerfield Beach, Boynton Beach, Boca Raton, Kissimmee, Deltona, Fort Myers, Melbourne, Largo, Palm Coast, Homestead, Delray Beach, Tamarac, ...

## CITY BATCH 4 DONE (verified =src, 4326) 2026-07-16
- PALM BAY: address 102072, future_land_use 79508 (12 null), parcels 84467, parks 40 (4 spatial). ZONING = NON-SPATIAL: GrowthManagement/Zoning/0 declares esriGeometryPolygon but serves NULL geom on query (display-only layer) -> dropped, zoning-as-polygons unavailable there. Palm Bay = 4 city categories.
- CORAL SPRINGS: address 11541 only (thin; zoning via Broward).
- POMPANO BEACH: address 28563, zoning 459 (1 null), future_land_use 269 (1 null), parks 55, fire_stations 9, flood_zones 966. FULL 6-cat city (org services.arcgis.com/HnPbdNoPBNAJ6Oel).
## LESSON (reconfirmed): a source Feature Layer can DECLARE polygon/point geom but serve NULL geometry on ?returnGeometry=true (display-only/joined layer) -> pulled table ends up non-spatial. Always check the pulled table has geom; if not, that category is unavailable-spatial from that layer.
## CITY SESSION TOTAL: 14 pulled = FortLauderdale,Clearwater,Orlando,CapeCoral,PortStLucie,Hialeah,Lakeland,Hollywood,PembrokePines,WestPalmBeach,Miramar,CoralSprings,PalmBay,PompanoBeach. + prior Tampa,StPete,DaytonaBeach = 17 cities.
## COUNTY-COVERED (no clean city org): Miami Gardens (Miami-Dade), Gainesville (Alachua/dataGNV-Socrata). WALL: Jacksonville FL.
## QUEUE: Sunrise, Plantation, Deerfield Beach, Boynton Beach, Boca Raton, Kissimmee, Deltona, Fort Myers, Melbourne, Largo, Palm Coast, Homestead, Delray Beach, Tamarac, North Port, Wellington, Jupiter, Port Orange, Sanford, Ocala, ...

## CITY BATCH 5 (2026-07-16)
- BOYNTON BEACH DONE (org services.arcgis.com/QlB3K6x50u6oHu4Z): boyntonbeach_city_ address 39951 (SITUS_PUB_CBB_2/0), zoning 21504 (Zoning_Classification_March6_2024/1, parcel-level, 1 null), future_land_use 21883 (FutureLandUse_March16_2022, 1 null), parks 36 (Park_Boundaries_Sept2022/4), flood_zones 31 (Flood_Zones_Map_2022). bbox -80.12..-80.05/26.48..26.57 = Palm Beach FL. =src, 4326. FULL 5-cat.
- BOCA RATON (running, org services1.arcgis.com/QFRSWfCZ5CjIDJJ2): bocaraton_city_ address 45877 (BOCA_SITUS_CITY/0), parks 45 (Parks_and_Preserves_WM), flood_zones 2117 (Flood_Zones_Current). bbox -80.17..-80.07/26.32..26.43 = Palm Beach FL. ZONING WALL: ZONING_AREA_WM on utility.arcgis.com proxy = 500 "Error generating token" (auth-walled). VERIFY.
- KISSIMMEE: no clean city org (only wildlife-area layer); likely Osceola County-covered (osceola_*). Deferred.
## CITY SESSION TOTAL: 16 pulled (+Boynton, +Boca) = ...,PalmBay,PompanoBeach,BoyntonBeach,BocaRaton. + prior 3 = 19 cities.
## QUEUE: Sunrise, Plantation, Deerfield Beach, Delray Beach, Deltona, Fort Myers, Melbourne, Largo, Palm Coast, Homestead, Tamarac, North Port, Wellington, Jupiter, Port Orange, Sanford, Ocala, Sarasota(city), Bradenton, ...

## CITY BATCH 6 (2026-07-16)
- FORT MYERS DONE (org services1.arcgis.com/T37xMyv8DRNzouiI, owner CFMGIS): fortmyers_city_ address 73480 (AddressPoints1/0), zoning 392 (Zoning1/0), future_land_use 202 (Fort_Myers_Future_Land_Use/0). bbox -81.90..-81.75/26.55..26.68 = Lee FL. =src, 4326.
- DELRAY BEACH (running, owner delraygis): ALL layers on utility.arcgis.com/usrsvcs/servers/{hash}/EnterpriseGIS_View/GIS_View proxy - each layer has its OWN proxy hash. IMPORTANT: unlike Boca zoning (500 token error), Delray proxy DOES serve geometry (verified sample -80.059,26.459 = Delray FL). delraybeach_city_ address 44417 (MapServer/80), zoning 1280 (FS/21), future_land_use 1238 (Land Use FS/37), parks 57 (FS/6), flood_zones 14199 (FS/38). VERIFY.
- LESSON: utility.arcgis.com/usrsvcs proxy views are hit-or-miss - some serve data+geom (Delray), some 500 "Error generating token" (Boca zoning). Always test one query before deciding wall.
- MELBOURNE + SUNRISE: no city org surfaced in owner-search; Melbourne likely Brevard-covered, Sunrise likely Broward-covered. Deferred (check enterprise gis.<city> or county next).
## CITY SESSION: 18 pulled (+FortMyers,+Delray). + prior 3 = 21 cities.

## DELRAY BEACH DONE (verified =src, 4326): address 44417, zoning 1280, future_land_use 1238, parks 57, flood_zones 14199 (chunked_small 250; 2 chunks failed on flaky proxy -> resumed offsets 12750/13250 in 100-row subchunks -> exact 14199, no dups). FULL 5-cat.
## FORT MYERS DONE: address 73480, zoning 392, future_land_use 202.
## CITY SESSION TOTAL: 18 new = FortLauderdale,Clearwater,Orlando,CapeCoral,PortStLucie,Hialeah,Lakeland,Hollywood,PembrokePines,WestPalmBeach,Miramar,CoralSprings,PalmBay,PompanoBeach,BoyntonBeach,BocaRaton,FortMyers,DelrayBeach. + prior Tampa,StPete,DaytonaBeach = 21 CITIES.
## QUEUE NEXT: Sunrise, Plantation, Deerfield Beach, Deltona, Melbourne, Largo, Palm Coast, Homestead, Tamarac, North Port, Wellington, Jupiter, Port Orange, Sanford, Ocala, Bradenton, Sarasota(city), Pensacola, Kissimmee(Osceola?), ...

## CITY BATCH 7 (2026-07-18)
- DEERFIELD BEACH (running, org services1/yJ4j7ns7W6juha0m): address 47577 (AddressPoints/0), zoning (DFB_Zoning/44), future_land_use 240 (Future_Land_Use_2021), parks 1100 (Parks_2021_Web_Map), flood 790 (Flood_Hazard_Areas_DFB). bbox -80.17..-80.08/26.28..26.33 = Broward FL.
- PALM COAST (running, org services1/tpnsCwhQRDqwL3mq): zoning 7059 (PalmCoastFL_Zoning), future_land_use 2113 (PalmCoastFL_FLU). bbox -81.37..-81.14/29.41..29.65 = Flagler FL. Address not a public FS -> Flagler county covers (have flagler_address_points).
- LARGO (staged, org services2/nYo0QaOOsjBkTG7Y): future_land_use 19148 only (parcel-level; address/zoning via Pinellas Co). bbox -82.85..-82.69/27.88..27.94 = Pinellas FL. THIN city.
- DELTONA: thin (commission districts/owned properties only) -> Volusia-covered. SUNRISE: no enterprise/org found -> Broward-covered. Deferred.
## CITY SESSION: 21 done + Deerfield/PalmCoast/Largo pending = ~24 cities.
## BATCH 7 DONE: Deerfield Beach 5-cat (addr47577,zoning304,flu240,parks1100,flood790), Palm Coast 2-cat (zoning7059,flu2113), Largo 1-cat (flu19148). All =src 4326. CITY SESSION TOTAL = 24 new + prior 3 = 27 CITIES.

## CITY BATCH 8 (2026-07-18)
- BRADENTON DONE (org services6/wl0q8tN2gn8MMx1p, owner CityofBradenton): bradenton_city_ address 34327, zoning 190, future_land_use 122, parks 35. All =src, 4326. FULL 4-cat.
  * CITY-BOUNDS CATCH: org has ADDRESS_pts = 279000 with COUNTY-WIDE bbox (-82.75..-82.04 = all Manatee) -> NOT city. Used ADDRESS__pts_CoBarea (34327, tight city bbox -82.69..-82.48/27.46..27.52) + the *_CoB suffixed layers (Zoning_CoB/FLU_CoB/ParksPreservesRec_CoB). Suffix _CoB = City of Bradenton = city-specific.
- OCALA (running, gis.ocalafl.org Public/GrowthManagement): ocala_city_zoning 1233 (layer 15), future_land_use 24726 (layer 11, parcel-level). bbox -82.25..-82.06/29.11..29.23 = Marion FL. Address/parks via Marion County. (Ocala search also surfaced gis.marionfl.org COUNTY layers = already have marion_*.)
- COUNTY-COVERED (deferred): PENSACOLA (Escambia IMAGiNE joint system = already pulled escambia_* covers Pensacola area), SARASOTA CITY (sarasota_* county + existing sarasota_city_zoning), NORTH PORT (Sarasota Co, no city org).
## CITY SESSION: 24 done + Bradenton + Ocala = 26 new cities (29 incl prior 3).
## QUEUE NEXT: Tamarac, Wellington, Jupiter, Port Orange, Sanford, Doral, Kendall, Town N Country(CDP), Pine Hills(CDP), Spring Hill(CDP), Riverview(CDP), Brandon(CDP), The Villages, Melbourne(Brevard?), Titusville, Fort Pierce, Ormond Beach, ...

## CITY BATCH 9 (2026-07-18)
- DORAL DONE (gis.cityofdoral.com enterprise): doral_city_ address 39867 (EnerGov/EnerGov_CSS_PROD/1), zoning 200 (Planning/Zoning/0), future_land_use 162 (Planning/LandUse/0), parks 11 (Government/PublicInformationViewer/2). bbox -80.39..-80.32/25.78..25.86 = Miami-Dade FL. FULL 4-cat.
- FORT PIERCE DONE (org services1/oDRzuf2MGmdEHAbQ, owner FtPierceGIS): fortpierce_city_ zoning 15 (dissolved districts), future_land_use 17249 (parcel-level). bbox -80.43..-80.29/27.37..27.47 = St Lucie FL. Address = AddressPoints_CountyWide (St Lucie county, NOT city) -> skipped.
- TITUSVILLE (running, gis.titusville.com enterprise): address 36480 (AddressPoints/0), zoning 2372 (CommunityDevelopment/15), future_land_use 1932 (/16). bbox -80.87..-80.78/28.49..28.65 = Brevard FL.
- JUPITER (running, org services1/pQrVKbO4a0hhA72L, owner jupitergis): address 47987 (AddressFeature/0), zoning 351 (TOJ_Zoning), future_land_use 400 (TOJ_FutureLandUse). bbox -80.18..-80.06/26.88..26.97 = Palm Beach FL.
- SANFORD: no city org (Seminole-covered). WELLINGTON: org wellingtongis (subdivisions/streets - check zoning/flu next).
## CITY SESSION: 26 + Doral + FortPierce = 28; + Titusville + Jupiter = 30 new (33 incl prior 3).

## CITY BATCH 10 (2026-07-18)
- WELLINGTON DONE (gis01.wellingtonfl.gov): wellington_city_ address 31747 (Admin/Addresses/0), future_land_use 420 (PlanningZoningBuilding/28). bbox -80.37..-80.18/26.57..26.70 = Palm Beach FL. Full zoning not published (only equestrian overlay).
- ORMOND BEACH (running, org services5/tHety5Dlgpjia0CW): address 32857 (OB_EnerGov_GIS_Map/0), zoning 544 (/6), future_land_use 562 (/5). bbox -81.39..-81.03/29.25..29.39 = Volusia FL.
- TAMARAC: thin (survey/damage only) -> Broward-covered. PORT ORANGE: no city org -> Volusia-covered.
## CITY SESSION: 32 new + prior 3 = 35 cities (Wellington+Ormond).

=========================================================
## CITY EXPANSION — COMPREHENSIVE STATE (2026-07-18)
=========================================================
### CITIES PULLED (own distinct GIS, all bbox/city-bounds verified FL, counts =src):
FULL/RICH (4-7 cat): Tampa, St.Petersburg, Daytona Beach, Fort Lauderdale, Clearwater, Orlando, Cape Coral, Port St Lucie, Hialeah, Lakeland, Pembroke Pines, West Palm Beach, Pompano Beach, Boynton Beach, Deerfield Beach, Doral, Bradenton, Ormond Beach, Delray Beach.
PARTIAL (2-3 cat, rest county-served): Miramar, Hollywood(zoning+flu), Palm Coast(zoning+flu), Boca Raton(addr+parks+flood), Fort Myers, Titusville, Jupiter, Ocala(zoning+flu), Wellington(addr+flu), Coral Springs(addr), Fort Pierce(zoning+flu), Largo(flu), Palm Bay(addr/flu/parcels/parks; zoning null-geom), Apopka(zoning+parks), Pinellas Park(zoning), Bonita Springs(flood).
=> ~38 cities with city-specific data.

### GENUINE CITY WALLS:
- Jacksonville FL: consolidated Duval gov, maps.coj.net exposes only operational layers (no parcels/zoning/address FS); AGOL "coj" org is Jacksonville NC (Onslow, jacksonvillenc.gov, CAMA/UDO) - verified via coords, NOT used.
- Boca Raton zoning: utility.arcgis.com proxy returns 500 "Error generating token" (auth wall). Rest of Boca pulled.

### COUNTY-COVERED (no distinct/thin city GIS -> data lives in the county tables already pulled; NOT mislabeled):
- Miami-Dade cities: Miami Gardens, Miami Beach, North Miami, Davie, Weston -> miamidade_* + Miami-Dade County GIS.
- Broward cities: Sunrise, Tamarac, Plantation, Coral Springs(zoning), Margate, Coconut Creek -> Broward GeoHub / broward clip.
- Volusia: Deltona, Port Orange -> volusia_*.
- Osceola: Kissimmee -> osceola_*.
- Seminole: Sanford -> seminole_*.
- Sarasota: North Port, Sarasota city (have sarasota_* + sarasota_city_zoning) -> sarasota_*.
- Alachua: Gainesville (ArcGIS layers = AlachuaCountyGIS; city on dataGNV Socrata) -> alachua_*.
- Escambia: Pensacola (IMAGiNE joint system) -> escambia_*.
- Bay: Panama City -> bay_*.
- Brevard: Melbourne -> brevard_*.
- Palm Beach: Palm Beach Gardens (not found as distinct) -> palmbeach_* / palmbeach clip.

### METHOD/DISCIPLINE (all recorded in [[city-gis-expansion]] memory):
enterprise gis.<city>.gov -> hub-DCAT /api/feed/dcat-us/1.1 -> AGOL owner-search (item->owner->search orgid). Checks: (1) FL coord/bbox, (2) CITY-bounds not county-wide (caught Bradenton ADDRESS_pts=279k=all Manatee -> used ADDRESS__pts_CoBarea + _CoB layers; Fort Pierce AddressPoints_CountyWide skipped), (3) geom-null layers (Palm Bay zoning, Columbia addr = declared geom but served null -> non-spatial, dropped/renamed), (4) proxy hit-or-miss (Delray proxy serves geom, Boca proxy token-walled - test before wall), (5) same-name traps (Jacksonville NC, Monroe OH, Santa Rosa CA, Duval TX, clayutility=Clay).

### REMAINING CITY LONG-TAIL: mostly <40k incorporated cities + CDPs (unincorporated=county by definition: Kendall, Brandon, Riverview, Spring Hill, Town n Country, Wesley Chapel, Poinciana, etc.). Continue owner-search per city where a distinct org exists; expect 0-2 categories each, many county-covered.

=========================================================
## COUNTY REFINEMENTS (2026-07-18) — filling under-covered major counties
=========================================================
Audited tracker: 12 counties at 10/10, most sub-10 gaps are genuine walls (municipal zoning, PA-vendor address, no subdivision layer). Found several MAJOR metros under-covered with FILLABLE gaps:
- BROWARD (was 6/10, missing zoning/flu/subdiv/parks): broward_future_land_use 3310 (services/JMAJrTsHNLrSsWf5 FutureLandUse, =Broward bbox). -> 7/10. Zoning=municipal(have city zonings), parks/subdiv not published county-wide.
- PASCO (9/10, missing FUTURE land use - had only land_use_land_cover=existing): pasco_future_land_use 315352 (services6/Mo4MddfRHpFwT7UF FutureLandUse2050, parcel-level, =Pasco bbox). -> 10/10 [PULLING gt=150].
- ORANGE (8/10, missing address+subdivisions): from ocgis4.ocfl.net Public_Dynamic - orange_address_points 712434 (layer/14), orange_subdivisions 14302 (layer/112). bbox=Orange FL. -> 10/10 [STAGED].
- HILLSBOROUGH (8/10, missing parcels+FLU): hillsborough_parcels_govt_source 527837 (gis.hcpafl.org HCPA WebParcels, sample coord Tampa), hillsborough_future_land_use 3158 (services/4qIOeADCgonipFEW, dissolved, =Hillsb bbox). -> 10/10 [STAGED].
- LEE (9/10): missing subdivisions - no county subdivision layer = WALL.
## NON-COUNTY tracker rows (cruft, not real counties): "St. Petersburg" (0/10 = phantom, HELD for human decision), "Tampa (city)"/"StPetersburg (city)"/"Daytona Beach (city)" (7-8/10, city-tracking rows), "Statewide-FEMA-NFIP" (9/10). These inflate the county count; real FL counties = 67.

## COUNTY REFINEMENT PASS — FINAL (2026-07-18)
Improved this pass (all verified =src, 4326): PASCO 9->10 (FLU 315352), ORANGE 8->10 (address 712434 + subdiv 14302), HILLSBOROUGH 8->10 (parcels 527837 + FLU 3158), BROWARD 6->7 (FLU 3310), POLK 5->6 (FLU 4993). => 15 counties at 10/10, real-county avg 6.67/10.
### MID-TIER remaining (6/10) - fillable but need DEEPER resolution (enterprise/portal servers not at guessed hosts; own-org facades):
- POLK (now 6): zoning/address/parks/subdivisions on gis.polk-county.net/portal (not /arcgis - webappviewer backend); HOASubdivisions=125 is HOA-only not real subdiv.
- SEMINOLE (6, missing parcels/zoning/flu/address/parks): AGOL org seminolegis = facade (0 hosted svcs); real data on county enterprise + SCPA (map.scpafl.org) - needs enumeration.
- HERNANDO (6, missing zoning/flu/address/flood): schools/flood behind Experience Builder apps (prior note); zoning/flu/address need Hernando county server.
- OSCEOLA (6, missing parcels/address/subdiv/flood): PA hub data-ocpagis 500s (prior), address layer empty, flood SSL-walled (prior). Mostly walls.
### DOCUMENTED WALLS (rural 3-4/10, 27 counties): vendor-locked (qPublic/Axis Geospatial), PA-only parcels. Statewide cadastral (services9/Gh9awoU677aKree0) = parcel ceiling. Per relay: Jackson,Franklin,Calhoun,Holmes,Hamilton,Jefferson,Madison,Baker,Bradford,DeSoto,Dixie,Gadsden,Gilchrist,Glades,Gulf,Hardee,Lafayette,Levy,Liberty,Okeechobee,Suwannee,Taylor,Union,Washington. Plus Indian River (IRCPA bulk shp behind Cloudflare), Duval (COJ operational-only), Sumter parcels (skip-list).
### CATEGORY-LEVEL WALLS on high counties (9/10): subdivisions genuinely absent (Bay,Collier,Escambia,Hendry,Lee,Pinellas,StJohns); address PA-vendor (Marion,Martin,SantaRosa); Nassau parks (no layer). These are true data-availability limits, not search failures.
=========================================================
## FINAL DATASET STATE (2026-07-18):
COUNTIES (67): 15 at 10/10, 11 at 9, 7 at 8, 2 at 7, 5 at 6, 17 at 4, 10 at 3. Avg 6.67/10. All gaps documented as fillable-needs-deeper-work vs genuine-wall.
CITIES (~38 w/ own GIS): full done/wall/county-covered breakdown in "CITY EXPANSION - COMPREHENSIVE STATE" section above.

## Seminole 6->7: seminole_parks 6696 (ParkInventory_View, org services3/n4VF6lyYfB5kizho, =Seminole bbox). Parcels/zoning/flu/address are on the SCPA property-appraiser enterprise (map.scpafl.org) - deeper dig; mid-tier counties now yield ~1 category per dig (substantive cats locked behind PA enterprise servers).
## COUNTY-REFINE SESSION TALLY: Broward 6->7, Pasco 9->10, Orange 8->10, Hillsborough 8->10, Polk 5->6, Seminole 6->7 (3 metros to 10/10). Now 15 at 10/10, real-county avg ~6.7/10.

## PERPLEXITY-LEAD PASS (2026-07-18) — Seminole 7->10/10, Polk 6->7/10
SEMINOLE (SCPA enterprise via public proxy path map.scpafl.org/gis/sharing/servers/<GUID>/rest/services/production/...):
  - parcels_building_sales/MapServer/19 -> seminole_parcels_govt_source = 181195 (0 null, 4326)
  - parcels_building_sales/MapServer/13 -> seminole_address_points = 164734
  - landuse/MapServer/14 -> seminole_zoning = 5244
  - landuse/MapServer/9  -> seminole_future_land_use = 4268
  All 4 verified =source, bbox = Seminole FL (-81.46..-80.99 / 28.61..28.88). => SEMINOLE 10/10.
  NOTE: direct /production path is token-walled; the map.scpafl.org/gis/sharing/servers/<serverGUID>/rest/... PROXY path (what the SCPA public viewer uses) serves data unauthenticated. Two server GUIDs: 53774df1... (parcels/address), 87a3fee8... (landuse zoning/flu).
POLK (county OWN production server gis.polk-county.net):
  - /hosting/.../All-In-One_Viewer/Land_Use_and_Zoning/MapServer/10 "2030 Future Land Use" -> polk_future_land_use = 5414 (deleted 9 null-geom -> 5405 polygons). AUTHORITATIVE: this is the /hosting production server the county's public All-In-One_Viewer uses. REPLACED the earlier AGOL copy (services1/YMN4aIYxPejzDjo2 = 4993). 3-mirror question resolved: 4993 (AGOL copy) < 5405 (county /hosting, current) ; picked county production server as authoritative per instruction.
  - /server/.../Map_Property_Appraiser/FeatureServer/3 "Subdivision" -> polk_subdivisions = 6662 (0 null). NEW category. (This is the real PA subdivision layer, NOT the HOASubdivisions=125 HOA-only layer noted earlier.)
  Polk parcels lead (Map_Property_Appraiser/FeatureServer/1 = 437807, bbox=Polk) VERIFIED but NOT pulled: Polk already has parcels_gis. => POLK 7/10.
  POLK REMAINING GAPS (genuine): zoning = no clean county-wide zoning polygon layer (only PD/PUD/overlay layers in Land_Use_and_Zoning 0-9); address = geocoder service only (per lead) = wall; parks = no resolved layer.
  Did NOT use statewide CO_NO fallback (confirmed broken on that service).
TALLY: 16 counties at 10/10 (added Seminole), real-county avg 6.71/10.

## HERNANDO 6->9/10 (2026-07-18) — real org found via web search
Real Hernando GIS = AGOL hosted org services2.arcgis.com/x5zvhhxfUuRDntRe (guessed gis.hernandocounty.us hosts all dead). Found via web search "Hernando County FL GIS ArcGIS REST zoning future land use".
  - Zoning_Flu/FeatureServer/0 "All Future Landuse Categories" -> hernando_future_land_use = 1461 (deleted 1 null -> 1460)
  - Zoning_Flu/FeatureServer/75 "Zoning" -> hernando_zoning = 119386 (parcel-level zoning, gt=100)
  - Parcels_Point/FeatureServer/0 -> hernando_address_points = 120217 (has full SITUS_ADDRESS/HOUSENO/STREET/CITY/ZIP fields = genuine situs address points)
  All bbox = Hernando FL (-82.68..-82.05 / 28.43..28.70), 0 null (after FLU cleanup), 4326.
  FLOOD stays a gap: FEMA_Flood_Lines is only "DFIRM Base Flood Elevation Breaklines" (polyline, 823) - NOT flood-zone polygons. No county flood-zone polygon layer. => HERNANDO 9/10.
  (Org also has: Parcels, Subdivisions, Schools, Hospitals, Hernando_County_Parks, Lakes, DaycareFacilities, Voters, MLS_SALES, PlanningCases - already had schools/parks/etc; parcels/subdiv already present too.)

## OSCEOLA = GENUINE WALL (confirmed 2026-07-18)
  - PA server ira.property-appraiser.org/arcgis = HTTP 523 Cloudflare "origin unreachable" (origin down behind CF).
  - data-ocpagis.opendata.arcgis.com hub = 500s (prior note).
  - AGOL app 32178f7e... item returns owner=None anonymously; OCPA_GIS owner-search = 0 results (org not anon-enumerable).
  - address layer empty, flood SSL-walled (prior notes).
  All source paths blocked at infra level. Parcel ceiling = statewide cadastral (services9/Gh9awoU677aKree0). Stays 6/10.

## SESSION TALLY (Perplexity-lead + Hernando pass): Seminole 7->10, Polk 6->7, Hernando 6->9. Osceola=wall. => 16 counties at 10/10, real-county avg 6.75/10.
LESSON: for a county whose guessed own-server hosts (gis.<county>.gov/.us, maps., gisweb.) all fail DNS/JSON, web-search "<county> FL GIS ArcGIS REST <category>" - the real data is often an AGOL hosted org (services2.arcgis.com/<orgid>) with a clean per-category service list. Parcels_Point-style layers with SITUS_* fields = valid address_points source.

## SUMTER 6->8/10 (2026-07-18) — own server
Own server gis.sumtercountyfl.gov/sumtergis/rest/services (found via web search).
  - Parks_New/MapServer/0 "Park and Recreation Areas" -> sumter_parks = 13 pts
  - Public/SCAS_Base/MapServer/0 "Address" -> sumter_address_points = 113964 pts (SCAS = Sumter County Addressing System; large due to The Villages)
  Both bbox = Sumter FL (-82.27..-81.95 / 28.32..28.96), 0 null, 4326. => SUMTER 8/10.
  REMAINING gaps: subdivisions = NO layer exists on the server (Development_Services has only FLU/zoning/flood; no subdivision layer anywhere) = genuine gap; parcels = SKIP per standing order (SCAS_Base/8 "Parcels" exists if ever needed, plus SWFWMD www25.swfwmd.state.fl.us cadastral).
## SESSION FINAL TALLY (2026-07-18): Seminole 7->10, Polk 6->7, Hernando 6->9, Sumter 6->8. Osceola=confirmed wall. => 16 counties at 10/10, real-county avg 6.78/10.
## TRACKER HYGIENE NOTE: duplicate row "St. Petersburg" (0/10) exists alongside "St. Petersburg (city)" (7/10) - the bare 0/10 row is an orphaned/empty duplicate (cities normally tracked by table-presence, not in county_coverage_status). Left in place (deleting tracker rows = user judgment call); flagged for user.

=========================================================
## UPDATED FINAL DATASET STATE (2026-07-18, after Perplexity-lead + AGOL-org pass)
COUNTIES (67 real): 16 at 10/10, 12 at 9 (Bay,Collier,Escambia,Hendry,Hernando,Lee,Marion,Martin,Nassau,Pinellas,Santa Rosa,St.Johns), 6 at 8 (Columbia,Highlands,Manatee,Monroe,Putnam,St.Lucie,Walton,Sumter), 3 at 7 (Broward,Okaloosa,Polk), 1 at 6 (Osceola=wall), 17 at 4, 10 at 3. Real-county avg 6.78/10 (up from 6.67).
  (+ city rows in tracker: Tampa 7, St.Petersburg(city) 7, Daytona Beach(city) 8, and an orphaned bare "St. Petersburg" 0/10 duplicate = hygiene flag.)
THIS SESSION cracked 4 mid-tier counties via the web-search->AGOL-hosted-org / own-server pattern (Hernando services2/x5zvhhxfUuRDntRe; Sumter gis.sumtercountyfl.gov; Seminole SCPA proxy; Polk gis.polk-county.net). Osceola = confirmed infra wall (PA 523, hub 500, AGOL not anon).
REMAINING real-county gaps are now mostly PREVIOUSLY-CONFIRMED data-availability limits (no new source lead):
  - 9/10 single gaps: subdivisions genuinely absent (Bay,Collier,Escambia,Hendry,Lee,Pinellas,St.Johns); address PA-vendor-locked (Marion,Martin,Santa Rosa); Nassau parks (no layer); Hernando flood (breaklines-only).
  - 7-8/10: Broward subdiv, Okaloosa (2 gaps), Polk (zoning=no clean layer + address=geocoder + parks), Sumter (subdiv absent + parcels skip), Monroe/Putnam/etc per prior notes.
  - 3-4/10 rural (27): cadastral-only, qPublic/Axis-Geospatial vendor-locked. Statewide FDOR cadastral = parcel ceiling.
  - Documented hard walls: Indian River (Cloudflare bot-challenge), Duval (COJ operational-only), Osceola (PA infra 523), Wakulla (Leon-regional partial only).
NEXT-LEAD DEPENDENCY: further real-county gains need NEW external research leads (Perplexity-style) for specific county PA enterprise/AGOL orgs, OR human-browser downloads for the Cloudflare-walled ones. The auto-resolvable frontier is essentially exhausted this pass.

=========================================================
## NEW DATA CATEGORY: BEBR county population (2026-07-18) — NOT tied to 10-cat tracker
Source: UF BEBR bulk Excel (bebr.ufl.edu/wp-content/uploads/...). Downloaded to ~/bebr/.
  - estimates_2025.xlsx "Table 03" -> bebr_county_estimates (68 rows = 67 counties + Florida): county_name, pop_2025, pop_2020, pop_2010, pop_2000, pct_change_2020_2025.
  - projections_2026.xlsx (latest vintage; "2030-2050 County L-M-H Project") -> bebr_county_projections (1020 rows = 68 x low/medium/high x years 2030,2035,2040,2045,2050): county_name, scenario, year, population, estimate_2025.
County names normalized to match parcels/tracker (Miami-Dade, St. Johns, St. Lucie, DeSoto, Palm Beach, Santa Rosa). Verified: 67 distinct real counties + Florida statewide row; sample values cross-checked vs raw workbook (Alachua est 298485, Alachua low-2030 295400, Miami-Dade med-2050 3,140,700). COMPLEMENTS Census ACS on the forward-projection axis (ACS has no projections). Loader: scratchpad/load_bebr.py.

## NEW DATA CATEGORY: BLS labor market (2026-07-18) — NOT tied to 10-cat tracker
Routed via BLS (data.bls.gov / bls.gov) to sidestep FloridaCommerce/floridajobs.org 403 block. curl needs a contact User-Agent. Files in ~/bls/.
  - LAUS county annual (bls.gov/lau/laucntyNN.xlsx, 2020-2024) -> bls_laus_county (335 rows = 67 counties x 5 yrs): county_name, county_fips(12xxx), year, labor_force, employed, unemployed, unemployment_rate.
  - QCEW per-area annual CSV (data.bls.gov/cew/data/api/2024/a/area/<fips>.csv, all 67 FL fips) -> bls_qcew_county (2260 rows): kept agglvl_code 70 (county total, all industries) + 74 (NAICS sector); cols area_fips, county_name, own_code, industry_code, industry_title, agglvl_code, year, annual_avg_estabs, annual_avg_emplvl, total_annual_wages, annual_avg_wkly_wage, avg_annual_pay. industry_title joined from data.bls.gov/cew/doc/titles/industry/industry_titles.csv.
County names normalized to parcels naming (strip " County, FL"; Miami-Dade/St. Johns/DeSoto correct). Verified 67 counties both tables, no missing; Miami-Dade unemployment 2020->2024 7.9->2.4%, Alachua QCEW total 139,023 emp / $1,227 wkly. COMPLEMENTS ACS strongly (time-sensitive employment/wages ACS lacks). Loader scratchpad/load_bls.py.

## DUVAL (Jacksonville) 3->8/10 (2026-07-18) — BIGGEST wall cracked via new techniques
Real COJ server maps.coj.net/coj/rest/services (found via web search; bbox-verified Duval FL sample coord -81.53/30.42 -> NOT the Jacksonville-NC "coj" AGOL trap). Reverses earlier "skip Duval parcels / COJ operational-only wall".
  - CityBiz/Parcels/MapServer/0 -> duval_parcels_govt_source = 407862 (0 null, 4326; slow: gt=100 = ~4000 pages over the connection, ~40min but completed exit=0).
  - ParkAssets/Park_Assets/MapServer/3 "Duval_Parks" -> duval_parks = 405 polygons (bbox Duval FL).
  - Parcels carry authoritative ZON_LABEL / LND_LABEL / FLD_ZONE (COJ delivers zoning/FLU/flood AS PARCEL ATTRIBUTES, no standalone dissolved services). Materialized parcel-level:
      duval_zoning = 385029 (49 codes: PUD,RLD-60,RLD-90,RMD-*...) via CTAS from parcels.
      duval_future_land_use = 385029 (20 codes: LDR,MDR,CGC,RPI,MU...).
      duval_flood_zones = 65827 (parcels in FEMA A/AE/AO/VE/0.2% zones; excluded "NOT IN FLOOD ZONE").
  => DUVAL categories now: parcels, zoning, flu, flood, parks + existing schools/fire/hospitals = 8/10.
  REMAINING gaps (genuine): address = Geocode folder is GeocodeServer only (geocoder, no address point layer) = wall; subdivisions = no layer on COJ server.
  HONEST NUANCE: zoning/flu/flood are derived from the parcels layer's attributes (authoritative source designations, just not published as separate polygon services). Faithful to what COJ serves.
Tracker: Duval 3->8. Avg 6.94.

## INDIAN RIVER 3->10/10 (2026-07-18) — FORMER "GENUINE WALL" fully cracked
Was logged as a genuine wall (IRCPA bulk shapefile behind Cloudflare bot-challenge). NEW technique cracked it: AGOL org ircgis -> Zoning WebMap item (7d25d5abdf7248b684c8fbdaad6e40f7) /data operationalLayers pointed to the county's OWN open server: gisportal.ircgov.com/server3/rest/services (wide open, no token). owner=IndianRiverCountyGIS orgId M0DpVhTwTZ42jNsw.
All bbox-verified Indian River FL (-80.88..-80.32 / 27.56..27.86):
  - IRCPA/Parcels_MS/0 -> indianriver_parcels_govt_source = 82934
  - Planning/IRC_Zoning_MS/0 -> indianriver_zoning = 638 (clean dissolved districts)
  - Planning/IRC_Future_Land_Use_MS/0 -> indianriver_future_land_use = 291
  - Addressing/IRC_Address_Points_MS/0 -> indianriver_address_points = 111748
  - IRCPA/Subdivisions_MS/0 -> indianriver_subdivisions = 2253
  - Parks/IRC_Parks_MS/0 -> indianriver_parks = 27
  - FEMA/FEMA_FloodZones_SFHA_2023_0126/0 -> indianriver_flood_zones = 19664/19674 (99.95%; last 10 OBJECTIDs 19665-19674 UNRETRIEVABLE at source - server returns "Missing features member" for those specific records by any method = genuine source data-quality limit, not a fetch issue).
  fast_pull single-request paging FAILED on the FEMA flood layer (ESRIJSON translation abort on invalid DFIRM polygons); chunked_small(250) + -skipfailures -makevalid worked; used returnIdsOnly to find/append gaps.
  => INDIAN RIVER 10/10 (schools/fire/hospitals existed; added parcels/zoning/flu/address/subdiv/parks/flood).
Tracker: 17 counties at 10/10, 13 at 9, avg 7.04.
LESSON: a county's public Web Map item (AGOL) -> /sharing/rest/content/items/<id>/data?f=json -> operationalLayers[].url reveals the OWN county server even when it's a non-obvious host (gisportal.<county>.com/serverN). This cracks "Cloudflare-walled bulk download" counties whose REST server is actually open. ALWAYS try the webmap-operationalLayers drilldown before declaring a wall.

## WAKULLA 3->9/10 (2026-07-18) — FORMER WALL cracked via AGOL parcels-search
Was a wall (thought to have only Leon-regional partial). Cracked via AGOL content search "Wakulla County parcels type:Feature Service" -> hosted org services9.arcgis.com/vAltLjtfYIJc7pDt (rich Wakulla County GIS). bbox -84.74..-84.08/29.97..30.3 = Wakulla FL.
  - Wakulla_County_Parcels/FeatureServer/0 -> wakulla_parcels_govt_source = 25807
  - Zoning_Map/FeatureServer/30 "Zoning_Master Pro" -> wakulla_zoning = 25624 (parcel-level)
  - Future_Land_Use/FeatureServer/8 "Land Use Master" -> wakulla_future_land_use = 25514 (parcel-level)
  - Subdivisions/FeatureServer/0 -> wakulla_subdivisions = 449
  - Parks/FeatureServer/0 -> wakulla_parks = 9 (Wakulla_County_Parks svc was per-park amenity POINTS, wrong; Parks/0 = boundaries)
  - Flood_Zone_Areas/FeatureServer/0 -> wakulla_flood_zones = 1973
  All verified =source, 0 null, 4326. => WAKULLA 9/10 (schools/fire/hospitals existed).
  GAP: address = no full address-point layer in org (only SepticToSewer_Addresses = partial S2S-project only).
Tracker: 17 at 10/10, 31 at >=9, avg 7.13.
### RURAL WALL SWEEP (AGOL batch search): most rural counties have NO independent GIS org - only statewide FDOR cadastral + regional (CFRPC, TLCGIS, FWC, FDEP) data. Checked Suwannee/Hardee/Levy/Okeechobee/Gadsden = no full parcels/zoning org (Gadsden data is on Leon TLCGIS org ptvDyBs1KkcwzQNJ but Leon-centric, only Gadsden boundary/schools). Wakulla was the standout exception (full org). qPublic/Axis vendor-lock confirmed for the rest.

## RURAL WALL SWEEP RESULTS (2026-07-18) — AGOL parcels content-search on remaining 3-4/10 counties
Method: AGOL search "<County> County parcels type:(Feature Service)", bbox-verify each hit is genuinely FL (heavy out-of-state name-trap density).
CRACKED:
  - GLADES 4->7: rich org services6/90Aakxb3SLGcQGor. glades_parcels_govt_source=11377, glades_zoning(GladesCounty_Zoning_03192026/4)=10234 (parcel-level), glades_future_land_use(GladesCounty_FLU_03192026/0)=963. bbox -81.57..-80.87/26.77..27.21 = Glades FL.
  - BRADFORD 4->5: county's own org services2/lDPOpWlxtwZ1tDwV (owner IT_BCF = Bradford County FL IT). bradford_parcels_govt_source=14902. bbox -82.42..-82.04/29.72..30.15 = Bradford FL. Org has ONLY parcels (+utility/airport/voting), no zoning/flu.
OUT-OF-STATE NAME TRAPS rejected via bbox: DeSoto(TX city), Taylor(TX), Union(NJ/OH), Washington(MD), Calhoun(TX), Hamilton(OH/Cincinnati CAGIS), Jefferson(AL jccal.org/KY), Franklin(VA/PA), Lafayette(WI vacant-only), Madison(ID/VA - service null). Baker: "Parcels in Baker and Nassau Counties" IS bbox-FL (64534, -82.46..-81.43/30.14..30.83) but owner CGRUSER_USG = ad-hoc U-Georgia academic upload (org full of worldwide litter dashboards) = NOT authoritative -> SKIPPED (use statewide FDOR cadastral if Baker parcels ever needed).
NO ORG (confirmed walls, statewide-cadastral only): Suwannee, Hardee, Levy, Okeechobee, Gadsden, Dixie, Gilchrist, Gulf, Lafayette, Liberty, Taylor, Union, Washington, Calhoun, Franklin, Hamilton, Holmes, Jackson, Jefferson, Madison. qPublic/Axis vendor-lock.
Tracker after sweep: 17 at 10/10, 22 at <=4, avg 7.18.

=========================================================
## SESSION FINAL STATE (2026-07-18, end of 5-step autonomous run)
STEP RESULTS:
 1. Deleted phantom "St. Petersburg" 0/10 tracker row.
 2. Confirmed Seminole 10/10 + Polk 7/10 already complete (Polk parcels already present as parcels_gis=437,259; not duplicated).
 3. BEBR population -> bebr_county_estimates(68), bebr_county_projections(1020 to 2050). NEW tables, not in 10-cat tracker.
 4. BLS labor -> bls_laus_county(335, 5yr), bls_qcew_county(2260, county+NAICS-sector 2024). Via BLS to bypass FloridaCommerce 403.
 5. WALL RE-AUDIT with new techniques (webmap-operationalLayers drilldown, AGOL parcels content-search, parcel-attribute materialization) - MAJOR wins:
    - DUVAL 3->8 (maps.coj.net; parcels 407862 + parks + materialized zoning/flu/flood from ZON_LABEL/LND_LABEL/FLD_ZONE)
    - INDIAN RIVER 3->10 (gisportal.ircgov.com/server3; all 7 missing cats; former Cloudflare wall)
    - WAKULLA 3->9 (AGOL org services9/vAltLjtfYIJc7pDt; parcels/zoning/flu/subdiv/parks/flood)
    - GLADES 4->7 (AGOL org services6/90Aakxb3SLGcQGor; parcels/zoning/flu)
    - BRADFORD 4->5 (county org services2/lDPOpWlxtwZ1tDwV IT_BCF; parcels)
FINAL COUNTY DISTRIBUTION (71 tracker rows incl ~4 city rows): 17 at 10/10, 14 at 9, 10 at 8, 6 at 7, 1 at 6, 1 at 5, 15 at 4, 7 at 3. AVG 7.18 (session start 6.67).
GENUINELY EXHAUSTED (remaining are real data-availability limits, not search failures):
 - Rural walls (no independent GIS org; statewide FDOR cadastral + qPublic/Axis vendor-lock): Suwannee,Hardee,Levy,Okeechobee,Gadsden,Dixie,Gilchrist,Gulf,Lafayette,Liberty,Taylor,Union,Washington,Calhoun,Franklin,Hamilton,Holmes,Jackson,Jefferson,Madison,Baker(ad-hoc only). Osceola=infra wall (PA 523).
 - 9/10 single-gaps CONFIRMED genuine absences (AGOL search found no service): subdivisions (Bay,Collier,Escambia,Lee,Pinellas,St.Johns); address PA-vendor (Marion,Martin,Santa Rosa); Nassau parks; Hernando flood.
KEY NEW TECHNIQUE (memory-saved): AGOL Web Map item /data -> operationalLayers[].url reveals a county's own open REST server even behind a "Cloudflare-walled bulk download"; AGOL content-search "<County> County parcels type:(Feature Service)" finds hosted county orgs on services{N}.arcgis.com (bbox-verify FL - heavy out-of-state name-trap density). ALWAYS try both before declaring a wall.

## REGIONAL-CONSOLIDATOR LEADS (2026-07-18) — all independently count+bbox verified
1. SUMTER parcels 8->9: TWO leads both genuinely Sumter FL (bbox -82.31..-81.95/28.31..28.96):
   - gis.ecfrpc.org/arcgis/rest/services/Basemap/MapServer/4 "Sumter Parcels" = 91234
   - www25.swfwmd.state.fl.us/arcgis12/rest/services/BaseVector/parcel_search/MapServer/16 "Sumter County Parcels" = 99406
   USED SWFWMD (99406, higher count, state agency) -> sumter_parcels_govt_source. Sumter now 9/10 (only subdivisions genuinely absent).
2. ARPC regional consolidator gis.arpc.org/**server**/rest/services (the /arcgis path 500s; /server works). "Counties" folder had ONLY:
   - Counties/Gadsden_GIS/MapServer: layer1 Gadsden_Parcels=34690, layer9 FLUMDEC_2020 (unincorp FLU)=2425. GADSDEN 3->6 (+parcels+FLU; already had flood/fire/hospitals/schools).
   - Counties/Jackson_FLUM/MapServer/0 = 568. JACKSON 3->4 (+FLU).
   NOT present at ARPC: Calhoun, Franklin, Gulf, Liberty (lead named them but ARPC has no data -> stay walls). GadsdenVAData/FranklinVAFiles folders = climate vulnerability rasters only, no parcels.
   GADSDEN FLU pull quirk: layer supportsPagination=FALSE, maxRec=2000 < 2425 features, objectIdField='FID' (NOT OBJECTID). fast_pull/chunked_small (offset-based) FAIL. FIX: fetch f=geojson in FID-range partitions (WHERE FID<=split / FID>split, each <2000), ogr2ogr the geojson files. Loader scratchpad/pull_gadsflu3.py.
3. SRWMD = DEAD END for county parcels: org services1/59dBAbzYnRk8johU has only springshed/dashboard/land-cover data + FFA_Branford_Parcels (one town in Suwannee Co) + County_TIGER boundaries. No full county parcels for Hamilton/Jefferson/Madison/Suwannee/Lafayette/Dixie/Taylor -> they stay walls.
4. (Ignored per instruction: CO_NO on services9/Gh9awoU677aKree0 = broken field; flood-domain list = bare domains.)
Tracker after: 17 at 10/10, 6 at <=3, avg 7.24.

## RURAL MEGA-BATCH (2026-07-18/19) — county-specific orgs + ARPC CNTYNAME + SRWMD. All count+bbox verified.
COUNTY-SPECIFIC AGOL/PA ORGS (layer URLs resolved by count-matching leads):
  BAKER services6/HSWu3dhzHf7nZfIa: parcels_web2/0=13265, Flood_Zones/0=759, zoning/0=16606, FLU/0=16446, 911_Addresses_Website2/0=14118, County_Subdivisions/0=212 -> 9/10 (only parks gap).
  DESOTO services3/4x1ttl3OlaXJtuj6: Crisis_Track_Parcel_/0=20106, Crisis_track_Flood_Zone_Area_Map/1=8079 -> 5/10 (zoning/flu/address absent).
  HAMILTON services6/wKGu58lMCTiOrVAj (NON-zero layer ids): June_2026_Parcels/31=14393, Flood_Hazard_Areas/8=5988, ZoneAtlas___2025_Update/4=197, FLU_Map/3=196 -> 7/10.
  JEFFERSON services5/vFMp1Ly1q6rKKp0o: JefCo_Parcels_20260122_162231/0=12482, FEMA_FLOOD_ZONES_2014_20050226/0=4846, FLUM_view/0=12043, 911_Address_Points/0=8548, Subdivisions_vw/0=222 -> 8/10 (zoning=Monticello-city-only, skipped).
  OKEECHOBEE services3/jE4lvuOFtdtz6Lbl (non-zero ids): Parcels_2022/2=31680, FEMA_Flood_Zones/48=615, Zoning/19=32037, Future_Land_Use/83=109; address services7/WqZsvbseLc0NDgA6 Address_Points_View/0=22880 -> 8/10.
  HARDEE gis.hardeecounty.net/arcgis (MapServer): LandUseZoning/6=parcels14659, FloodZones/15=6015, LandUseZoning/20=zoning910, /16=flu1311, /21=subdiv7462; Addressing/3=address14686 -> 9/10 (only parks gap).
ARPC CNTYNAME-FILTERED PARCELS (MapImages/Parcels/MapServer/0, supportsPagination=True; filter VERIFIED via groupBy - isolates correct county, bbox-checked): CALHOUN=10985, FRANKLIN=17780, LIBERTY=5646, +bonus GULF=17478, JACKSON=39266. Plus ARPC Hosted: Franklin_Zones_2292024/0 zoning=18869 (re-pulled via f=geojson - ESRIJSON typed fid as numeric(4), overflowed at 11451), Special_Flood_Hazard_Area_for_Franklin_County/0=2245, Gulf_County_FEMS_SFHA_Layes/0=6812.
SRWMD http://gis.srwmd.org/arcgis (http REQUIRED). Layer-index scheme VERIFIED (SRWMD_Parcels & RM_Flood_Hazard_Areas_FEMA share identical county indexing): Dixie=4,Gilchrist=5,Hamilton=6,Jefferson=7,Lafayette=8,Levy=9,Madison=10,Suwannee=11,Taylor=12,Union=13. Pulling parcels+flood for Dixie/Gilchrist/Lafayette/Madison/Suwannee/Taylor/Union/Levy (batch D). Levy parcels via SRWMD/9=47513 (matches the SWFWMD www45 lead exactly). Counts: Dixie p16384/f8734, Gilchrist 14063/2079, Lafayette 7234/1435, Madison 16428/2604, Suwannee 31908/1484, Taylor 18799/13269, Union 6961/3788, Levy 47513/15835.
POST-BATCH-A/B/C TRACKER: Baker9, Hardee9, Jefferson8, Okeechobee8, Hamilton7, Franklin6, DeSoto5, Liberty5, Gulf5, Jackson5, Calhoun4. 17 at 10/10, only 2 at <=3, avg 7.68.
CRASH NOTE: session interrupted mid-batch-C but batch C completed cleanly (verified all tables =source, 0 null, 4326 - nothing corrupted). Only franklin_zoning needed re-pull (done).
STILL TODO: statewide FLU (flu_l2_2020) for Calhoun/Franklin/Liberty/Levy FLU; Calhoun/Liberty flood; Jackson flood; NFHL for Holmes/Washington (flood + CO_NO parcels - VERIFY CO_NO works first). DeSoto/Baker/Hardee parks gap likely genuine.

## RURAL MEGA-BATCH COMPLETE (2026-07-19) — SRWMD + GeoPlan FLU + NFHL. MILESTONE: 0 counties at <=3/10.
SRWMD http://gis.srwmd.org/arcgis (http) SRWMD_Parcels + RM_Flood_Hazard_Areas_FEMA, layer-index scheme VERIFIED: pulled parcels+flood for Dixie(4),Gilchrist(5),Lafayette(8),Madison(10),Suwannee(11),Taylor(12),Union(13),Levy(9). Parcels all exact. Flood: dense multipart polygons choke paging - used chunked_small + geojson-chunk resume w/ objectid-dedup. Residual server-dropped gaps (genuine SRWMD reliability limit, not fetch error): gilchrist_flood 1979/2079, suwannee 1484/1484(ok), madison 2604(ok), levy 15835(ok), dixie/lafayette/taylor/union ok.
GEOPLAN statewide FLU_L2_2020 (services.arcgis.com/LBbVDC0hKPAnLRpO, county field=COUNTY, dissolved-FLU polygons) filtered by COUNTY -> FLU for 12 counties (all bbox-verified, exact): Calhoun401, Franklin1993, Liberty106, Levy2830, Dixie468, Gilchrist467, Lafayette238, Madison567, Suwannee842, Taylor875, Union312, Gulf816. *** LEAD'S FLU COUNTS WERE WRONG (e.g. lead said Calhoun 11,858; real GeoPlan dissolved = 401). Used verified GeoPlan counts. ***
NFHL FEMA flood (hazards.fema.gov/.../NFHL/MapServer/28, filter DFIRM_ID) for Holmes(12059C),Washington(12133C),Calhoun(12013C),Jackson(12063C). Public NFHL server is FLAKY (intermittent "Missing features" even w/ 6 retries) - got 96-99%: holmes 2842/2942, washington 5900/5935, calhoun 5200/5258, jackson 3255/3355. Deduped by fld_ar_id (unique in FEMA data). Documented server-limit residuals.
CO_NO CONFIRMED BROKEN (again): CO_NO=40/CO_NO=77 on services9/Gh9awoU677aKree0 statewide cadastral return EMPTY - field exists but filter errors. => Holmes/Washington get NO parcels (genuine wall). Only flood (NFHL).
COUNTY-ORG batch A/B/C (verified earlier): Baker9, Hardee9 (only parks gap), Jefferson8, Okeechobee8, Hamilton7, Franklin7, Calhoun6, Gulf6, Jackson6, DeSoto5, Liberty6.
=========================================================
## FINAL DISTRIBUTION (2026-07-19): 10/10:17 | 9/10:17 | 8/10:11 | 7/10:8 | 6/10:14 | 5/10:2 | 4/10:2 | <=3:0. AVG 8.01 (session start 6.67).
Holmes/Washington=4/10 ceiling (parcels walled by broken CO_NO + no county org; flood via NFHL). DeSoto=5 (no zoning/flu/address per source). Rural SRWMD/Apalachee counties=6 (parcels+flood+flu; zoning/address/subdiv/parks genuinely absent for most). 
NEW SOURCES for memory: SWFWMD www25 parcel_search (per-county parcel layers), SRWMD gis.srwmd.org http per-county-layer scheme, ARPC CNTYNAME filter + Hosted folder, GeoPlan FLU_L2_2020 COUNTY filter (statewide FLU for ANY county), NFHL DFIRM_ID (statewide flood fallback), FEMA NFHL flakiness, CO_NO permanently broken. County AGOL orgs: Baker HSWu3dhzHf7nZfIa, DeSoto 4x1ttl3OlaXJtuj6, Hamilton wKGu58lMCTiOrVAj, Jefferson vFMp1Ly1q6rKKp0o, Okeechobee jE4lvuOFtdtz6Lbl, Hardee gis.hardeecounty.net.

=========================================================
## REGISTRY: FULL 67-COUNTY COVERAGE REACHED (2026-07-19)
data_source_registry: **249 active sources / 67 counties / 10 inactive**. Every FL county now has >=1 verified-live source.
HOW THE LAST 16 WERE CLOSED:
 - Volusia: legacy script used COLON format "service:layer:table" (parser only did pipe) -> URL=BASE/service/FeatureServer/id. 5 sources.
 - Charlotte: "layerid|table" with BASE already ending /MapServer -> URL=BASE/id (my earlier parser wrongly appended /FeatureServer/0). 4 sources.
 - Martin: NOT REST. Parcels come from a zipped File Geodatabase (pamartinfl.gov, ~154MB, verified HTTP200 application/zip). Built new **gdb_download** technique in master_refresh.py (download->unzip->find .gdb->ogr2ogr). Zoning/FLU are normal REST (geoweb.martin.fl.us .../Administrative_Areas/MapServer/8 and /9).
 - 13 scriptless counties re-resolved with a new ~/resolve_county.py: walks a county server/org, filters layers by category keywords, counts them, and MATCHES AGAINST THE EXISTING DB TABLE COUNT. Hosts found:
     Bay gis.baycountyfl.gov/arcgis | Citrus services7/G6NDVglwRcrz6l7N (Citrus County BOCC) | Clay maps.claycountygov.com/server
     Columbia gis.columbiacountyfla.com/hosting | Escambia gismaps.myescambia.com/arcgis | Hendry services7/8l7Qq5t0CPLAJwJK
     Highlands services2/xEhz4K4uxbjGXOPE (Highlands BOCC) | Leon intervector.leoncountyfl.gov/intervector
     Monroe services.arcgis.com/D7K7hj5GW1YIVRiA | Nassau maps.ncpafl.com/ncflpa_arcgis | Okaloosa okgis.myokaloosa.com/arcgis
     Santa Rosa services.arcgis.com/Eg4L1xEv2R3abuQd (gisupdates_SantaRosa) | Walton services1/TaXHPwWfIMuzJ7Ov (CitizenServe/EnerGov vendor org that hosts Walton's real layers - found via webappviewer 03358c36 -> webmap -> operationalLayers)
STRICT VALIDATION (register_strict.py) - every auto-match must pass BOTH:
  (a) live count within max(5, 10%) of the existing DB table count, and
  (b) layer NAME contains the category keyword AND not a conflicting one.
  This caught 5 genuine bad matches the loose first pass let through: "Flood **Zon**es"->zoning (Nassau, Monroe), "**Park**way"->parks (Highlands), count mismatches (Bay flood 14vs35, Santa Rosa parks 18vs61). Those 5 category-slots are now REJECTED/inactive = real gaps needing manual source resolution (the county table still holds its data; only the refresh source is unknown).
  1 false-reject reinstated: Columbia FLU (layer 'COFU_Web' in service folder FLUM, exact 316=316).
KNOWN CATEGORY GAPS (table exists, no verified refresh source): Bay flood_zones, Highlands parks, Monroe zoning, Nassau zoning, Santa Rosa parks. Plus flood_zones for several counties came from statewide clips, not per-county services (Columbia/Citrus/Highlands/Nassau/Okaloosa/Monroe/Santa Rosa flood NO MATCH) - those are statewide-clip derived.
LESSON: WSL /tmp is WIPED between wsl.exe invocations (VM shuts down) - persist working files to $HOME, not /tmp.
## HONEST COVERAGE ACCOUNTING (2026-07-19, end of registry work)
COUNTY-LEVEL: all 67 FL counties have >=1 verified-live refresh source (249 active registry rows).
CATEGORY-LEVEL: of 299 COUNTY category tables, 226 (76%) have an active refresh source; 73 do not.
CITY-LEVEL: 110 city category tables (the separate ~38-city track) were never in registry scope - only 1 registered.
THE 73 UNREFRESHED COUNTY TABLES, by pattern:
  - ~25 are *_flood_zones (alachua,bay,bradford,brevard,citrus,collier,columbia,flagler,gadsden,glades,highlands,liberty,
    manatee,martin,miamidade,monroe,nassau,okaloosa,palmbeach,pinellas,polk,putnam,santarosa...). These were built by
    CLIPPING the statewide fema_flood_zones table, not from per-county services - which is why resolve_county found
    "NO MATCH" for flood on nearly every county. CLOSING THIS IS ONE TECHNIQUE, NOT 25 URL HUNTS: add a
    `statewide_clip` technique to master_refresh.py that re-clips statewide fema_flood_zones/NFHL per county boundary.
  - municipal sub-layers inside counties (flagler_beach/bunnell/marineland_zoning, lake_howeyinthehills_zoning) - low value.
  - statewide tables caught by the naming pattern (fema_flood_zones, hifld_mobile_home_parks) - not county sources.
  - genuine per-category gaps needing manual resolution: hillsborough_parcels_govt_source, pasco_future_land_use,
    broward_future_land_use, orange_subdivisions, alachua_(address/flu/parks), flagler_(address/subdiv), brevard_subdivisions,
    citrus_subdivisions, hendry_future_land_use, hernando_(parks/subdiv), marion_subdivisions, martin_(parks/subdiv),
    highlands_parks, monroe_zoning, nassau_zoning, santarosa_parks, bay_flood_zones.
NEXT LEVERS (highest value first): (1) statewide_clip technique -> closes ~25 flood rows at once;
(2) ~18 genuine per-category manual resolutions; (3) city track if it should be refreshable at all.

=========================================================
## NEW CATEGORY: SINKHOLE / SUBSIDENCE INCIDENTS (2026-07-19)
Source: ca.dep.state.fl.us/arcgis/rest/services/OpenData/FGS_SUBSIDENCE/MapServer/0 ("Subsidence Incident Reports")
VERIFIED: 4417 points, statewide FL bbox (-86.66..-79.9 / 24.52..30.99), point geom, maxRec 1000, pagination TRUE.
*** THE SPEC'S GUESSED FIELD NAMES WERE WRONG - verified against real metadata as instructed. ***
  Spec guessed: INCIDENT_ID, DATE_REPORTED, SUBSIDENCE_TYPE/INCIDENT_TYPE, NOTES/DESCRIPTION, CITY/ADDRESS.
  ACTUAL: OBJECTID, REF_NUM, DATE_REV, EVENT_DATE, TRUE_SINK, LONGDD, LATDD, COUNTY, TWNSHP/RANGE/SECTION,
  ACCURACY, RPT_SOURCE, RPT_NAME, OCITY, OZIP, SIZDIM, SINSHAPE, SINLNGTH, SINWIDTH, SINDEPTH, SLOPE, WATSIN,
  WATBLS, LIMVIS, CAVVIS, SUBRATE, PROPDAM, REPAIR_S, DRAINSTR, SOILTYPE, COMMENTS, COMMENTS_2, ACCESS_.
  Original field names PRESERVED in all tables (per spec step 1).
PIPELINE (scratchpad/ingest_sinkholes.py, re-runnable):
 1. raw statewide pull -> fgs_subsidence_incidents_raw (4417 = source, 0 null geom)
 2. county derived FRESH via ST_Intersects vs fl_county_boundaries (basename + geoid=FIPS) into
    derived_county_name / derived_county_fips. 59 counties matched, 0 points outside FL polygons.
    *** 24 rows where the source's own COUNTY field DISAGREES with the derived county - derived wins.
    (Validates the instruction not to trust the source COUNTY field.) NOTE: use fl_county_boundaries.BASENAME
    ('Alachua') not NAME ('Alachua County') or table names come out as 'alachuacounty_...'.
 3. split -> <county>_sinkhole_incidents (59 tables). Top: Hillsborough616, Marion477, Citrus448, Pasco341,
    Hernando311, Polk304, Orange231, Suwannee212 - i.e. the real FL sinkhole belt, geologically plausible.
 4. CAVEAT applied as a postgres COMMENT ON TABLE to all 59 + raw (verified stored):
    "Sourced from FGS Subsidence Incident Reports - voluntary, unverified incident locations, not a modeled
     risk score or parcel-level hazard. Descriptive only, not suitable for underwriting or risk-rating use."
 5. registered in data_source_registry as category='sinkhole_incidents' (statewide row, monthly refresh).
    VERIFIED it is a DISTINCT category: 0 sinkhole rows categorised as flood/hazard; county 10-category
    tracker unchanged (Hillsborough still 10) - sinkholes do NOT satisfy flood/hazard.
## OTHER ITEMS THIS PASS
 - HIGHLANDS address points: services2/xEhz4K4uxbjGXOPE SiteAddressPoints/0 = 150457 (lead said 151354),
   bbox -81.57..-80.98/27.03..27.65 = Highlands FL. PULLED+registered. Highlands tracker 3->6/10 (old value
   was undercounting; real categories = address,fire,flood,hospitals,parks,zoning).
 - HIGHLANDS parcels = CONFIRMED WALL (token-gated HTTP 499 on county server; PA has no public REST).
   Registered inactive with note; statewide FDOR cadastral remains a DOCUMENTED PARTIAL, not a full win.
 - LEON flood = NOT a single layer. TLC_OverlayFEMA_D_WM/MapServer layers: 0=BFE lines, 1=Zone AE Floodway,
   2=Zone AE 100yr, 3=Zone A 100yr, 4=Zone X5 500yr. Needs a union/append of 1-4. Registered inactive w/ note.
 - MONROE TLS: the lead warned of an incomplete cert chain needing -k. VERIFIED NOT NEEDED for the registered
   Monroe source (services.arcgis.com/D7K7hj5GW1YIVRiA) - returns 200 under STRICT TLS. Warning must apply to
   a different Monroe host; no -k added.
 - The 12 "full REST coverage" counties in the lead were already independently resolved+registered last pass;
   the lead's per-county URL detail did NOT arrive in the message, so nothing was taken on faith.
## MARTIN gdb_download VALIDATED END-TO-END (2026-07-19)
The direct path pamartinfl.gov/tools-resources/data-downloads/47-real-master-shape-files-geodatabase/download
IS clean (HTTP 200, application/zip, 154.8MB, no bot-protection) - confirmed by an actual full download, not just headers.
Zip contains BOTH a shapefile (real_master.shp) and real_master.gdb; the .gdb has exactly ONE layer (real_master, MultiPolygon).
FIRST ATTEMPT FAILED with "current transaction is aborted". Root cause was NOT multi-layer and NOT a schema issue -
the real first error (masked by the aborted-transaction cascade) was:
    ERROR 1: COPY statement failed.  ERROR: canceling statement due to statement timeout
i.e. the SAME Supabase pooler statement_timeout that bites dense-polygon COPYs. The gdb handler was missing -gt,
so ogr2ogr tried ONE giant COPY of 98k dense multipolygons.
FIX: h_gdb_download now passes -gt (page_size, default 100) + --config PG_USE_COPY YES. Registry page_size=100 for martin_parcels.
RE-TEST: full refresh dry-run -> martin_parcels 98566 -> 98566 (0.0%) OK. Technique is production-ready.
DIAGNOSTIC LESSON: when ogr2ogr reports "current transaction is aborted", that is a CASCADE - grep the stderr with
`grep -v "current transaction is aborted"` to find the actual first error.

=========================================================
## NEW HAZARD/ENVIRONMENTAL CATEGORIES (2026-07-19)
### 1. FEMA DISASTER DECLARATIONS - category=disaster_declarations  [CLEAN WIN]
OpenFEMA v2 API https://www.fema.gov/api/open/v2/DisasterDeclarationsSummaries?$filter=state eq 'FL'
Genuine structured REST API ($top/$skip/$inlinecount). Pulled 2794 = exactly the reported FL count. 28 original
fields preserved. County derived by FIPS join (lpad(fipsStateCode,2)||lpad(fipsCountyCode,3) = boundaries.geoid):
2705 matched, 89 unmatched = statewide records with fipsCountyCode='000' (correct, not an error).
NOTE 19 rows where FEMA's own designatedArea disagrees with the FIPS-derived county - derived wins.
-> fema_disaster_declarations + 67 per-county <prefix>_disaster_declarations (ALL 67 counties).
Incident types: Hurricane 1432, Severe Storm 376, Fire 280, Tropical Storm 266, Biological 150, Freezing 147,
Flood 74, Tornado 38. Top counties Collier54, Manatee50, Bay49, Sarasota48, Hillsborough47, Monroe47.
*** THIS CONFIRMS THE HURDAT2/IBTrACS CALL: 1698 hurricane+tropical-storm declarations already county-indexed is a
cleaner proxy for "which storms hit which counties" than track geometry. Hurricane tracks remain UNPURSUED. ***
CAVEAT on every table: declaration = administrative/eligibility record for a county, not a property-level hazard
measure or risk score; descriptive history only, not for underwriting.
### 2. FDEP BROWNFIELDS - category=brownfields  [CLEAN WIN, precise scope]
https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/BROWNFIELD_AREAS/MapServer  layer0=Areas, layer1=Sites
Areas 624/624, Sites 571/571, 0 null geom, 0 unassigned. County derived by LARGEST-OVERLAP spatial join (polygons
can straddle counties). 3 rows where source COUNTY disagreed (areas), 0 (sites).
-> fdep_brownfield_areas (49 county tables) + fdep_brownfield_sites (35 county tables).
PRECISION CAVEAT (as instructed): these are FORMALLY DESIGNATED brownfield areas/sites under Florida's Brownfields
Redevelopment Act (local-government resolution) - a REDEVELOPMENT-PROGRAM DESIGNATION LAYER, NOT a comprehensive
contaminated-sites inventory and NOT a contamination severity/risk score.
### 3. EPA FRS / SUPERFUND - category=superfund_facilities  [REAL API - answered the open question]
ANSWER: EPA FRS IS genuinely queryable via the Envirofacts REST service (data.epa.gov/efservice/), filterable to
Florida - NOT request-based only. Unscoped FL facility count = 294,608 (ALL regulated facilities).
SCOPED to Superfund: pgm_sys_acrnm=SEMS -> 646 FL records (CERCLIS/NPL/SUPERFUND acronyms return 0 - SEMS is current).
-> epa_superfund_facilities (646) + 54 per-county tables. County derived from std_county_fips, then exact name,
then NORMALIZED name (recovered 74 - EPA writes 'MIAMI DADE' without the hyphen), plus legacy 'DADE'->Miami-Dade (1).
FINAL 617/646 matched; the remaining 29 are literally 'NOT DEFINED' in EPA's source data. Non-spatial (address-based).
CAVEAT: presence = TRACKED in Superfund program; does NOT imply current contamination, active cleanup, or NPL listing.
### 4. WILDFIRE - *** NOT INGESTED - THE LAYER IS NOT WHAT ITS NAME SAYS ***
https://gis.myfwc.com/hosting/rest/services/Open_Data/Fire_Occurrences_in_Florida/MapServer/0
Despite the name "Fire Occurrences in Florida", the layer description states it is DERIVED FROM USGS BURNED AREA
PRODUCTS (Hawbaker et al. 2017), evaluating annual BAECV Burn Probability RASTER datasets. Reality:
 - POLYGON geometry (not incident points), 63 fields that are ANNUAL BURN FLAGS (B1994..B2019) per polygon
 - 3,285,550 features (a raster-to-vector burn grid)
 - bbox reaches 33.6N - well north of Florida (max ~31N), so it spills into GA/AL
This is a remote-sensed burn-detection grid, NOT incident occurrence records, and does not map onto the
sinkhole-style "occurrences -> spatial join -> per-county" treatment. Ingesting 3.3M polygons under a
"wildfire occurrences" label would be actively misleading. NOT INGESTED - flagged for a human decision.
If per-county burn HISTORY is genuinely wanted, the honest framing is an aggregate (burned-area by county by year),
which is a derived analytic product and should be labelled as such. FWC has no point-based fire-occurrence service
(only this one fire-related service in the Open_Data folder).
### SKIPPED per instruction (confirmed genuine limitations, not chased): storm surge inundation polygons,
code enforcement/liens, FL-specific LUST. Hurricane tracks deprioritised - superseded by FEMA declarations (above).

=========================================================
## LEAD ROUND: FDOT / Broward geohub / Osceola ocgis / Polk permits (2026-07-19)
### 1. FDOT statewide parcels -> DEAD (token-gated)
https://gis.fdot.gov/arcgis/rest/services/Parcels/FeatureServer returns {"error":{"code":499,"message":"Token Required"}}
on both the service root and a count query. It is NOT a usable alternative statewide fallback to the DOR cadastral
(whose CO_NO filter is separately broken). => WASHINGTON + HOLMES parcels re-confirmed as WALLS. Holmes is qPublic-only.
Both logged inactive in the registry with the reason. Not forced.
### 2. Broward -> WIN, last gap CLOSED
geohub-bcgis.opendata.arcgis.com DCAT is reachable (~814KB) but its REST URLs resolve to the SAME org already
registered (services.arcgis.com/JMAJrTsHNLrSsWf5) plus the bcgishub.broward.org host. The DCAT itself listed NO
land-use titles and was flaky on refetch (71 bytes second time). Going straight at the AGOL org found it:
  services.arcgis.com/JMAJrTsHNLrSsWf5/arcgis/rest/services/FutureLandUse/FeatureServer/0
  count 3310 == broward_future_land_use 3310 EXACT, bbox -80.45..-80.07/25.95..26.36 = Broward FL. REGISTERED.
Broward now has all its existing category tables refreshable (parcels 553909, address 483733, FLU 3310).
Fort Lauderdale city GIS not needed - the county-wide gap was FLU, not centerlines.
### 3. Osceola ocgis.com -> *** WRONG-STATE TRAP, REJECTED ***
https://www.ocgis.com/arcpub/rest/services is ORANGE COUNTY, CALIFORNIA - not Osceola FL.
Tell-tale folders: JWA (John Wayne Airport), Treasurer_Tax_Collector, HealthCareAgency, OCParks, OCWR, OC_Sheriff.
PROOF: Map_Layers/Parcels extent = -118.12..-117.41 / 33.38..33.95 (Orange County CA). Osceola FL would be
~-81.5..-80.7 / 27.6..28.4. "OC" = Orange County CA. Adds to the trap list: Santa Rosa CA, Monroe OH, Duval TX,
Jacksonville NC, Clay GA, Columbia SC, and now Osceola->Orange County CA.
OSCEOLA county parcels remain a WALL (PA ira.property-appraiser.org still 523; data-ocpagis hub 500s).
PARTIAL taken: St. Cloud city (a municipality IN Osceola) Referenced_Layers/Parcels/MapServer/**42** (not layer 0)
= 54806, bbox -81.38..-81.16/28.12..28.34 verified inside Osceola FL. Pulled as stcloud_city_parcels (CITY TRACK).
COMMENT + registry note state explicitly it is PARTIAL and does NOT satisfy Osceola county parcels coverage.
### 4. Polk permits -> PERMANENT LIMITATION, CLOSED
No bulk permit API exists; portal-based lookup (Accela) + formal records request only. Not automatable at scale.
Logged inactive as a permanent limitation - same class as Sumter subdivisions. Stop searching this one.
REGISTRY after round: 257 active / 16 inactive.

=========================================================
## "WILDFIRE OCCURRENCES" -> DELIVERED AS burn_detection_history (2026-07-19)
FEMA declarations + FDEP brownfields were ALREADY ingested in the prior pass (2794 / 624+571) - re-verified present,
not re-run. Only the wildfire item was outstanding.
### WHAT THE SOURCE ACTUALLY IS (verified, all 63 fields listed)
gis.myfwc.com/hosting/rest/services/Open_Data/Fire_Occurrences_in_Florida/MapServer/0
 - esriGeometryPOLYGON, 3,285,550 features, supportsStatistics=TRUE
 - fields: B1994..B2020 (binary burn flag per year), FYEAR94..FYEAR20, LFFI, FRQ (fire frequency),
   YLB (year last burned), TSPF (time since previous fire), Shape_Area/Length. NO county field. NO incident id,
   date, cause, name, or per-fire acreage. Sample row = a ~5.5ha burn patch.
 - description: derived from USGS Burned Area Products (Hawbaker et al. 2017), annual BAECV burn-probability RASTERS.
=> It is a satellite burn-DETECTION raster product, NOT incident occurrences. A point-in-polygon "occurrences" join
   as originally specced is not possible (no points, no incidents).
### WHAT WAS BUILT INSTEAD (honest equivalent)
Server-side aggregation via outStatistics + county-polygon spatial filter (67 POSTs, 0 failures) - no 3.3M-polygon dump:
 - fl_burn_detection_history: county_name, county_fips, year, burned_patches (1809 rows = 67 counties x 27 yrs 1994-2020)
 - fl_burn_detection_summary: total_burn_patches, total_burn_area_sqm per county
 - 67 per-county <prefix>_burn_detection_history tables; 69 tables carry the caveat comment
 - registry category = burn_detection_history (technique arcgis_statistics_by_county)
### TWO FINDINGS THAT FORCED THE RENAME (originally named "wildfire")
1. *** IT IS NOT WILDFIRE - IT IS MOSTLY AGRICULTURAL/PRESCRIBED BURNING. ***
   Everglades Agricultural Area box (-81.0..-80.4 / 26.3..26.9) alone = 614,586 detections = ~19% of the ENTIRE
   statewide layer, in a ~60x65km agricultural rectangle. That is routine sugarcane pre-harvest burning. It is why
   the "top wildfire counties" came out as Palm Beach 534,926 / Hendry 119,337 / Glades 80,259 - the EAA cane belt.
   Publishing that as "wildfire" would have been actively misleading. RENAMED wildfire_* -> burn_detection_*.
2. 23% of the source lies OUTSIDE Florida: 3,285,550 total vs 2,528,188 inside the FL envelope (757,362 out-of-state).
   This explains why the per-county sum (2,141,362) is LOWER than the layer total, not higher - the remainder is
   out-of-state plus water/coastal areas inside the envelope but outside county polygons.
3. Year ranking (2018 644k, 2020 551k, 2019 512k highest; 1998 NOT a standout despite being FL's historic wildfire
   year) further confirms this tracks prescribed-burn volume + improving satellite detection, NOT wildfire severity.
   Caveat states year-over-year change is NOT a fire trend.
County 10-category tracker verified UNCHANGED at 7.99 - burn_detection does not satisfy flood/hazard.

=========================================================
## 311 / CODE ENFORCEMENT (2026-07-19) - "noise" premise did NOT survive verification
### THE HEADLINE: MIAMI-DADE 311 HAS NO NOISE DATA
Resolved the real REST endpoints (hub 'about' pages -> org services.arcgis.com/8Pc9XBTAsYuxx9Ny):
  services data_311_2013 .. data_311_2023 (11 yrs) + 311_Service_Request. 2023=343,851 / 2019=318,329 / 2015=282,572.
  Schema (verified, NOT guessed): ticket_id, issue_type, issue_description, case_owner, street_address, city, zip_code,
  neighborhood_district, ticket_created_date_time (epoch ms), ticket_status, latitude, longitude, method_received,
  sr_priority, goal_days, actual_completed_days, ticket_year, ObjectId. geometryType=None (a TABLE) but lat/lon present.
*** Filtering to noise returned ZERO across 2015/2019/2023. Ruled out a broken query with a CONTROL TEST:
    POTHOLE returns 10,984 via both LIKE and equality, so the mechanism works. Then pulled the FULL distinct
    issue_type list = 213 values, and NONE match noise|loud|sound|music|stereo|bark|disturb|nuisance.
    => Miami-Dade 311 genuinely does not publish noise complaints (they route elsewhere, e.g. police non-emergency).
    The requested "noise complaints" category DOES NOT EXIST for Miami-Dade either. No noise category was created. ***
### WHAT WAS BUILT INSTEAD (within stated intent - user named "code enforcement" as an equivalent target)
miamidade_code_enforcement_requests = 311 requests filtered to code-enforcement issue types.
  2015=34,003 | 2019=39,958 | 2023=36,404 -> 110,365 rows (each == source count exactly)
  109,262 geocoded; SPATIAL VALIDATION: 109,256 of them fall inside the Miami-Dade county polygon (6 strays).
  1,103 rows have no lat/lon. Geometry built from lat/lon (source is a table, not a feature layer).
  Types: illegal dumping (10,453), junk/trash/overgrowth (4,672), unauthorized commercial vehicle (4,623),
  abandoned property/vehicle, failure to obtain zoning permit, unauthorized use, graffiti, fence/sign violations.
  Registry category=code_enforcement_requests, county_name='Miami-Dade'.
CAVEAT stored on table: NOT noise; RESIDENT-REPORTED SERVICE REQUESTS not adjudicated violations/liens (may be DUP,
unfounded, or closed without action); counts reflect reporting behaviour as much as conditions; MIAMI-DADE ONLY with
no statewide equivalent; not for underwriting.
### THE TWO EXTRA LEADS - CHECKED DIRECTLY, NOT ACCEPTED SECONDHAND
1. TAMPA opendata.tampa.gov IS a real CKAN instance and the API IS functional: package_list returns 28 datasets.
   package_search for 311 / "service request" / "code enforcement" / noise -> success=true, count=0 for ALL FOUR.
   Of the 28 dataset names the only near-match is 'construction-services-dataset'. => Tampa genuinely does not
   publish 311/code-enforcement data. Verified negative (functional API, empty result), not an access failure.
2. ORANGE netapps.ocfl.net/CETitleViolationSearch -> 301, followed to .../CETitleViolationSearch/ (200, 6,813 bytes).
   Plain ASP.NET postback form: <form action="./">, scripts are only jquery-1.12.4/bootstrap, and there are NO
   ajax/fetch/url hints and NO .asmx/.ashx//api/ endpoints in the page. It is server-side rendered, not a frontend
   over a JSON API. => No bulk/API access. Verified by direct inspection.
=> The Miami-Dade-only conclusion STANDS, now on our own evidence rather than secondhand research.

=========================================================
## INSURANCE DATA VIA PDF PARSING (2026-07-19) - new technique: pdf_table_extract
TOOLING: NO pdf tooling existed (no pdfplumber/camelot/tabula/pypdf, no java, no ghostscript, no pdftotext).
Installed **pdfplumber 0.11.10** (pure python, no java/gs needed) via `pip install --break-system-packages`
(WSL python is PEP-668 externally-managed; system-wide install keeps it visible to the existing scripts).
### 1. OIR ISU REPORT -> fl_insurance_avg_premiums  [DONE, 67/67]
january-2026-isu-report-final.pdf (30pp). Table "Average Premiums Charged" spans pp.19-21:
County | Homeowners (Avg Incl Wind, Avg Ex Wind) | Condo Unit Owners (Avg Incl Wind, Avg Ex Wind).
Parsed 67/67 counties, none missing. Keyed (county, report_period) so future reports APPEND.
*** VALIDATION PROBLEM: the report contains NO printed statewide average - the requested sanity check does not
exist in the document (only non-county table rows are the title and header; no Statewide/Total row anywhere). ***
SUBSTITUTE VALIDATION: re-extracted the same table via an INDEPENDENT text-regex path and required agreement.
66/67 matched immediately; the 1 "mismatch" (DeSoto) was a defect in MY validator, not the data - the PDF spells it
"Desoto" (lowercase s) and my text check was case-sensitive. Raw line confirmed: 'Desoto $3,449 $1,407 $1,111 $650'
== the table-parser output exactly. => all 67 x 4 values verified by two independent methods.
PLAUSIBILITY: highest Monroe $7,829 / Palm Beach $6,412 / Broward $6,220 (coastal S FL);
lowest Sumter $2,111 / Marion $2,217 / Baker $2,317 (inland N-central). Correct hurricane-exposure gradient.
### 2. OIR RESIDENTIAL MARKET SHARE -> *** LEAD'S PREMISE IS WRONG - NO COUNTY/ZIP DATA ***
The page publishes 51 files and they are ALL .xlsx (not PDF - good), but every one is a STATEWIDE SUMMARY:
  13x monthly_mir_statewide_summary_by_company_and_policy_type
  13x monthly_mir_statewide_summary_by_company_and_commercial_personal
  + quarterly/quasr statewide equivalents 2022q3..2025q4.
Downloaded Jan-2026 monthly MIR and opened it: exactly ONE sheet, "By Company then Policy Type", 442 rows x 34 cols,
columns = NAIC code / Company name / Policy type / policy counts. THERE IS NO COUNTY OR ZIP BREAKDOWN, in the
filenames or inside the workbook. The claim of "monthly, county AND zip-code level policy counts by carrier" is NOT
supported by what OIR actually publishes here. NOT INGESTED - it is statewide-carrier grain, a different dataset
from the county model, so flagged for a human decision rather than force-fitted.
### 3. CITIZENS DETAIL BY COUNTY -> fl_citizens_policies_by_county  [DONE, fully validated]
20260430 Detail by County.pdf (6pp). Structure: 6 PRODUCT sections x county rows, cols = Policies In-Force,
Building Count, Total Premium, Total Exposure (+ change-from-prior-month). Parsed by text lines (extract_tables
only returned header fragments; text parsing is the reliable path here).
FIRST ATTEMPT FAILED VALIDATION AND CORRECTLY REFUSED TO LOAD. Two real bugs, both surfaced by the check:
  (a) product regex '^(PR-|CR-)\w+' missed **CNR-M and CNR-W**, so those rows were mis-attributed to CR-W
      (CR-W came out 4,280 vs printed 1,501 - over by 2,387, the tell-tale signature);
  (b) the PDF writes **"ST JOHNS"/"ST LUCIE" WITHOUT periods**, so 12 county rows never matched -> the shortfalls.
AFTER FIX: 220 county-product rows, 67 counties, 6 products (PR-M, PR-W, CR-M, CR-W, CNR-M, CNR-W) and
*** EVERY per-product county-sum equals the PDF's own printed Total exactly, and the grand total = 294,894 which
equals Citizens' published Apr-2026 statewide policies-in-force. ***
Top counties by PIF: Miami-Dade 71,400 / Broward 47,052 / Palm Beach 25,565 / Pinellas 22,376 / Monroe 12,192.
CAVEAT (both tables): PDF-SOURCED, PERIODICALLY PUBLISHED, NOT A LIVE API - refresh cadence follows OIR/Citizens
publication, unlike the REST categories. ISU figures are averages across policies, not quotes/parcel-level premiums.
Citizens counts are RESIDUAL-MARKET share, 'Excludes Takeouts', and are dominated by depopulation (statewide PIF
fell ~810k Apr-2025 -> ~295k Apr-2026), so they are NOT a measure of insurance demand or risk in a county.

=========================================================
## FL CLERK "OFFICIAL RECORDS" API SURVEY - 10 largest counties (2026-07-19) - INVESTIGATION ONLY, nothing ingested
VERDICT: NO county in the top 10 publishes a documented public API or bulk download for Official Records.
All are search-only portals on a handful of vendor platforms, and several actively refuse non-browser clients.
| County       | Platform                        | Probe result                                   | URL-automatable? |
|--------------|---------------------------------|------------------------------------------------|------------------|
| Miami-Dade   | custom ASP.NET                  | 200; page JS calls an INTERNAL JSON API        | see note below   |
| Broward      | AcclaimWeb (Kofile/Acclaim)     | 403 to non-browser client (WAF)                | no               |
| Palm Beach   | custom (erec.mypalmbeachclerk)  | 200 -> redirect /Home/RedirectToHome gate      | no               |
| Hillsborough | Kofile QuickLinks               | 200, ASP.NET <form method="post"> (viewstate)  | no (POST)        |
| Orange       | Tyler/Eagle recorder (eagleweb) | 200 -> redirects to login.jsp                  | no (login)       |
| Duval        | AcclaimWeb                      | 200 at or.duvalclerk.com                       | no               |
| Pinellas     | (WAF-fronted)                   | 403 to non-browser client                      | no               |
| Lee          | LandmarkWeb                     | 403 / connection timeout                       | no               |
| Polk         | Angular SPA (browserviewor)     | 200, JS-driven single-page app                 | no (JS)          |
| Brevard      | OnCore                          | unreachable from this network (no route :80)   | unverified       |
### MIAMI-DADE - the one real API, and why it is NOT a green light
StandardSearch.aspx contains, in page JS:
  var apiUrl = `${origin}${baseUrl}/api/home/recordingsearch?bookNumber=${b}&pageNumber=${p}&bookType=
                &searchType=Recording Book/Page&token=&skipCaptcha=true`;  await fetch(apiUrl, {...})
So a JSON endpoint genuinely exists and takes URL parameters. BUT it carries **token=** and **skipCaptcha=**
parameters - i.e. the system has an explicit CAPTCHA / token gate. It is an app-internal endpoint, not a published
API, with no documentation, no terms permitting bulk use, and an anti-automation control in the signature.
=> I did NOT exercise it for bulk retrieval and did not attempt to defeat the captcha/token. Building a pipeline on
it would mean circumventing bot protection and likely breaching site terms. Flagged for a human/legal decision.
### PLATFORM INSIGHT (why this is uniform)
Only ~5 vendor stacks serve these: AcclaimWeb (Broward, Duval), Kofile QuickLinks (Hillsborough), OnCore (Brevard),
LandmarkWeb (Lee + most small counties), Eagle/Tyler (Orange), plus customs (Miami-Dade, Palm Beach, Polk).
None of these vendor products exposes a documented public REST API in its public deployment; all are
session/ViewState/POST or JS-SPA driven. So this is a platform-level limitation, not a per-county quirk.
### RE: LIENS / JUDGMENTS / HOA DECLARATIONS SPECIFICALLY
Availability is NOT the constraint - these ARE recorded instruments indexed by document type (LIEN, JUDGMENT,
DECLARATION/DEC, NOTICE OF COMMENCEMENT, LIS PENDENS) and by party name in every one of these systems.
The constraint is purely the ACCESS MECHANISM. Same conclusion as Polk permits / code enforcement: portal-only.
### LEGITIMATE ROUTES (not scraping)
1. Clerk bulk-data subscriptions/FTP - many FL clerks sell bulk Official Records index+image feeds commercially.
2. MyFloridaCounty.com (Florida Assoc. of Court Clerks) - multi-county Official Records search aggregator (200 OK,
   references LandmarkWeb+AcclaimWeb); FACC also runs commercial data services.
3. Formal public-records request per county.
CAVEAT ON METHOD: a 403 to my client proves non-browser access is refused; it does NOT prove no API exists behind a
real browser session. Brevard could not be reached from this network at all and is genuinely unverified.

=========================================================
## VOLUSIA OFFICIAL RECORDS - ASP.NET POSTBACK TECHNIQUE TRANSFERS *** PROVEN WORKING *** (2026-07-19)
PREMISE CHECK FIRST: I did not remember an arrest pipeline and nearly said so - VERIFIED INSTEAD and the user was
right. ~/clerk_cr24_*.py exist and volusia_arrest_booking_records holds exactly 1,810 rows (matching the claim).
It predates my notes file (which only covers the GIS work). Lesson: verify before contradicting.
### THE TECHNIQUE IS THE SAME, ONLY THE CONTROL NAMES DIFFER
arrest pipeline : GET base -> scrape __VIEWSTATE/__VIEWSTATEGENERATOR/__EVENTVALIDATION
                  -> POST __EVENTTARGET='ctl00$Content1$button_accept'  -> session valid
official records: GET https://app02.clerk.org/or_m/default.aspx  (the disclaimer, ~56KB)
                  -> POST same 3 viewstate fields + 'ctl00$ContentPlaceHolder1$accept':'Accept'  (type=submit)
                  -> then GET/POST https://app02.clerk.org/or_m/inquiry.aspx in the SAME session
SEARCH POSTBACK CONTRACT (this is what I got wrong twice before reading the markup):
  the Submit control is <input type="button"> firing __doPostBack('ctl00$ContentPlaceHolder1$search','')
  => you MUST set __EVENTTARGET='ctl00$ContentPlaceHolder1$search' (NOT send a submit value), and mirror the
  dates into the hidden ctl00$ContentPlaceHolder1$hdfromDate / hdtoDate as well as fromDateTxt / toDateTxt.
  Skipping the disclaimer yields a 702-byte page: "Your session has expired ... redirect to Disclaimer page".
  No CAPTCHA, no WAF, no token - unlike Miami-Dade's /api/home/recordingsearch (which has token+skipCaptcha).
### PROOF (single narrow searches, not a bulk pull)
  doctype=RESTRICTIONS 01/06-01/12/2026 -> 200, 111,254 bytes, 13 result rows
  doctype=LIEN         01/06-01/08/2026 -> 200, 136,768 bytes, 25 result rows
  returned columns: instrument# | recorded date | book/page | type code | party name | LEGAL DESCRIPTION
  e.g. 2026001656 | 01/06/2026 | 8799/2734 | LN | TWIN LAKES AT DELTONA HOMEOWNERS ASSOCIATION INC
       | LOT 136, TWIN LAKES AT DELTONA - UNIT 3A
### ANSWERS THE HOA QUESTION EMPIRICALLY
There is NO "DECLARATION" doctype in Volusia's 50-option list. HOA/subdivision declarations are filed under
**RESTRICTIONS** (proven: 'VILLAS AT MASSEY RANCH PHASE II' subdivision restriction filings) and condo docs under
**CONDOMINUM** (their spelling, sic - also 'PROPETY APPRAISER' is misspelled; use exact padded option values).
HOA LIENS appear under **LIEN** with the association as a named party (Twin Lakes at Deltona HOA example above).
Judgments: JUDGMENT/ORDER, FINAL JUDGMENT INJ/M, FINAL JUDGMENT W/PRO, AMENDED JGMT ORDER. Plus LIS PENDENS
(foreclosure signal). Search fields include **parcel** and name/nameType(BOTH|DIRECT|REVERSE), book/page, instrument.
### STATUS: capability proven, FULL PIPELINE NOT BUILT (awaiting scope decision)
Scope questions that need a human answer before a bulk run: how far back, which doctypes, and rate-limiting -
this is a county server with no paid bulk product, so a full historical crawl should be deliberately throttled.
VOLUSIA-SPECIFIC: this works because Volusia's own app has no captcha/WAF. It does NOT generalise - see the
10-county survey above (Broward/Pinellas/Lee 403, Orange login, Hillsborough POST/viewstate, Miami-Dade captcha).

=========================================================
## VOLUSIA OFFICIAL RECORDS PIPELINE - BUILT & RUNNING (2026-07-20)
Scope (owner-specified): RESTRICTIONS, LIEN, JUDGMENT/ORDER, LIS PENDENS; 2015-01-01 -> present;
one week per search, throttled. Tables: volusia_official_records_private + volusia_or_scrape_progress.
Collector: ~/volusia_or_collect.py   log: ~/or_crawl.log

### GOVERNANCE (mirrors volusia_arrest_booking_records)
RLS enabled, ZERO policies => service-role only. Table comment states: personal research use only,
NOT for PIR / B2B / customer-facing output, no redistribution or resale. Collection deliberately
throttled + weekly-windowed to match the app's own 7-day granularity (county has no paid bulk product).

### THE BUG THAT NEARLY POISONED THE WHOLE DATASET  *** most important finding ***
Reusing one ASP.NET session across searches CORRUPTS the grid: once the MaxRows postback is fired,
every LATER search in that session returns exactly 25 rows under the label "Records found 25".
The label is SELF-CONSISTENT (rows==25==N), so a page-level assertion CANNOT detect it.
First validation run reported a clean "ok=12 failed=0" while silently discarding ~93% of the data
(438 rows). Same 12 jobs with a fresh session per week -> 6,628 rows. 15x.
CAUGHT ONLY BY: looking at the count DISTRIBUTION (a wall of exactly-25s across unrelated
doctypes/weeks is not what real data looks like), not by the success line or the assertions.
FIX 1: Site.week() calls self.new() -- brand-new session+disclaimer per week-job. Mandatory, not hygiene.
FIX 2: any week landing on exactly 25 rows / 1 page is re-run in a second clean session and must agree.
LESSON: a self-consistent integrity check validates the parser, not the source. Distribution sanity
(does this look like real-world data?) is the check that actually catches a lying upstream.

### SOURCE CONTRACT (verified empirically)
- site's own JS clamps the window: dtToDate = dtFromDate + 7. A 1-month range returns the same rows
  as its first week -> weekly stepping is REQUIRED, not just polite.
- default page size 25; MaxRows select offers 25/50/100/200/500 (fired as its own postback).
- pager = ctl00$ContentPlaceHolder1$Grid$ctl01$LinkButton3 ("Next").
- label contract: "More than X records found. Viewing A To B" = more pages; "Records found N" = final
  page, N = rows ON THAT PAGE (not the grand total).
- exportButton (OfficialRecords.xls, actually an HTML table) exports the CURRENT PAGE ONLY, not the
  full result set -- tested and rejected; cross-check: export=25 vs paged truth=760 for the same week.
- grid columns are FIXED 9: View|Instrument|Date|Book/Page|Document Type|Name|Legal|Status|Direction.
  Parse by index and require len(tds)==9 -- filtering empty cells shifts columns when Legal is blank.

### DATA SHAPE
One row per PARTY per instrument (direction D=direct/grantor, R=reverse/grantee), so COUNT(*) is a
party count; use count(distinct instrument_number) for documents. Volume is dominated by
JUDGMENT/ORDER (~1,400-2,000 party-rows/week, code JDO1), then LIEN (~220-760), LIS PENDENS (~120),
RESTRICTIONS (~4-13). Full run projects to roughly 1.3M party-rows over ~601 weeks x 4 doctypes.
Integrity checks on the validated slice: 0 null dates, 0 directions outside D/R, 0 rows falling
outside their own week window.

### RUN CHARACTERISTICS
2,412 week-jobs at --delay 3 => observed ~1.2 jobs/min => ~30-33 hours wall clock. Resumable:
the ledger is authoritative, so re-running skips completed weeks and only fetches what is missing.
This makes incremental top-up FREE -- a later run picks up only the new weeks, no special code.
NOT added to data_source_registry: it is not a REST source and the monthly driver would try to
re-crawl 33 hours of history; incremental top-up via re-running the collector is the right pattern.
A week absent from / non-'ok' in the ledger must be read as NOT COLLECTED, never as zero records.

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

=========================================================
## TABLE QUARANTINE PROCEDURE (rename indexes WITH the table) (2026-07-22)
When parking a superseded staging/live table by RENAME (e.g. -> <t>_abandoned_YYYYMMDD),
Postgres renames the TABLE but NOT its indexes. The old index names stay attached to the
abandoned table and then COLLIDE with the next same-named staging table's index creation
(ogr2ogr CREATE INDEX <stg>_geom_geom_idx fails: "relation already exists"). This silently
broke the Orange re-pull for 3 launches.

PROCEDURE for quarantine-by-rename:
  1. ALTER TABLE <t> RENAME TO <t>_abandoned_YYYYMMDD;
  2. For EACH index on it, rename to match:
       ALTER INDEX <t>_geom_geom_idx RENAME TO <t>_abandoned_YYYYMMDD_geom_idx;
     (find them: select i.relname from pg_index x join pg_class i on i.oid=x.indexrelid
                 join pg_class t on t.oid=x.indrelid where t.relname='<abandoned name>')
  3. Verify no *_stg_geom_geom_idx (or other soon-to-be-reused index name) remains dangling.
Belt-and-suspenders in the puller: -lco SPATIAL_INDEX=NONE on staging loads (staging needs no
spatial index anyway; the live table keeps its own through TRUNCATE+INSERT).

DONE 2026-07-22:
  orange_parcels_govt_source_stg_geom_geom_idx  -> orange_parcels_abandoned_20260722_geom_idx
  pinellas_parcels_govt_source_stg_geom_geom_idx-> pinellas_parcels_abandoned_20260722_geom_idx
  (both were quarantine artifacts of the paging remediation)
REMAINING / FLAGGED (NOT a quarantine artifact, left for owner decision):
  baker_subdivisions_stg_geom_geom_idx on LIVE baker_subdivisions (212 rows, registered active).
  Cosmetic _stg leftover in the index name; no collision now (no baker_subdivisions_stg table),
  but a future baker re-pull WOULD collide. Recommended: rename to baker_subdivisions_geom_idx.

=========================================================
## DOR STATEWIDE TAX ROLL (NAL + SDF) INGEST (2026-07-23)
Purpose: authoritative ground-truth to reconcile ArcGIS parcel pulls; homestead/exemption source.
Source: FL DOR Property Tax Oversight PTO Data Library (SharePoint), 2025 FINAL roll.
Scripts: ~/dor_load.py (single), ~/dor_bulk.py (all 67, resumable), ~/dor_plan.json (the map).
Log: ~/dor_bulk.log. Tables: <slug>_nal_dor_source (165 cols), <slug>_sdf_dor_source (23 cols).

### DOWNLOAD MECHANISM (enumerated via SharePoint REST, not the web UI)
BASE=floridarevenue.com/property/dataportal
List folder: {BASE}/_api/web/GetFolderByServerRelativeUrl('<rel>')/Files  (Accept: application/json;odata=verbose)
Tax Roll Data Files/{NAL,SDF}/2025F/  -> 67 per-county zips each, e.g.
  "Baker 12 Final NAL 2025.zip" -> contains NAL12F202502VAB.csv (VAB = post-value-adjustment-board, most final)
Direct download: HOST + quote(ServerRelativeUrl). Files are public, anonymous GET works.
FILENAME QUIRKS: "Dade 23" (=Miami-Dade), "Indin River 41" (typo), "Dixie...SDF 2025..zip" (double dot),
  "Collier...SDF  2025.zip" (double space). co_no is parsed from the filename, not the name text.

### FORMAT (per 2025 User's Guide, read in full)
CSV, comma-delimited, FIELD NAMES IN HEADER ROW (NOT fixed-width -- the fixed-width era was DBF).
NAL = 165 fields, SDF = 23. Load RAW: all columns text (PARCEL_ID is zero-padded, must stay text).

### KEY FIELD MAP (NAL) -- for the pairing audit + homestead signal
  CO_NO(1)          DOR county number 11-77 (alphabetical, Miami-Dade coded "Dade"=23). Join partition.
  PARCEL_ID(2)      up to 26 alnum, county-specific format. **The join key to our parcel tables.** text.
  DOR_UC(8)         DOR land use code 000-099 (full table captured). PA_UC(9)=county use code.
  JV(11)            just value = market value (~ FL "just value" in our contract).
  AV_SD/AV_NSD(14/15) assessed (school / non-school). TV_SD/TV_NSD(16/17) taxable.
  JV_HMSTD/AV_HMSTD(18/19)  homestead (Save-Our-Homes) just/assessed -- OWNER-OCCUPANCY signal.
  EXMPT_01(110)     homestead exemption $ (up to 25k). EXMPT_02(111)=additional. => homestead flag.
  APP_STAT(89)      homestead applicant status.
  OWN_NAME(74); OWN_ADDR1/2,OWN_CITY,OWN_STATE,OWN_ZIPCD (75-79)  = MAILING address.
  PHY_ADDR1/2,PHY_CITY,PHY_ZIPCD (99-102) = PHYSICAL/SITUS address.
    => owner-occupancy: homesteaded parcel => situs ~= mailing (the misattribution-defense signal).
  ALT_KEY(103); S_LEGAL(88) short legal; STATE_PAR_ID(162) DOR uniform parcel id; CENSUS_BK(98).
SDF key fields: CO_NO,PARCEL_ID,DOR_UC,SALE_PRC(19),SALE_YR/MO(17/18),QUAL_CD(16),
  OR_BOOK/OR_PAGE/CLERK_NO(13/14/15) -> links sales to Official Records.

### GOVERNANCE
Each table: RLS ON, ZERO policies => service_role only. PARCEL_ID indexed. Provenance in table comment.

### EMERGING RECONCILIATION SIGNAL (report only; root-cause is the task-3 pairing audit)
DOR NAL is consistently SLIGHTLY SMALLER than our ArcGIS parcel count, modest (~0.5-1%):
  Baker  13,064 vs 13,265  (-201)     Alachua 108,389 vs 109,057 (-668)
Direction is consistent (DOR < ArcGIS). Plausible: ArcGIS layers carry extra geometry features
(condo/sub-parcels, ROW slivers) or DOR excludes centrally-assessed/confidential rows. DO NOT
conclude before the pairing audit joins on PARCEL_ID.

### *** BONUS: DOR NAL FILLS OUR WALLED COUNTIES ***
6 counties have NO live parcel table -- exactly the ones we WALLED:
  18 Charlotte, 40 Holmes, 59 Osceola, 63 Polk, 66 St Lucie, 77 Washington.
Their DOR NAL lands with no delta comparison, but gives us authoritative parcel-level records
(owner/value/use/homestead/legal, no geometry) for counties where the ArcGIS pull failed.

### PENDING (task 3, GATED -- do not start): PARCEL_ID pairing audit DOR<->ArcGIS per county;
owner-occupancy (situs~=mailing) misattribution-defense signal from homestead+address fields.

=========================================================
## DOR NAL FIX (12 urban-core) + VOLUSIA CAMA INGEST (2026-07-23)

### DOR TASK A -- 12 empty NAL fixed
Root cause: single COPY of a large NAL (200k-1M rows x165 cols) exceeded pooler statement_timeout,
died mid-stream ~line 256-370k. NOT memory/parse. Fix (~/dor_fix.py): SET statement_timeout=0 +
chunked COPY (50k/batch) + post-load assert count>0 + FAILED list + full 67x2 table.
Result: ALL 67x2 NON-EMPTY. NAL total=10,998,001  SDF total=2,122,122.
Skip predicate already keyed on count>0 (not existence) -- empty tables reloaded, not skipped.
*** CONDO-STACKING SIGNATURE in the deltas (DOR NAL vs our GIS parcels): ***
  Broward +200,462   PalmBeach +173,744   Pasco +10,047   Volusia +23,343  (DOR >> GIS)
  vs Miami-Dade -57,153  Duval -9,547  Lee -6,908 (GIS >= DOR, minor)
  The big +deltas are condo counties: DOR NAL lists each condo unit as a parcel; our polygon GIS
  stacks/omits them. This is exactly the GeoPlan condo-stacking fix the user described.

### VOLUSIA CAMA -- new source, SUPERSEDES DOR NAL for Volusia
Source: https://vcpa.vcgov.org/files/database/CAMA_DATA_EXPORT.zip (219MB zip -> 1.44GB .accdb,
ACE12). Layout: https://vcpa.vcgov.org/files/download/newLayout.pdf. Data current 2026-07-20
(weekly), retrieved 2026-07-23 -- vs DOR NAL's Jan-1-2025 snapshot (19 months stale).
Tooling: mdbtools reads the .accdb (mdb-tables/mdb-count/mdb-export). 18 tables (doc says 17;
+VCPA_CAMA_AGLAND). All keyed on PARID (=AltKey). Loaded via mdb-export -> chunked COPY.
Tables volusia_cama_<suffix>, service_role only (RLS on, no policies), PARID indexed, provenance
comment (source/current-as-of/retrieved). Total 7,249,446 rows, all 18 non-empty.

*** VERIFICATION GATE PASSED: AltKey 3671058 -> 2 owner rows (OWNSEQ 0 MCNEELY GENE, 1 MCNEELY
IRIS). Relational, NOT flattened. Round-trip confirmed in the loaded volusia_cama_owner too. ***

### THE SOURCE-HIERARCHY ANSWER (Volusia real-property parcel count, most->least complete):
  VCPA CAMA REAL-active (CUR=Y,ROLLTYPE=REAL) = 313,619   [weekly, 3 days old]  == CAMA_LEGAL 313,619
  DOR NAL 2025 Final                           = 309,344   [Jan-1-2025 snapshot, 19 mo]
  our volusia_parcels_govt_source (ArcGIS)     = 286,001   [GIS export]
  => CAMA > DOR NAL > GIS on BOTH completeness (+27,618 / +23,343 vs GIS) AND currency.
  For any SINGLE county, the county's own CAMA beats DOR on both axes. DOR's only edge was
  one-schema-for-all-67. Confirms: county CAMA is the spine where available.
Owner distinct PARID=343,841 (incl PP accounts). Homestead exemptions: 159,448 parcels (codes
01/04/05/24/26/27) -- the owner-occupancy signal, ~51% of real parcels.
Key value-add vs DOR NAL: multi-owner (OWNER table, OWNSEQ), full sales history 1.6M rows back to
1960s, buildings (RES_BLDG beds/baths), permits 992k, land lines, situs -- the 1:many
relationships the NAL flattens away.

### SCOPING (does the Volusia open-weekly-CAMA model generalize?) -- PRELIMINARY, don't-pull scan
Checked Baker, Broward, Palm Beach, Wakulla (the 4 with no owner column in our GIS):
  Baker (bakerpa.com): tax roll viewable; bulk only via TaxNetUSA (3rd-party, paid). No open export.
  Broward (bcpa.net): has a CAMA system (RFP-BCPA-CAMA.pdf) but bulk via Regrid/TaxNetUSA or request.
  Palm Beach (pbcpao.gov): some downloadable parcel datasets; bulk needs an account.
  Wakulla (qpublic/mywakullapa.com): hosted qPublic portal; parcel data via Dynamo Spatial/TaxNetUSA
    shapefile. No open CAMA export.
VERDICT: Volusia's open self-serve weekly relational CAMA zip appears UNCOMMON. The 4 checked
route bulk data through vendors / account-gated requests / hosted portals -- none an equivalent
open download. BUT the DOR NAL we already loaded fills the flattened owner/value/homestead gap for
all of them; the open question is only the FULLER relational per-county export, which is not freely
available for these 4. Definitive per-county answer needs direct site checks (not done -- scan only).
NOTE: this is a summary-search scan; qPublic/GSA portals sometimes have download links worth a
direct look before concluding a county has nothing.

=========================================================
## STATEWIDE CADASTRAL (direct FGDB) + CAMA WEEKLY CLOCK (2026-07-23)

### PROMPT 1 -- FL statewide cadastral, DIRECT FILE (not the paged ArcGIS crawl)
Source: https://publicfiles.dep.state.fl.us/otis/gis/data/Cadastral_Statewide.zip (2.77GB zip,
Last-Modified 2026-05-05). Contains CADASTRAL_DOR.gdb (File Geodatabase). Layer CADASTRAL_DOR,
Feature Count 10,831,924 (EXACT match to stated). Native SRID EPSG:6439 (FL GDL Albers); geom is
3D Measured MultiPolygon. Schema = DOR NAL fields joined to geometry (CO_NO,PARCEL_ID,DOR_UC,JV,
OWN_NAME,PHY_ADDR,JV_HMSTD,ALT_KEY,... + PARCELNO). Read via ogrinfo/ogr2ogr (OpenFileGDB).
Loading as fl_cadastral_dor_statewide: -s_srs 6439 -t_srs 4326, -nlt MULTIPOLYGON -dim XY, chunked
-gt 20000, statement_timeout=0, SPATIAL_INDEX=NONE (build GiST after). ~/cad_load.sh, log ~/cad_load.log.

*** COUNTY PARTITION FIELD -- CO_NO IS NOT CLEAN (user was right to warn) ***
GROUP BY CO_NO (via ogrinfo -dialect SQLITE; OGRSQL has no GROUP BY): 68 groups =
  67 real counties (11-77, ALL present) + a CO_NO=0 ORPHAN bucket of 92,043 unattributed parcels.
Sum = 10,831,924 (matches). 67-county sum = 10,739,881. The 92,043 need alternate attribution
(spatial point-in-county, or FIPS per metadata) -- do NOT treat CO_NO=0 as a county.

### THREE-WAY AUDIT (cadastral / our GIS parcels / DOR NAL), 67 counties
Totals: cadastral 10,739,881 | GIS 9,663,437 | NAL 10,998,001.
Cadastral ~ NAL (both DOR-derived, Aug-2025 vs Jan-2025). Notable:
  CONDO-STACKING (cadastral & NAL >> our GIS): Broward +211k, PalmBeach +202k, Collier +67k,
    StJohns +53k vs our GIS. Our polygon GIS omits/stacks condos these list as parcels.
  *** MIAMI-DADE ANOMALY: cadastral 585,220 << NAL 933,535 (-348k) and << our GIS 990,688. ***
    The statewide cadastral GIS does NOT carry Miami-Dade's separate condo-unit polygons, while
    Broward/PB cadastral DO (765k/683k ~ NAL). This is the exact per-county condo-stacking
    INCONSISTENCY GeoPlan fixes (Prompt 4). Manatee also anomalous: cadastral 224k << GIS 338k.
  Volusia ladder (most->least complete): CAMA 313,619 > NAL 309,344 > cadastral 306,889 > GIS 286,001.
Per-county table saved: ~/cadastral/co_counts.json + printed in cad_parse.py output.

### PROMPT 2 -- CAMA already loaded (prior turn); WEEKLY CLOCK now set (step 6)
First capture taken: ~/cama_snapshots/CAMA_20260720.zip archived (data current 2026-07-20),
manifest volusia_cama_snapshot_log (capture_date, data_current_as_of, per-table counts jsonb).
Job ~/cama_snapshot.py (idempotent, dedup by data-date, backfill-proof raw-zip archive).
Wrapper ~/run_cama_snapshot.sh. Windows Task Scheduler "VolusiaCAMASnapshot": WEEKLY Tue 04:00,
StartWhenAvailable (catch-up), next run 2026-07-28. Validated end-to-end: LastTaskResult=0, dedup
held (1 log row after 2 runs). Design choice: archive raw zip weekly (~11GB/yr, complete, nothing
lost) rather than weekly full 7.25M-row DB snapshots; dated DB tables materializable from archives.

### DOR TASK A verified complete this turn (user saw Volusia at 0 mid-run): polk 431,877,
volusia 309,344, ZERO empty NAL across all 67. Was a mid-run snapshot; finished fine.

### STILL QUEUED: Prompt 3 (67-county export survey, calibrate vs Volusia/Suwannee/MiamiDade),
Prompt 4 (FGDL + FGIO catalog enumerate, don't pull). User: run 1&2 first (done/running).
