import json, glob, re, sys, urllib.request, urllib.parse
S = sys.argv[1]; APPLY = len(sys.argv) > 2 and sys.argv[2] == 'apply'
env = dict(l.rstrip('\r\n').split('=',1) for l in open('.env.local',encoding='utf-8') if '=' in l and not l.startswith('#'))
KEY = env['SUPABASE_SECRET_KEY'].strip().strip('"'); B='https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1'
H={'apikey':KEY,'Authorization':'Bearer '+KEY,'Content-Type':'application/json'}
def get(p): return json.load(urllib.request.urlopen(urllib.request.Request(B+p, headers=H)))
geo={r['admin1_abbr']:r['geo_id'] for r in get('/geo_reference?country_iso=eq.US&admin_level=eq.1&select=geo_id,admin1_abbr')}
# construction scope, judged from each state's survey notes (reported with the ranking)
SCOPE = dict(AL='licence',AK='registration',AZ='licence',AR='licence',CA='licence',CO='trades_only',CT='registration',DE='registration',
  DC='registration',GA='licence',HI='licence',ID='registration',IL='trades_only',IN='trades_only',IA='registration',KS='trades_only',KY='trades_only',
  LA='licence',ME='trades_only',MD='home_improvement_only',MA='home_improvement_only',MI='residential_only',MN='residential_only',MS='licence',
  MO='trades_only',MT='registration',NE='registration',NV='licence',NH='trades_only',NJ='home_improvement_only',NM='licence',NY='none',NC='licence',
  ND='licence',OH='trades_only',OK='trades_only',OR='licence',PA='home_improvement_only',RI='registration',SC='licence',SD='trades_only',TN='licence',
  TX='trades_only',UT='licence',VT='residential_only',VA='licence',WA='registration',WV='licence',WI='residential_only',WY='trades_only',FL='licence')
ACC={'bulk_download','api','lookup_form_only','records_request','paid','none','not_established'}
rows=[]; 
for f in sorted(glob.glob(S+'/survey_*.json')): rows += json.load(open(f,encoding='utf-8'))
seen=set(); out=[]
for r in rows:
  st=r['state']; prof='construction' if r['profession']=='contractor' else 'real_estate'
  if (st,prof) in seen: continue
  seen.add((st,prof))
  pd = r.get('posted_date'); pd = re.match(r'\d{4}-\d{2}-\d{2}', pd or '') ; pd = pd.group(0) if pd else None
  acc = r.get('access_type') if r.get('access_type') in ACC else 'not_established'
  note = ('SOURCE URL NOT CONFIRMED BY FETCH. ' if r.get('url_fetched') is False else '') + (r.get('notes') or '')
  scope = SCOPE.get(st) if prof=='construction' else None
  body = dict(authority=r.get('authority'), access_type=acc, source_url=r.get('source_url'), file_format=r.get('file_format'),
     approx_rows=r.get('approx_rows'), cadence=r.get('cadence'), posted_date=pd, fields_present=r.get('fields') or None,
     code_list_url=r.get('code_list_url'), terms=r.get('terms'), surveyed_at='2026-09-28', survey_notes=note[:4000], register_scope=scope)
  if st!='FL': body['coverage_state'] = 'no_register_exists' if scope in ('trades_only','none') else 'not_held'
  out.append((geo[st],prof,body))
print('cells', len(out), 'states', len({o[0] for o in out}))
from collections import Counter
print(Counter((p, b.get('coverage_state','held'), b['access_type']) for g,p,b in out).most_common())
missing=[(a,p) for a in geo for p in ('construction','real_estate') if (a,p) not in seen]; print('missing', missing)
if APPLY:
  for g,p,b in out:
    q=f"/register_coverage?state_geo_id=eq.{g}&profession=eq.{p}"
    req=urllib.request.Request(B+q, data=json.dumps(b).encode(), method='PATCH', headers={**H,'Prefer':'return=minimal'})
    assert urllib.request.urlopen(req).status in (200,204)
  print('applied')
