#!/usr/bin/env python3
"""
Pull NHD Flowline (layer 4) and Area (layer 5) from FDEP.
Decided over FHD on contents - see ruling 100.

  NHD/4 Flowline  480,792   the whole rivers/canals gap
  NHD/5 Area        5,776   bays, inlets, sea/ocean - the Biscayne Bay case

Source is EPSG 6439 (NAD83 Florida GDL Albers, METRES). outSR=4326 is
mandatory or geometry silently misplaces - the same trap as the FDEP
mining layers.

MaxRecordCount is 1000 here, NOT 2000. Any batch landing on an exact
multiple of 1000 is a truncation suspect.

Run:  python3 pull_nhd.py           # both layers, Area first (small)
      python3 pull_nhd.py 5         # one layer
"""

import gzip, json, os, sys, time, urllib.parse, urllib.request

ROOT = "https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/NHD/MapServer"
OUTDIR = "nhd_out"
PAGE = 500            # under the 1000 cap; auto-halves on failure
MIN_PAGE = 50
PAUSE = 1.0
RETRIES = 5
PRECISION = 6

# Measured 2026-08-10 via returnCountOnly. Verification targets.
LAYERS = {
    "5": ("area",     5776),
    "4": ("flowline", 480792),
}


def fetch(layer, params, tag=""):
    url = f"{ROOT}/{layer}/query"
    data = urllib.parse.urlencode(params).encode()
    last = None
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(url, data=data,
                                         headers={"User-Agent": "DoP-pull/1.0"})
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


def pull_layer(layer, name, expected):
    print(f"\n=== NHD layer {layer} ({name}) - expecting {expected:,}", flush=True)

    ids = fetch(layer, {"where": "1=1", "returnIdsOnly": "true",
                        "f": "json"}, tag="[oids]").get("objectIds") or []
    print(f"  OIDs: {len(ids):,}", flush=True)
    if not ids:
        raise RuntimeError("ABORT: zero OIDs. Empty is a sentinel, not a result.")
    if len(ids) != expected:
        print(f"  !! differs from baseline by {len(ids)-expected:+,}", flush=True)

    idset, seen, count = set(ids), set(), 0
    offset, page = 0, PAGE
    path = os.path.join(OUTDIR, f"nhd_{name}.geojsonl.gz")

    # Line-delimited: 480k features must never be held in memory at once.
    with gzip.open(path, "wt") as out:
        while offset < len(ids):
            try:
                obj = fetch(layer, {
                    "where": "1=1",
                    "outFields": "*",
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
                    print(f"      halving page to {page}", flush=True)
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
                out.write(json.dumps(f) + "\n")
            count += len(got)
            offset += len(got)
            if count % 5000 < page:
                print(f"  {count:,}/{len(ids):,}   ", end="\r", flush=True)
            time.sleep(PAUSE)

    print(f"  fetched: {count:,}                         ", flush=True)

    missing = idset - seen
    if missing:
        print(f"  !! {len(missing):,} OIDs never returned", flush=True)
    if count and count % 1000 == 0:
        print("  !! exact multiple of 1000 - TRUNCATION SUSPECT", flush=True)

    print(f"  wrote {path} ({os.path.getsize(path)/1e6:.1f} MB gz)", flush=True)
    return {"layer": layer, "name": name, "expected": expected,
            "oids": len(ids), "fetched": count, "missing": len(missing),
            "file": path, "ok": count == len(ids) and not missing}


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    targets = sys.argv[1:] or ["5", "4"]      # Area first: small, proves the path

    done, failed = [], []
    for layer in targets:
        name, exp = LAYERS[layer]
        try:
            done.append(pull_layer(layer, name, exp))
        except Exception as e:
            print(f"  FAILED layer {layer}: {e}", flush=True)
            failed.append({"layer": layer, "name": name, "error": str(e)})

    with open(os.path.join(OUTDIR, "manifest.json"), "w") as fh:
        json.dump({"pulled": done, "failed": failed,
                   "source_srid": 6439, "output_srid": 4326,
                   "geometry_precision": PRECISION}, fh, indent=2)

    print("\n" + "=" * 60)
    for d in done:
        print(f"  {'OK ' if d['ok'] else 'BAD'} {d['name']}: "
              f"{d['fetched']:,} of {d['oids']:,}")
    for f in failed:
        print(f"  FAILED {f['name']}: {f['error']}")
    if failed or not all(d["ok"] for d in done):
        print("\nNOT COMPLETE - do not load.")
        sys.exit(1)
    print("\nReconciles. Safe to load.")
    print("\nAt ingest, remember:")
    print("  - carry FTYPE; exclude 558 ArtificialPath from any")
    print("    'watercourse present' predicate (synthetic centreline, not a stream)")
    print("  - three concepts, not one: water_area_adjacent,")
    print("    watercourse_proximity, waterbody_proximity")
    print("  - validate geometry ONCE at ingest, never per call")


if __name__ == "__main__":
    main()
