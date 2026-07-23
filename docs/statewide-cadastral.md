
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
