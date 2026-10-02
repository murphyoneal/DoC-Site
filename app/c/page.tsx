import Link from 'next/link'
import { COUNTY_KEYS, COUNTY_KEYS_BY_LABEL, countyLabel } from '@/lib/county'
import { notHeldNote } from '@/lib/licence-status'
import { getRegisterPostedDate } from '@/lib/register-date'

// "Search another contractor" — where a profile's search box goes (work order 653 (c)).
// Backed by register_search (201b): both Florida contractor registers - the construction file (Construction Industry
// Licensing Board) and the electrical file (Electrical Contractors' Licensing Board) - the same function the public
// register page uses. One row per LICENCE record from one board's file; results stay grouped by register and each row
// links to its own page (href): /c/<slug> for construction, /e/<licence> for electrical.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''

type Result = {
  register: 'construction' | 'electrical'; href: string; name: string; licensee?: string | null
  trade: string | null; class_code?: string | null; class_label?: string | null
  city: string | null; county: string | null; license_number: string | null
  status_text?: string | null; file_date?: string | null
}
type Register = { register: string; label: string; file_date: string | null; count: number; returned: number }
type Payload = { field_status: string; count: number; returned: number; results: Result[]; registers?: Register[]; coverage_note?: string }

async function search(q: string): Promise<Payload | null> {
  try {
    const res = await fetch(`https://${SB_HOST}/rest/v1/rpc/register_search`, {
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

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
function isoDay(iso: string | null | undefined): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso ?? ''))
  return m ? `${+m[3]} ${MONTHS[+m[2] - 1]} ${m[1]}` : null
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
  const rawCounty = String(Array.isArray(sp.county) ? sp.county[0] : sp.county ?? '').toLowerCase()
  const county = (COUNTY_KEYS as readonly string[]).includes(rawCounty) ? rawCounty : ''
  // Every word must match (name, licence, trade or class, city or county); a picked county is a strict
  // filter, sent as county:<key> so a word like "orange" cannot stand in for Orange County.
  const query = [q, county ? `county:${county}` : ''].filter(Boolean).join(' ')
  const [data, postedDate] = await Promise.all([q.length >= 2 || county ? search(query) : Promise.resolve(null), getRegisterPostedDate()])
  const groups = (data?.registers ?? []).map(reg => ({ reg, rows: (data?.results ?? []).filter(r => r.register === reg.register) }))

  return (
    <main style={{ maxWidth: '760px', margin: '0 auto', padding: '32px 16px' }}>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', fontWeight: 700, margin: '0 0 6px' }}>
        Search contractors
      </h1>
      <p style={{ fontSize: '0.82rem', color: 'var(--color-sage)', margin: '0 0 14px' }}>
        Two Florida state licence files: construction (Construction Industry Licensing Board) and electrical (Electrical Contractors&rsquo; Licensing Board).
      </p>
      <form action="/c" method="get" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '20px' }}>
        <label htmlFor="q" style={{ position: 'absolute', left: '-9999px' }}>Business name or licence number</label>
        <input id="q" name="q" type="search" defaultValue={q} minLength={2}
          placeholder="e.g. roofing, alarm, a business name, or a licence number"
          style={{ flex: '1 1 240px', padding: '10px 12px', borderRadius: '8px', border: '1px solid #cfc8bd', fontSize: '0.9rem' }} />
        <label htmlFor="county" style={{ position: 'absolute', left: '-9999px' }}>County</label>
        <select id="county" name="county" defaultValue={county}
          style={{ padding: '10px 12px', borderRadius: '8px', border: '1px solid #cfc8bd', fontSize: '0.9rem', background: 'white' }}>
          <option value="">All Florida counties</option>
          {COUNTY_KEYS_BY_LABEL.map(k => (
            <option key={k} value={k}>{countyLabel(k)}</option>
          ))}
        </select>
        <button type="submit" style={{ padding: '10px 18px', borderRadius: '8px', border: 'none', background: 'var(--color-navy)', color: 'white', fontWeight: 600 }}>
          Search
        </button>
      </form>

      {(q.length >= 2 || county) && data === null && (
        <p style={{ fontSize: '0.86rem', color: '#8a4a17' }}>The search could not be run just now. This is a fault on our side — please try again.</p>
      )}

      {data && data.field_status !== 'present' && (
        <p style={{ fontSize: '0.86rem', color: 'var(--color-sage)' }}>
          Nothing in either licence file we hold matched &ldquo;{q}&rdquo;{county ? ` in ${countyLabel(county)} County` : ''}. Every word has to match a name, licence number, trade or class, city or county.
          {' '}{notHeldNote(postedDate)}
          {' '}<Link href="/register-your-business">Not listed? Register your business</Link>.</p>
      )}

      {data && data.field_status === 'present' && groups.map(({ reg, rows }) => (
        <section key={reg.register} style={{ marginBottom: '22px' }}>
          <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.02rem', fontWeight: 700, margin: '0 0 4px' }}>
            {reg.register === 'electrical' ? 'Electrical' : 'Construction'} — {reg.label}
          </h2>
          <p style={{ fontSize: '0.78rem', color: 'var(--color-sage)', margin: '0 0 10px' }}>
            {reg.count === 0
              ? 'No matching licence records in this file.'
              : reg.count > reg.returned
                ? `Showing ${reg.returned} of ${reg.count} matching licence records — add a word or pick a county to narrow it.`
                : `${reg.count} matching licence record${reg.count === 1 ? '' : 's'}.`}
            {isoDay(reg.file_date) ? ` From the state file dated ${isoDay(reg.file_date)}.` : ''}
          </p>
          {rows.length > 0 && (
            <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '10px' }}>
              {rows.map(r => (
                <li key={`${r.register}-${r.license_number}-${r.href}`} style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)', borderRadius: '10px', padding: '12px 14px' }}>
                  <Link href={r.href} style={{ color: 'var(--color-navy)', fontWeight: 700, textDecoration: 'none' }}>{r.name}</Link>
                  <p style={{ fontSize: '0.8rem', color: 'var(--color-sage)', margin: '2px 0 0' }}>
                    {[r.register === 'electrical' ? (r.class_label ?? r.class_code) : r.trade, r.city, r.county ? `${r.county} County` : null].filter(Boolean).join(' · ')}
                    {r.license_number ? ` · Licence ${r.license_number}` : ''}
                    {r.register === 'electrical' && r.status_text ? ` · ${r.status_text}` : ''}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </section>
      ))}

      {data && data.field_status === 'present' && data.coverage_note && (
        <p style={{ fontSize: '0.74rem', color: 'var(--color-sage)', margin: '6px 0 0' }}>{data.coverage_note}</p>
      )}
    </main>
  )
}
