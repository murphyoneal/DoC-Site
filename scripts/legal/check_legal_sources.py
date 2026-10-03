"""Fetch every served /rights primary_source_url, record liveness and statute-quote drift (ruling 1005, 3c/3d).

Writes one legal_source_check row per state. Reads the database URL from LEGAL_CHECK_DSN; it never prints it.
Outcomes are three-way on purpose: a site that refuses an automated fetch is 'blocked' - unverifiable, neither
live nor dead. A quote is 'found' only when every stored segment (split on ellipses) appears in the fetched text
after normalising case, whitespace and punctuation; a 'not_found' is a lead to read the statute, not proof it moved.
"""
import html, os, re, sys, urllib.error, urllib.request
import psycopg2

UA = 'Mozilla/5.0 (compatible; DoP-legal-source-check/1.0; statute link and quote check)'


def norm(s):
    s = html.unescape(s or '').lower()
    s = s.replace('’', "'").replace('“', '"').replace('”', '"').replace('§', ' section ')
    return re.sub(r'[^a-z0-9]+', ' ', s).strip()


def page_text(raw):
    raw = re.sub(r'(?is)<(script|style)[^>]*>.*?</\1>', ' ', raw)
    return norm(re.sub(r'(?s)<[^>]+>', ' ', raw))


def check(url, quote):
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'text/html,application/xhtml+xml'})
        with urllib.request.urlopen(req, timeout=30) as r:
            status = r.status
            ctype = r.headers.get('Content-Type', '')
            body = r.read(5_000_000)
    except urllib.error.HTTPError as e:
        if e.code in (404, 410):
            return e.code, 'dead', 'not_checkable', f'HTTP {e.code}'
        return e.code, 'blocked', 'not_checkable', f'HTTP {e.code} - automated fetch refused or failed'
    except Exception as e:  # DNS, TLS, timeout
        msg = type(e).__name__ + ': ' + str(e)[:160]
        dead = 'Name or service not known' in msg or 'getaddrinfo' in msg or 'nodename nor servname' in msg
        return None, 'dead' if dead else 'error', 'not_checkable', msg
    if 'pdf' in ctype.lower():
        return status, 'live', 'not_checkable', 'PDF - quote not compared'
    text = page_text(body.decode('utf-8', 'replace'))
    if len(text) < 400 or 'captcha' in text or 'verify you are human' in text or 'access denied' in text[:2000]:
        return status, 'blocked', 'not_checkable', 'page body is a challenge or too short to hold the statute'
    if not quote:
        return status, 'live', 'not_checkable', 'no stored quote'
    segs = [norm(s) for s in re.split(r'\.\.\.|…', quote)]
    segs = [s for s in segs if len(s) >= 20]
    if not segs:
        return status, 'live', 'not_checkable', 'stored quote too short to compare'
    missing = [s for s in segs if s not in text]
    if missing:
        return status, 'live', 'not_found', f'{len(missing)} of {len(segs)} quote segments absent, e.g. "{missing[0][:80]}"'
    return status, 'live', 'found', f'{len(segs)} quote segment(s) present'


def main():
    dsn = os.environ.get('LEGAL_CHECK_DSN')
    if not dsn:
        sys.exit('LEGAL_CHECK_DSN not set')
    conn = psycopg2.connect(dsn)
    conn.autocommit = True
    c = conn.cursor()
    c.execute('select state_code, primary_source_url, statute_quote from public.construction_defect_law where primary_verified order by 1')
    rows = c.fetchall()
    if not rows:
        sys.exit('no served rows - refusing to report an empty run as clean')
    tally = {}
    for st, url, quote in rows:
        if not url:
            status, outcome, qs, note = None, 'error', 'not_checkable', 'no primary_source_url stored'
            url = ''
        else:
            status, outcome, qs, note = check(url, quote)
        c.execute('insert into public.legal_source_check (state_code, url, http_status, outcome, quote_state, note) values (%s,%s,%s,%s,%s,%s)',
                  (st, url, status, outcome, qs, note))
        tally[(outcome, qs)] = tally.get((outcome, qs), 0) + 1
        print(st, outcome, qs, status, note[:100])
    print('TALLY', sorted(tally.items()), 'of', len(rows))


if __name__ == '__main__':
    main()
