#!/usr/bin/env python3
"""
clerk_platform_probe.py — fingerprint which VENDOR PLATFORM each Florida county clerk runs, for tax-deed
sales and (paired) meeting-agenda publishing. Writes durable, diffable rows to clerk_platform_probe.

WHY
  67 clerks are only tractable if they share platforms. If a dozen counties run RealAuction
  (<county>.realtaxdeed.com), that is ONE integration, not twelve — the same leverage the CAMA vendor probe
  and the Legistar/agenda work found. This does not scrape sales; it identifies the SYSTEM so acquisition can
  be written once per vendor. tax_deed and agenda are the same institutions asked two questions (--kind).

TECHNIQUE (identical to cama_schema_probe / fdep_hub_enumerate)
  1. For each county, build candidate URLs from vendor templates using the county's slug.
  2. Fetch each; FINGERPRINT the vendor from the response (final URL, <title>, Server/Set-Cookie headers,
     body markers) — recording the VERBATIM marker that identified it as evidence. Never guess a vendor.
  3. Upsert to clerk_platform_probe (co_no, kind, candidate_url, vendor_system, http_status, evidence).
     Reached-but-unrecognised => vendor 'unidentified' (a human look), NOT a fabricated vendor. Unreachable =>
     http_status 0/null. A NULL vendor with no status = not yet probed.
  4. Summary prints the per-vendor county count — the shared-platform leverage, at a glance.

DISCIPLINE
  A candidate URL resolving is NOT proof it is that county's official platform — a vendor subdomain can 404,
  redirect to a marketing page, or park. The evidence column records what actually identified it; is_primary
  (the resolved platform per county) is set by REVIEW, not by this script. Same "a name match is not
  attribution" rule as the county-source work.

USAGE (run from the WSL pull env — Git Bash cannot reach these hosts)
    export DATABASE_URL='postgresql://…:5432/postgres'
    python3 scripts/pulls/clerk_platform_probe.py --dry-run                    # print candidate URLs, no fetch/write
    python3 scripts/pulls/clerk_platform_probe.py --kind tax_deed              # probe + record tax-deed platforms
    python3 scripts/pulls/clerk_platform_probe.py --kind agenda                # the paired agenda-platform census
    python3 scripts/pulls/clerk_platform_probe.py --kind both --counties Volusia,Orange
"""

import argparse
import os
import re
import sys

# requests + psycopg2 are imported LAZILY (inside probe()/main) so --dry-run enumerates candidate URLs with
# neither installed — the network fetch and DB write are the only things that need them.

UA = "DoP-clerk-platform-probe/1.0 (property-intelligence; contact: murphy.oneal@gmail.com)"
HTTP_TIMEOUT = 25

# 67 Florida counties — the offline fallback; when a DB is available the live county_registry is used instead
# (so co_no comes from the registry, never a hardcoded map — the never-assert-co_no rule).
FL_COUNTIES = [
    "Alachua","Baker","Bay","Bradford","Brevard","Broward","Calhoun","Charlotte","Citrus","Clay","Collier",
    "Columbia","DeSoto","Dixie","Duval","Escambia","Flagler","Franklin","Gadsden","Gilchrist","Glades","Gulf",
    "Hamilton","Hardee","Hendry","Hernando","Highlands","Hillsborough","Holmes","Indian River","Jackson",
    "Jefferson","Lafayette","Lake","Lee","Leon","Levy","Liberty","Madison","Manatee","Marion","Martin",
    "Miami-Dade","Monroe","Nassau","Okaloosa","Okeechobee","Orange","Osceola","Palm Beach","Pasco","Pinellas",
    "Polk","Putnam","St. Johns","St. Lucie","Santa Rosa","Sarasota","Seminole","Sumter","Suwannee","Taylor",
    "Union","Volusia","Wakulla","Walton","Washington",
]


def slug(county):
    """Vendor-subdomain slug: lowercase, drop punctuation/spaces (Miami-Dade->miamidade, St. Johns->stjohns)."""
    return re.sub(r"[^a-z0-9]", "", county.lower())


# Candidate URL templates per kind. {s} = slug. These are the SHAPES the vendors use; a candidate resolving is
# not proof (see DISCIPLINE) — the fingerprint + review decide. Order = rough FL market share, most likely first.
TEMPLATES = {
    "tax_deed": [
        ("RealAuction",  "https://{s}.realtaxdeed.com"),
        ("RealAuction",  "https://{s}.realforeclose.com"),
        ("GrantStreet",  "https://{s}.realtdm.com"),
        ("GovEase",      "https://www.govease.com/auctions/{s}-fl"),
    ],
    "agenda": [
        ("Legistar",     "https://{s}.legistar.com"),
        ("Granicus",     "https://{s}.granicus.com"),
        ("PrimeGov",     "https://{s}.primegov.com"),
        ("CivicClerk",   "https://{s}.api.civicclerk.com"),
        ("NovusAGENDA",  "https://{s}.novusagenda.com/agendapublic"),
    ],
}

# Vendor fingerprints — regex applied to (final_url + title + server/set-cookie headers + body head). The FIRST
# match wins and its matched text is stored VERBATIM as evidence. A reached page matching none => 'unidentified'.
FINGERPRINTS = [
    (re.compile(r"realauction|realtaxdeed|realforeclose", re.I), "RealAuction"),
    (re.compile(r"grant\s*street|realtdm|bidexpress", re.I),     "GrantStreet"),
    (re.compile(r"govease", re.I),                                "GovEase"),
    (re.compile(r"legistar", re.I),                               "Legistar"),
    (re.compile(r"granicus|mediamanager", re.I),                  "Granicus"),
    (re.compile(r"primegov", re.I),                               "PrimeGov"),
    (re.compile(r"civicclerk|civicplus", re.I),                   "CivicPlus/CivicClerk"),
    (re.compile(r"novusagenda", re.I),                            "NovusAGENDA"),
]


def fingerprint(resp):
    """Return (vendor_system, evidence_marker) from a response, or ('unidentified', None) if reached but unknown."""
    title = ""
    m = re.search(r"<title[^>]*>(.*?)</title>", resp.text[:20000], re.I | re.S)
    if m:
        title = m.group(1).strip()
    hay = " | ".join([
        resp.url or "",
        title,
        resp.headers.get("Server", ""),
        resp.headers.get("Set-Cookie", ""),
        resp.headers.get("X-Powered-By", ""),
        resp.text[:20000],
    ])
    for rx, vendor in FINGERPRINTS:
        mm = rx.search(hay)
        if mm:
            return vendor, mm.group(0)
    return "unidentified", None


def probe(url):
    """GET a candidate. Return (http_status, vendor_system, evidence). Unreachable => (0, None, reason)."""
    try:
        import requests
    except ImportError:
        sys.exit("requests not installed; run in the WSL pull env: pip install requests")
    try:
        r = requests.get(url, headers={"User-Agent": UA}, timeout=HTTP_TIMEOUT, allow_redirects=True)
    except requests.RequestException as e:
        return 0, None, f"unreachable: {type(e).__name__}"
    if r.status_code >= 400:
        return r.status_code, None, None
    vendor, evidence = fingerprint(r)
    return r.status_code, vendor, evidence


def load_counties(conn, subset):
    """Prefer the live county_registry (co_no from the registry, never a hardcoded map); fall back to FL_COUNTIES."""
    rows = []
    if conn is not None:
        with conn.cursor() as cur:
            cur.execute("SELECT dor_county_no::numeric, county_name FROM county_registry WHERE state_code='FL' ORDER BY county_name")
            rows = [(co, nm) for co, nm in cur.fetchall()]
    if not rows:
        rows = [(None, nm) for nm in FL_COUNTIES]
    if subset:
        want = {s.strip().lower() for s in subset.split(",")}
        rows = [(co, nm) for co, nm in rows if nm.lower() in want]
    return rows


def main():
    ap = argparse.ArgumentParser(description="Fingerprint FL county clerk tax-deed / agenda platforms; record durably.")
    ap.add_argument("--kind", choices=["tax_deed", "agenda", "both"], default="tax_deed")
    ap.add_argument("--counties", help="comma-separated county-name subset (default all 67)")
    ap.add_argument("--dry-run", action="store_true", help="print candidate URLs; no fetch, no write")
    args = ap.parse_args()
    kinds = ["tax_deed", "agenda"] if args.kind == "both" else [args.kind]

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

    # counties: try the registry even in dry-run if a DB happens to be configured; else the offline list
    dry_conn = None
    if args.dry_run and (os.environ.get("DATABASE_URL") or os.environ.get("SUPABASE_DB_URL")):
        try:
            import psycopg2
            dry_conn = psycopg2.connect(os.environ.get("DATABASE_URL") or os.environ.get("SUPABASE_DB_URL"))
        except Exception:
            dry_conn = None
    counties = load_counties(conn or dry_conn, args.counties)

    vendor_counts = {}   # (kind, vendor) -> set of counties (the shared-platform leverage)
    n_probed = n_hit = 0
    for kind in kinds:
        for co_no, county in counties:
            s = slug(county)
            for _hint, tmpl in TEMPLATES[kind]:
                url = tmpl.format(s=s)
                if args.dry_run:
                    print(f"[{kind:8s}] {county:15s} {url}")
                    continue
                status, vendor, evidence = probe(url)
                n_probed += 1
                if vendor and vendor != "unidentified":
                    n_hit += 1
                    vendor_counts.setdefault((kind, vendor), set()).add(county)
                print(f"[{kind:8s}] {county:15s} {str(status):3s} {vendor or '-':22s} {url}"
                      + (f"  «{evidence[:40]}»" if evidence else ""))
                with conn.cursor() as cur:
                    cur.execute(
                        """INSERT INTO public.clerk_platform_probe
                             (co_no, county_name, kind, candidate_url, vendor_system, http_status, evidence, probed_at, probed_by)
                           VALUES (%s,%s,%s,%s,%s,%s,%s, now(), 'clerk_platform_probe.py')
                           ON CONFLICT (co_no, kind, candidate_url) DO UPDATE
                             SET vendor_system=EXCLUDED.vendor_system, http_status=EXCLUDED.http_status,
                                 evidence=EXCLUDED.evidence, probed_at=EXCLUDED.probed_at""",
                        (co_no, county, kind, url, vendor, status, evidence))
    if conn:
        conn.commit()
        conn.close()

    if args.dry_run:
        print(f"\n(dry-run) {len(counties)} counties × templates for kind(s) {kinds} — nothing fetched or written.")
        return
    print(f"\nprobed {n_probed} candidates, {n_hit} identified. Shared-platform leverage:")
    for (kind, vendor), cos in sorted(vendor_counts.items(), key=lambda kv: -len(kv[1])):
        print(f"  {kind:8s} {vendor:22s} {len(cos):2d} counties  ({', '.join(sorted(cos))[:80]})")
    print("Rows in clerk_platform_probe. Set is_primary per county+kind by REVIEW — a resolving URL is not "
          "proof it is the official platform.")


if __name__ == "__main__":
    main()
