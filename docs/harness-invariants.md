# Data-pipeline harness invariants

The rules below are enforced on every ingest run. Each one is here because it *cost us a
failure* — the parenthetical is the concrete incident. The condensed list also lives in the root
`CLAUDE.md` so it loads unconditionally; this file is the evidence and reasoning behind it.

## 1. Probe the OID field from layer metadata — never hardcode `objectid`

On ArcGIS layers built from a join/export, the real object-ID column is `OBJECTID_1` /
`OBJECTID_12` / `ESRI_OID`, and the plain `objectid` survives as an ordinary, duplicable
attribute. Read it from layer metadata: `objectIdField`, else the `esriFieldTypeOID` field,
else `returnIdsOnly.objectIdFieldName`. Some layers report `objectIdField: null` yet still have
an OID-typed field.

- Gadsden looked "50% duplicated" on `objectid`; its real OID `objectid_1` was 100% unique — a false positive.
- Baker's table stored the OID as `fid`; a hardcoded `objectid` check crashed the load.
- Orange's `objectIdField` was `None`; the OID came from `returnIdsOnly`.

A uniqueness test only means something if the column is **source-derived** — check `pg_attrdef`
for `nextval` first, or a local serial will read as "unique" and prove nothing.

## 2. Empty `returnIdsOnly` → abort, touch nothing

A down service returning zero IDs is **not** "the source has no rows." Treating it as such would
truncate a live table to empty. If the id set comes back empty, stop before touching anything.
(Orange's `ocgis4.ocfl.net` returned `code 500` on every request minutes after successfully
serving 496,798 ids — a transient outage, not an empty source.)

## 3. Verify against the source id set, not the row count

Row-count equality with the source proves nothing — it cannot see a swap or a clean truncation.

- AR/Crittenden loaded 27,620 rows = source count, but 200 were duplicated and 200 real parcels missing.
- BC/Capital-RD matched the source count exactly with 25 dups / 25 missing.
- Prong-2 audit found the "confirmed clean" major-county parcel core **short** by clean
  truncation (Orange −15,000, a page-boundary loss) that overlap-scanning structurally cannot detect.

Fix: `orderByFields=<OID> ASC` for stable paging, **and** a `returnIdsOnly` set-diff against the
load (0 missing / 0 extra). `returnIdsOnly` returns the complete id list uncapped by
`maxRecordCount`. Beware load-balanced replicas (palmbeach_zoning returned 2,088 / 1,493 / 1,577
ids across attempts, some absent from the server's own id list) — that's replica drift, not a
paging parameter to tune; log it, don't force it.

## 4. Quarantine-by-rename must rename the indexes too

Postgres renames a table but not its indexes. The old index names stay attached to the abandoned
table and collide with the next same-named staging table's index creation. This silently broke
the Orange re-pull for three launches (`orange_parcels_govt_source_stg_geom_geom_idx` still lived
on `..._abandoned_20260722`). See `quarantine-procedure.md`. Belt-and-suspenders in the puller:
`-lco SPATIAL_INDEX=NONE` on staging loads (staging needs no spatial index).

## 5. Process-liveness interlocks must not self-match

`pgrep -f script.py` matches the very shell `os.popen` spawns to run it, because that shell's
command line contains the pattern — so the guard trips every time and "fails closed" into an
outage. Use the bracket trick `[s]cript` and **test it from a file** (an inline test is
contaminated by the pattern text in the surrounding command). A guard that false-positives is
worse than no guard.

## 6. Chunk large COPY (50k) and `SET statement_timeout=0`

A single oversized `COPY` dies mid-stream around 256k–370k rows on the pooler's
`statement_timeout`. The 12 largest counties' DOR NAL loads (200k–1M rows × 165 cols) all failed
this way while the small counties finished. Fix: `SET statement_timeout=0` on the session **and**
chunked COPY in ~50k-row batches with a per-batch running count.

## 7. empty ≠ done

Skip/resume predicates test `count(*) > 0`, never table existence — an empty table that already
exists must reload, not be skipped. Assert non-zero after every load, keep an explicit FAILED
list, and print a final table that **names failures** rather than a summary implying success. The
DOR bulk run reported "67/67 complete" while all 12 urban-core NAL tables were empty.

## 8. Self-consistent checks lie — anchor to independent ground truth

A check that validates against the source's own reported count validates your parser, not your
data. The Volusia Official Records grid returned exactly 25 rows under a false `Records found 25`
label when an ASP.NET session was reused across searches; the per-page assertion passed while 93%
of the data was discarded. What caught it was the **distribution** — a wall of exactly-25s across
unrelated weeks is not what real data looks like. After any bulk pull, look at the spread of
per-unit counts before declaring success.

## WSL / interop gotchas (Windows host)

- Shell variables (`$var`, `$1`, loop vars, `$(...)`) **blank to empty** through
  `wsl bash -lc '...'`. Write scripts to a file and run them by path; never rely on inline shell
  variables across the interop boundary.
- Heredocs mangle (quoting/`$` expansion). Author scripts with the editor, `cp` into place.
- `/tmp` is wiped between `wsl.exe` invocations (the VM shuts down). Persist working files to
  `$HOME`. Detached background processes survive across invocations as long as one stays running.
- Scheduling: Windows Task Scheduler is the reliable trigger, **not** WSL cron. Hardcode args in
  a wrapper script — args passed across the `wsl.exe` boundary get mangled.

## Verification discipline (applies everywhere)

- Never trust a tool's "OK / loaded / N succeeded" line — verify against real source counts.
- Bbox/FIPS-check that geographic data is genuinely the correct place (ambiguous-name traps:
  Santa Rosa CA, Monroe OH, Osceola→Orange County CA, and the cadastral's `CO_NO=0` orphan bucket
  of 92,043 unattributed parcels).
- Pull ESRIJSON (`f=json`) not GeoJSON from ArcGIS — GeoJSON forces WGS84 and reprojects on
  ingest, destroying "raw as delivered."
