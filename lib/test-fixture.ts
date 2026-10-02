// Registered test fixtures (test_fixture, ruling 723) must never be indexed (ruling 927).
//
// The fixture's own pages stay reachable by direct URL under the 922 interim, so they mark themselves noindex and
// robots.txt disallows them once indexing is on. Decided by the registry KEY (is_test_fixture / test_fixture), never by
// the row's name or values - a name prefix is a convention, not a control. Fails closed: if the check cannot run, the
// page is treated as a fixture (noindex), because indexing a fabricated contractor is not recoverable.

const SB = 'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const H = { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' }

export async function isTestFixture(register: 'contractors' | 'agent_license_roster', key: string | null | undefined): Promise<boolean> {
  if (!key) return false
  try {
    const r = await fetch(`${SB}/rpc/is_test_fixture`, {
      method: 'POST', headers: H, body: JSON.stringify({ p_register: register, p_key: key }), next: { revalidate: 300 },
    })
    if (!r.ok) return true
    return (await r.json()) === true
  } catch {
    return true
  }
}

// Paths of every registered contractor fixture's own pages, for robots.txt.
export async function fixtureContractorPaths(): Promise<string[]> {
  try {
    const f = await fetch(`${SB}/test_fixture?register=eq.contractors&select=key`, { headers: H, next: { revalidate: 300 } })
    if (!f.ok) return []
    const keys = ((await f.json()) as { key: string }[]).map(k => k.key).filter(Boolean)
    if (keys.length === 0) return []
    const c = await fetch(`${SB}/contractors?license_number=in.(${keys.map(encodeURIComponent).join(',')})&select=slug`, { headers: H, next: { revalidate: 300 } })
    if (!c.ok) return []
    const slugs = ((await c.json()) as { slug: string | null }[]).map(r => r.slug).filter((s): s is string => !!s)
    return slugs.flatMap(s => [`/c/${s}`, `/claim/${s}`])
  } catch {
    return []
  }
}
