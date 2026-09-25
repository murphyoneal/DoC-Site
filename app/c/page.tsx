import Link from 'next/link'

// "Search another contractor" — where a profile's search box goes (work order 653 (c)).
// Backed by contractor_register_search, the same function the public register uses, so the two
// search surfaces return the same records with the same record date and coverage note.
// It returns one row per LICENCE record; a business holding two licences can appear twice, and
// both links land on the same business page. One row per business is a held, coordinated change.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''

type Result = { slug: string; name: string; trade: string | null; city: string | null; county: string | null; license_number: string | null; license_status: string | null }
type Payload = { field_status: string; count: number; returned: number; results: Result[]; coverage_note?: string; source_retrieved?: string | null }

async function search(q: string): Promise<Payload | null> {
  try {
    const res = await fetch(`https://${SB_HOST}/rest/v1/rpc/contractor_register_search`, {
      method: 'POST',
      headers: { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ q, lim: 25 }),
      cache: 'no-store',
    })
    if (!res.ok) return null
    return await res.json()
  } catch {
    return null
  }
}

export const metadata = { title: 'Search contractors' }

export default async function ContractorSearchPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>
}) {
  const sp = await searchParams
  const raw = Array.isArray(sp.q) ? sp.q[0] : sp.q
  const q = (raw ?? '').trim().slice(0, 100)
  const data = q.length >= 2 ? await search(q) : null

  return (
    <main style={{ maxWidth: '760px', margin: '0 auto', padding: '32px 16px' }}>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', fontWeight: 700, margin: '0 0 12px' }}>
        Search contractors
      </h1>
      <form action="/c" method="get" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '20px' }}>
        <label htmlFor="q" style={{ position: 'absolute', left: '-9999px' }}>Business name or licence number</label>
        <input id="q" name="q" type="search" defaultValue={q} required minLength={2}
          placeholder="Business name or licence number"
          style={{ flex: '1 1 240px', padding: '10px 12px', borderRadius: '8px', border: '1px solid #cfc8bd', fontSize: '0.9rem' }} />
        <button type="submit" style={{ padding: '10px 18px', borderRadius: '8px', border: 'none', background: 'var(--color-navy)', color: 'white', fontWeight: 600 }}>
          Search
        </button>
      </form>

      {q.length >= 2 && data === null && (
        <p style={{ fontSize: '0.86rem', color: '#8a4a17' }}>The search could not be run just now. This is a fault on our side — please try again.</p>
      )}

      {data && data.field_status !== 'present' && (
        <p style={{ fontSize: '0.86rem', color: 'var(--color-sage)' }}>
          No licence record matched &ldquo;{q}&rdquo;. This searches the Florida licence records we hold; a business that is not in them may still be licensed elsewhere.
        </p>
      )}

      {data && data.field_status === 'present' && (
        <>
          <p style={{ fontSize: '0.78rem', color: 'var(--color-sage)', margin: '0 0 10px' }}>
            {data.count > data.returned ? `Showing ${data.returned} of ${data.count} matching licence records.` : `${data.count} matching licence record${data.count === 1 ? '' : 's'}.`}
          </p>
          <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {data.results.map(r => (
              <li key={`${r.slug}-${r.license_number}`} style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)', borderRadius: '10px', padding: '12px 14px' }}>
                <Link href={`/c/${r.slug}`} style={{ color: 'var(--color-navy)', fontWeight: 700, textDecoration: 'none' }}>{r.name}</Link>
                <p style={{ fontSize: '0.8rem', color: 'var(--color-sage)', margin: '2px 0 0' }}>
                  {[r.trade, r.city, r.county ? `${r.county} County` : null].filter(Boolean).join(' · ')}
                  {r.license_number ? ` · Licence ${r.license_number}` : ''}
                </p>
              </li>
            ))}
          </ul>
          {data.coverage_note && (
            <p style={{ fontSize: '0.74rem', color: 'var(--color-sage)', margin: '14px 0 0' }}>
              {data.source_retrieved ? `Licence records as retrieved on ${data.source_retrieved}. ` : ''}{data.coverage_note}
            </p>
          )}
        </>
      )}
    </main>
  )
}
