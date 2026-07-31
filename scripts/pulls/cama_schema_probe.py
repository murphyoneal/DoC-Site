#!/usr/bin/env python3
"""
cama_schema_probe.py — classify each Florida county's CAMA export by its SCHEMA.

WHY THIS EXISTS
  Only Volusia (2.86% of Florida's 10.7M parcels) has the RICH product today, because only Volusia's
  relational CAMA export (Tyler iasWorld) is loaded. The single largest lever on statewide depth is
  loading the relational export for the populous counties — but the COST of each county is entirely the
  VENDOR, because the vendor is the schema. iasWorld-shaped counties reuse the Volusia loader near-free;
  other vendors need per-vendor work; roll-only counties can't get the rich product at all.

  We do NOT guess the vendor from memory (contracts change; that is the fabrication class). The AUTHORITATIVE
  signal is the EXPORT SCHEMA at pull time. This script fetches each county's candidate CAMA export, reads
  the schema, and classifies it into exactly three outcomes:

    iasworld     — PARID / OWNSEQ / PCTOWN / MICODE / INSTRTYP present. The Volusia loader applies near-free.
    other_vendor — a relational export, but not the iasWorld signature. Schema captured so the per-vendor
                   work can be scoped.
    roll_only    — no relational export published; only the flat DOR NAL roll. Thin ceiling. This is a
                   source/disclose defect (the county caps at the thin product), NOT a probe failure.

  Results are written to the public.cama_vendor_probe REGISTRY (append-only; latest row per county is
  current). The lesson from the web-search probe that sat unread for five turns: durable rows, not a
  console log.

USAGE (run from the WSL pull environment, which has network + DB reach — Git Bash cannot reach it)
    export DATABASE_URL='postgresql://...:5432/postgres'      # Supabase session (not the pooler)
    python3 scripts/pulls/cama_schema_probe.py --all          # probe every county with a candidate URL
    python3 scripts/pulls/cama_schema_probe.py --county broward
    python3 scripts/pulls/cama_schema_probe.py --all --dry-run  # classify + print, do NOT write rows

  Candidate export URLs live in scripts/pulls/cama_sources.json (a manifest you populate from research —
  the appraiser's public data-download page). A county with no candidate URL is left 'pending', not failed.

CONTRACT
  * One HTTP identity, with a contact User-Agent (some FL sources 403 an anonymous agent — the BLS lesson).
  * Never assert a vendor the schema did not show. An unreachable source is 'unreachable', not a guess.
  * Idempotent: each run appends one row per probed county; nothing is overwritten or deleted.
"""

import argparse
import io
import json
import os
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

try:
    import requests
except ImportError as e:  # pragma: no cover - environment guard
    sys.exit(f"missing dependency ({e}); run in the WSL pull env: pip install requests")
# psycopg2 is imported lazily (only when writing rows) so --dry-run works with just requests.

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "cama_sources.json"
UA = "DoP-CAMA-schema-probe/1.0 (property-intelligence; contact: murphy.oneal@gmail.com)"
HTTP_TIMEOUT = 60

# The iasWorld fingerprint — column tokens that appear in Volusia's relational export and identify the
# Tyler iasWorld schema. >= 3 present => iasworld (the Volusia loader transfers).
IASWORLD_TOKENS = {"PARID", "OWNSEQ", "PCTOWN", "MICODE", "INSTRTYP", "OWNTYPE1", "APRTOT", "STEB_DESC"}
IASWORLD_MIN_HITS = 3
# The flat DOR NAL roll — uniform across all 67 counties. If the export is ONLY this shape (no separate
# relational owner/sales/permit tables), the county publishes roll-only and caps at the thin product.
NAL_TOKENS = {"PARCEL_ID", "DOR_UC", "JV", "LND_VAL", "OWN_NAME", "SALE_PRC1", "ASMNT_YR", "SPC_FEA_VAL"}
NAL_MIN_HITS = 4


def load_manifest():
    if not MANIFEST.exists():
        sys.exit(f"manifest not found: {MANIFEST}")
    return json.loads(MANIFEST.read_text())


def http_get(url):
    r = requests.get(url, headers={"User-Agent": UA}, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r


def schema_tokens_from_arcgis(url):
    """An ArcGIS REST layer: read field names from ?f=json (append if not present)."""
    sep = "&" if "?" in url else "?"
    meta = http_get(url + sep + "f=json").json()
    fields = meta.get("fields") or []
    return {str(f.get("name", "")).upper() for f in fields}, {"arcgis_layer": [f.get("name") for f in fields]}


def schema_tokens_from_zip(content):
    """A ZIP of CSV/DBF/TXT exports: read the header row of each tabular member; capture per-file columns."""
    tokens, captured = set(), {}
    with zipfile.ZipFile(io.BytesIO(content)) as z:
        for name in z.namelist():
            low = name.lower()
            if low.endswith((".csv", ".txt", ".tab")):
                with z.open(name) as fh:
                    header = fh.readline().decode("latin-1", "replace").strip()
                delim = "\t" if "\t" in header else ("|" if "|" in header else ",")
                cols = [c.strip().strip('"').upper() for c in header.split(delim) if c.strip()]
                tokens |= set(cols)
                captured[name] = cols
            elif low.endswith(".dbf"):
                cols = _dbf_columns(z.read(name))
                tokens |= set(cols)
                captured[name] = cols
    return tokens, captured


def _dbf_columns(data):
    """Read DBF field names from the header without a DBF library (field descriptors are 32 bytes each)."""
    cols = []
    try:
        n = 0
        pos = 32
        while pos + 32 <= len(data) and data[pos] != 0x0D:  # 0x0D terminates the field descriptor array
            name = data[pos:pos + 11].split(b"\x00")[0].decode("latin-1", "replace").strip().upper()
            if name:
                cols.append(name)
            pos += 32
            n += 1
            if n > 512:
                break
    except Exception:
        pass
    return cols


def schema_tokens_from_csv(content):
    header = content.split(b"\n", 1)[0].decode("latin-1", "replace").strip()
    delim = "\t" if "\t" in header else ("|" if "|" in header else ",")
    cols = [c.strip().strip('"').upper() for c in header.split(delim) if c.strip()]
    return set(cols), {"csv": cols}


def extract_schema(url, fmt_hint):
    """Return (token_set, captured_schema_dict). Dispatch on the format hint / URL shape."""
    if fmt_hint == "arcgis" or "/arcgis/rest/" in url.lower() or url.lower().rstrip("/").endswith(("mapserver", "featureserver")) or "/query" in url.lower():
        return schema_tokens_from_arcgis(url)
    resp = http_get(url)
    body = resp.content
    ctype = resp.headers.get("content-type", "").lower()
    if fmt_hint == "zip" or url.lower().endswith(".zip") or body[:2] == b"PK":
        return schema_tokens_from_zip(body)
    if fmt_hint == "csv" or url.lower().endswith((".csv", ".txt")) or "csv" in ctype or "text/plain" in ctype:
        return schema_tokens_from_csv(body)
    if "json" in ctype or fmt_hint == "json":
        data = json.loads(body)
        # ArcGIS-style fields, or a records array whose first object's keys are the columns
        if isinstance(data, dict) and data.get("fields"):
            cols = [f.get("name") for f in data["fields"]]
        elif isinstance(data, list) and data and isinstance(data[0], dict):
            cols = list(data[0].keys())
        else:
            cols = []
        return {str(c).upper() for c in cols}, {"json": cols}
    # last resort: treat as a header row
    return schema_tokens_from_csv(body)


def classify(tokens):
    """Return (outcome, vendor_signature, loader_applies, matched_signals)."""
    ias_hits = sorted(tokens & IASWORLD_TOKENS)
    if len(ias_hits) >= IASWORLD_MIN_HITS:
        return ("iasworld", "iasWorld (PARID/OWNSEQ/PCTOWN/MICODE/INSTRTYP)", True, ",".join(ias_hits))
    nal_hits = sorted(tokens & NAL_TOKENS)
    # roll-only: it is the DOR NAL shape and shows no sign of a separate relational vendor schema
    if len(nal_hits) >= NAL_MIN_HITS and len(ias_hits) == 0:
        return ("roll_only", "DOR NAL flat roll (no relational export published)", False, ",".join(nal_hits))
    # something relational, but not iasWorld — capture it for per-vendor scoping
    return ("other_vendor", "relational export, non-iasWorld schema", False, ",".join(ias_hits) or "none")


def probe_one(entry):
    url = (entry.get("candidate_url") or "").strip()
    if not url:
        return dict(outcome="pending", source_url=None, vendor_signature=None, loader_applies=None,
                    schema_captured=None, matched_signals=None, notes="no candidate export URL in manifest")
    try:
        tokens, captured = extract_schema(url, entry.get("format_hint"))
    except Exception as e:
        return dict(outcome="unreachable", source_url=url, vendor_signature=None, loader_applies=None,
                    schema_captured=None, matched_signals=None, notes=f"fetch/parse failed: {e}")
    outcome, sig, loader, signals = classify(tokens)
    return dict(outcome=outcome, source_url=url, vendor_signature=sig, loader_applies=loader,
                schema_captured=json.dumps(captured)[:200000], matched_signals=signals,
                notes=f"{len(tokens)} distinct columns read")


def write_result(conn, entry, result):
    with conn.cursor() as cur:
        cur.execute(
            """INSERT INTO public.cama_vendor_probe
                 (co_no, county_name, parcel_count, pct_of_state, source_url, outcome,
                  vendor_signature, loader_applies, schema_captured, matched_signals, notes)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s::jsonb,%s,%s)""",
            (entry["co_no"], entry.get("county_name"), entry.get("parcel_count"), entry.get("pct_of_state"),
             result["source_url"], result["outcome"], result["vendor_signature"], result["loader_applies"],
             result["schema_captured"], result["matched_signals"], result["notes"]),
        )
    conn.commit()


def main():
    ap = argparse.ArgumentParser(description="Classify each county's CAMA export schema (iasworld/other_vendor/roll_only).")
    ap.add_argument("--county", help="county name or co_no to probe")
    ap.add_argument("--all", action="store_true", help="probe every manifest entry that has a candidate URL")
    ap.add_argument("--limit", type=int, default=0, help="cap the number probed (0 = no cap)")
    ap.add_argument("--dry-run", action="store_true", help="classify and print; do NOT write registry rows")
    args = ap.parse_args()

    manifest = load_manifest()["counties"]
    if args.county:
        key = args.county.strip().lower()
        manifest = [e for e in manifest if key in (str(e.get("county_name", "")).lower(), str(e.get("co_no")))]
    elif not args.all:
        ap.error("specify --county NAME/co_no or --all")
    manifest = [e for e in manifest if (e.get("candidate_url") or "").strip()]  # only entries with a URL
    if args.limit:
        manifest = manifest[: args.limit]
    if not manifest:
        print("no manifest entries with a candidate_url — populate scripts/pulls/cama_sources.json first.")
        return

    conn = None
    if not args.dry_run:
        dsn = os.environ.get("DATABASE_URL") or os.environ.get("SUPABASE_DB_URL")
        if not dsn:
            sys.exit("set DATABASE_URL (Supabase session connection) or use --dry-run")
        try:
            import psycopg2
        except ImportError:
            sys.exit("psycopg2 not installed; run in the WSL pull env: pip install psycopg2-binary")
        conn = psycopg2.connect(dsn)

    counts = {}
    for entry in manifest:
        result = probe_one(entry)
        counts[result["outcome"]] = counts.get(result["outcome"], 0) + 1
        stamp = datetime.now(timezone.utc).strftime("%H:%M:%S")
        print(f"[{stamp}] {entry.get('county_name','?'):14s} co_no={entry['co_no']:>3} "
              f"-> {result['outcome']:12s} {result['vendor_signature'] or ''}  ({result['notes']})")
        if conn:
            write_result(conn, entry, result)
    if conn:
        conn.close()
    print("\nsummary:", ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    print("results written to public.cama_vendor_probe (latest row per county is current)."
          if not args.dry_run else "\n(dry-run — no rows written)")


if __name__ == "__main__":
    main()
