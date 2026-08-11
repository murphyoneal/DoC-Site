#!/usr/bin/env python3
"""
Pull FEMA NFHL Flood Hazard Zones (layer 28) for the 14 Florida counties
with no served flood layer.

v2 - rewritten after measurement:
  * objectIds batching returns HTTP 500 at scale (a 1000-feature response is
    ~95MB and the service will not build it). Uses resultOffset pagination,
    which measured clean at 200/request.
  * geometryPrecision=6 (~4 inches) cuts payload 44% with no meaningful loss -
    a FIRM boundary is not drawn to sub-nanometre precision regardless.
  * Output gzipped. Pull only; load is a separate step, so a failed load never
    means re-fetching 175k polygons.

Run:  python3 pull_nfhl_14.py            # all 14, smallest first
      python3 pull_nfhl_14.py 12019      # one county
"""

import gzip, json, os, sys, time, urllib.parse, urllib.request

BASE = "https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer/28/query"
OUTDIR = "nfhl_out"
PAGE = 500            # auto-halves on failure
MIN_PAGE = 100
PAUSE = 1.0
RETRIES = 5
PRECISION = 6

FIELDS = ("OBJECTID,FLD_AR_ID,FLD_ZONE,ZONE_SUBTY,STATIC_BFE,DEPTH,"
          "V_DATUM,LEN_UNIT,DUAL_ZONE,SOURCE_CIT,DFIRM_ID")

# Measured 2026-08-10 via returnCountOnly. Verification targets.
EXPECTED = {
    "12001": ("Alachua",    3391), "12005": ("Bay",       10076),
    "12009": ("Brevard",   23480), "12015": ("Charlotte",  8411),
    "12019": ("Clay",       1704), "12031": ("Duval",     10207),
    "12043": ("Glades",     3726), "12053": ("Hernando",  12768),
    "12069": ("Lake",       6791), "12077": ("Liberty",    2758),
    "12081": ("Manatee",   13820), "12097": ("Osceola",    2850),
    "12105": ("Polk",      21220), "12115": ("Sarasota",  54526),
}


def fetch(params, tag=""):
    """Retry on empty body, HTTP 500 and transport drops.

    The observed failure mode on this host is an intermittent FAST empty
    response - a longer timeout never helps. An empty body is an ERROR,
    never a zero."""
    data = urllib.parse.urlencode(params).encode()
    last = None
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(BASE, data=data,
                                         headers={"User-Agent": "DoP-pull/2.0"})
            with urllib.request.urlopen(req, timeout=300) as r:
                body = r.read().decode("utf-8", "replace")
            if not body.strip():
                last = "empty body"
            else:
                obj = json.loads(body)
                if isinstance(obj, dict) and "error" in obj:
                    last = f"arcgis: {obj['error'].get('message')}"
                else:
                    return obj
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
        wait = min(2 ** attempt, 30)
        print(f"      retry {attempt}/{RETRIES} {tag} after {last} "
              f"- sleep {wait}s", flush=True)
        time.sleep(wait)
    raise RuntimeError(f"failed after {RETRIES}: {last}")


def get_oids(fips):
    obj = fetch({"where": f"DFIRM_ID LIKE '{fips}%'",
                 "returnIdsOnly": "true", "f": "json"}, tag="[oids]")
    return obj.get("objectIds") or []


def pull_county(fips, name, expected):
    print(f"\n=== {name} ({fips}) - expecting {expected:,}", flush=True)

    ids = get_oids(fips)
    print(f"  OIDs: {len(ids):,}", flush=True)
    if not ids:
        raise RuntimeError("ABORT: zero OIDs. Empty is a sentinel, not a result.")
    if len(ids) != expected:
        print(f"  !! OID count differs from baseline by {len(ids)-expected:+,} "
              f"- source may have changed. Recorded in manifest.", flush=True)

    idset, feats, seen = set(ids), [], set()
    offset, page = 0, PAGE

    while offset < len(ids):
        try:
            obj = fetch({
                "where": f"DFIRM_ID LIKE '{fips}%'",
                "outFields": FIELDS,
                "returnGeometry": "true",
                "outSR": "4326",
                "geometryPrecision": str(PRECISION),
                "orderByFields": "OBJECTID",
                "resultOffset": str(offset),
                "resultRecordCount": str(page),
                "f": "geojson",
            }, tag=f"[{offset}/{len(ids)}]")
        except RuntimeError:
            if page > MIN_PAGE:
                page = max(MIN_PAGE, page // 2)
                print(f"      halving page size to {page}", flush=True)
                continue
            raise

        got = obj.get("features") or []
        if not got:
            raise RuntimeError(
                f"ABORT: empty page at offset {offset} with "
                f"{len(ids)-offset:,} OIDs still expected.")

        for f in got:
            oid = f.get("id") or (f.get("properties") or {}).get("OBJECTID")
            if oid is not None:
                seen.add(oid)
        feats.extend(got)
        offset += len(got)
        print(f"  {len(feats):,}/{len(ids):,}   ", end="\r", flush=True)
        time.sleep(PAUSE)

    print(f"  fetched: {len(feats):,}                         ", flush=True)

    # Completeness by set-diff against the OID list - never the loop tally.
    missing = idset - seen
    extra = seen - idset
    if missing:
        print(f"  !! {len(missing):,} OIDs never returned", flush=True)
    if extra:
        print(f"  !! {len(extra):,} unexpected OIDs returned", flush=True)
    if len(feats) and len(feats) % 2000 == 0:
        print("  !! exact multiple of 2000 - TRUNCATION SUSPECT", flush=True)

    path = os.path.join(OUTDIR, f"nfhl_{fips}_{name.lower()}.geojson.gz")
    with gzip.open(path, "wt") as fh:
        json.dump({"type": "FeatureCollection", "features": feats}, fh)
    print(f"  wrote {path} ({os.path.getsize(path)/1e6:.1f} MB gz)", flush=True)

    return {"fips": fips, "county": name, "expected": expected,
            "oids": len(ids), "fetched": len(feats),
            "missing": len(missing), "extra": len(extra),
            "file": path, "ok": len(feats) == len(ids) and not missing}


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    targets = sys.argv[1:] or list(EXPECTED)
    targets.sort(key=lambda f: EXPECTED[f][1])   # smallest first: fail cheap

    done, failed = [], []
    for fips in targets:
        name, exp = EXPECTED[fips]
        try:
            done.append(pull_county(fips, name, exp))
        except Exception as e:
            print(f"  FAILED {name}: {e}", flush=True)
            failed.append({"fips": fips, "county": name, "error": str(e)})

    with open(os.path.join(OUTDIR, "manifest.json"), "w") as fh:
        json.dump({"pulled": done, "failed": failed,
                   "geometry_precision": PRECISION, "fields": FIELDS}, fh, indent=2)

    print("\n" + "=" * 60)
    good = [d for d in done if d["ok"]]
    print(f"complete: {len(good)}/{len(targets)}")
    for d in done:
        if not d["ok"]:
            print(f"  INCOMPLETE {d['county']}: {d['fetched']:,} of {d['oids']:,}")
    for f in failed:
        print(f"  FAILED     {f['county']}: {f['error']}")
    print(f"features: {sum(d['fetched'] for d in done):,} "
          f"(baseline 175,728 for all 14)")
    if failed or len(good) != len(targets):
        print("\nNOT COMPLETE - do not load until every county reconciles.")
        sys.exit(1)
    print("\nAll counties reconcile. Safe to load.")


if __name__ == "__main__":
    main()
