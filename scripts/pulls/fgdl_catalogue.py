#!/usr/bin/env python3
"""
fgdl_catalogue.py — enumerate the Florida Geographic Data Library (FGDL) catalogue, classify each layer,
diff it against what we already hold, and register the gaps in data_source_registry.

WHY ONE SCRIPT ANSWERS SEVERAL QUESTIONS
  FGDL (fgdl.org, UF GeoPlan Center) is Florida's statewide geospatial clearinghouse. Enumerating it once
  answers the geohazard question (sinkholes/subsidence/karst — the source behind the incident layers we just
  wired), the soils question, the erosion/coastal question, and several we haven't thought to ask. The
  output is a durable, diffable registry of "what FL publishes vs what we hold", not a one-off console dump.

WHAT IT DOES
  1. Fetch the FGDL catalogue index (a CSW/ISO XML feed, a JSON index, or an HTML download listing — the
     parser auto-detects; you supply the URL because we do not assert an endpoint we cannot verify).
  2. Parse each record: layer NAME, VINTAGE (a date if present), DOWNLOAD URL.
  3. CLASSIFY into a concept, flagging the GEOHAZARD set first (sinkhole/subsidence/karst/geology/soils/
     erosion/coastal/...) — the priority set.
  4. DIFF against what we hold (information_schema tables + table_inventory basenames), so each row is
     'held' or 'missing'.
  5. WRITE the missing (and updated-vintage) rows to data_source_registry with pull_mode set
     appropriately (bulk_download for an FGDL zip/ftp; arcgis_rest if the distribution is a REST layer).

  Discipline (same as the CAMA probe and the sentinel sweep): read what the catalogue actually says; do NOT
  pre-map a layer's meaning or guess a vintage. A record with no download URL is 'no_download', not skipped.

USAGE (run from the WSL pull environment — Git Bash cannot reach it)
    export DATABASE_URL='postgresql://...:5432/postgres'
    # point --catalogue at the FGDL metadata index Murphy has verified (CSW GetRecords, a JSON index, or an
    # HTML directory of downloads). Examples of the SHAPES supported, not asserted live endpoints:
    #   CSW:  'https://<fgdl-csw>/csw?service=CSW&version=2.0.2&request=GetRecords&typeNames=csw:Record&resultType=results&maxRecords=9999&elementSetName=full'
    #   JSON: 'https://<host>/catalogue.json'   HTML: 'https://<host>/ftp/'
    python3 scripts/pulls/fgdl_catalogue.py --catalogue '<url>' --geohazard-first
    python3 scripts/pulls/fgdl_catalogue.py --catalogue '<url>' --dry-run   # classify + diff + print; no writes
"""

import argparse
import html
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

try:
    import requests
except ImportError as e:  # pragma: no cover
    sys.exit(f"missing dependency ({e}); run in the WSL pull env: pip install requests")
# psycopg2 imported lazily so --dry-run works with just requests.

UA = "DoP-FGDL-catalogue/1.0 (property-intelligence; contact: murphy.oneal@gmail.com)"
HTTP_TIMEOUT = 120

# Concept classification. GEOHAZARD is the priority set; the rest map an FGDL layer to our concept
# vocabulary. Keyword -> concept; first match wins. Read the catalogue's own words — never invent a meaning.
GEOHAZARD_RX = re.compile(
    r"sinkhole|subsidence|karst|closed[\s_]?depression|geolog|liquefac|seismic|landslide|erosion|"
    r"shorelin|coastal[\s_]?(construction|hazard|erosion)|scarp|bluff|slope[\s_]?stab", re.I)
CONCEPT_RULES = [
    (re.compile(r"sinkhole|subsidence|karst|closed[\s_]?depression", re.I), "sinkhole"),
    (re.compile(r"geolog|litholog|surficial|bedrock|formation", re.I),      "geology"),
    (re.compile(r"\bsoils?\b|ssurgo|drainage[\s_]?class", re.I),            "soils"),
    (re.compile(r"erosion|shorelin|scarp|bluff|coastal[\s_]?constr", re.I), "coastal"),
    (re.compile(r"flood|fema|firm|sfha|floodprone|repetitive", re.I),       "flood"),
    (re.compile(r"wetland|hydro|nhd|waterbod|flowline|stream|canal|spring", re.I), "hydrology"),
    (re.compile(r"aquifer|wellfield|recharge|groundwater", re.I),           "wellfield_protection"),
    (re.compile(r"zoning|land[\s_]?use|future[\s_]?land", re.I),            "land_use"),
    (re.compile(r"parcel|cadastr", re.I),                                   "parcels"),
    (re.compile(r"wind|hurricane|storm[\s_]?surge|evac", re.I),             "storm_surge"),
]


def classify(name, title):
    text = f"{name} {title or ''}"
    concept = next((c for rx, c in CONCEPT_RULES if rx.search(text)), "other")
    return concept, bool(GEOHAZARD_RX.search(text))


def http_get(url):
    r = requests.get(url, headers={"User-Agent": UA}, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r


# ── parsers: CSW/ISO XML, JSON index, HTML directory ────────────────────────────────────────────────────
def _localname(tag):
    return tag.rsplit("}", 1)[-1].lower()


def parse_csw(root):
    """CSW GetRecords (Dublin Core csw:Record, or ISO gmd:MD_Metadata). Extract title, date, download URL."""
    out = []
    for rec in root.iter():
        ln = _localname(rec.tag)
        if ln not in ("record", "summaryrecord", "md_metadata"):
            continue
        title = date = url = None
        for el in rec.iter():
            t, txt = _localname(el.tag), (el.text or "").strip()
            if t == "title" and not title and txt:
                title = txt
            elif t in ("date", "modified", "temporalextent", "ciDate") and not date and re.search(r"\d{4}", txt):
                date = re.search(r"\d{4}(-\d{2}(-\d{2})?)?", txt).group(0)
            elif t in ("references", "url", "linkage", "onlineresource") and not url and txt.lower().startswith("http"):
                url = txt
            for k, v in el.attrib.items():
                if _localname(k) in ("href", "url") and str(v).lower().startswith("http") and not url:
                    url = v
        if title:
            out.append({"name": _slug(title), "title": title, "vintage": date, "download_url": url})
    return out


def parse_json(data):
    recs = data if isinstance(data, list) else (data.get("records") or data.get("features") or data.get("dataset") or [])
    out = []
    for r in recs:
        p = r.get("properties", r) if isinstance(r, dict) else {}
        title = p.get("title") or p.get("name") or p.get("layer") or p.get("id")
        if not title:
            continue
        url = p.get("downloadUrl") or p.get("download_url") or p.get("url") or p.get("distribution")
        date = str(p.get("vintage") or p.get("date") or p.get("year") or "")
        m = re.search(r"\d{4}(-\d{2}(-\d{2})?)?", date)
        out.append({"name": _slug(title), "title": title, "vintage": (m.group(0) if m else None), "download_url": url})
    return out


def parse_html_dir(text, base_url):
    out = []
    for m in re.finditer(r'href=["\']([^"\']+\.(?:zip|gdb\.zip|shp\.zip))["\']', text, re.I):
        href = html.unescape(m.group(1))
        url = href if href.lower().startswith("http") else base_url.rstrip("/") + "/" + href.lstrip("/")
        name = _slug(re.sub(r"\.(zip|gdb|shp)$", "", os.path.basename(href), flags=re.I))
        out.append({"name": name, "title": os.path.basename(href), "vintage": None, "download_url": url})
    return out


def _slug(s):
    return re.sub(r"_+", "_", re.sub(r"[^a-z0-9]+", "_", str(s).lower())).strip("_")


def fetch_and_parse(url):
    resp = http_get(url)
    ctype = resp.headers.get("content-type", "").lower()
    body = resp.text
    if "xml" in ctype or body.lstrip().startswith("<?xml") or "<csw" in body[:2000].lower() or "GetRecordsResponse" in body[:2000]:
        return parse_csw(ET.fromstring(resp.content))
    if "json" in ctype or body.lstrip()[:1] in "[{":
        return parse_json(json.loads(body))
    return parse_html_dir(body, url)


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
    # index by normalised token set for fuzzy containment
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
    if "/arcgis/rest/" in u or u.rstrip("/").endswith(("mapserver", "featureserver")):
        return "arcgis_rest"
    if u.endswith((".zip", ".gdb.zip", ".shp.zip")) or "/ftp/" in u:
        return "bulk_download"
    return "manual"


def main():
    ap = argparse.ArgumentParser(description="Enumerate the FGDL catalogue, classify, diff, and register gaps.")
    ap.add_argument("--catalogue", required=True, help="FGDL catalogue index URL (CSW GetRecords, JSON index, or HTML dir)")
    ap.add_argument("--geohazard-first", action="store_true", help="process/print the geohazard set first")
    ap.add_argument("--dry-run", action="store_true", help="classify + diff + print; write nothing")
    args = ap.parse_args()

    records = fetch_and_parse(args.catalogue)
    if not records:
        print("no records parsed — check --catalogue points at a CSW/JSON/HTML catalogue index.")
        return
    for r in records:
        r["concept"], r["geohazard"] = classify(r["name"], r["title"])
    if args.geohazard_first:
        records.sort(key=lambda r: (not r["geohazard"], r["concept"], r["name"]))

    conn = None
    held = set()
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

    counts = {"geohazard": 0, "held": 0, "missing": 0, "no_download": 0, "registered": 0}
    for r in records:
        h = is_held(r["name"], r["title"], held) if not args.dry_run else None
        status = "held" if h else ("no_download" if not r["download_url"] else "missing")
        counts["geohazard"] += r["geohazard"]
        counts[status] = counts.get(status, 0) + 1
        tag = "GEOHAZARD" if r["geohazard"] else r["concept"]
        print(f"[{tag:12s}] {status:11s} {r['name'][:44]:44s} vintage={r['vintage'] or '?':10s} {r['download_url'] or '(no download)'}")
        # register the MISSING ones with a download; never overwrite a held/active pull
        if conn and status == "missing":
            with conn.cursor() as cur:
                cur.execute(
                    """INSERT INTO public.data_source_registry
                         (county_name, category, table_name, source_url, access_technique, pull_mode, active, notes)
                       VALUES ('Florida', %s, %s, %s, 'fgdl_catalogue', %s, false,
                               %s)
                       ON CONFLICT DO NOTHING""",
                    (r["concept"], "fgdl_" + r["name"], r["download_url"], pull_mode_for(r["download_url"]),
                     f"FGDL catalogue: {r['title']} (vintage {r['vintage'] or 'unknown'}); geohazard={r['geohazard']}; not yet pulled"),
                )
            counts["registered"] += 1
    if conn:
        conn.commit()
        conn.close()

    print("\nsummary:", ", ".join(f"{k}={v}" for k, v in counts.items()), f"of {len(records)} catalogued")
    print("missing rows written to data_source_registry (active=false, pull_mode set) — the diffable work-list."
          if not args.dry_run else "\n(dry-run — nothing written)")


if __name__ == "__main__":
    main()
