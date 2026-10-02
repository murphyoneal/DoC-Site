import { notFound } from 'next/navigation'
import Link from 'next/link'

// Electrical licence register entry (ruling 927 item 1, as ruled in 905): the minimum honest page.
// What the Electrical Contractors' Licensing Board file holds for one licence, the file it came from and its date,
// the board's own lookup, and a claim route that says plainly what happens. Not a profile: no contact details, no
// photos, no ratings. One register, one table - this reads reg_us_fl.eclb_licence through get_eclb_entry, never the
// construction register.

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY ?? ''

type Entry = {
  found: boolean
  license_number?: string; class_code?: string; class_label?: string | null; class_label_state?: string | null
  trade?: string | null; licensee_name?: string | null; business_name?: string | null
  city?: string | null; county?: string | null
  primary_status_code?: string | null; secondary_status_code?: string | null; status_text?: string
  original_date?: string | null; effective_date?: string | null; expiry_date?: string | null
  in_latest_file?: boolean; file_name?: string | null; file_source_url?: string | null; file_date?: string | null
  board_lookup_url?: string
}

async function getEntry(licence: string): Promise<Entry | null> {
  if (!/^[A-Za-z]{2}[0-9]{4,10}$/.test(licence)) return { found: false }
  try {
    const r = await fetch(`https://${SB_HOST}/rest/v1/rpc/get_eclb_entry`, {
      method: 'POST',
      headers: { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_licence: licence }),
      next: { revalidate: 3600 },
    })
    if (!r.ok) return null
    return (await r.json()) as Entry
  } catch {
    return null
  }
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
// "2026-09-30" -> "30 Sep 2026", by hand: ICU prints "Sept" on some runtimes.
function isoDay(iso: string | null | undefined): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(iso ?? ''))
  return m ? `${+m[3]} ${MONTHS[+m[2] - 1]} ${m[1]}` : null
}

export async function generateMetadata({ params }: { params: Promise<{ licence: string }> }) {
  const { licence } = await params
  const e = await getEntry(decodeURIComponent(licence))
  if (!e?.found) return { title: 'Licence not found' }
  const name = e.business_name ?? e.licensee_name ?? e.license_number
  return {
    title: `${name} — electrical licence ${e.license_number}`,
    description: `${e.license_number}: ${e.class_label ?? e.class_code} in the Florida Electrical Contractors' Licensing Board file${e.file_date ? ` dated ${isoDay(e.file_date)}` : ''}.`,
  }
}

const row = { display: 'flex', gap: '12px', padding: '8px 0', borderBottom: '1px solid var(--color-light-gray)', fontSize: '0.86rem' } as const
const key = { width: '150px', flexShrink: 0, color: 'var(--color-sage)' } as const

export default async function ElectricalEntryPage({ params }: { params: Promise<{ licence: string }> }) {
  const { licence } = await params
  const e = await getEntry(decodeURIComponent(licence))
  if (e === null) {
    return (
      <main style={{ maxWidth: '720px', margin: '0 auto', padding: '32px 16px' }}>
        <p style={{ fontSize: '0.9rem', color: '#8a4a17' }}>This entry could not be loaded just now. That is a fault on our side, not a finding about the licence — please try again.</p>
      </main>
    )
  }
  if (!e.found) notFound()

  const name = e.business_name ?? e.licensee_name ?? e.license_number
  const fileDay = isoDay(e.file_date)
  const classText = e.class_label
    ? `${e.class_code} — ${e.class_label}`
    : `${e.class_code} (the board's page gives this class no title)`
  const mailSubject = encodeURIComponent(`Claim: electrical licence ${e.license_number}`)

  return (
    <main style={{ maxWidth: '720px', margin: '0 auto', padding: '32px 16px' }}>
      <p style={{ fontSize: '0.78rem', color: 'var(--color-sage)', margin: '0 0 6px' }}>
        <Link href="/" style={{ color: 'var(--color-bronze)' }}>Register</Link> · Electrical Contractors&rsquo; Licensing Board
      </p>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.45rem', fontWeight: 700, margin: '0 0 4px' }}>{name}</h1>
      <p style={{ fontSize: '0.9rem', color: 'var(--color-ink)', margin: '0 0 18px' }}>
        Florida electrical licence {e.license_number}{e.trade ? ` · ${e.trade}` : ''}
      </p>

      <section style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)', borderRadius: '12px', padding: '6px 18px 10px', marginBottom: '16px' }}>
        <div style={row}><span style={key}>Licence class</span><span>{classText}</span></div>
        {e.business_name && e.licensee_name && <div style={row}><span style={key}>Licensee</span><span>{e.licensee_name}</span></div>}
        {(e.city || e.county) && <div style={row}><span style={key}>Recorded location</span><span>{[e.city, e.county ? `${e.county} County` : null].filter(Boolean).join(', ')}</span></div>}
        <div style={row}><span style={key}>Status in the file</span><span>{e.status_text}</span></div>
        {e.original_date && <div style={row}><span style={key}>Original date</span><span>{e.original_date} (as published)</span></div>}
        {e.effective_date && <div style={row}><span style={key}>Effective date</span><span>{e.effective_date} (as published)</span></div>}
        {e.expiry_date && <div style={row}><span style={key}>Expiry date</span><span>{e.expiry_date} (as published)</span></div>}
        <div style={{ ...row, borderBottom: 'none' }}><span style={key}>Source</span>
          <span>
            The Florida DBPR electrical contractor licence file{fileDay ? `, dated ${fileDay}` : ''}{e.in_latest_file ? ' — this licence is in that file' : ''}.
            {e.file_source_url && <> <a href={e.file_source_url} style={{ color: 'var(--color-bronze)' }} rel="nofollow">The file</a>.</>}
          </span>
        </div>
      </section>

      <p style={{ fontSize: '0.84rem', color: 'var(--color-ink)', margin: '0 0 18px' }}>
        A licence register shows who is licensed now; this page shows the file as of its date, so the licence may have been
        renewed or changed since. Confirm current standing with the board: search licence number <strong>{e.license_number}</strong> on{' '}
        <a href={e.board_lookup_url} style={{ color: 'var(--color-bronze)' }} rel="nofollow">the state licence search</a>.
      </p>

      <section style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)', borderRadius: '12px', padding: '16px 18px' }}>
        <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.02rem', fontWeight: 700, margin: '0 0 6px' }}>Is this your licence?</h2>
        <p style={{ fontSize: '0.84rem', color: 'var(--color-ink)', margin: '0 0 10px' }}>
          Claiming electrical register entries online is not built yet. To claim this one or correct it, email{' '}
          <a href={`mailto:register@departmentofproperty.com?subject=${mailSubject}`} style={{ color: 'var(--color-bronze)' }}>register@departmentofproperty.com</a>{' '}
          from the address you want us to reply to, with the licence number. A person reads every message and replies by email.
          We can&rsquo;t yet promise how long that takes.
        </p>
        <p style={{ fontSize: '0.78rem', color: 'var(--color-sage)', margin: 0 }}>
          Nothing on this page is a rating or a recommendation. We hold the board&rsquo;s file; we do not hold complaints, discipline, insurance or bonding for any contractor.
        </p>
      </section>
    </main>
  )
}
