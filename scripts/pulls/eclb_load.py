#!/usr/bin/env python3
"""Florida ECLB (board 08) register loader - WO 862, migration 176a.

Downloads lic08el.csv (or takes --file), archives it with its sha256, DBPR posted date (Last-Modified) and our
capture time, COPYs every row verbatim (22 fields) into reg_us_fl.eclb_extract_row, then calls
reg_us_fl.eclb_ingest_extract(), which upserts on (class_code, licence_serial) and asserts the load.

Connection: env DOP_PG_DSN only. This script never holds a credential.
Exit codes: 0 loaded or unchanged, 1 anything else. A failure is never reported as success.
"""
import csv, datetime, email.utils, hashlib, io, os, sys, urllib.request
import psycopg2

URL = "https://www2.myfloridalicense.com/sto/file_download/extracts/lic08el.csv"
DIR = os.path.expanduser("~/dbpr/eclb")
NFIELDS = 22

def log(m): print(f"[{datetime.datetime.now():%Y-%m-%d %H:%M:%S}] {m}", flush=True)

def fetch():
    captured = datetime.datetime.now(datetime.timezone.utc)
    req = urllib.request.Request(URL, headers={"User-Agent": "DoP-register-loader"})
    with urllib.request.urlopen(req, timeout=120) as r:
        body = r.read(); lm = r.headers.get("Last-Modified")
    if not lm: raise SystemExit("no Last-Modified header - posted date unknown, refusing to guess")
    posted = email.utils.parsedate_to_datetime(lm)
    path = os.path.join(DIR, f"lic08el_{captured:%Y%m%dT%H%M%SZ}.csv")
    with open(path, "wb") as f: f.write(body)
    return path, body, posted, captured

def main():
    args = sys.argv[1:]
    if "--file" in args:
        path = args[args.index("--file") + 1]; body = open(path, "rb").read()
        posted = datetime.datetime.fromisoformat(args[args.index("--posted") + 1])
        captured = datetime.datetime.fromisoformat(args[args.index("--captured") + 1])
    else:
        path, body, posted, captured = fetch()
    sha = hashlib.sha256(body).hexdigest()
    rows = list(csv.reader(io.StringIO(body.decode("latin-1"))))
    if not rows: raise SystemExit("empty file - touching nothing")
    bad = [i for i, r in enumerate(rows, 1) if len(r) != NFIELDS]
    if bad: raise SystemExit(f"{len(bad)} rows without {NFIELDS} fields (first at line {bad[0]}) - touching nothing")
    if sum(1 for r in rows if r[2].strip()) != len(rows):
        raise SystemExit("licensee_name blank on some rows in the FILE - stop and look before loading")
    log(f"{path}: {len(rows)} rows, sha256 {sha[:12]}, posted {posted.isoformat()}")

    dsn = os.environ.get("DOP_PG_DSN")
    if not dsn: raise SystemExit("DOP_PG_DSN not set")
    cn = psycopg2.connect(dsn); cn.autocommit = False; c = cn.cursor()
    c.execute("set statement_timeout = 0")
    c.execute("select extract_id, ingested_at from reg_us_fl.eclb_extract where sha256 = %s", (sha,))
    hit = c.fetchone()
    if hit and hit[1] is not None:
        log(f"unchanged: identical file already ingested as extract {hit[0]}"); cn.rollback(); return 0
    c.execute("""insert into reg_us_fl.eclb_extract (source_url, file_name, sha256, bytes, posted_at, captured_at, archived_path, row_count)
                 values (%s,%s,%s,%s,%s,%s,%s,%s) returning extract_id""",
              (URL, os.path.basename(path), sha, len(body), posted, captured, path, len(rows)))
    xid = c.fetchone()[0]
    buf = io.StringIO(); w = csv.writer(buf)
    for i, r in enumerate(rows, 1): w.writerow([xid, i] + r)
    buf.seek(0)
    c.copy_expert("copy reg_us_fl.eclb_extract_row from stdin with (format csv)", buf)
    c.execute("select reg_us_fl.eclb_ingest_extract(%s)", (xid,))
    res = c.fetchone()[0]
    cn.commit()
    log(f"LOADED extract {xid}: {res}")
    return 0

if __name__ == "__main__":
    try: sys.exit(main())
    except SystemExit as e:
        if e.code not in (0, None): log(f"FAILED: {e.code}"); sys.exit(1)
        raise
    except Exception as e:
        log(f"FAILED: {type(e).__name__}: {e}"); sys.exit(1)
