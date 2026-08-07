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
  * A browser HTTP identity (several FL appraiser sites 403 a non-browser User-Agent — Pinellas, Brevard);
    the contact stays in the From header for transparency.
  * HTML index pages are scraped for the current file link at probe time — rotating filenames, monthly
    GUIDs (Duval) and ASP indexes (Hillsborough) do not survive a hard-coded URL but do survive a re-scrape.
  * Never assert a vendor the schema did not show. An unreachable source is 'unreachable', not a guess.
  * Idempotent: each run appends one row per probed county; nothing is overwritten or deleted.
"""

import argparse
import io
import json
import os
import re
import sys
import zipfile
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin

try:
    import requests
except ImportError as e:  # pragma: no cover - environment guard
    sys.exit(f"missing dependency ({e}); run in the WSL pull env: pip install requests")
# psycopg2 is imported lazily (only when writing rows) so --dry-run works with just requests.

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "cama_sources.json"
# A browser identity: several FL appraiser sites (Pinellas, Brevard) 403 a non-browser User-Agent.
# The contact stays in the From header so the traffic is still attributable to us.
BROWSER_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "From": "murphy.oneal@gmail.com",
}
HTTP_TIMEOUT = 60
DATA_EXTS = (".zip", ".csv", ".txt", ".dbf", ".tab")

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
    r = requests.get(url, headers=BROWSER_HEADERS, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r


def schema_tokens_from_arcgis(url):
    """An ArcGIS REST layer: read field names from ?f=json (append if not present)."""
    sep = "&" if "?" in url else "?"
    meta = http_get(url + sep + "f=json").json()
    fields = meta.get("fields") or []
    return {str(f.get("name", "")).upper() for f in fields}, {"arcgis_layer": [f.get("name") for f in fields]}


_CANDIDATE_DELIMS = {"\t": "tab", "|": "pipe", ",": "comma", ";": "semicolon"}


def _split_header(header):
    """Identify the delimiter that best explains the header; return (columns, delimiter_name).
    Returns ([], None) when NO candidate delimiter yields a table (>= 2 fields). A fixed-width or
    single-column file is an UNPARSED file, not a 1-column table — this is the structural guard:
    we hand back columns only for a delimiter we actually identified, never a guessed whole-line token."""
    header = header.lstrip("﻿").strip()
    best_cols, best_name, best_n = [], None, 1
    for ch, name in _CANDIDATE_DELIMS.items():
        if ch not in header:
            continue
        cols = [c.strip().strip('"').upper() for c in header.split(ch) if c.strip()]
        if len(cols) > best_n:
            best_cols, best_name, best_n = cols, name, len(cols)
    return (best_cols, best_name) if best_n >= 2 else ([], None)


def schema_tokens_from_zip(content):
    """A ZIP of CSV/DBF/TXT exports: read the header of each tabular member; capture per-file columns.
    A delimited member is accepted only if a delimiter was identified (>= 2 fields); otherwise it is
    recorded as skipped (unparsed) — never guessed into a 1-column table."""
    tokens, captured, skipped = set(), {}, {}
    with zipfile.ZipFile(io.BytesIO(content)) as z:
        captured["_zip_members"] = z.namelist()  # diagnostic: reveals .mdb/.accdb/.gdb/.xlsx we don't parse
        for name in z.namelist():
            low = name.lower()
            if low.endswith((".csv", ".txt", ".tab")):
                with z.open(name) as fh:
                    header = fh.readline().decode("latin-1", "replace")
                cols, delim = _split_header(header)
                if cols:
                    tokens |= set(cols)
                    captured[name] = {"columns": cols, "delimiter": delim}
                else:
                    skipped[name] = "no delimiter identified (fixed-width or single-column)"
            elif low.endswith(".dbf"):
                cols = _dbf_columns(z.read(name))
                if cols:
                    tokens |= set(cols)
                    captured[name] = {"columns": cols, "delimiter": "dbf-header"}
                else:
                    skipped[name] = "dbf header unreadable"
            else:
                skipped[name] = "non-tabular member (not .csv/.txt/.tab/.dbf)"
    if skipped:
        captured["_skipped"] = skipped
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
    header = content.split(b"\n", 1)[0].decode("latin-1", "replace")
    cols, delim = _split_header(header)
    if not cols:
        return set(), {"_container": "text", "_delimiter": None,
                       "_note": "no delimiter identified (tab/pipe/comma/semicolon) — fixed-width or "
                                "single-column file, not parsed as a table"}
    return set(cols), {"_container": "csv", "_delimiter": delim, "columns": cols}


class _LinkExtractor(HTMLParser):
    """Collect (href, link_text) pairs from an HTML index page — stdlib only, no bs4 dependency."""
    def __init__(self):
        super().__init__()
        self.links = []
        self._cur = None
    def handle_starttag(self, tag, attrs):
        if tag == "a":
            href = dict(attrs).get("href")
            self._cur = [href, ""] if href else None
    def handle_data(self, data):
        if self._cur is not None:
            self._cur[1] += data
    def handle_endtag(self, tag):
        if tag == "a" and self._cur is not None:
            self.links.append((self._cur[0], self._cur[1].strip()))
            self._cur = None


def _looks_html(resp):
    if "html" in resp.headers.get("content-type", "").lower():
        return True
    # substring, not startswith — a robots/WAF block page (Collier) can lead with a BOM, whitespace, or a
    # <meta> refresh before <html>, and must still route to the HTML path rather than the zip parser.
    head = resp.content[:1024].lstrip().lower()
    return b"<!doctype html" in head or b"<html" in head


def resolve_index_link(page_url, html_bytes, pattern=None):
    """Scrape an HTML index page for the CURRENT data-file link. Return (picked_url_or_None, diag).
    Reads the link at probe time, so rotating filenames / monthly GUIDs / ASP index pages survive.
    A per-county `pattern` (regex, from the manifest) selects the right link when the generic heuristic
    can't — the pattern IS the human signal, so a match is trusted even if it doesn't end in a data
    extension. Without a pattern, the heuristic prefers the parcel table and archives and de-prioritises
    sales/tangible/sample/layout. `diag` always reports the anchors seen + a sample, so a miss is
    debuggable from the run (which is how Hillsborough/Polk/Miami-Dade get their real link structure)."""
    p = _LinkExtractor()
    try:
        p.feed(html_bytes.decode("latin-1", "replace"))
    except Exception:
        return None, {"anchors": 0, "considered": 0, "sample": [], "pattern": pattern, "picked": None}
    rx = re.compile(pattern, re.I) if pattern else None
    anchors = [h for h, _ in p.links if h]
    cands = []
    for href, text in p.links:
        if not href:
            continue
        absu = urljoin(page_url, href)
        base = absu.lower().split("?")[0]
        low = (href + " " + text).lower()
        if rx is not None:
            if not (rx.search(href) or rx.search(text) or rx.search(absu)):
                continue
        else:
            is_asset = "getcontentasset" in low or "download" in low  # GUID/asset links carry no extension
            if not base.endswith(DATA_EXTS) and not is_asset:
                continue
        score = 0
        if "parcel" in low: score += 5
        if any(k in low for k in ("real_estate", "real-estate", "propdata", "webdata", "cama", "property", "roll")): score += 3
        if base.endswith(".zip"): score += 2
        elif base.endswith((".csv", ".txt", ".dbf")): score += 1
        if any(k in low for k in ("sales", "tangible", "sample", "example", "readme", "layout", "aerial", "codes")): score -= 2
        cands.append((score, absu))
    cands.sort(key=lambda t: t[0], reverse=True)
    # A matched pattern is trusted at any score; the generic path still requires a positive score.
    picked = cands[0][1] if cands and (rx is not None or cands[0][0] > 0) else None
    diag = {"anchors": len(anchors), "considered": len(cands),
            "sample": [urljoin(page_url, h) for h in anchors[:10]], "pattern": pattern, "picked": picked}
    return picked, diag


def extract_schema(url, fmt_hint, _depth=0, pattern=None):
    """Return (token_set, captured_schema_dict). Dispatch on the format hint / URL shape.
    An HTML index page is scraped once (using the per-county `pattern` if given) for the current file
    link, then followed (_depth guard). `captured` always carries a '_meta' diagnostic (content-type,
    bytes, final URL; zip member list) so a zero-column outcome can report WHY the container was not
    understood — bytes arriving is not a schema. On a followed index, captured also records the picked
    link and the anchor diagnostic."""
    # A Nextcloud public share (Palm Beach) serves a preview app, not the file — it needs an
    # authenticated session / download token. Short-circuit honestly instead of hanging to timeout.
    if "clouddrive" in url.lower() or "/invitations/?share=" in url.lower():
        raise ValueError("Nextcloud public share — needs an authenticated session / download token; deferred")
    if fmt_hint == "arcgis" or "/arcgis/rest/" in url.lower() or url.lower().rstrip("/").endswith(("mapserver", "featureserver")) or "/query" in url.lower():
        toks, cap = schema_tokens_from_arcgis(url)
        cap.setdefault("_meta", {"kind": "arcgis", "final_url": url})
        return toks, cap
    resp = http_get(url)
    body = resp.content
    ctype = resp.headers.get("content-type", "")
    ctl = ctype.lower()
    meta = {"content_type": ctype, "bytes": len(body),
            "final_url": getattr(resp, "url", url), "head_hex": body[:16].hex()}
    # An HTML response is an index page (or a robots/WAF block page), never the data file itself.
    if _looks_html(resp):
        if _depth == 0:
            target, idiag = resolve_index_link(url, body, pattern)
            if not target:
                raise ValueError(f"HTML index page; no data-file link found (JS/postback or session required) "
                                 f"[content-type={ctype!r}, {len(body)} bytes, anchors={idiag['anchors']}, "
                                 f"considered={idiag['considered']}, pattern={idiag['pattern']!r}, "
                                 f"sample={idiag['sample'][:6]}]")
            toks, cap = extract_schema(target, fmt_hint, _depth=1)
            cap["_followed_link"] = target          # LOG which link was picked (Pinellas ask)
            cap["_index_diag"] = idiag
            return toks, cap
        # depth>0: the link we followed returned HTML, not a file — do NOT parse markup as columns.
        raise ValueError(f"followed link returned HTML, not a data file [content-type={ctype!r}, {len(body)} bytes]")
    try:
        if fmt_hint == "zip" or url.lower().endswith(".zip") or body[:2] == b"PK":
            toks, cap = schema_tokens_from_zip(body)
        elif fmt_hint == "csv" or url.lower().endswith((".csv", ".txt")) or "csv" in ctl or "text/plain" in ctl:
            toks, cap = schema_tokens_from_csv(body)
        elif "json" in ctl or fmt_hint == "json":
            data = json.loads(body)
            # ArcGIS-style fields, or a records array whose first object's keys are the columns
            if isinstance(data, dict) and data.get("fields"):
                cols = [f.get("name") for f in data["fields"]]
            elif isinstance(data, list) and data and isinstance(data[0], dict):
                cols = list(data[0].keys())
            else:
                cols = []
            toks, cap = {str(c).upper() for c in cols}, {"json": cols}
        else:
            # Structural guard: the container was not identified. Do NOT guess by treating bytes as a
            # header row — return no columns so the zero-guard fails closed with a diagnostic.
            toks, cap = set(), {"_container": None,
                                "_note": f"unidentified container (content-type {ctype!r}, "
                                         f"head {body[:16].hex()}) — not parsed"}
    except Exception as e:
        raise ValueError(f"{type(e).__name__}: {e} "
                         f"[content-type={ctype!r}, {len(body)} bytes, head={body[:32]!r}]") from e
    cap["_meta"] = meta
    return toks, cap


def classify(tokens):
    """Return (outcome, vendor_signature, loader_applies, matched_signals).
    A verdict REQUIRES columns. Zero columns is a broken read, never a finding — fail closed here so no
    caller can turn an empty schema into a classification (the flood-layer 'not in an SFHA, from a layer
    it never read' defect class). probe_one guards this too; this is the backstop that cannot be bypassed."""
    if not tokens:
        raise ValueError("classify() received 0 columns — an empty read is a broken-query sentinel, never a verdict")
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
        tokens, captured = extract_schema(url, entry.get("format_hint"), pattern=entry.get("link_pattern"))
    except Exception as e:
        return dict(outcome="unreachable", source_url=url, vendor_signature=None, loader_applies=None,
                    schema_captured=None, matched_signals=None, notes=f"fetch/parse failed: {e}")
    followed = (captured or {}).get("_followed_link") if isinstance(captured, dict) else None
    # FAIL CLOSED: a classification derived from zero columns is a verdict from no evidence. Bytes may have
    # arrived, but if the extractor read no schema the container was not understood — report WHY (content
    # type, size, zip member list) and return 'unreachable', NEVER a classification.
    if not tokens:
        meta = (captured or {}).get("_meta", {}) if isinstance(captured, dict) else {}
        members = (captured or {}).get("_zip_members") if isinstance(captured, dict) else None
        diag = f"content-type={meta.get('content_type')!r}, {meta.get('bytes')} bytes"
        if members is not None:
            diag += f"; zip has {len(members)} members, e.g. {members[:40]}"
        if followed:
            diag += f"; followed index link -> {followed}"
        return dict(outcome="unreachable", source_url=url, vendor_signature=None, loader_applies=None,
                    schema_captured=json.dumps(captured)[:200000] if captured else None, matched_signals=None,
                    notes=f"0 columns read — extractor did not understand the container "
                          f"(broken-query sentinel, not a finding). [{diag}]")
    outcome, sig, loader, signals = classify(tokens)
    return dict(outcome=outcome, source_url=url, vendor_signature=sig, loader_applies=loader,
                schema_captured=json.dumps(captured)[:200000], matched_signals=signals,
                notes=f"{len(tokens)} distinct columns read" + (f"; followed {followed}" if followed else ""))


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
