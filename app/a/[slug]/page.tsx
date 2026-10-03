import type { Metadata } from 'next'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { getAgentPage } from '@/lib/agent-profile'
import { fileDate } from '@/lib/licence-status'

// /a/{slug} - a Florida real estate licensee's page (work order 712, R4). It exists only once a person
// has approved the agent's claim. The register block is the state's record, each value dated; the
// agent's own details follow, switch by switch. A brokerage the agent declares sits BESIDE the
// register's, never over it.

type P = Promise<{ slug: string }>

export async function generateMetadata({ params }: { params: P }): Promise<Metadata> {
  const a = await getAgentPage((await params).slug)
  if (!a) return { title: 'Not found' }
  return { title: `${a.register.name}: Florida real estate licence ${a.register.license_number}`,
           description: `${a.register.rank ?? 'Real estate licensee'}. Licence status as recorded in the Florida real estate licence register.` }
}

const row = (label: string, value: React.ReactNode) => value ? (
  <div style={{ display: 'flex', gap: 12, fontSize: '0.86rem', padding: '4px 0', borderBottom: '1px solid #f0ece6' }}>
    <span style={{ width: 150, flexShrink: 0, color: 'var(--color-sage)' }}>{label}</span><span>{value}</span>
  </div>) : null

export default async function AgentPublicPage({ params }: { params: P }) {
  const { slug } = await params
  const a = await getAgentPage(slug)
  if (!a) notFound()
  const r = a.register, o = a.own
  const hasOwn = Object.keys(o).some(k => k !== 'updated_on')
  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '24px 16px 48px' }}>
      <div style={{ maxWidth: 720, margin: '0 auto', display: 'grid', gap: 16 }}>
        <div className="reg-card">
          <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', margin: '0 0 4px' }}>{r.name}</h1>
          <p style={{ fontSize: '0.86rem', color: 'var(--color-sage)', margin: '0 0 12px' }}>{r.rank ?? 'Real estate licensee'} · Florida licence {r.license_number}</p>
          {row('Status', r.status ?? 'Not in the status file we hold')}
          {row('Expires', fileDate(r.expiry))}
          {row('Brokerage', r.brokerage)}
          {row('County on the licence', r.county)}
          {row('First licensed', fileDate(r.first_issued))}
          <p style={{ fontSize: '0.74rem', color: 'var(--color-sage)', margin: '10px 0 0' }}>
            {r.source} Status, expiry and brokerage as retrieved {fileDate(r.status_as_of) ?? 'on an unrecorded date'}. Confirm current standing at myfloridalicense.com.
          </p>
        </div>
        {hasOwn && (
          <div className="reg-card">
            <h2 className="reg-h2" style={{ marginTop: 0 }}>From the agent</h2>
            <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '2px 0 10px' }}>Added by the agent{o.updated_on ? `, last updated ${fileDate(o.updated_on)}` : ''}. Not from the state registerce file.</p>
            {o.bio && <p style={{ fontSize: '0.86rem', margin: '0 0 10px', whiteSpace: 'pre-line' }}>{o.bio}</p>}
            {(o.phone || o.email || o.website) && (
              <p style={{ display: 'flex', gap: 14, flexWrap: 'wrap', margin: '0 0 8px', fontSize: '0.84rem' }}>
                {o.phone && <a href={`tel:${o.phone.replace(/[^\d+]/g, '')}`} style={{ color: 'var(--color-bronze)' }}>{o.phone}</a>}
                {o.email && <a href={`mailto:${o.email}`} style={{ color: 'var(--color-bronze)' }}>{o.email}</a>}
                {o.website && <a href={o.website} target="_blank" rel="nofollow noopener noreferrer" style={{ color: 'var(--color-bronze)' }}>Website</a>}
              </p>
            )}
            {o.property_classes?.length ? <p style={{ fontSize: '0.84rem', margin: '0 0 6px' }}><b>Works in:</b> {o.property_classes.join(', ')} property</p> : null}
            {o.counties?.length ? <p style={{ fontSize: '0.84rem', margin: '0 0 6px' }}><b>Counties served:</b> {o.counties.join('; ')}</p> : null}
            {o.declared_brokerage && (
              <p style={{ fontSize: '0.84rem', margin: '0 0 6px' }}><b>Brokerage, as the agent states it:</b> {o.declared_brokerage}
                {r.brokerage && o.declared_brokerage.toUpperCase() !== r.brokerage.toUpperCase() &&
                  <span style={{ color: 'var(--color-sage)' }}> (the state register, retrieved {fileDate(r.status_as_of)}, shows {r.brokerage})</span>}</p>
            )}
          </div>
        )}
        <p style={{ fontSize: '0.76rem', color: 'var(--color-sage)', margin: 0 }}>
          Is this you? <Link href={`/a/${slug}/edit`} style={{ color: 'var(--color-bronze)' }}>Edit your details</Link> (sign in with the email on your approved claim).
        </p>
      </div>
    </main>
  )
}
