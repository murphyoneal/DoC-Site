#!/usr/bin/env python3
"""
WO 106 / rulings 100-105,107 — load NHD (hydrography) + NRHP (historic) into Supabase.

RUN IN WSL (that is where a working psycopg2 + DB DSN live; the pooler honors an in-session
`SET statement_timeout=0`, which is the ONLY way a big COPY/INSERT survives here — see CLAUDE.md §7).

    export SUPABASE_DB_URL='postgresql://...'          # the same DSN cad_load.py uses
    export DOC_DATA_DIR='/mnt/c/Users/murph/Documents/GitHub/DoC-Site'   # where nhd_out/ nrhp_out/ live
    python3 scripts/wo106_load_nhd_nrhp.py             # loads all four layers
    python3 scripts/wo106_load_nhd_nrhp.py nhd_flowline   # or one at a time

WHAT IT ENFORCES (the schema already forbids the rest — 113a):
  * Load EVERY row. The synthetic FTYPE 558/334 centrelines and coastline 566 are needed for network
    tracing; they are excluded at SERVE (views nhd_watercourse / nhd_coastline), NEVER here (ruling 107).
  * FDATE / CREATEDATE / EDIT_DATE / SRC_DATE are epoch-MILLISECONDS -> UTC timestamp (/1000).
  * CertDate stays raw 'MM/DD/YY' text (2-digit year is ambiguous; parse at serve, not here).
  * INNETWORK 'None' -> SQL NULL (the CHECK on the column is the backstop).
  * Point geom stays Point; every Polygon/LineString is ST_Multi'd to match the Multi* column type; SRID 4326.
  * Geometry is repaired ONCE after load (repair_geometry_once), never per served call.

DISCIPLINE (CLAUDE.md invariants): full-refresh = TRUNCATE then load, so a re-run cannot duplicate
(idempotence, §9). Non-zero asserted after every chunk AND every table (empty != done, §6). Loaded count
is reconciled against the pull manifest; any table that errors or fails to reconcile lands in FAILED and
the process exits non-zero. A summary is printed ONLY if FAILED is empty.
"""
import gzip, json, os, sys, glob
from datetime import datetime, timezone

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    sys.exit("psycopg2 not found. In WSL: pip install psycopg2-binary")

DSN = os.environ.get("SUPABASE_DB_URL") or os.environ.get("DATABASE_URL")
if not DSN:
    sys.exit("Set SUPABASE_DB_URL to the psycopg2 DSN the other WSL loaders (cad_load.py) use.")
DATA = os.environ.get("DOC_DATA_DIR", "/mnt/c/Users/murph/Documents/GitHub/DoC-Site")
CHUNK = 50_000

# ── coercions ────────────────────────────────────────────────────────────────
def as_int(v):
    if v is None or v == "":
        return None
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return None

def as_float(v):
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None

def as_epoch_ts(v):                       # epoch-milliseconds -> aware UTC datetime
    if v is None or v == "":
        return None
    try:
        return datetime.fromtimestamp(int(float(v)) / 1000.0, tz=timezone.utc)
    except (TypeError, ValueError, OSError):
        return None

def as_text(v):
    return None if v is None else str(v)

def as_innetwork(v):                      # 'None' string is a text-null sentinel
    if v is None or str(v) == "None":
        return None
    return str(v)

KIND = {"int": as_int, "float": as_float, "ts": as_epoch_ts, "text": as_text, "innet": as_innetwork}

# ── per-layer spec: (target_col, source_key, kind). geom handled separately. ──
NRHP_BASE = [
    ("objectid", "OBJECTID", "int"), ("nris_refnum", "NRIS_Refnum", "text"),
    ("resname", "RESNAME", "text"), ("restype", "ResType", "text"),
    ("address", "Address", "text"), ("city", "City", "text"), ("county", "County", "text"),
    ("state", "State", "text"), ("vicinity", "Vicinity", "text"), ("multiname", "MultiName", "text"),
    ("numcbldg", "NumCBldg", "int"), ("numcobj", "NumCObj", "int"),
    ("numcsite", "NumCSite", "int"), ("numcstru", "NumCStru", "int"),
    ("is_nhl", "Is_NHL", "text"), ("bnd_type", "BND_TYPE", "text"), ("bnd_other", "BND_OTHER", "text"),
    ("is_extant", "IS_EXTANT", "text"), ("extant_oth", "EXTANT_OTH", "text"),
    ("certdate", "CertDate", "text"),                       # raw MM/DD/YY
    ("createdate", "CREATEDATE", "ts"), ("edit_date", "EDIT_DATE", "ts"),
    ("map_method", "MAP_METHOD", "text"), ("map_mth_ot", "MAP_MTH_OT", "text"),
    ("source", "SOURCE", "text"), ("src_date", "SRC_DATE", "ts"),
    ("src_scale", "SRC_SCALE", "text"), ("src_accu", "SRC_ACCU", "text"), ("src_coord", "SRC_COORD", "text"),
    ("originator", "ORIGINATOR", "text"), ("constrant", "CONSTRANT", "text"),
    ("cr_id", "CR_ID", "text"), ("geom_id", "GEOM_ID", "text"), ("property_id", "PROPERTY_ID", "text"),
    ("status", "STATUS", "text"), ("nara_url", "NARA_URL", "text"),
]

LAYERS = {
    "nhd_area": {
        "files": ["nhd_out/nhd_area.geojsonl.gz"],
        "geom": "multi",
        "spec": [
            ("objectid", "OBJECTID", "int"), ("permanent_identifier", "PERMANENT_IDENTIFIER", "text"),
            ("fdate", "FDATE", "ts"), ("resolution", "RESOLUTION", "int"),
            ("gnis_id", "GNIS_ID", "text"), ("gnis_name", "GNIS_NAME", "text"),
            ("areasqkm", "AREASQKM", "float"), ("ftype", "FTYPE", "int"), ("fcode", "FCODE", "int"),
            ("shape_area", "SHAPE.AREA", "float"), ("shape_len", "SHAPE.LEN", "float"),
        ],  # ELEVATION + VISIBILITYFILTER intentionally absent
    },
    "nhd_flowline": {
        "files": ["nhd_out/nhd_flowline.geojsonl.gz"],
        "geom": "multi",
        "spec": [
            ("objectid", "OBJECTID", "int"), ("permanent_identifier", "PERMANENT_IDENTIFIER", "text"),
            ("fdate", "FDATE", "ts"), ("resolution", "RESOLUTION", "int"),
            ("gnis_id", "GNIS_ID", "text"), ("gnis_name", "GNIS_NAME", "text"),
            ("lengthkm", "LENGTHKM", "float"), ("reachcode", "REACHCODE", "text"),
            ("flowdir", "FLOWDIR", "int"),
            ("wbarea_permanent_identifier", "WBAREA_PERMANENT_IDENTIFIER", "text"),
            ("ftype", "FTYPE", "int"), ("fcode", "FCODE", "int"),
            ("innetwork", "INNETWORK", "innet"), ("parent_feature", "PARENT_FEATURE", "text"),
            ("globalid", "GLOBALID", "text"), ("shape_len", "SHAPE.LEN", "float"),
        ],  # ENABLED, FLOWDIRECTION, MAINPATH, VISIBILITYFILTER intentionally absent
    },
    "nrhp_points": {"files": ["nrhp_out/nrhp_points.geojsonl.gz"], "geom": "point", "spec": NRHP_BASE},
    "nrhp_district_polygons": {
        "files": ["nrhp_out/nrhp_district_polygons.geojsonl.gz"], "geom": "multi",
        "spec": NRHP_BASE + [("shape_length", "Shape_Length", "float"), ("shape_area", "Shape_Area", "float")],
    },
}

# ── file readers (handle BOTH shapes) ────────────────────────────────────────
def iter_features(path):
    """Yield GeoJSON Feature dicts from .geojsonl.gz (one per line) or .geojson.gz (FeatureCollection)."""
    if ".geojsonl" in os.path.basename(path):
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    yield json.loads(line)
    else:  # FeatureCollection (e.g. NFHL flood counties)
        with gzip.open(path, "rt", encoding="utf-8") as fh:
            for feat in json.load(fh).get("features", []):
                yield feat

def manifest_count(path):
    """Authoritative pulled-count for THIS file from its dir manifest ({"pulled":[{file,fetched,...}]})."""
    m = os.path.join(os.path.dirname(path), "manifest.json")
    if not os.path.exists(m):
        return None
    try:
        d = json.load(open(m, encoding="utf-8"))
    except (ValueError, OSError):
        return None
    base = os.path.basename(path)
    for entry in d.get("pulled", []):
        if os.path.basename(str(entry.get("file", ""))) == base:
            for k in ("fetched", "expected", "count", "oids"):
                if isinstance(entry.get(k), int):
                    return entry[k]
    return None

# ── loader ───────────────────────────────────────────────────────────────────
def build_row(feat, spec):
    p = feat.get("properties", {})
    # case-insensitive property lookup (ArcGIS field-name casing is not stable — CLAUDE.md)
    lower = {k.lower(): v for k, v in p.items()}
    out = []
    for _col, src, kind in spec:
        v = p.get(src, lower.get(src.lower()))
        out.append(KIND[kind](v))
    out.append(json.dumps(feat.get("geometry")))   # geom json is the final param
    return tuple(out)

def load_layer(conn, name, cfg, failed):
    cols = [c for c, _s, _k in cfg["spec"]]
    geo = ("ST_SetSRID(ST_GeomFromGeoJSON(%s),4326)" if cfg["geom"] == "point"
           else "ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(%s),4326))")
    template = "(" + ",".join(["%s"] * len(cols)) + "," + geo + ")"
    insert = f"INSERT INTO {name} ({','.join(cols)},geom) VALUES %s " \
             f"ON CONFLICT (objectid) DO NOTHING"

    paths = []
    for pat in cfg["files"]:
        paths.extend(sorted(glob.glob(os.path.join(DATA, pat))))
    if not paths:
        print(f"  !! {name}: NO input files matched {cfg['files']} under {DATA}")
        failed.append(name)
        return

    cur = conn.cursor()
    cur.execute(f"TRUNCATE {name}")          # full-refresh: a re-run cannot duplicate (§9)
    expected = 0
    loaded = 0
    batch = []
    try:
        for path in paths:
            mc = manifest_count(path)
            if mc:
                expected += mc
            for feat in iter_features(path):
                batch.append(build_row(feat, cfg["spec"]))
                if len(batch) >= CHUNK:
                    execute_values(cur, insert, batch, template=template, page_size=1000)
                    if cur.rowcount == 0:        # a full chunk inserting nothing is a defect, not a no-op
                        raise RuntimeError(f"{name}: chunk of {len(batch)} inserted 0 rows")
                    loaded += len(batch)
                    conn.commit()
                    print(f"  .. {name}: {loaded:,} rows")
                    batch = []
        if batch:
            execute_values(cur, insert, batch, template=template, page_size=1000)
            loaded += len(batch)
            conn.commit()
    except Exception as e:      # noqa: BLE001 — any failure quarantines this table, never a silent partial
        conn.rollback()
        print(f"  !! {name}: LOAD FAILED: {e}")
        failed.append(name)
        return

    # assertions: non-zero, and count == distinct(objectid) (no dup slipped in)
    cur.execute(f"SELECT count(*), count(DISTINCT objectid) FROM {name}")
    n, ndistinct = cur.fetchone()
    repaired = 0
    if n > 0:
        cur.execute("SELECT public.repair_geometry_once(%s::regclass)", (name,))
        repaired = cur.fetchone()[0]
        conn.commit()
    ok = n > 0 and n == ndistinct
    recon = "n/a" if not expected else ("RECONCILED" if n == expected else f"MISMATCH pulled={expected:,}")
    print(f"  == {name}: rows={n:,} distinct={ndistinct:,} geom_repaired={repaired:,} pulled={expected or '?'} [{recon}]")
    if not ok or (expected and n != expected):
        failed.append(name)

def main():
    want = sys.argv[1:] or list(LAYERS.keys())
    unknown = [w for w in want if w not in LAYERS]
    if unknown:
        sys.exit(f"unknown layer(s): {unknown}. choices: {list(LAYERS)}")
    conn = psycopg2.connect(DSN)
    conn.cursor().execute("SET statement_timeout = 0")   # pooler honors the in-session SET (§7)
    conn.commit()
    failed = []
    for name in want:
        print(f"loading {name} ...")
        load_layer(conn, name, LAYERS[name], failed)
    conn.close()
    if failed:
        print(f"\nFAILED: {failed}  <-- NOT done. Investigate before trusting any of the above.")
        sys.exit(1)
    print(f"\nOK: {want} loaded, reconciled, geometry repaired once. Re-run detections + goldens next.")

if __name__ == "__main__":
    main()
