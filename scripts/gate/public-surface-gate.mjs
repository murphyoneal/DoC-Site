// Ruling 927 item 6 - THE GATE: nothing fabricated or withdrawn is reachable from any public surface of the contractor
// register, and a real licence still is (or the test proves nothing).
//
//   node --env-file=.env.local scripts/gate/public-surface-gate.mjs [https://departmentofconstruction.com]
//
// Public checks use only what a visitor has: plain HTTP to the site, and the homepage's own publishable key against the
// same REST functions the browser calls. The service key (from the environment) is used ONLY to read registries - which
// rows are fixtures (test_fixture), which slugs were deleted or withdrawn (moderation_action) - so the gate follows the
// records instead of a hard-coded list, and to run two catalog predicates that HTTP cannot see whole.
// Exit 0 = every check passed. Any failure, or any check that could not run, exits 1. A check that cannot run is never
// counted as passing.

const BASE = (process.argv[2] ?? 'https://departmentofconstruction.com').replace(/\/$/, '')
const SB = 'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1'
const SVC = process.env.SUPABASE_SECRET_KEY
if (!SVC) { console.error('FAIL: SUPABASE_SECRET_KEY not set (needed to read the fixture and withdrawal registries).'); process.exit(1) }

// One retry on a network error; a second failure throws, the process exits non-zero, and nothing is counted as passing.
const _fetch = globalThis.fetch
globalThis.fetch = async (...a) => { try { return await _fetch(...a) } catch { await new Promise(r => setTimeout(r, 2000)); return _fetch(...a) } }

const results = []
const pass = (name, detail = '') => results.push({ ok: true, name, detail })
const fail = (name, detail = '') => results.push({ ok: false, name, detail })

const svcGet = async (path) => {
  const r = await fetch(`${SB}/${path}`, { headers: { apikey: SVC, Authorization: 'Bearer ' + SVC } })
  if (!r.ok) throw new Error(`${path} -> ${r.status} ${await r.text()}`)
  return r.json()
}
const svcRpc = async (fn, body) => {
  const r = await fetch(`${SB}/rpc/${fn}`, { method: 'POST', headers: { apikey: SVC, Authorization: 'Bearer ' + SVC, 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
  if (!r.ok) throw new Error(`${fn} -> ${r.status} ${await r.text()}`)
  return r.json()
}

// the visitor's key: read from the live homepage, exactly as the browser gets it
const home = await (await fetch(BASE + '/')).text()
const ANON = (home.match(/sb_publishable_[A-Za-z0-9_-]+/) ?? [])[0]
if (!ANON) { console.error('FAIL: no publishable key on the homepage - cannot call the public search as a visitor.'); process.exit(1) }
const anonRpc = async (fn, body) => {
  const r = await fetch(`${SB}/rpc/${fn}`, { method: 'POST', headers: { apikey: ANON, Authorization: 'Bearer ' + ANON, 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
  return { status: r.status, body: r.ok ? await r.json() : await r.text() }
}
const page = async (path, redirect = 'follow') => {
  const r = await fetch(BASE + path, { redirect })
  return { status: r.status, location: r.headers.get('location'), text: redirect === 'manual' ? '' : await r.text() }
}

// ---- registries -------------------------------------------------------------------------------------------------
// The fabricated set is the registry UNION the reserved ZZ licence range (ruling 723), read independently. The first
// red run of this gate removed the fixture's registry row and the gate went GREEN - it had learned what was fabricated
// from the same registry the control reads, so removing the row blinded the test and the control together. A
// reserved-range row that the registry does not list is itself a failure (registry and range must agree).
const registry = await svcGet('test_fixture?select=register,key,label')
const reservedContractors = await svcGet('contractors?license_number=like.ZZ*&select=license_number')
const reservedAgents = await svcGet('agent_license_roster?license_number=like.ZZ*&select=license_number')
const byKey = new Map()
for (const f of registry) byKey.set(f.register + ':' + f.key, { ...f, registered: true })
for (const r of reservedContractors) { const k = 'contractors:' + r.license_number; if (!byKey.has(k)) byKey.set(k, { register: 'contractors', key: r.license_number, label: null, registered: false }) }
for (const r of reservedAgents) { const k = 'agent_license_roster:' + r.license_number; if (!byKey.has(k)) byKey.set(k, { register: 'agent_license_roster', key: r.license_number, label: null, registered: false }) }
const fixtures = [...byKey.values()]
for (const f of fixtures.filter(f => !f.registered)) fail(`reserved-range row ${f.register}:${f.key} is registered as a test fixture`, 'NOT in test_fixture - the control cannot exclude it')
if (fixtures.length === 0) fail('fabricated set is non-empty', 'no fixtures and no reserved-range rows found - the gate would test nothing')
const contractorFixtures = fixtures.filter(f => f.register === 'contractors')
const agentFixtures = fixtures.filter(f => f.register === 'agent_license_roster')
for (const f of contractorFixtures) {
  const rows = await svcGet(`contractors?license_number=eq.${encodeURIComponent(f.key)}&select=slug,business_name,display_name,trade_label,city`)
  Object.assign(f, rows[0] ?? {})
}
const deleted = (await svcGet("moderation_action?action=eq.delete_parse_artefact&target_table=eq.contractors&select=before_state,after_state"))
  .map(m => ({ slug: m.before_state?.contractor?.slug, to: String(m.after_state?.redirect ?? '').split(' -> ')[1] }))
const withdrawn = (await svcGet("moderation_action?action=eq.withdraw_from_serving&target_table=eq.contractors&select=before_state"))
  .map(m => m.before_state?.slug).filter(Boolean)

// ---- 1. fixtures by licence, name, trade, city: both searches, the search page, the agent search ------------------
// Only RESULT ROWS count: the payload echoes the query ("query", "terms"), so searching for the fixture's licence would
// otherwise "find" it in the echo (the first run of this gate failed 9 checks on exactly that - a false red).
const leaks = (payload, f) => (Array.isArray(payload?.results) ? payload.results : []).some(r =>
  r.license_number === f.key || (f.slug && r.slug === f.slug) || (f.business_name && r.name === f.business_name) || (f.display_name && r.name === f.display_name))
// On a page, the search box echoes the query; a leak is the fixture as a RESULT: a link to its page, or its licence
// printed in a result line.
// (Not the bare key between tags: the "Nothing matched" sentence echoes the query as >KEY< between React's comment
// markers - a second false red on the first run.)
const pageLeaks = (html, f) => (f.slug && html.includes(`href="/c/${f.slug}"`)) || html.includes(`Licence ${f.key}`) || html.includes(`Licence <!-- -->${f.key}`)
for (const f of contractorFixtures) {
  const probes = [f.key, f.business_name, f.display_name, f.slug, f.label ?? null, `${f.trade_label ?? ''} ${f.city ?? ''}`.trim(), f.city, 'zz test', 'dop system check'].filter(Boolean)
  for (const q of [...new Set(probes)]) {
    for (const fn of ['register_search', 'contractor_register_search']) {
      const r = await anonRpc(fn, { q, lim: 50 })
      if (r.status !== 200) fail(`fixture ${f.key} via ${fn}("${q}")`, `could not run: HTTP ${r.status}`)
      else if (leaks(r.body, f)) fail(`fixture ${f.key} via ${fn}("${q}")`, 'RETURNED')
      else pass(`fixture ${f.key} via ${fn}("${q}")`)
    }
    const p = await page('/c?q=' + encodeURIComponent(q))
    if (p.status !== 200) fail(`fixture ${f.key} via /c?q=${q}`, `could not run: HTTP ${p.status}`)
    else if (pageLeaks(p.text, f)) fail(`fixture ${f.key} via /c?q=${q}`, 'SHOWN')
    else pass(`fixture ${f.key} via /c?q=${q}`)
  }
}
for (const f of agentFixtures) {
  for (const q of [f.key, f.label, 'zz test'].filter(Boolean)) {
    const r = await anonRpc('agent_register_search', { q })
    if (r.status !== 200) fail(`agent fixture ${f.key} via agent_register_search("${q}")`, `could not run: HTTP ${r.status} ${String(r.body).slice(0, 120)}`)
    else if ((r.body?.results ?? []).some(x => JSON.stringify(x).includes(f.key))) fail(`agent fixture ${f.key} via agent_register_search("${q}")`, 'RETURNED')
    else pass(`agent fixture ${f.key} via agent_register_search("${q}")`)
  }
}

// ---- 2. every list: the view all lists read, and the list pages themselves -----------------------------------------
{
  const inView = await svcGet(`contractors_public?license_number=in.(${contractorFixtures.map(f => encodeURIComponent(f.key)).join(',')})&select=license_number`)
  if (inView.length) fail('contractors_public (the view every list reads) holds no registered fixture', `holds ${inView.map(r => r.license_number).join(', ')} - item 5 (200b) not applied`)
  else pass('contractors_public (the view every list reads) holds no registered fixture')
}
const sitemap = await page('/sitemap.xml')
const listPaths = ['/', '/c', '/map', '/florida', ...[...sitemap.text.matchAll(/<loc>https?:\/\/[^/<]+(\/[^<]*)<\/loc>/g)].map(m => m[1].replace(/&amp;/g, '&'))]
for (const path of [...new Set(listPaths)]) {
  const p = await page(path)
  const hit = contractorFixtures.find(f => pageLeaks(p.text, f) || (f.slug && p.text.includes(f.slug)) || (f.business_name && p.text.includes(f.business_name)))
  if (p.status >= 500) fail(`list ${path}`, `could not run: HTTP ${p.status}`)
  else if (hit) fail(`list ${path}`, `shows fixture ${hit.key}`)
  else pass(`list ${path}`, `HTTP ${p.status}`)
}
{
  const hit = [...contractorFixtures, ...deleted.map(d => ({ key: d.slug, slug: d.slug })), ...withdrawn.map(s => ({ key: s, slug: s }))]
    .find(f => f.slug && sitemap.text.includes(f.slug))
  if (sitemap.status !== 200) fail('sitemap.xml', `could not run: HTTP ${sitemap.status}`)
  else if (hit) fail('sitemap.xml lists nothing fabricated or withdrawn', `lists ${hit.slug}`)
  else pass('sitemap.xml lists nothing fabricated or withdrawn')
}
// the fixture's own direct page (922 interim) must never be indexable
for (const f of contractorFixtures.filter(f => f.slug)) {
  const p = await page('/c/' + f.slug)
  if (p.status === 404) pass(`fixture page /c/${f.slug}`, '404')
  else if (/<meta name="robots" content="[^"]*noindex/.test(p.text)) pass(`fixture page /c/${f.slug}`, 'noindex')
  else fail(`fixture page /c/${f.slug}`, `HTTP ${p.status} without noindex`)
}

// ---- 3. the 4 deleted shifted rows 308 to the real business; the 3 withdrawn 404 ---------------------------------
if (deleted.length !== 4) fail('deleted shifted rows on record', `expected 4, found ${deleted.length}`)
for (const d of deleted) {
  const p = await page('/c/' + d.slug, 'manual')
  if (p.status === 308 && String(p.location ?? '').endsWith('/c/' + d.to)) pass(`deleted /c/${d.slug} 308 -> ${d.to}`)
  else fail(`deleted /c/${d.slug}`, `HTTP ${p.status} -> ${p.location}`)
}
if (withdrawn.length !== 3) fail('withdrawn rows on record', `expected 3, found ${withdrawn.length}`)
for (const s of withdrawn) {
  const p = await page('/c/' + s, 'manual')
  if (p.status === 404) pass(`withdrawn /c/${s} 404`)
  else fail(`withdrawn /c/${s}`, `HTTP ${p.status}`)
}

// ---- 4. status vocabulary and names: what is served, not just what is stored -------------------------------------
{
  const det = await svcGet("data_defect_registry?defect_id=eq.contractor-status-vocabulary-and-shape&select=detection_sql")
  if (!det.length) fail('status vocabulary detection exists', 'missing')
  const vocab = new Set(['active', 'inactive', 'not_stated', 'not_in_latest_file'])
  let seen = 0, bad = []
  for (const q of ['roofing', 'smith', 'electric', 'alarm', 'pool', 'county:volusia', 'county:dade', 'llc']) {
    const r = await anonRpc('register_search', { q, lim: 50 })
    if (r.status !== 200) { fail(`served status check via register_search("${q}")`, `could not run: HTTP ${r.status}`); continue }
    for (const row of r.body.results ?? []) {
      seen++
      if (row.register === 'construction' && !vocab.has(row.license_status)) bad.push(`${row.license_number}:${row.license_status}`)
      if (row.register === 'electrical' && !row.status_text) bad.push(`${row.license_number}:no status_text`)
      const nm = String(row.name ?? '')
      if (/^\s*W\//i.test(nm) && !/\b(INC|LLC|CORP|CO|COMPANY|LTD|LLP|PA|PLLC|GROUP)\b/i.test(nm)) bad.push(`${row.license_number}:descriptive name "${nm}"`)
      if (/^[0-9]+$/.test(String(row.license_number ?? ''))) bad.push(`${row.license_number}:numeric licence (shifted-row shape)`)
    }
  }
  if (seen === 0) fail('served status vocabulary and names', 'no rows examined - cannot pass an empty check')
  else if (bad.length) fail('served status vocabulary and names', `${bad.length} bad of ${seen}: ${bad.slice(0, 5).join('; ')}`)
  else pass('served status vocabulary and names', `${seen} served rows examined`)
}

// ---- 5. the reverse direction: real licences ARE reachable -------------------------------------------------------
for (const [lic, path] of [['CGC1531639', '/c/smith-wagner-construction-llc-ponce-inlet-fl'], ['EF0000971', '/e/EF0000971']]) {
  const r = await anonRpc('register_search', { q: lic, lim: 5 })
  if (r.status === 200 && JSON.stringify(r.body).includes(lic)) pass(`real licence ${lic} found by the public search`)
  else fail(`real licence ${lic} found by the public search`, `HTTP ${r.status}`)
  const p = await page(path)
  if (p.status === 200 && p.text.includes(lic)) pass(`real licence page ${path}`)
  else fail(`real licence page ${path}`, `HTTP ${p.status}`)
}

// ---- 6. detector controls: the leak detectors must SEE a real result, or "no leak" proves nothing ------------------
{
  const real = { key: 'CGC1531639', slug: 'smith-wagner-construction-llc-ponce-inlet-fl', business_name: 'SMITH & WAGNER CONSTRUCTION LLC' }
  const r = await anonRpc('register_search', { q: real.key, lim: 5 })
  if (r.status === 200 && leaks(r.body, real)) pass('detector control: the search-leak check sees a real licence')
  else fail('detector control: the search-leak check sees a real licence', 'blind - every "no leak" above is unproven')
  const p = await page('/c?q=' + real.key)
  if (p.status === 200 && pageLeaks(p.text, real)) pass('detector control: the page-leak check sees a real result')
  else fail('detector control: the page-leak check sees a real result', 'blind - every "not shown" above is unproven')
}

// ---- report ------------------------------------------------------------------------------------------------------
const failed = results.filter(r => !r.ok)
for (const r of results) if (!r.ok) console.log(`  FAIL  ${r.name}${r.detail ? ' - ' + r.detail : ''}`)
console.log(`\n${failed.length === 0 ? 'GATE PASS' : 'GATE FAIL'} - ${results.length - failed.length}/${results.length} checks passed against ${BASE}` +
  ` (fixtures: ${contractorFixtures.length} contractor, ${agentFixtures.length} agent; deleted ${deleted.length}; withdrawn ${withdrawn.length})`)
process.exit(failed.length === 0 ? 0 : 1)
