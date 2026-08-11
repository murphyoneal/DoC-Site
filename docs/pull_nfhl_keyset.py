#!/usr/bin/env python3
"""
Re-fetch the two NFHL counties that failed under resultOffset paging.

WHY THIS EXISTS
  Polk failed at 15,875/21,220 and Brevard at 17,625/23,480 - both at ~75%,
  both exhausting retries down to page 100. Sarasota completed 54,526 at far
  deeper offsets, so it is NOT depth alone. resultOffset makes the server
  compute and discard every preceding row, so a heavy region late in the
  ordering compounds; keyset seeks instead.

  Keyset: WHERE DFIRM_ID LIKE '<fips>%' AND OBJECTID > <last>
  ordered by OBJECTID. Cost is flat regardless of position.

ALSO: writes each page to disk as it goes. The previous script held everything
in memory and wrote at the end, so a failure at 75% lost 100% of the work.

Run:  python3 pull_nfhl_keyset.py            # both
      python3 pull_nfhl_keyset.py 12105      # one
"""

import gzip, json, os, sys, time, urllib.parse, urllib.request

BASE = "https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer/28/query"
OUTDIR = "nfhl_out"
PAGE = 250
MIN_PAGE = 25
PAUSE = 1.0
RETRIES = 6
PRECISION = 6

FIELDS = ("OBJECTID,FLD_AR_ID,FLD_ZONE,ZONE_SUBTY,STATIC_BFE,DEPTH,"
          "V_DATUM,LEN_UNIT,DUAL_ZONE,SOURCE_CIT,DFIRM_ID")

EXPECTED = {"12105": ("Polk", 21220), "12009": ("Brevard", 23480)}


def fetch(params, tag=""):
    data = urllib.parse.urlencode(params).encode()
    last = None
    for attempt in range(1, RETRIES + 1):
        try:
            req = urllib.request.Request(BASE, data=data,
                                         headers={"User-Agent": "DoP-pull/3.0"})
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
        wait = min(2 ** attempt, 45)
        print(f"      retry {attempt}/{RETRIES} {tag} after {last} "
              f"- sleep {wait}s", flush=True)
        time.sleep(wait)
    raise RuntimeError(f"failed after {RETRIES}: {last}")


def pull(fips, name, expected):
    print(f"\n=== {name} ({fips}) - expecting {expected:,}  [keyset]", flush=True)

    ids = fetch({"where": f"DFIRM_ID LIKE '{fips}%'",
                 "returnIdsOnly": "true", "f": "json"},
                tag="[oids]").get("objectIds") or []
    if not ids:
        raise RuntimeError("ABORT: zero OIDs. Empty is a sentinel.")
    ids.sort()
    print(f"  OIDs: {len(ids):,}  (min {ids[0]}, max {ids[-1]})", flush=True)

    idset, seen, count = set(ids), set(), 0
    last_oid = ids[0] - 1
    page = PAGE
    stalls = 0
    path = os.path.join(OUTDIR, f"nfhl_{fips}_{name.lower()}.geojsonl.gz")

    # Line-delimited and written as we go: a failure at 75% keeps the 75%.
    with gzip.open(path, "wt") as out:
        while len(seen) < len(ids):
            try:
                obj = fetch({
                    "where": (f"DFIRM_ID LIKE '{fips}%' "
                              f"AND OBJECTID > {last_oid}"),
                    "outFields": FIELDS,
                    "returnGeometry": "true",
                    "outSR": "4326",
                    "geometryPrecision": str(PRECISION),
                    "orderByFields": "OBJECTID",
                    "resultRecordCount": str(page),
                    "f": "geojson",
                }, tag=f"[{count:,}/{len(ids):,} oid>{last_oid}]")
            except RuntimeError:
                if page > MIN_PAGE:
                    page = max(MIN_PAGE, page // 2)
                    print(f"      halving page to {page}", flush=True)
                    continue
                # At the floor: step over one obstinate record and record it.
                nxt = [i for i in ids if i > last_oid]
                if not nxt:
                    break
                print(f"      SKIPPING OID {nxt[0]} - unservable at page "
                      f"{MIN_PAGE}. Recorded as missing.", flush=True)
                last_oid = nxt[0]
                stalls += 1
                if stalls > 50:
                    raise RuntimeError("too many unservable records - stopping")
                page = PAGE
                continue

            got = obj.get("features") or []
            if not got:
                print("      empty page with OIDs outstanding - stopping",
                      flush=True)
                break

            for f in got:
                oid = f.get("id") or (f.get("properties") or {}).get("OBJECTID")
                if oid is not None:
                    seen.add(oid)
                    last_oid = max(last_oid, oid)
                out.write(json.dumps(f) + "\n")
            count += len(got)
            if page < PAGE and len(got) == page:
                page = min(PAGE, page * 2)   # recover after a rough patch
            print(f"  {count:,}/{len(ids):,}   ", end="\r", flush=True)
            time.sleep(PAUSE)

    missing = sorted(idset - seen)
    print(f"  fetched: {count:,}                          ", flush=True)
    if missing:
        print(f"  !! {len(missing):,} OIDs never returned: "
              f"{missing[:10]}{' ...' if len(missing) > 10 else ''}", flush=True)
    print(f"  wrote {path} ({os.path.getsize(path)/1e6:.1f} MB gz)", flush=True)

    return {"fips": fips, "county": name, "expected": expected,
            "oids": len(ids), "fetched": count, "missing": missing,
            "skipped": stalls, "file": path,
            "ok": count == len(ids) and not missing}


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    targets = sys.argv[1:] or list(EXPECTED)
    out = []
    for fips in targets:
        name, exp = EXPECTED[fips]
        try:
            out.append(pull(fips, name, exp))
        except Exception as e:
            print(f"  FAILED {name}: {e}", flush=True)
            out.append({"fips": fips, "county": name, "error": str(e),
                        "ok": False})

    with open(os.path.join(OUTDIR, "manifest_keyset.json"), "w") as fh:
        json.dump(out, fh, indent=2)

    print("\n" + "=" * 60)
    for d in out:
        if d.get("ok"):
            print(f"  OK  {d['county']}: {d['fetched']:,}/{d['oids']:,}")
        else:
            print(f"  BAD {d['county']}: {d.get('error') or ''} "
                  f"{d.get('fetched', 0):,} fetched, "
                  f"{len(d.get('missing', [])):,} missing")
    if not all(d.get("ok") for d in out):
        print("\nNOT COMPLETE.")
        sys.exit(1)
    print("\nBoth reconcile.")


if __name__ == "__main__":
    main()
