import { notFound, permanentRedirect } from 'next/navigation'
import { headers } from 'next/headers'
import { after } from 'next/server'
import Link from 'next/link'
import { logScanServer, requestMeta, firstParam } from '@/lib/scan'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'
import { resolveBusinessSlug, getBusinessLicences, getRelatedBusinesses, withQuery } from '@/lib/business'
import { countyLabel, countyLanding as countyLandingFor } from '@/lib/county'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
// Read from the environment — never hardcode the key. Set SUPABASE_SECRET_KEY in
// Vercel (and .env.local for local dev). Matches lib/supabase/server.ts.
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors_public?slug=eq.${encodeURIComponent(slug)}&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 60 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

// The date the licence data was retrieved from DBPR — the same log row the public register
// search stamps its results with, so the two surfaces can never show different dates.
async function getRecordDate(): Promise<string | null> {
  try {
    const res = await fetch(
      `https://${SB_HOST}/rest/v1/dbpr_snapshot_log?is_register_source=eq.true&select=capture_date&limit=1`,
      { headers: SB_HEADERS, next: { revalidate: 3600 } }
    )
    if (!res.ok) return null
    const rows = await res.json()
    const d = rows?.[0]?.capture_date
    return d ? new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }) : null
  } catch {
    return null
  }
}

// There is deliberately no permit section. It matched Volusia permits by business-name substring
// (contractor_name is cut at 30 characters, so long names never matched and short ones matched
// other firms) and showed "Permits Found: 100" — the query's limit, not a count. Permits stay off
// profiles until the match is measured against an anchor (ruling 2026-09-26).


export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Contractor Not Found' }
  return {
    title: `${c.display_name}`,
    description: `${CATEGORY_LABELS[c.doc_category] ?? 'Contractor'} in ${c.city ?? 'Florida'}. License ${c.license_number}.`,
  }
}

export default async function ContractorProfilePage({
  params,
  searchParams,
}: {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>
}) {
  const { slug } = await params
  const sp = await searchParams
  const ref = firstParam(sp.ref)
  // Request data must be read here: a Server Component cannot read headers inside after().
  const meta = requestMeta(await headers())

  // A retired slug (another licence record of the same business) redirects permanently to the
  // business's slug, keeping ?ref so a printed QR scan is still attributed. The hop itself is
  // logged: it is how we learn an old slug — often a printed code — is still in circulation.
  const business = await resolveBusinessSlug(slug)
  if (business?.redirect) {
    after(() => logScanServer({ slug, ref, action: 'slug_redirect', meta }))
    permanentRedirect(withQuery(`/c/${business.slug}`, sp))
  }

  const c = await getContractor(slug)
  if (!c) notFound()

  // Logged by the request, not the browser: counts visitors without JavaScript too.
  after(() => logScanServer({
    slug, ref, action: 'page_view',
    tradeCategory: c.doc_category, city: c.city, state: c.state, meta,
  }))

  const licences = business ? await getBusinessLicences(business.slug) : []
  const recordDate = await getRecordDate()
  const related = business ? await getRelatedBusinesses(business.slug) : null
  const countyTitle = countyLabel(c.county_name)
  const countyLanding = countyLandingFor(c.county_name)


  const tradeLabel = CATEGORY_LABELS[c.doc_category] ?? c.trade_label ?? 'Contractor'

  const statusColor =
    c.license_status === 'active'  ? '#2d7d46' :
    c.license_status === 'expired' ? '#c0392b' : '#8B6F47'

  // No street: the registered address is usually a sole trader's home, and it is published only
  // if the business chooses to at claim time (ruling 2026-09-24). contractors_public nulls it too.
  const address = [c.city, c.state, c.zip_code].filter(Boolean).join(', ')

  const qrUrl = `/api/qr/${slug}?ref=profile&size=200`
  const scanUrl = `/c/${slug}/scan`

  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '0' }}>


      {/* Header bar */}
      <div style={{ background: 'var(--color-navy)', padding: '12px 24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <Link href="/" style={{ color: 'var(--color-bronze)', textDecoration: 'none', fontSize: '0.82rem' }}>
          ← Department of Property
        </Link>
      </div>

      <div style={{ maxWidth: '760px', margin: '0 auto', padding: '32px 16px' }}>

        {/* Profile card */}
        <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '28px', marginBottom: '20px' }}>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '24px', flexWrap: 'wrap' }}>
            <div style={{ flex: 1, minWidth: '200px' }}>
              <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.5rem', fontWeight: 700, margin: '0 0 4px' }}>
                {c.display_name}
              </h1>
              <p style={{ color: 'var(--color-bronze)', fontSize: '0.9rem', margin: '0 0 8px' }}>{tradeLabel}</p>
              {address && (
                <p style={{ color: 'var(--color-sage)', fontSize: '0.82rem', margin: '0 0 12px' }}>{address}</p>
              )}

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                <span style={{
                  padding: '4px 12px', borderRadius: '20px', fontSize: '0.78rem', fontWeight: 600,
                  background: statusColor + '18', color: statusColor, border: `1px solid ${statusColor}40`
                }}>
                  {/* DBPR's status field, reproduced — not our endorsement. */}
                  Licence status: {c.license_status ? c.license_status.charAt(0).toUpperCase() + c.license_status.slice(1) : 'Unknown'}
                </span>
                {/* This is the page a QR code lands on: the reader has no other way to know how old
                    the record is. */}
                <span style={{ fontSize: '0.72rem', fontWeight: 600, letterSpacing: '0.04em', textTransform: 'uppercase', color: 'var(--color-sage)', border: '1px solid var(--color-light-gray)', padding: '4px 10px', borderRadius: '20px' }}>
                  {recordDate ? `Record dated ${recordDate}` : 'Record date not available'}
                </span>
                {c.verified && (
                  <span style={{ fontSize: '0.75rem', color: 'var(--color-navy)', background: '#e8f0fb', padding: '3px 10px', borderRadius: '20px' }}>
                    ✓ Verified
                  </span>
                )}
                {c.emergency_available && (
                  <span style={{ fontSize: '0.75rem', color: '#c0392b', background: '#fde8e8', padding: '3px 10px', borderRadius: '20px', fontWeight: 600 }}>
                    🚨 Emergency
                  </span>
                )}
              </div>
            </div>

            {/* QR Code — always visible */}
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '6px', flexShrink: 0 }}>
              <a href={scanUrl} title="Scan to view mobile profile">
                <img
                  src={qrUrl}
                  alt={`QR code for ${c.display_name}`}
                  width={120}
                  height={120}
                  style={{ borderRadius: '8px', border: '1px solid var(--color-light-gray)', display: 'block' }}
                />
              </a>
              <span style={{ fontSize: '0.68rem', color: 'var(--color-sage)', textAlign: 'center' }}>Scan or share</span>
              <a
                href={`/api/qr/${slug}?ref=download&size=512`}
                download={`doc-qr-${slug}.png`}
                style={{ fontSize: '0.72rem', color: 'var(--color-bronze)', textDecoration: 'underline' }}
              >
                Download hi-res
              </a>
            </div>
          </div>

          {/* License info */}
          <div style={{ marginTop: '20px', padding: '14px', background: 'var(--color-cream)', borderRadius: '8px', display: 'flex', flexWrap: 'wrap', gap: '20px' }}>
            <div>
              <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>License Number</p>
              <p style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--color-ink)', margin: 0 }}>{c.license_number ?? '—'}</p>
            </div>
            {c.expiry_date && (
              <div>
                <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Expiry (as recorded)</p>
                <p style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--color-ink)', margin: 0 }}>{c.expiry_date}</p>
              </div>
            )}
            {c.county_name && (
              <div>
                <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>County</p>
                <p style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--color-ink)', margin: 0 }}>{countyTitle}</p>
              </div>
            )}
            <p style={{ flexBasis: '100%', fontSize: '0.74rem', color: 'var(--color-sage)', margin: 0 }}>
              Licence status and expiry are reproduced from the Florida DBPR public licence file
              {recordDate ? ` as retrieved on ${recordDate}` : ''}. They may have changed since — a licence
              may have been renewed, or its status changed. Confirm current standing at myfloridalicense.com.
            </p>
          </div>

          {/* Every licence record of this business. DBPR publishes one row per licence, so a
              business holding two licences was two profiles; it is one business now. */}
          {licences.length > 1 && (
            <div style={{ marginTop: '16px' }}>
              <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 6px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                Licence records for this business
              </p>
              <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '6px' }}>
                {licences.map(l => (
                  <li key={`${l.link_basis}-${l.license_number}-${l.trade_code}`} style={{ fontSize: '0.84rem', color: 'var(--color-ink)' }}>
                    <strong>{l.license_number ?? '—'}</strong>
                    {' · '}{l.trade_label ?? l.trade_code}
                    {l.license_status && <> · {l.license_status}</>}
                    {l.expiry_date && <> · expires {l.expiry_date}</>}
                    {l.link_basis === 'qualifier' && (
                      <span style={{ color: 'var(--color-sage)' }}> · the licence DBPR records as qualifying this business{l.holder_name ? ` (${l.holder_name})` : ''}</span>
                    )}
                  </li>
                ))}
              </ul>
              <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '6px 0 0' }}>
                As published in the DBPR licence file. Confirm current standing at myfloridalicense.com.
              </p>
            </div>
          )}

          {/* Contact */}
          {(c.phone || c.email || c.website) && (
            <div style={{ marginTop: '16px', display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
              {c.phone && (
                <a href={`tel:${c.phone}`} style={{ fontSize: '0.84rem', color: 'var(--color-bronze)', textDecoration: 'none' }}>
                  📞 {c.phone}
                </a>
              )}
              {c.email && (
                <a href={`mailto:${c.email}`} style={{ fontSize: '0.84rem', color: 'var(--color-bronze)', textDecoration: 'none' }}>
                  ✉ {c.email}
                </a>
              )}
              {c.website && (
                <a href={c.website} target="_blank" rel="noopener noreferrer" style={{ fontSize: '0.84rem', color: 'var(--color-bronze)', textDecoration: 'none' }}>
                  🌐 Website
                </a>
              )}
            </div>
          )}
        </div>

        {/* Claim CTA */}
        {!c.claimed && (
          <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '20px', marginBottom: '20px' }}>
            <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1rem', fontWeight: 700, margin: '0 0 6px' }}>
              Is this your business?
            </h2>
            <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 14px' }}>
              Claim this entry to add your own details &mdash; contact, photos, specialties. Nothing you add is published until you add it.
            </p>
            <Link
              href={`/claim/${slug}`}
              style={{
                display: 'inline-block', padding: '10px 24px', borderRadius: '8px',
                background: 'var(--color-bronze)', color: 'white',
                fontSize: '0.84rem', fontWeight: 600, textDecoration: 'none',
              }}
            >
              Claim This Profile →
            </Link>
          </div>
        )}

        {c.claimed && (
          <div style={{ background: '#f0fdf4', borderRadius: '14px', border: '1px solid #bbf7d0', padding: '16px', marginBottom: '20px' }}>
            <p style={{ fontSize: '0.84rem', color: '#166534', margin: 0, fontWeight: 600 }}>
              ✓ This entry has been claimed by the business.
            </p>
          </div>
        )}

        {/* vCard */}
        <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
          <a
            href={`/api/vcard/${slug}`}
            style={{
              padding: '9px 18px', borderRadius: '8px', fontSize: '0.8rem', fontWeight: 600,
              background: 'var(--color-navy)', color: 'white', textDecoration: 'none',
            }}
          >
            ↓ Save Contact
          </a>
        </div>

        {/* Everything about THIS business comes first; alternatives come after the claim card
            (ruling 2026-09-25). The order is claimed-first then alphabetical — never a ranking. */}
        {related?.field_status === 'present' && related.items.length > 0 && (
          <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '20px', marginTop: '28px' }}>
            <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1rem', fontWeight: 700, margin: '0 0 4px' }}>
              Other {tradeLabel} businesses in {countyTitle} County
            </h2>
            <p style={{ fontSize: '0.74rem', color: 'var(--color-sage)', margin: '0 0 12px' }}>
              Listed alphabetically{related.items.some(r => r.claimed) ? ', claimed profiles first' : ''}. Not a ranking or a recommendation.
            </p>
            <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: '8px' }}>
              {related.items.map(r => (
                <li key={r.slug} style={{ fontSize: '0.86rem' }}>
                  <Link href={`/c/${r.slug}`} style={{ color: 'var(--color-navy)', fontWeight: 600, textDecoration: 'none' }}>{r.name}</Link>
                  {r.city && <span style={{ color: 'var(--color-sage)' }}> · {r.city}</span>}
                </li>
              ))}
            </ul>
          </div>
        )}

        {/* The way off the page. Forward, not back: the header link only reached a finder by
            accident of what the apex happens to serve. */}
        <div style={{ marginTop: '20px', padding: '20px', borderRadius: '14px', background: 'var(--color-light-gray)' }}>
          <form action="/c" method="get" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            <label htmlFor="contractor-search" style={{ position: 'absolute', left: '-9999px' }}>Search another contractor</label>
            <input
              id="contractor-search" name="q" type="search" required minLength={2}
              placeholder="Search another contractor by name or licence number"
              style={{ flex: '1 1 240px', padding: '10px 12px', borderRadius: '8px', border: '1px solid #cfc8bd', fontSize: '0.86rem' }}
            />
            <button type="submit" style={{ padding: '10px 18px', borderRadius: '8px', border: 'none', background: 'var(--color-navy)', color: 'white', fontSize: '0.84rem', fontWeight: 600 }}>
              Search
            </button>
          </form>
          <p style={{ fontSize: '0.78rem', margin: '10px 0 0' }}>
            <Link href={countyLanding} style={{ color: 'var(--color-bronze)' }}>
              {countyLanding === '/florida' ? 'Browse contractors across Florida →' : `Browse contractors in ${countyTitle} County →`}
            </Link>
          </p>
        </div>

      </div>
    </main>
  )
}
