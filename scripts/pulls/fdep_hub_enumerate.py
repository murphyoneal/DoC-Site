#!/usr/bin/env python3
"""
fdep_hub_enumerate.py — enumerate the FDEP Geospatial Open Data Portal (geodata.dep.state.fl.us, an ArcGIS
Hub), classify every dataset, diff against what we hold, and register the gaps in data_source_registry.

WHY ONE SCRIPT
  geodata.dep.state.fl.us is an ArcGIS Hub (opendata-ui on hubcdn.arcgis.com; ArcGIS item IDs exposed). Every
  dataset resolves to a FeatureServer/MapServer — the SAME pull class the harness already runs ~219 times, not
  a new integration. Enumerating it once resolves mines, delineated groundwater-contamination areas, FGS
  geohazards (FAVA / karst / surficial geology), solid-waste facilities, the Petroleum Restoration Program,
  and brownfield/institutional-controls in a single pass — instead of chasing one layer at a time.

TWO GEOMETRY CLASSES, TWO QUERY SHAPES — DO NOT COLLAPSE THEM
  The most repeated defect in this project is asking a question with the wrong spatial shape. This script
  labels every row with the query shape its geometry demands, EVIDENCED from the FeatureServer's geometryType
  when --probe-geometry is set (never guessed from the title alone):
    * POLYGON  -> a SHADOW. "Does the parcel sit inside/over this footprint?" -> ST_Intersects (containment).
                  Mine boundaries, reclamation units, groundwater-contamination areas, brownfield areas.
    * POINT    -> a PINPOINT. "How close, how often?" -> distance / frequency. A parcel two miles from active
                  blasting has a vibration exposure that has nothing to do with sitting on a mine.
  A mine polygon answered with a distance query, or a blasting point answered with containment, rebuilds the
  defect we have spent the week removing. The query_shape column carries the answer to the wiring step.

THE SENTINEL / HISTORIC-USE CAVEAT (carried into notes, so the wiring step cannot forget it)
  Every FDEP register records what was DISCOVERED and REGULATED — it is blind to what a parcel WAS.
    * Mining "Current Mines" (2023) and the Mandatory phosphate layers are ACTIVE PERMITS, not history. Land
      mined under a mandatory permit is post-1 Jul 1975; land mined BEFORE that was never required to be
      reclaimed and is absent. A backfilled 1960s borrow pit under a subdivision is the higher risk precisely
      because nobody knows it is there. So a null is "not a currently/mandatorily permitted mine", NEVER
      "never mined" — a not_available in the sentinel class. Historic sites (USGS MRDS, historic quads) remain
      an open gap.
    * Groundwater-contamination areas (Ch. 62-524) are a state_regulatory CONSTRAINT (well-drilling bar), not
      area context.
  PROJECTION: FDEP mining services publish in EPSG 3087 / 6439 (Florida GDL Albers), not 4326. Reproject on
  ingest or every spatial test silently fails against 4326 parcels.

WHAT IT DOES
  1. Enumerate the Hub catalogue. Preferred: the DCAT-US 1.1 feed the Hub exposes
     (https://<hub>/api/feed/dcat-us/1.1.json). Fallback: an ArcGIS Portal Sharing search URL you pass with
     --search (…/sharing/rest/search?q=…&f=json). You supply the endpoint — we do not assert one we cannot
     verify — but the default --portal is geodata.dep.state.fl.us.
  2. Parse each dataset: TITLE, ITEM ID, distribution URL (FeatureServer/MapServer), VINTAGE (modified/issued).
  3. CLASSIFY into a concept, flagging the GEOHAZARD + MINING + GROUNDWATER + BROWNFIELD priority sets; and
     assign a query_shape (from --probe-geometry's esri geometryType, else a keyword hint marked 'unverified').
  4. DIFF against what we hold (information_schema + table_inventory).
  5. WRITE missing rows to data_source_registry (active=false, pull_mode set, caveats in notes).

USAGE (run from the WSL pull environment — Git Bash cannot reach these hosts)
    export DATABASE_URL='postgresql://…:5432/postgres'
    python3 scripts/pulls/fdep_hub_enumerate.py --dry-run                     # DCAT feed, classify+diff, no writes
    python3 scripts/pulls/fdep_hub_enumerate.py --probe-geometry              # evidence polygon/point per layer
    python3 scripts/pulls/fdep_hub_enumerate.py --priority-first              # geohazard/mining/gw/brownfield first
    python3 scripts/pulls/fdep_hub_enumerate.py --search '<portal search URL>'  # fallback enumeration source
"""

import argparse
import json
import os
import re
import sys

try:
    import requests
except ImportError as e:  # pragma: no cover
    sys.exit(f"missing dependency ({e}); run in the WSL pull env: pip install requests")
# psycopg2 imported lazily so --dry-run works with just requests.

UA = "DoP-FDEP-hub-enumerate/1.0 (property-intelligence; contact: murphy.oneal@gmail.com)"
HTTP_TIMEOUT = 120
DEFAULT_PORTAL = "geodata.dep.state.fl.us"

# ── classification ──────────────────────────────────────────────────────────────────────────────────────
# PRIORITY sets flagged first. Keyword -> concept; first match wins. Read the catalogue's own words — never
# invent a meaning or a vintage. A dataset with no distribution URL is 'no_download', not skipped.
PRIORITY_RX = re.compile(
    r"mine|mining|phosphat|reclamation|borrow[\s_]?pit|blast|"                       # mining + blasting
    r"ground[\s_]?water[\s_]?contamination|delineated|62-?524|potable[\s_]?well|"    # groundwater restriction
    r"brownfield|institutional[\s_]?control|petroleum[\s_]?restoration|"             # cleanup / PRP / IC
    r"sinkhole|subsidence|karst|fava|aquifer[\s_]?vulnerab|surficial[\s_]?geolog",   # FGS geohazards
    re.I)
CONCEPT_RULES = [
    # mining — split so the polygon/point distinction survives into the concept name
    (re.compile(r"blast|vibration|mine[\s_]?activity[\s_]?clearinghouse", re.I),        "mining_blasting_points"),
    (re.compile(r"released.*(mine|reclamation)|reclamation[\s_]?unit", re.I),           "mining_released_boundary"),
    (re.compile(r"mandatory.*(mine|reclamation)|phosphat|\bmine\b|mining|borrow[\s_]?pit", re.I), "mining_boundary"),
    (re.compile(r"ground[\s_]?water[\s_]?contamination|delineated|62-?524|potable[\s_]?well", re.I), "groundwater_restriction"),
    (re.compile(r"institutional[\s_]?control", re.I),                                   "institutional_control"),
    (re.compile(r"brownfield", re.I),                                                   "brownfield"),
    (re.compile(r"petroleum[\s_]?restoration|\bprp\b|storage[\s_]?tank|\bpcts\b", re.I),"petroleum_restoration"),
    (re.compile(r"solid[\s_]?waste|landfill|disposal|dredg", re.I),                     "solid_waste"),
    (re.compile(r"sinkhole|subsidence|karst|closed[\s_]?depression", re.I),             "sinkhole"),
    (re.compile(r"fava|aquifer[\s_]?vulnerab|recharge", re.I),                          "aquifer_vulnerability"),
    (re.compile(r"geolog|litholog|surficial|bedrock|formation", re.I),                 "geology"),
    (re.compile(r"drycleaning|dry[\s_]?clean", re.I),                                   "drycleaning"),
    (re.compile(r"flood|fema|firm|sfha|repetitive", re.I),                              "flood"),
    (re.compile(r"wetland|hydro|nhd|waterbod|flowline|spring", re.I),                   "hydrology"),
    (re.compile(r"erosion|shorelin|scarp|coastal[\s_]?constr", re.I),                   "coastal"),
]
# Concepts whose spatial question is CONTAINMENT (polygon shadow) vs PROXIMITY (point pinpoint), when we can't
# probe the geometry. This is a HINT (marked 'unverified'); --probe-geometry replaces it with the real
# esriGeometryType. The wiring step must not treat an unverified hint as evidence.
CONTAINMENT_CONCEPTS = {
    "mining_boundary", "mining_released_boundary", "groundwater_restriction", "brownfield",
    "institutional_control", "flood",
}
PROXIMITY_CONCEPTS = {"mining_blasting_points"}

# Per-concept caveat baked into the registry note, so the wiring step inherits the discipline.
CONCEPT_CAVEAT = {
    "mining_boundary": "ACTIVE/mandatory permit (post-1 Jul 1975) — null means 'not a mandatorily-permitted mine', NEVER 'never mined'. Reproject from EPSG 3087/6439. Containment (ST_Intersects), a shadow not a distance.",
    "mining_released_boundary": "RELEASED = reclamation obligation discharged (62C-16.0068) but altered hydrology, waste clay, uncertain fill, elevated radon persist — looks clean in every register and isn't. Containment. Reproject 3087/6439.",
    "mining_blasting_points": "POINT layer — a pinpoint, NOT a footprint. Distance + frequency only; vibration exposure is unrelated to sitting on a mine. Do NOT ST_Intersects.",
    "groundwater_restriction": "Ch. 62-524 state_regulatory CONSTRAINT (potable-well bar, FDOH-enforced). Containment, treat like the flood mandate. NOTE: fdep_gwca is already held+wired — diff should mark held.",
    "brownfield": "Held-vs-served: brownfield areas/sites + institutional controls largely already ingested (fdep_brownfield_*). Confirm serving mechanism before re-pulling.",
    "institutional_control": "Recorded administrative restriction. Containment against the IC polygon; join to official records for terms.",
}


def classify(name, title, keywords):
    text = f"{name} {title or ''} {keywords or ''}"
    concept = next((c for rx, c in CONCEPT_RULES if rx.search(text)), "other")
    priority = bool(PRIORITY_RX.search(text))
    return concept, priority


def query_shape_hint(concept):
    if concept in CONTAINMENT_CONCEPTS:
        return "containment"      # ST_Intersects — polygon shadow
    if concept in PROXIMITY_CONCEPTS:
        return "proximity"        # distance / frequency — point pinpoint
    return "unknown"


ESRI_SHAPE = {
    "esriGeometryPolygon": "containment", "esriGeometryPolyline": "proximity",
    "esriGeometryPoint": "proximity", "esriGeometryMultipoint": "proximity",
}


def http_get(url, **kw):
    r = requests.get(url, headers={"User-Agent": UA}, timeout=HTTP_TIMEOUT, **kw)
    r.raise_for_status()
    return r


def _slug(s):
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", str(s).lower())).strip("_")


# ── enumeration: ArcGIS Hub DCAT-US feed (preferred) or Portal Sharing search (fallback) ─────────────────
def enumerate_dcat(portal):
    """ArcGIS Hub exposes a DCAT-US 1.1 catalogue at /api/feed/dcat-us/1.1.json (also .../dcat-us/1.1.json)."""
    for path in ("/api/feed/dcat-us/1.1.json", "/api/feed/dcat-us/1.1", "/data.json"):
        url = f"https://{portal}{path}"
        try:
            data = http_get(url).json()
        except Exception:
            continue
        datasets = data.get("dataset") if isinstance(data, dict) else None
        if not datasets:
            continue
        out = []
        for d in datasets:
            title = d.get("title")
            if not title:
                continue
            dist_url, dl_url = None, None
            for dist in d.get("distribution", []) or []:
                acc = (dist.get("accessURL") or dist.get("downloadURL") or "")
                if re.search(r"/(Feature|Map)Server", acc, re.I) and not dist_url:
                    dist_url = acc
                if (dist.get("downloadURL") or "").lower().endswith((".zip", ".gdb.zip")) and not dl_url:
                    dl_url = dist.get("downloadURL")
            landing = d.get("landingPage") or ""
            item_id = None
            m = re.search(r"([0-9a-f]{32})", landing + " " + (d.get("identifier") or ""))
            if m:
                item_id = m.group(1)
            vintage = (d.get("modified") or d.get("issued") or "")
            mv = re.search(r"\d{4}(-\d{2}(-\d{2})?)?", str(vintage))
            out.append({
                "name": _slug(title), "title": title,
                "url": dist_url or dl_url or landing or None,
                "feature_server": dist_url, "download_url": dl_url,
                "item_id": item_id, "vintage": (mv.group(0) if mv else None),
                "keywords": " ".join(d.get("keyword", []) or []),
            })
        print(f"enumerated {len(out)} datasets via DCAT: {url}")
        return out
    return []


def enumerate_search(search_url):
    """ArcGIS Portal Sharing search (…/sharing/rest/search?q=…&f=json). Paginates on nextStart."""
    out, start = [], 1
    while start != -1:
        u = search_url + (("&" if "?" in search_url else "?") + f"start={start}&num=100&f=json")
        data = http_get(u).json()
        for it in data.get("results", []):
            title = it.get("title") or it.get("name")
            if not title:
                continue
            base = it.get("url")
            out.append({
                "name": _slug(title), "title": title, "url": base,
                "feature_server": base if base and re.search(r"/(Feature|Map)Server", base, re.I) else None,
                "download_url": None, "item_id": it.get("id"),
                "vintage": None, "keywords": " ".join(it.get("tags", []) or []),
            })
        start = data.get("nextStart", -1)
    print(f"enumerated {len(out)} items via Portal search")
    return out


def probe_geometry(feature_server):
    """Read the layer's esriGeometryType so polygon/point is EVIDENCED, not guessed. Network — Murphy runs it."""
    if not feature_server:
        return None
    base = re.sub(r"/\d+$", "", feature_server.rstrip("/"))
    try:
        meta = http_get(base + "/0", params={"f": "json"}).json()
        gt = meta.get("geometryType") or (meta.get("layers", [{}])[0].get("geometryType") if meta.get("layers") else None)
        return ESRI_SHAPE.get(gt) if gt else None
    except Exception:
        return None


# ── diff against what we hold ────────────────────────────────────────────────────────────────────────────
def held_basenames(conn):
    held = set()
    with conn.cursor() as cur:
        cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")
        held |= {r[0] for r in cur.fetchall()}
        try:
            cur.execute("SELECT table_name FROM public.table_inventory")
            held |= {r[0] for r in cur.fetchall() if r[0]}
        except Exception:
            pass
    return held


def is_held(name, title, held):
    toks = [t for t in _slug(f"{name} {title}").split("_") if len(t) > 3]
    for h in held:
        hl = h.lower()
        if name and name in hl:
            return h
        if toks and sum(1 for t in toks if t in hl) >= max(2, len(toks) - 1):
            return h
    return None


def pull_mode_for(url):
    if not url:
        return "manual"
    u = url.lower()
    if "/arcgis/rest/" in u or re.search(r"/(feature|map)server", u):
        return "arcgis_rest"
    if u.endswith((".zip", ".gdb.zip", ".shp.zip")) or "/ftp/" in u:
        return "bulk_download"
    return "manual"


def main():
    ap = argparse.ArgumentParser(description="Enumerate the FDEP ArcGIS Hub, classify, diff, and register gaps.")
    ap.add_argument("--portal", default=DEFAULT_PORTAL, help=f"ArcGIS Hub domain (default {DEFAULT_PORTAL})")
    ap.add_argument("--search", help="fallback: an ArcGIS Portal Sharing search URL (…/sharing/rest/search?q=…)")
    ap.add_argument("--probe-geometry", action="store_true", help="probe each FeatureServer for esriGeometryType (evidence the query shape)")
    ap.add_argument("--priority-first", action="store_true", help="print the geohazard/mining/groundwater/brownfield set first")
    ap.add_argument("--dry-run", action="store_true", help="classify + diff + print; write nothing")
    args = ap.parse_args()

    records = enumerate_search(args.search) if args.search else enumerate_dcat(args.portal)
    if not records:
        sys.exit("no datasets enumerated — check --portal reachable (DCAT feed) or pass --search '<portal search URL>'.")

    for r in records:
        r["concept"], r["priority"] = classify(r["name"], r["title"], r.get("keywords"))
        shape = probe_geometry(r.get("feature_server")) if args.probe_geometry else None
        r["query_shape"] = shape or query_shape_hint(r["concept"])
        r["shape_evidenced"] = bool(shape)
    if args.priority_first:
        records.sort(key=lambda r: (not r["priority"], r["concept"], r["name"]))

    conn, held = None, set()
    if not args.dry_run:
        dsn = os.environ.get("DATABASE_URL") or os.environ.get("SUPABASE_DB_URL")
        if not dsn:
            sys.exit("set DATABASE_URL (Supabase session connection) or use --dry-run")
        try:
            import psycopg2
        except ImportError:
            sys.exit("psycopg2 not installed; run in the WSL pull env: pip install psycopg2-binary")
        conn = psycopg2.connect(dsn)
        held = held_basenames(conn)

    counts = {"priority": 0, "held": 0, "missing": 0, "no_download": 0, "registered": 0}
    for r in records:
        h = is_held(r["name"], r["title"], held) if not args.dry_run else None
        status = "held" if h else ("no_download" if not r["url"] else "missing")
        counts["priority"] += r["priority"]
        counts[status] = counts.get(status, 0) + 1
        tag = "PRIORITY" if r["priority"] else r["concept"]
        shp = r["query_shape"] + ("" if r["shape_evidenced"] else "?")
        print(f"[{tag:12s}] {status:11s} {shp:13s} {r['name'][:40]:40s} v={r['vintage'] or '?':10s} {r['url'] or '(none)'}")
        if conn and status == "missing":
            note = (f"FDEP Hub: {r['title']} (vintage {r['vintage'] or 'unknown'}; item {r['item_id'] or '?'}). "
                    f"query_shape={r['query_shape']}{'' if r['shape_evidenced'] else ' (UNVERIFIED hint — probe geometryType before wiring)'}. "
                    + CONCEPT_CAVEAT.get(r["concept"], "Absence in the register is not absence in the ground."))
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO public.data_source_registry
                         (county_name, category, table_name, source_url, access_technique, pull_mode, active, notes)
                       VALUES ('Florida', %s, %s, %s, 'fdep_hub_enumerate', %s, false, %s)
                       ON CONFLICT DO NOTHING""",
                    (r["concept"], "fdep_" + r["name"], r["url"], pull_mode_for(r["url"]), note))
            counts["registered"] += 1
    if conn:
        conn.commit()
        conn.close()

    print("\nsummary:", ", ".join(f"{k}={v}" for k, v in counts.items()), f"of {len(records)} catalogued")
    if not args.dry_run:
        print("missing rows written to data_source_registry (active=false, pull_mode + query_shape caveat in notes) — the diffable work-list.")
        print("NB: query shapes marked '?' are keyword hints, not evidence — re-run with --probe-geometry before wiring any layer.")
    else:
        print("(dry-run — nothing written)")


if __name__ == "__main__":
    main()
