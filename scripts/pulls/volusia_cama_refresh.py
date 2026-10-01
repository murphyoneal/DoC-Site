#!/usr/bin/env python3
"""Refresh the 18 volusia_cama_* tables from an ARCHIVED weekly capture (ruling 889 O2), through the collapse guard.

  --zip   ~/cama_snapshots/CAMA_YYYYMMDD.zip   (must have a row in volusia_cama_snapshot_log with the same sha256)
  --dry-run   export + count + compare columns; touch nothing in the database except reads
  --threshold 15

Per table: export (mdb-export) -> load into public."<table>_stg" -> decide against the LIVE row count:
  UNAVAILABLE (export failed) / EMPTY_AT_SOURCE (0 rows) / SCHEMA_CHANGED (columns differ) / QUARANTINED (shrank past the
  threshold) -> live untouched, staging kept or dropped and the reason printed;
  OK / FLAG_GROWTH -> in ONE transaction: TRUNCATE live; INSERT INTO live SELECT * FROM stg. Grants, RLS, indexes,
  comments and every by-name function reference survive, and readers never see an empty table.
Exit 1 if any table did not load. Connection: env DOP_PG_DSN only.
"""
import argparse, csv, datetime, hashlib, io, os, subprocess, sys, zipfile
import psycopg2
csv.field_size_limit(10**9)

def log(m): print(f"[{datetime.datetime.now():%H:%M:%S}] {m}", flush=True)

def decide(old, new, ok, threshold, cols_match):
    if not ok: return "UNAVAILABLE"
    if not new: return "EMPTY_AT_SOURCE"
    if not cols_match: return "SCHEMA_CHANGED"
    if old and new < old * (1 - threshold / 100.0): return "QUARANTINED"
    if old and new > old * (1 + threshold / 100.0): return "FLAG_GROWTH"
    return "OK"

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--zip", required=True); ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--threshold", type=float, default=15.0); a = ap.parse_args()
    zp = os.path.expanduser(a.zip)
    sha = hashlib.sha256(open(zp, "rb").read()).hexdigest()
    cn = psycopg2.connect(os.environ["DOP_PG_DSN"]); cn.autocommit = True; c = cn.cursor(); c.execute("set statement_timeout = 0")
    c.execute("select data_current_as_of, capture_date from volusia_cama_snapshot_log where sha256 = %s", (sha,))
    hit = c.fetchone()
    if not hit: log(f"ABORT: {zp} sha256 {sha[:12]} is not in volusia_cama_snapshot_log"); return 1
    as_of, captured = hit; log(f"{zp}: sha256 {sha[:12]}, county data as of {as_of}, captured {captured}")

    work = os.path.expanduser(f"~/cama_refresh/{as_of:%Y%m%d}"); os.makedirs(work, exist_ok=True)
    with zipfile.ZipFile(zp) as z:
        accdb = [n for n in z.namelist() if n.lower().endswith(".accdb")]
        if len(accdb) != 1: log(f"ABORT: expected one .accdb in the zip, found {accdb}"); return 1
        z.extract(accdb[0], work); db = os.path.join(work, accdb[0])
    tables = subprocess.run(["mdb-tables", "-1", db], capture_output=True, text=True, check=True).stdout.split()
    log(f"{len(tables)} tables in the capture")

    results = []
    for src in sorted(tables):
        table = "volusia_cama_" + src.replace("VCPA_CAMA_", "").lower(); stg = table + "_stg"
        csvfn = os.path.join(work, src + ".csv")
        ok = subprocess.run(["mdb-export", db, src], stdout=open(csvfn, "w"), text=True).returncode == 0
        rows, header = [], []
        if ok:
            with open(csvfn, newline="") as f:
                rdr = csv.reader(f); header = next(rdr, [])
                seen = {}; cols = []
                for h in header:
                    cols.append(h if h not in seen else f"{h}_{seen[h]}"); seen[h] = seen.get(h, 0) + 1
                rows = list(rdr)
        c.execute("select array_agg(column_name::text order by ordinal_position) from information_schema.columns where table_schema='public' and table_name=%s", (table,))
        live_cols = c.fetchone()[0]
        c.execute(f'select count(*) from public."{table}"') if live_cols else None
        live = c.fetchone()[0] if live_cols else None
        cols_match = live_cols is not None and live_cols == cols
        status = decide(live, len(rows), ok, a.threshold, cols_match)
        if not a.dry_run and status in ("OK", "FLAG_GROWTH"):
            c.execute(f'drop table if exists public."{stg}"')
            c.execute(f'create unlogged table public."{stg}" (like public."{table}")')
            for i in range(0, len(rows), 50000):
                buf = io.StringIO(); csv.writer(buf).writerows(rows[i:i + 50000]); buf.seek(0)
                c.copy_expert(f'copy public."{stg}" from stdin with (format csv)', buf)
            c.execute(f'select count(*) from public."{stg}"'); staged = c.fetchone()[0]
            if staged != len(rows):
                status = "UNAVAILABLE"; log(f"  {table}: staged {staged} != exported {len(rows)} -- not swapped")
            else:
                cn.autocommit = False
                try:
                    c.execute(f'truncate public."{table}"')
                    c.execute(f'insert into public."{table}" select * from public."{stg}"')
                    c.execute(f'select count(*) from public."{table}"'); after = c.fetchone()[0]
                    if after != staged: raise RuntimeError(f"live {after} != staged {staged}")
                    cn.commit()
                except Exception as e:
                    cn.rollback(); status = "UNAVAILABLE"; log(f"  {table}: swap rolled back: {e}")
                finally:
                    cn.autocommit = True
            c.execute(f'drop table if exists public."{stg}"')
        results.append((table, live, len(rows), status, None if cols_match else (len(live_cols or []), len(cols))))
        log(f"  {status:15} {table:42} live {live} -> capture {len(rows)}" + ("" if cols_match else f"  COLUMNS live {len(live_cols or [])} vs capture {len(cols)}"))
        os.remove(csvfn)

    bad = [r for r in results if r[3] not in ("OK", "FLAG_GROWTH")]
    log(f"SUMMARY: {len(results)} tables, {len(results) - len(bad)} {'would load' if a.dry_run else 'loaded'}, {len(bad)} not: {[(r[0], r[3]) for r in bad]}")
    if not a.dry_run and not bad:
        c.execute("""update data_source_registry set last_successful_pull_date = current_date, last_pull_basis = 'fetcher',
                     last_pull_evidence = %s where active and county_name = 'Volusia' and category = 'cama'""",
                  (f"volusia_cama_refresh from archived capture sha256 {sha[:12]} (county as of {as_of}, captured {captured})",))
    return 1 if bad else 0

if __name__ == "__main__": sys.exit(main())
