// The indexing switch, checked on the live hosts: robots.txt and each page's own robots signals (meta tag AND the
// X-Robots-Tag header) must agree with the state you expect. Rulings 927 / 961: "confirm on production, not a
// preview - two sources, and they must agree."
//
//   node scripts/gate/indexing-check.mjs --expect=closed    # before the flip (today)
//   node scripts/gate/indexing-check.mjs --expect=open      # after SITE_INDEXABLE=true AND a redeploy
//
// SITE_INDEXABLE is read at BUILD time (app/robots.ts, app/layout.tsx, next.config.ts), so setting the variable does
// nothing until production is redeployed. Run this after the deploy, not after the setting.
// Some pages never index whatever the switch says: the registered test fixture, the /doc/ duplicate of the DoC
// homepage, and the agent register (ruling 927: agent side not today). Exit 0 = every check agrees; anything else
// exits 1. A page that cannot be fetched is a failure, never a pass.

const arg = process.argv.find(a => a.startsWith('--expect='))
const EXPECT = arg ? arg.split('=')[1] : null
if (EXPECT !== 'open' && EXPECT !== 'closed') { console.error('usage: --expect=open|closed'); process.exit(1) }
const OPEN = EXPECT === 'open'
const DOC = 'https://departmentofconstruction.com'
const DOP = 'https://departmentofproperty.com'
// INDEX_CHECK_LOCAL=http://localhost:3003 runs the same checks against a local server with SITE_INDEXABLE set,
// sending each production host name as the Host header - so --expect=open can be proven before the flip.
const LOCAL = process.env.INDEX_CHECK_LOCAL ?? null
// fetch() silently drops a custom Host header, so local mode uses node:http, which sends it. (The first version used
// fetch and every local request was served as localhost - the DoC homepage check was reading the DoP homepage and
// passed; the red run with the old hard-coded noindex restored is what exposed it.)
const { request } = await import('node:http')
const _fetch = globalThis.fetch
globalThis.fetch = (url, opts = {}) => {
  if (!LOCAL) return _fetch(url, opts)
  const u = new URL(url)
  const l = new URL(LOCAL)
  return new Promise((resolve, reject) => {
    const req = request({ hostname: l.hostname, port: l.port, path: u.pathname + u.search, method: 'GET', headers: { host: u.host } }, res => {
      let body = ''
      res.setEncoding('utf8')
      res.on('data', c => { body += c })
      res.on('end', () => resolve({
        status: res.statusCode,
        headers: { get: k => { const v = res.headers[k.toLowerCase()]; return v == null ? null : String(v) } },
        text: async () => body,
      }))
    })
    req.on('error', reject)
    req.end()
  })
}

const results = []
const ok = (name, detail = '') => results.push({ ok: true, name, detail })
const bad = (name, detail = '') => results.push({ ok: false, name, detail })

async function signals(url) {
  const r = await fetch(url, { redirect: 'follow' })
  const html = await r.text()
  const meta = (html.match(/<meta\s+name="robots"\s+content="([^"]*)"/i) ?? [])[1] ?? null
  const header = r.headers.get('x-robots-tag')
  const noindex = /noindex/i.test(meta ?? '') || /noindex/i.test(header ?? '')
  const nofollow = /nofollow/i.test(meta ?? '') || /nofollow/i.test(header ?? '')
  return { status: r.status, meta, header, noindex, nofollow }
}

// robots.txt: closed = "Disallow: /" for every agent; open = "Allow: /" for * and a sitemap line
for (const host of [DOC, DOP]) {
  const r = await fetch(host + '/robots.txt')
  const t = await r.text()
  // anchored at line start: "Disallow: /" contains "allow: /" (the first version of this check failed on exactly that)
  const allowAll = /^Allow:\s*\/\s*$/im.test(t)
  const closed = /^User-Agent:\s*\*\s*\r?\n\s*Disallow:\s*\/\s*$/im.test(t) && !allowAll
  const open = allowAll && /^Sitemap:/im.test(t)
  if (r.status !== 200) bad(`${host}/robots.txt`, `HTTP ${r.status}`)
  else if (OPEN ? open : closed) ok(`${host}/robots.txt is ${EXPECT}`)
  else bad(`${host}/robots.txt is ${EXPECT}`, t.split('\n').slice(0, 3).join(' | '))
}

// pages that follow the switch
const follow = [
  DOC + '/', DOC + '/map', DOC + '/map?county=volusia', DOC + '/c', DOC + '/c?q=roofing',
  DOC + '/c/smith-wagner-construction-llc-ponce-inlet-fl', DOC + '/e/EF0000971', DOC + '/florida',
  DOP + '/',
]
for (const u of follow) {
  try {
    const s = await signals(u)
    if (s.status !== 200) { bad(u, `HTTP ${s.status}`); continue }
    const agrees = OPEN ? (!s.noindex && !s.nofollow) : s.noindex
    if (agrees) ok(u, `meta=${s.meta ?? '-'} header=${s.header ?? '-'}`)
    else bad(u, `expected ${EXPECT}: meta=${s.meta ?? '-'} header=${s.header ?? '-'}`)
  } catch (e) { bad(u, `could not fetch: ${e.message}`) }
}

// pages that never index, whatever the switch says
const never = [
  DOC + '/c/zz-test-contracting-dop-system-check',   // registered test fixture (ruling 927)
  DOC + '/doc/index.html',                          // duplicate of the DoC homepage
  DOP + '/agents.html',                             // agent register - ruling 927: agent side not today
]
for (const u of never) {
  try {
    const s = await signals(u)
    if (s.status === 404) ok(u, '404')
    else if (s.noindex) ok(u, `noindex (meta=${s.meta ?? '-'} header=${s.header ?? '-'})`)
    else bad(u, `INDEXABLE: HTTP ${s.status} meta=${s.meta ?? '-'} header=${s.header ?? '-'}`)
  } catch (e) { bad(u, `could not fetch: ${e.message}`) }
}

const failed = results.filter(r => !r.ok)
for (const r of results) console.log(`  ${r.ok ? 'ok  ' : 'FAIL'}  ${r.name}${r.detail ? ' - ' + r.detail : ''}`)
console.log(`\n${failed.length ? 'INDEXING CHECK FAIL' : 'INDEXING CHECK PASS'} - ${results.length - failed.length}/${results.length} agree with --expect=${EXPECT}`)
process.exit(failed.length ? 1 : 0)
