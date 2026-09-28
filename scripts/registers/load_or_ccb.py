"""Oregon CCB Active Licenses -> reg_us_or.ccb_active_license (migration 148a).

Pulls data.oregon.gov dataset g77e-6bhs page by page (5,000 rows, ordered by :id), refuses an empty
or short pull, upserts in 2,000-row batches on (license_number, license_type), then calls
finish_or_ccb_load, which asserts the run carried exactly the source's row count, marks licences the
file no longer lists as absent_from_latest_file, and records coverage. Safe to run twice.
Usage: python scripts/registers/load_or_ccb.py
"""
import json, urllib.request, urllib.parse, datetime

B = 'https://data.oregon.gov/resource/g77e-6bhs.json'
env = dict(l.rstrip('\r\n').split('=', 1) for l in open('.env.local', encoding='utf-8') if '=' in l and not l.startswith('#'))
KEY = env['SUPABASE_SECRET_KEY'].strip().strip('"')
RPC = 'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1/rpc/'
H = {'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Content-Type': 'application/json'}

def rpc(fn, body):
    req = urllib.request.Request(RPC + fn, data=json.dumps(body).encode(), method='POST', headers=H)
    return json.load(urllib.request.urlopen(req, timeout=300))

meta = json.load(urllib.request.urlopen('https://data.oregon.gov/api/views/g77e-6bhs.json'))
source_updated = datetime.datetime.fromtimestamp(meta['rowsUpdatedAt'], datetime.timezone.utc).isoformat()
expected = int(json.load(urllib.request.urlopen(B + '?' + urllib.parse.urlencode({'$select': 'count(*)'})))[0]['count'])
if expected <= 0:
    raise SystemExit('ABORT: the source reports 0 rows - a down service is not an empty register. Nothing touched.')

rows, off = [], 0
while True:
    q = urllib.parse.urlencode({'$select': '*,:id', '$order': ':id', '$limit': 5000, '$offset': off})
    page = json.load(urllib.request.urlopen(B + '?' + q, timeout=300))
    rows += page; off += len(page)
    if len(page) < 5000: break
if len(rows) != expected:
    raise SystemExit(f'ABORT: pulled {len(rows)} rows, the source says {expected}. Nothing touched.')

retrieved = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
done = 0
for i in range(0, len(rows), 2000):
    done += rpc('load_or_ccb_batch', {'p_rows': rows[i:i + 2000], 'p_retrieved': retrieved, 'p_source_updated': source_updated})
print('upserted', done, 'of', expected, 'source updated', source_updated)
print('finish:', rpc('finish_or_ccb_load', {'p_retrieved': retrieved, 'p_source_updated': source_updated, 'p_expected': expected}))
