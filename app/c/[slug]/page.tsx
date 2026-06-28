import { notFound } from 'next/navigation'
import Link from 'next/link'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWZxb3J3bWdheWlxbWJ0emNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjMxNjIzOCwiZXhwIjoyMDk3ODkyMjM4fQ.L23cjzASjDbuFQ1zeQt30CThOSX_aRwyWpbl7QLeO-E'
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors?slug=eq.${encodeURIComponent(slug)}&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 60 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

async function getPermitSummary(slug: string) {
  // Get contractor name to fuzzy-match permits
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors?slug=eq.${encodeURIComponent(slug)}&select=business_name&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 300 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  if (!rows?.[0]?.business_name) return null

  const name = rows[0].business_name.toUpperCase()
  const permitRes = await fetch(
    `https://${SB_HOST}/rest/v1/property_permit_history?contractor_name=ilike.*${encodeURIComponent(name)}*&select=trade_category,permit_date,job_value&limit=100`,
    { headers: SB_HEADERS, next: { revalidate: 300 } }
  )
  if (!permitRes.ok) return null
  return await permitRes.json()
}

const CATEGORY_LABELS: Record<string, string> = {
  general_contractor: 'General Contractor',
  roofing: 'Roofing',
  plumbing: 'Plumbing',
  hvac: 'HVAC',
  electrical: 'Electrical',
  pool_spa: 'Pool & Spa',
  solar: 'Solar',
  painting: 'Painting',
  flooring: 'Flooring',
  masonry: 'Masonry',
  landscaping: 'Landscaping',
  windows_doors: 'Windows & Doors',
  insulation: 'Insulation',
  drywall: 'Drywall',
  fencing: 'Fencing',
  fire_protection: 'Fire Protection',
  residential_contractor: 'Residential Contractor',
  general_engineering: 'General Engineering',
  pressure_washing: 'Pressure Washing',
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Contractor Not Found' }
  return {
    title: `${c.display_name} | Department of Construction`,
    description: `${CATEGORY_LABELS[c.doc_category] ?? 'Contractor'} in ${c.city ?? 'Florida'}. License ${c.license_number}.`,
  }
}

export default async function ContractorProfilePage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) notFound()

  const permits = await getPermitSummary(slug)
  const permitCount = permits?.length ?? 0
  const totalValue = permits?.reduce((sum: number, p: any) => sum + (p.job_value ?? 0), 0) ?? 0

  const tradeLabel = CATEGORY_LABELS[c.doc_category] ?? c.trade_label ?? 'Contractor'

  const statusColor =
    c.license_status === 'active'  ? '#2d7d46' :
    c.license_status === 'expired' ? '#c0392b' : '#8B6F47'

  const address = [c.address_line_1, c.city, c.state, c.zip_code].filter(Boolean).join(', ')

  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '0' }}>

      {/* Header bar */}
      <div style={{ background: 'var(--color-navy)', padding: '12px 24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <Link href="/" style={{ color: 'var(--color-bronze)', textDecoration: 'none', fontSize: '0.82rem' }}>
          ← Department of Construction
        </Link>
      </div>

      <div style={{ maxWidth: '760px', margin: '0 auto', padding: '32px 16px' }}>

        {/* Profile card */}
        <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '28px', marginBottom: '20px' }}>

          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: '16px', flexWrap: 'wrap' }}>
            <div style={{ flex: 1 }}>
              <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.5rem', fontWeight: 700, margin: '0 0 4px' }}>
                {c.display_name}
              </h1>
              <p style={{ color: 'var(--color-bronze)', fontSize: '0.9rem', margin: '0 0 8px' }}>{tradeLabel}</p>
              {address && (
                <p style={{ color: 'var(--color-sage)', fontSize: '0.82rem', margin: '0 0 4px' }}>{address}</p>
              )}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '6px' }}>
              <span style={{
                padding: '4px 12px', borderRadius: '20px', fontSize: '0.78rem', fontWeight: 600,
                background: statusColor + '18', color: statusColor, border: `1px solid ${statusColor}40`
              }}>
                {c.license_status ? c.license_status.charAt(0).toUpperCase() + c.license_status.slice(1) : 'Unknown'}
              </span>
              {c.verified && (
                <span style={{ fontSize: '0.75rem', color: 'var(--color-navy)', background: '#e8f0fb', padding: '3px 10px', borderRadius: '20px' }}>
                  ✓ Verified
                </span>
              )}
              {c.emergency_available && (
                <span style={{ fontSize: '0.75rem', color: '#c0392b', background: '#fde8e8', padding: '3px 10px', borderRadius: '20px', fontWeight: 600 }}>
                  🚨 Emergency Available
                </span>
              )}
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
                <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Expiry</p>
                <p style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--color-ink)', margin: 0 }}>{c.expiry_date}</p>
              </div>
            )}
            {c.county_name && (
              <div>
                <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>County</p>
                <p style={{ fontSize: '0.88rem', fontWeight: 600, color: 'var(--color-ink)', margin: 0 }}>{c.county_name}</p>
              </div>
            )}
          </div>

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

        {/* Permit history summary */}
        {permitCount > 0 && (
          <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '20px', marginBottom: '20px' }}>
            <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1rem', fontWeight: 700, margin: '0 0 12px' }}>
              Permit History (Volusia County)
            </h2>
            <div style={{ display: 'flex', gap: '24px', flexWrap: 'wrap' }}>
              <div>
                <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Permits Found</p>
                <p style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--color-navy)', margin: 0 }}>{permitCount}</p>
              </div>
              {totalValue > 0 && (
                <div>
                  <p style={{ fontSize: '0.72rem', color: 'var(--color-sage)', margin: '0 0 2px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Total Job Value</p>
                  <p style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--color-navy)', margin: 0 }}>
                    ${totalValue.toLocaleString()}
                  </p>
                </div>
              )}
            </div>
            <p style={{ fontSize: '0.75rem', color: 'var(--color-sage)', margin: '12px 0 0' }}>
              * Permit records are matched by business name and are unverified. Contractors can verify their permit history by claiming this profile.
            </p>
          </div>
        )}

        {/* Claim CTA */}
        {!c.claimed && (
          <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '20px', marginBottom: '20px' }}>
            <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1rem', fontWeight: 700, margin: '0 0 6px' }}>
              Is this your business?
            </h2>
            <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 14px' }}>
              Claim this profile to update your contact details, verify your permit history, and receive project enquiries.
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
              ✓ This profile has been claimed and verified by the licence holder.
            </p>
          </div>
        )}

        {/* QR / vCard */}
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
          <Link
            href={`/api/qr/${slug}`}
            style={{
              padding: '9px 18px', borderRadius: '8px', fontSize: '0.8rem', fontWeight: 600,
              background: 'var(--color-cream)', color: 'var(--color-navy)',
              textDecoration: 'none', border: '1px solid var(--color-light-gray)',
            }}
          >
            QR Code
          </Link>
        </div>

      </div>
    </main>
  )
}
