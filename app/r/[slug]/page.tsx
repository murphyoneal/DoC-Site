import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import { getRegisteredPage, countyDisplay, type PublicCredential } from '@/lib/registration'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'

// /r/{slug} - a SELF-REGISTERED business (work order 699, ruling 701 §3). A /c/ page is reproduced
// from a state register; this page is the business's own declaration. Different provenance,
// different page, different path. It exists only after a person approved it AND the business chose
// to be listed, and it shows only the fields the business switched on. Each credential is two
// facts: what the business declared, and what our check found - including "we can't check this".

type Params = Promise<{ slug: string }>

export async function generateMetadata({ params }: { params: Params }): Promise<Metadata> {
  const { slug } = await params
  const b = await getRegisteredPage(slug)
  if (!b) return { title: 'Not found' }
  return {
    title: `${b.business_name}: self-registered business in ${b.state}`,
    description: `${b.business_name} registered itself with us. What it declared, and what we could check against the state registers we hold.`,
  }
}

const KIND: Record<PublicCredential['kind'], string> = { licence: 'State licence', certification: 'Certification', insurance: 'Insurance' }

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
// "7 Sep 2026", as the rest of the site writes dates (en-GB would say "Sept").
function fmt(d: string | null) {
  const m = d?.match(/^(\d{4})-(\d{2})-(\d{2})/)
  return m ? `${Number(m[3])} ${MONTHS[Number(m[2]) - 1]} ${m[1]}` : null
}

export default async function RegisteredBusinessPage({ params }: { params: Params }) {
  const { slug } = await params
  const b = await getRegisteredPage(slug)
  if (!b) notFound()

  const where = [b.city, b.county ? countyDisplay(b.county, b.county_level) : null, b.state].filter(Boolean).join(', ')
  const trades = (b.trades ?? []).map(t => CATEGORY_LABELS[t] ?? t)

  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '24px 16px 48px' }}>
      <div style={{ maxWidth: 720, margin: '0 auto', display: 'grid', gap: 16 }}>
        <div className="reg-card">
          <span className="reg-label">Self-registered business</span>
          <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', margin: '10px 0 4px' }}>{b.business_name}</h1>
          <p style={{ fontSize: '0.9rem', color: 'var(--color-sage)', margin: '0 0 12px' }}>{where}</p>
          {trades.length > 0 && <p className="reg-p"><b>Trades:</b> {trades.join(', ')}</p>}
          {b.other_services && <p className="reg-p"><b>Also:</b> {b.other_services}</p>}
          {(b.public_phone || b.website) && (
            <p className="reg-p" style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
              {b.public_phone && <a href={`tel:${b.public_phone.replace(/[^\d+]/g, '')}`} style={{ color: 'var(--color-bronze)' }}>{b.public_phone}</a>}
              {b.website && <a href={b.website} rel="nofollow noopener noreferrer" target="_blank" style={{ color: 'var(--color-bronze)' }}>Website</a>}
            </p>
          )}
          <p style={{ fontSize: '0.78rem', color: 'var(--color-sage)', margin: '8px 0 0', lineHeight: 1.5 }}>
            This page is the business&rsquo;s own declaration, not an entry reproduced from a state register. It registered
            itself on {fmt(b.registered_on)}{b.approved_on ? ` and was reviewed by a person on ${fmt(b.approved_on)}` : ''}.
            It shows only what the business chose to show.
          </p>
        </div>

        <div className="reg-card">
          <h2 className="reg-h2" style={{ marginTop: 0, marginBottom: 10 }}>Licences, certifications and insurance</h2>
          {b.credentials.length === 0 ? (
            <p className="reg-p">The business has not chosen to show any credentials here.</p>
          ) : (
            <ul className="reg-checks">
              {b.credentials.map((c, i) => (
                <li key={i} style={{ borderTop: i ? '1px solid #eee' : 0, paddingTop: i ? 10 : 0 }}>
                  <b>{KIND[c.kind]}{c.number ? ` ${c.number}` : ''}</b>
                  {c.issuing_state ? `, ${c.issuing_state}` : ''}
                  {c.trade ? ` · ${CATEGORY_LABELS[c.trade] ?? c.trade}` : ''}
                  {c.issuer ? ` · ${c.issuer}` : ''}
                  {c.expires_on ? ` · expires ${fmt(c.expires_on)}` : ''}
                  <br />
                  <span style={{ fontSize: '0.82rem', color: 'var(--color-ink)' }}>Declared by the business on {fmt(c.declared_at)}.</span>
                  <br />
                  <span className={'reg-check ' + c.check_state}>
                    Our check ({fmt(c.checked_at)}): {c.check_note}
                    {c.check_state === 'register_held_matched' && c.matched_slug && (
                      <> <a href={`/c/${c.matched_slug}`} style={{ color: 'var(--color-bronze)' }}>See the register entry</a>.</>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </main>
  )
}
