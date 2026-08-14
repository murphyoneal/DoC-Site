#!/usr/bin/env python3
"""
Parked CAMA loads (rulings 176/181) — Pinellas, Collier, Pasco relational CAMA into Supabase.
Run in WSL on Silverbox. One schema-ADAPTIVE loader for all three counties: it reads each CSV's REAL
header at load time and builds the table from it (ruling 150: "write the DDL against the real headers,
not the published layout" — this reads them literally). All columns land as TEXT, matching the established
Volusia CAMA pattern where casts happen at the fact/serving layer (STRAP/leading zeros/codes/the preserved
typo all survive; nothing is coerced or lost at ingest).

Every named trap on the bus is handled here:
  * Collier UTF-8 BOM (msg 155)      -> header read via utf-8-sig; the BOM never reaches a column name.
  * Pinellas duplicate YEAR_BUILT    -> positional de-dup (year_built, year_built_2); post-load DISAGREEMENT
    in RP_PROPERTY_INFO (msg 150)       report (year_built is the primary join anchor — this is not cosmetic).
  * Pasco sales.zip = 3 members      -> archive members ENUMERATED, never "one CSV per zip"; the subset
    (msg 157)                           sales_last_10years.csv is skipped; README/xlsx/pdf auto-skipped.
  * Pasco extrafeatures a week stale -> file_as_of recorded PER FILE (the zip member mtime), never per county.
    (msg 157)
  * Pasco typo Sale_Qalified_Code    -> headers are NOT corrected; renaming would silently break every refresh.
    (msg 157)
  * Person names in sales tables     -> loaded, never exposed on a person-search path (a serving-layer concern).

Invariants (CLAUDE.md §10): SET statement_timeout=0; chunked COPY at 50k rows (a single oversized COPY dies
mid-stream ~256-370k); assert row_count == baseline after every table, fail loud, explicit FAILED list, never
print a summary that implies success; idempotent (TRUNCATE + reload; manifest UPSERT on natural key).

Baselines below are the verification targets from the bus (Pinellas msg 130, Collier msg 155, Pasco msg 157).

Env:
  SUPABASE_DB_DSN   postgresql://USER:PASS@HOST:PORT/postgres   (DIRECT connection, not the pooler — a 16.3M
                    load must not fight the 2-min pooler timeout; the session SET below still applies.)
  PINELLAS_DIR / COLLIER_DIR / PASCO_DIR   optional override of the per-county input directory.

Usage:  python3 wo_cama_load.py pinellas [TABLE ...]     # omit tables to load all; names match the member stem
        python3 wo_cama_load.py collier
        python3 wo_cama_load.py pasco
"""
import csv, glob, io, os, re, sys, zipfile
from datetime import datetime, timezone
import psycopg2

csv.field_size_limit(1 << 30)   # TRAVERSE building-sketch strings + long legal descriptions blow the default

LOADER_VERSION = 'wo_cama_load/1'
DSN = os.environ['SUPABASE_DB_DSN']

# --- per-county config -------------------------------------------------------
# expected: baseline row count from the bus (None = no target published; load + record, do not assert).
COUNTIES = {
    'pinellas': {
        'co_no': 62, 'prefix': 'pinellas_cama_',
        'dir': os.environ.get('PINELLAS_DIR', 'pcpao_out'),
        'skip_members': set(),
        'expected': {
            'rp_structural_elements': 6104018, 'rp_sales_history': 2392695, 'rp_permits': 1654923,
            'rp_exemptions': 1312647, 'rp_sub_areas': 1252484, 'rp_extra_features': 707495,
            'rp_all_owners': 681923, 'rp_all_site_addresses': 446809, 'rp_legal': 437568,
            'rp_property_info': 437568, 'rp_building': 428229, 'rp_land': 322608,
            'rp_sales': 157171, 'rp_millage_rates': 570,
        },
    },
    'collier': {
        'co_no': 21, 'prefix': 'collier_cama_',
        'dir': os.environ.get('COLLIER_DIR', 'collier_out'),
        'skip_members': set(),
        'expected': {   # only the tables whose counts msg 155 published; others load without assertion
            'int_parcels': 298248, 'int_sales': 1287039, 'int_values_rp_history': 1454552,
            'int_legal': 670412, 'int_buildings': 569361, 'int_land': 208481, 'int_usecodes': 101,
        },
    },
    'pasco': {
        'co_no': 61, 'prefix': 'pasco_cama_',
        'dir': os.environ.get('PASCO_DIR', 'pasco_out'),
        'skip_members': {'sales_last_10years.csv'},   # subset of sales_all — loading both duplicates every recent sale
        'expected': {
            'sales_all': 1760052, 'land': 539397, 'site_addresses': 360851,
            'parcel': 324735, 'owners': 321781, 'building': 276649,   # extrafeatures: stale, no published target
        },
    },
}

IDENT_RE = re.compile(r'[^a-z0-9_]+')


def sql_ident(raw):
    """A real header cell -> a safe snake_case identifier. Preserves the token (incl. the Pasco typo);
       only lowercases and replaces separators. BOM already stripped upstream by utf-8-sig."""
    s = raw.strip().strip('"').lstrip('﻿').lower()
    s = IDENT_RE.sub('_', s).strip('_')
    return s or 'col'


def dedup(cols):
    """Positional de-dup: the second YEAR_BUILT becomes year_built_2, etc. Returns (names, dup_bases)."""
    seen, out, dups = {}, [], set()
    for c in cols:
        if c in seen:
            seen[c] += 1
            out.append(f'{c}_{seen[c]}')
            dups.add(c)
        else:
            seen[c] = 1
            out.append(c)
    return out, sorted(dups)


def member_as_of(zi):
    """The member's own mtime as UTC — recorded PER FILE (Pasco extrafeatures is a week stale vs its siblings)."""
    y, mo, d, h, mi, s = zi.date_time
    try:
        return datetime(y, mo, d, h, mi, s, tzinfo=timezone.utc)
    except ValueError:
        return None


def ensure_manifest(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS public.cama_load_manifest (
          id             bigserial PRIMARY KEY,
          county         text NOT NULL,
          co_no          numeric NOT NULL,
          table_name     text NOT NULL,
          source_archive text,
          source_member  text NOT NULL,
          file_as_of     timestamptz,          -- PER FILE, never per county
          row_count      bigint,
          expected_count bigint,
          count_ok       boolean,
          columns_loaded int,
          had_bom        boolean DEFAULT false,
          dup_columns    text[],
          header_sha256  text,
          loaded_at      timestamptz DEFAULT now(),
          loader_version text,
          UNIQUE (table_name, source_member)
        )""")


def load_member(cur, county, cfg, zf, zi, only):
    member = os.path.basename(zi.filename)
    if not member.lower().endswith('.csv'):
        return None                                   # README.TXT / parcel_summary xlsx+pdf auto-skip
    if member in cfg['skip_members']:
        print(f'  skip (configured subset): {member}')
        return None
    stem = sql_ident(member[:-4])
    if only and stem not in only:
        return None
    table = cfg['prefix'] + stem
    expected = cfg['expected'].get(stem)

    raw = zf.read(zi.filename)
    had_bom = raw[:3] == b'\xef\xbb\xbf'
    text = io.TextIOWrapper(io.BytesIO(raw), encoding='utf-8-sig', newline='')
    reader = csv.reader(text)
    header = next(reader)
    cols, dups = dedup([sql_ident(h) for h in header])
    import hashlib
    header_sha = hashlib.sha256(('\x1f'.join(header)).encode('utf-8')).hexdigest()

    coldefs = ', '.join(f'{c} text' for c in cols)
    collist = ', '.join(cols)
    cur.execute(f'CREATE TABLE IF NOT EXISTS public.{table} ({coldefs})')
    cur.execute(f'TRUNCATE public.{table}')           # idempotent reload

    n, batch = 0, io.StringIO()
    w = csv.writer(batch)
    b = 0
    copy_sql = f'COPY public.{table} ({collist}) FROM STDIN WITH (FORMAT csv)'
    for row in reader:
        w.writerow(row)
        n += 1; b += 1
        if b >= 50000:                                # chunk the COPY (invariant 5)
            batch.seek(0); cur.copy_expert(copy_sql, batch)
            batch = io.StringIO(); w = csv.writer(batch); b = 0
    if b:
        batch.seek(0); cur.copy_expert(copy_sql, batch)

    count_ok = None if expected is None else (n == expected)
    cur.execute("""
        INSERT INTO public.cama_load_manifest
          (county, co_no, table_name, source_archive, source_member, file_as_of, row_count,
           expected_count, count_ok, columns_loaded, had_bom, dup_columns, header_sha256, loader_version)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        ON CONFLICT (table_name, source_member) DO UPDATE SET
          file_as_of=EXCLUDED.file_as_of, row_count=EXCLUDED.row_count, expected_count=EXCLUDED.expected_count,
          count_ok=EXCLUDED.count_ok, columns_loaded=EXCLUDED.columns_loaded, had_bom=EXCLUDED.had_bom,
          dup_columns=EXCLUDED.dup_columns, header_sha256=EXCLUDED.header_sha256, loaded_at=now(),
          loader_version=EXCLUDED.loader_version""",
        (county, cfg['co_no'], table, os.path.basename(zf.filename), member, member_as_of(zi), n,
         expected, count_ok, len(cols), had_bom, dups or None, header_sha, LOADER_VERSION))

    tag = 'OK' if count_ok else ('no-target' if expected is None else 'COUNT MISMATCH')
    extra = f' BOM' if had_bom else ''
    extra += f' dup={dups}' if dups else ''
    print(f'  {table}: {n} rows (expected {expected}) [{tag}]{extra}')

    # Pinellas duplicate YEAR_BUILT: report whether the two ever disagree (msg 150 — anchor-relevant).
    if 'year_built' in cols and 'year_built_2' in cols:
        cur.execute(f"SELECT count(*) FROM public.{table} WHERE year_built IS DISTINCT FROM year_built_2")
        d = cur.fetchone()[0]
        print(f'    YEAR_BUILT vs YEAR_BUILT_2: {d} rows disagree '
              + ('(identical — second is droppable, register the finding)' if d == 0
                 else '(GENUINELY TWO BUILD YEARS — decide which feeds the anchor before serving)'))
    return (table, count_ok, expected)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in COUNTIES:
        sys.exit(f'usage: {sys.argv[0]} <{"|".join(COUNTIES)}> [TABLE ...]')
    county = sys.argv[1]
    only = {sql_ident(a) for a in sys.argv[2:]}
    cfg = COUNTIES[county]
    zips = sorted(glob.glob(os.path.join(cfg['dir'], '*.zip')))
    if not zips:
        sys.exit(f'FAILED: no .zip archives under {cfg["dir"]}')

    conn = psycopg2.connect(DSN); conn.autocommit = False
    cur = conn.cursor()
    cur.execute('SET statement_timeout = 0')
    ensure_manifest(cur); conn.commit()

    loaded, failed = [], []
    for zpath in zips:
        with zipfile.ZipFile(zpath) as zf:
            for zi in zf.infolist():
                try:
                    res = load_member(cur, county, cfg, zf, zi, only)
                except Exception as e:
                    conn.rollback()
                    failed.append((os.path.basename(zi.filename), str(e).splitlines()[0]))
                    print(f'  FAILED {zi.filename}: {str(e).splitlines()[0]}')
                    continue
                if res is None:
                    continue
                table, count_ok, expected = res
                conn.commit()
                if count_ok is False:
                    failed.append((table, f'count mismatch vs baseline {expected}'))
                else:
                    loaded.append(table)

    print(f'\nloaded OK: {len(loaded)}')
    if failed:
        print('FAILED / UNVERIFIED:')
        for name, why in failed:
            print(f'  - {name}: {why}')
        sys.exit(f'{county}: {len(failed)} table(s) failed or missed their baseline — NOT complete.')
    print(f'{county}: all archives processed, every published baseline matched.')


if __name__ == '__main__':
    main()
