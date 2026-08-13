#!/usr/bin/env python3
"""
WO 111 — load FEMA NFHL flood zones (14 counties) into nfhl_flood_zones. RUN IN WSL. Companion to
wo106_load_nhd_nrhp.py; kept separate because flood is per-county (not full-refresh), spans three file
shapes, and must MEASURE its geometry before the repair is accepted.

    export SUPABASE_DB_URL='postgresql://...'
    export DOC_DATA_DIR='/mnt/c/Users/murph/Documents/GitHub/DoC-Site'
    python3 scripts/wo111_load_flood.py            # load + MEASURE geometry, DO NOT repair (review first)
    python3 scripts/wo111_load_flood.py --repair   # after the measurement is accepted: also repair + verify

WHY MEASURE FIRST (ruling in WO111): ST_MakeValid on a self-intersecting polygon can drop parts. On NHD
the dropped parts were degenerate (a ~10cm line, empty points). FEMA zone polygons self-intersect far
more heavily and there are 175,728 of them — do NOT assume the discards are degenerate. This prints, per
county: invalid count, collection count, and the SIZE of what repair would discard (line length + point
count). Accept the repair only if those are degenerate, then re-run with --repair.

ENFORCED:
  * -9999 in STATIC_BFE / DEPTH -> SQL NULL at ingest (it means NOT DETERMINED; else it renders as an
    elevation). The CHECK on the column and the served nullif() are backstops.
  * Per-county DELETE+load = a re-run cannot duplicate. count==distinct(co_no,objectid) asserted.
  * Brevard is TWO files (main 23,183 + tail 297 = 23,480); OBJECTIDs verified disjoint. Reconcile is
    against the COMBINED target — loading one file is a silent 1.3% loss that a per-file check would pass.
  * Every Polygon is ST_Multi'd to MultiPolygon; SRID 4326 (pull already reprojected).
  * A county is not done until its loaded count == its target. Mismatch -> FAILED -> exit 1.
"""
import gzip, json, os, sys, glob, re
try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    sys.exit("psycopg2 not found. In WSL: pip install psycopg2-binary")

DSN = os.environ.get("SUPABASE_DB_URL") or os.environ.get("DATABASE_URL")
if not DSN:
    sys.exit("Set SUPABASE_DB_URL to the psycopg2 DSN the WSL loaders use.")
DATA = os.environ.get("DOC_DATA_DIR", "/mnt/c/Users/murph/Documents/GitHub/DoC-Site")
FLOOD_DIR = os.path.join(DATA, "nfhl_out")
CHUNK = 50_000
DO_REPAIR = "--repair" in sys.argv[1:]

# authoritative verification targets (WO111 / flood baseline note 117); Brevard is the COMBINED count.
TARGETS = {
    "12001": 3391, "12005": 10076, "12009": 23480, "12015": 8411, "12019": 1704,
    "12031": 10207, "12043": 3726, "12053": 12768, "12069": 6791, "12077": 2758,
    "12081": 13820, "12097": 2850, "12105": 21220, "12115": 54526,
}  # sum = 175,728

COLS = ["co_no", "fips", "objectid", "fld_ar_id", "fld_zone", "zone_subty",
        "static_bfe", "depth", "v_datum", "len_unit", "dual_zone", "source_cit", "dfirm_id"]
TEMPLATE = "(" + ",".join(["%s"] * len(COLS)) + ",ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326)))"
INSERT = f"INSERT INTO nfhl_flood_zones ({','.join(COLS)},geom) VALUES %s"

def as_float_no_sentinel(v):
    if v is None or v == "":
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return None if f == -9999 else f      # -9999 = NOT DETERMINED

def iter_features(path):
    """.geojsonl.gz -> one Feature/line; .geojson.gz -> FeatureCollection (streamed via ijson if present)."""
    if ".geojsonl" in os.path.basename(path):
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    yield json.loads(line)
    else:
        try:
            import ijson  # stream the big FeatureCollections (Sarasota gz is 112 MB) without loading all of it
            with gzip.open(path, "rb") as fh:
                for feat in ijson.items(fh, "features.item"):
                    yield feat
        except ImportError:
            with gzip.open(path, "rt", encoding="utf-8") as fh:
                for feat in json.load(fh).get("features", []):
                    yield feat

def row(feat, co_no, fips):
    p = feat.get("properties", {})
    g = {k.lower(): v for k, v in p.items()}
    def t(k):
        v = g.get(k)
        return None if v is None else str(v)
    return (co_no, fips,
            int(float(g["objectid"])) if g.get("objectid") not in (None, "") else None,
            t("fld_ar_id"), t("fld_zone"), t("zone_subty"),
            as_float_no_sentinel(g.get("static_bfe")), as_float_no_sentinel(g.get("depth")),
            t("v_datum"), t("len_unit"), t("dual_zone"), t("source_cit"), t("dfirm_id"),
            json.dumps(feat.get("geometry")))

def files_by_fips():
    out = {}
    for path in sorted(glob.glob(os.path.join(FLOOD_DIR, "nfhl_*.geojson*.gz"))):
        m = re.match(r"nfhl_(\d{5})_", os.path.basename(path))
        if m:
            out.setdefault(m.group(1), []).append(path)
    return out

def fips_to_co_no(cur):
    # geo_reference.geo_id embeds the 5-digit FIPS ('US-12001') and dor_co_no is the DOR number (Alachua=11)
    cur.execute("SELECT substring(geo_id from 4), dor_co_no FROM geo_reference "
                "WHERE geo_id LIKE 'US-12%' AND dor_co_no IS NOT NULL")
    return {f: int(c) for f, c in cur.fetchall()}

def load_county(cur, conn, fips, co_no, paths, failed):
    cur.execute("DELETE FROM nfhl_flood_zones WHERE co_no=%s", (co_no,))
    loaded, batch = 0, []
    try:
        for path in paths:
            for feat in iter_features(path):
                batch.append(row(feat, co_no, fips))
                if len(batch) >= CHUNK:
                    execute_values(cur, INSERT, batch, template=TEMPLATE, page_size=1000)
                    loaded += len(batch); conn.commit(); batch = []
        if batch:
            execute_values(cur, INSERT, batch, template=TEMPLATE, page_size=1000)
            loaded += len(batch); conn.commit()
    except Exception as e:      # noqa: BLE001
        conn.rollback()
        print(f"  !! {fips} co_no={co_no}: LOAD FAILED: {e}")
        failed.append(fips)
        return
    cur.execute("SELECT count(*), count(DISTINCT objectid) FROM nfhl_flood_zones WHERE co_no=%s", (co_no,))
    n, ndist = cur.fetchone()
    target = TARGETS.get(fips)
    recon = "RECONCILED" if n == target else f"MISMATCH target={target:,}"
    dup = "" if n == ndist else f"  DUP objectid: {n-ndist}"
    print(f"  == {fips} co_no={co_no}: rows={n:,} target={target:,} [{recon}]{dup}")
    if n != target or n != ndist or n == 0:
        failed.append(fips)

def measure_county(cur, fips, co_no):
    # what would repair DISCARD? (line length + point count of non-polygon parts). degenerate => tiny/empty.
    cur.execute("""
        WITH inv AS (SELECT ST_MakeValid(geom) mv FROM nfhl_flood_zones
                     WHERE co_no=%s AND geom IS NOT NULL AND NOT ST_IsValid(geom))
        SELECT count(*),
               count(*) FILTER (WHERE GeometryType(mv)='GEOMETRYCOLLECTION'),
               coalesce(max(ST_Length(ST_CollectionExtract(mv,2)::geography)),0),
               coalesce(sum(ST_NPoints(ST_CollectionExtract(mv,1))),0)
        FROM inv""", (co_no,))
    n_inv, n_coll, max_line_m, dropped_pts = cur.fetchone()
    cur.execute("""
        SELECT max(ST_NPoints(geom)),
               percentile_disc(0.99) WITHIN GROUP (ORDER BY ST_NPoints(geom)),
               count(*) FILTER (WHERE ST_MemSize(geom) > 1000000),
               max(ST_MemSize(geom))
        FROM nfhl_flood_zones WHERE co_no=%s""", (co_no,))
    mx, p99, over1mb, maxbytes = cur.fetchone()
    warn = "  <-- SIMPLIFIED SERVING GEOMETRY LIKELY WARRANTED" if (mx or 0) > 300000 else ""
    print(f"     geom: invalid={n_inv} collections={n_coll} discard(line={float(max_line_m):.2f}m,"
          f"pts={dropped_pts}) | npoints max={mx} p99={p99} | >1MB={over1mb} maxbytes={maxbytes}{warn}")

def main():
    if not TARGETS:
        sys.exit("no targets")
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    cur.execute("SET statement_timeout = 0")
    conn.commit()
    fmap = fips_to_co_no(cur)
    by_fips = files_by_fips()
    missing = [f for f in TARGETS if f not in by_fips]
    if missing:
        print(f"MISSING files for FIPS {missing} under {FLOOD_DIR} — refusing partial run.")
        conn.close(); sys.exit(1)

    failed = []
    print(f"mode: {'LOAD + MEASURE + REPAIR' if DO_REPAIR else 'LOAD + MEASURE ONLY (review before --repair)'}")
    for fips in sorted(TARGETS):
        co_no = fmap.get(fips)
        if co_no is None:
            print(f"  !! {fips}: no co_no in county_registry"); failed.append(fips); continue
        print(f"loading {fips} ({len(by_fips[fips])} file(s)) ...")
        load_county(cur, conn, fips, co_no, by_fips[fips], failed)
        if fips not in failed:
            measure_county(cur, fips, co_no)

    cur.execute("SELECT count(*), count(DISTINCT co_no) FROM nfhl_flood_zones")
    total, ncounties = cur.fetchone()
    print(f"\nTOTAL loaded {total:,} across {ncounties} counties (target 175,728 / 14).")

    if failed:
        print(f"FAILED: {sorted(set(failed))}  <-- NOT done. No repair, no wiring. Fix and re-run.")
        conn.close(); sys.exit(1)

    if DO_REPAIR:
        print("repairing geometry once (dimension-aware, fail-loud) ...")
        cur.execute("SELECT public.repair_geometry_once('nfhl_flood_zones'::regclass)")
        print(f"  repaired {cur.fetchone()[0]:,} rows; 0 remain invalid (function raises otherwise).")
        conn.commit()
        print("14/14 reconciled + repaired. NEXT: run migrations/114b_wire_flood.sql to wire the resolver,\n"
              "then re-run detections + goldens. Until 114b runs, these counties still serve not_available.")
    else:
        print("MEASURE-ONLY complete. Review the per-county geom lines above. If discards are degenerate,\n"
              "re-run with --repair. (Nothing is wired yet; counties still serve not_available.)")
    conn.close()

if __name__ == "__main__":
    main()
