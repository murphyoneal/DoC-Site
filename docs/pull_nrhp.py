#!/usr/bin/env python3
"""
Pull National Register of Historic Places from the NPS ArcGIS service.
Item 118. Currently the database holds points only - districts have no boundary,
so "is this parcel inside a historic district" cannot be answered.

TWO TRAPS ALREADY PAID FOR ON THIS SERVICE:
  1. The filter is State = 'FLORIDA' - the FULL UPPERCASE NAME, not 'FL'.
  2. Page size must cap at 250. A full batch produced a JSONDecodeError.

Layer 1 = district POLYGONS (the gap). Layer 0 = points (re-pull).

Run:  python3 pull_nrhp.py            # both, polygons first
      python3 pull_nrhp.py 1          # polygons only
      python3 pull_nrhp.py --probe    # print layer names/fields and exit
"""

import gzip, json, os, sys, time, urllib.parse, urllib.request

ROOT = ("https://mapservices.nps.gov/arcgis/rest/services/"
        "cultural_resources/nrhp_locations/MapServer")
OUTDIR = "nrhp_out"
PAGE = 250            # HARD CAP - larger batches break this service
MIN_PAGE = 50
PAUSE = 1.0
RETRIES = 5
PRECISION = 6
STATE_FIELD = "State"
STATE_VALUE = "FLORIDA"      # full name, uppercase. NOT 'FL'.

LAYERS = {"1": "district_polygons", "0": "points"}


def call(url, params, tag=""):
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


def probe():
    """Verify layer indices and the state field BEFORE pulling. The service
    may not be laid out the way the backlog note remembers."""
    meta = call(ROOT, {"f": "json"}, tag="[root]")
    print("SERVICE LAYERS:")
    for lyr in meta.get("layers", []):
        print(f"  {lyr['id']:>3}  {lyr['name']}  ({lyr.get('geometryType')})")
    for lid in ("0", "1"):
        try:
            lm = call(f"{ROOT}/{lid}", {"f": "json"}, tag=f"[layer {lid}]")
            names = [f["name"] for f in lm.get("fields", [])]
            print(f"\nLAYER {lid}: {lm.get('name')}  "
                  f"geometry={lm.get('geometryType')}  "
                  f"maxRecordCount={lm.get('maxRecordCount')}")
            print(f"  fields: {names}")
            state_like = [n for n in names if 'state' in n.lower()]
            print(f"  state-ish fields: {state_like}")
        except Exception as e:
            print(f"  LAYER {lid}: {e}")


def pull(layer, name):
    print(f"\n=== layer {layer} ({name})", flush=True)
    url = f"{ROOT}/{layer}/query"
    where = f"{STATE_FIELD} = '{STATE_VALUE}'"

    n = call(url, {"where": where, "returnCountOnly": "true",
                   "f": "json"}, tag="[count]").get("count")
    print(f"  count: {n:,}", flush=True)
    if not n:
        raise RuntimeError(
            f"ABORT: zero rows for {where}. Empty is a sentinel, not a result. "
            f"Run --probe and check the state field name and value.")

    ids = call(url, {"where": where, "returnIdsOnly": "true",
                     "f": "json"}, tag="[oids]").get("objectIds") or []
    print(f"  OIDs: {len(ids):,}", flush=True)
    if len(ids) != n:
        print(f"  !! OID count {len(ids):,} != count {n:,}", flush=True)

    idset, seen, count = set(ids), set(), 0
    offset, page = 0, PAGE
    path = os.path.join(OUTDIR, f"nrhp_{name}.geojsonl.gz")

    with gzip.open(path, "wt") as out:
        while offset < len(ids):
            try:
                obj = call(url, {
                    "where": where, "outFields": "*",
                    "returnGeometry": "true", "outSR": "4326",
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
                raise RuntimeError(f"ABORT: empty page at offset {offset} "
                                   f"with {len(ids)-offset:,} still expected.")
            for f in got:
                oid = f.get("id") or (f.get("properties") or {}).get("OBJECTID")
                if oid is not None:
                    seen.add(oid)
                out.write(json.dumps(f) + "\n")
            count += len(got)
            offset += len(got)
            print(f"  {count:,}/{len(ids):,}   ", end="\r", flush=True)
            time.sleep(PAUSE)

    print(f"  fetched: {count:,}                    ", flush=True)
    missing = idset - seen
    if missing:
        print(f"  !! {len(missing):,} OIDs never returned", flush=True)
    if count and count % PAGE == 0:
        print(f"  !! exact multiple of {PAGE} - TRUNCATION SUSPECT", flush=True)
    print(f"  wrote {path} ({os.path.getsize(path)/1e6:.1f} MB gz)", flush=True)

    return {"layer": layer, "name": name, "count": n, "oids": len(ids),
            "fetched": count, "missing": len(missing), "file": path,
            "ok": count == len(ids) and not missing}


def main():
    if "--probe" in sys.argv:
        probe(); return
    os.makedirs(OUTDIR, exist_ok=True)
    targets = [a for a in sys.argv[1:] if a in LAYERS] or ["1", "0"]

    done, failed = [], []
    for lid in targets:
        try:
            done.append(pull(lid, LAYERS[lid]))
        except Exception as e:
            print(f"  FAILED layer {lid}: {e}", flush=True)
            failed.append({"layer": lid, "error": str(e)})

    with open(os.path.join(OUTDIR, "manifest.json"), "w") as fh:
        json.dump({"pulled": done, "failed": failed,
                   "filter": f"{STATE_FIELD} = '{STATE_VALUE}'",
                   "page_size": PAGE}, fh, indent=2)

    print("\n" + "=" * 60)
    for d in done:
        print(f"  {'OK ' if d['ok'] else 'BAD'} {d['name']}: "
              f"{d['fetched']:,} of {d['oids']:,}")
    for f in failed:
        print(f"  FAILED layer {f['layer']}: {f['error']}")
    if failed or not all(d["ok"] for d in done):
        print("\nNOT COMPLETE - do not load.")
        sys.exit(1)
    print("\nReconciles. Safe to load.")
    print("\nAt ingest: NPS states transcription errors permeate the boundary")
    print("data. District membership is AN INDICATION REQUIRING CONFIRMATION,")
    print("never a determination. That caveat ships with every rendered hit.")


if __name__ == "__main__":
    main()
