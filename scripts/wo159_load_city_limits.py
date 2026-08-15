#!/usr/bin/env python3
"""
WO159 loader — FGDL/FDOT "City_Boundaries" -> public.fl_city_limits
Run in WSL on Silverbox. Input: citylimits_out/fl_city_limits.geojson.gz (Murphy's pull, outSR=4326).

Handles the three ingest traps named in WO159:
  1. MIXED GEOMETRY (174 Polygon + 238 MultiPolygon) -> ST_Multi() everything (column is MultiPolygon).
  2. fgdlaqdate is EPOCH MILLISECONDS -> /1000 -> date.
  3. GeoJSON lowercases the field names (fid, placefp, name, county, taxauthcd, fgdlaqdate, ...).
Plus: Weeki Wachee (disincorporated 2020-06-09) is LOADED but flagged is_active=false — never dropped.

Idempotent: TRUNCATE + reload. Asserts 412 rows, 0 null geom, placefp unique — fails loud otherwise.
Target table + GiST index + provenance/defect are already created in Supabase (migration 121a).

Env:
  SUPABASE_DB_DSN   postgresql://USER:PASS@HOST:PORT/postgres   (direct or session pooler)
  CITYLIMITS_GEOJSON  optional override of the input path
"""
import gzip, json, os, sys
from datetime import datetime, timezone
import psycopg2
from psycopg2.extras import execute_batch

INPUT  = os.environ.get('CITYLIMITS_GEOJSON', 'citylimits_out/fl_city_limits.geojson.gz')
DSN    = os.environ['SUPABASE_DB_DSN']
EXPECT = 412

def main():
    with gzip.open(INPUT, 'rt', encoding='utf-8') as f:
        gj = json.load(f)
    feats = gj.get('features', [])
    print(f'features in file: {len(feats)}')
    rows = []
    for ft in feats:
        p = ft.get('properties', {})
        name = p.get('name')
        fgdl = p.get('fgdlaqdate')                                    # epoch ms
        fgdl_date = datetime.fromtimestamp(fgdl / 1000, tz=timezone.utc).date() if fgdl else None
        is_active = not (name and 'WEEKI WACHEE' in name.upper())     # disincorporated 2020-06-09
        rows.append((
            p.get('fid'), p.get('placefp'), name, p.get('bebr_id'), p.get('county'),
            p.get('tax_count'), p.get('taxauthcd'), p.get('acres'), p.get('descript'),
            p.get('notes'), p.get('autoid'),
            fgdl_date, json.dumps(ft.get('geometry')), is_active,
        ))

    sql = """INSERT INTO public.fl_city_limits
      (fid, placefp, name, bebr_id, county, tax_count, taxauthcd, acres, descript, notes, autoid,
       fgdlaq_date, geom, is_active)
      VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
              ST_Multi(ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326)),   -- ST_Multi handles the mixed geometry
              %s)"""

    conn = psycopg2.connect(DSN); conn.autocommit = False
    cur = conn.cursor()
    cur.execute('SET statement_timeout = 0')
    cur.execute('TRUNCATE public.fl_city_limits')
    execute_batch(cur, sql, rows, page_size=200)

    cur.execute("""SELECT count(*), count(*) FILTER (WHERE geom IS NOT NULL),
                          count(DISTINCT placefp), count(*) FILTER (WHERE NOT is_active)
                   FROM public.fl_city_limits""")
    total, withgeom, distinct_placefp, inactive = cur.fetchone()
    problems = []
    if total != EXPECT:            problems.append(f'loaded {total}, expected {EXPECT}')
    if withgeom != total:          problems.append(f'{total - withgeom} NULL geometries')
    if distinct_placefp != total:  problems.append(f'placefp not unique ({distinct_placefp} distinct)')
    if inactive != 1:              problems.append(f'expected exactly 1 inactive (Weeki Wachee), got {inactive}')
    if problems:
        conn.rollback()
        sys.exit('FAILED: ' + '; '.join(problems))
    conn.commit()
    print(f'OK: {total} rows, {distinct_placefp} distinct placefp, 0 null geom, {inactive} inactive (Weeki Wachee).')

if __name__ == '__main__':
    main()
