import type { Metadata } from 'next'
import { notFound } from 'next/navigation'
import Link from 'next/link'
import { contractorSocket } from '@/lib/sockets/contractors'
import StatusBadge from '@/app/components/StatusBadge'

interface Props {
  params: Promise<{ slug: string }>
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const contractor = await contractorSocket.forProfile(slug)
  if (!contractor) return { title: 'Contractor Not Found' }

  return {
    title: `${contractor.display_name} — ${contractor.trade_label ?? 'Contractor'} in ${contractor.city ?? ''}, ${contractor.state ?? ''} | DoC`,
    description: `${contractor.display_name} is a ${contractor.trade_label ?? 'licensed contractor'} based in ${contractor.city ?? ''}, ${contractor.state ?? ''}. Licence ${contractor.license_number ?? ''} — ${contractor.license_status ?? 'status unknown'}.`,
    openGraph: {
      title: contractor.display_name,
      description: `${contractor.trade_label} · ${contractor.city}, ${contractor.state}`,
    },
  }
}

export default async function ContractorProfilePage({ params }: Props) {
  const { slug } = await params
  const c = await contractorSocket.forProfile(slug)
  if (!c) notFound()

  const specialistFlags = [
    c.ada_compliant_work         && 'ADA Compliant Work',
    c.aging_in_place             && 'Aging-in-Place',
    c.chemical_sensitivity_aware && 'Chemical Sensitivity Aware',
    c.mobility_accessible_worksite && 'Accessible Worksite',
    c.hurricane_hardening        && 'Hurricane Hardening',
    c.impact_window_certified    && 'Impact Window Certified',
    c.roof_certification         && 'Roof Certification',
    c.storm_restoration          && 'Storm Restoration',
  ].filter(Boolean) as string[]

  const emergencyFlags = [
    c.emergency_available       && 'Emergency Services',
    c.emergency_plumbing        && 'Emergency Plumbing',
    c.emergency_roofing         && 'Emergency Roofing',
    c.emergency_electrical      && 'Emergency Electrical',
    c.emergency_storm_damage    && 'Storm Damage Response',
    c.emergency_water_damage    && 'Water Damage Response',
    c.emergency_board_up        && 'Board-Up Services',
  ].filter(Boolean) as string[]

  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'LocalBusiness',
    name: c.display_name,
    description: c.trade_label ?? undefined,
    identifier: c.license_number ?? undefined,
    address: {
      '@type': 'PostalAddress',
      addressLocality: c.city ?? undefined,
      addressRegion: c.state ?? undefined,
      addressCountry: c.country_code ?? 'US',
    },
    ...(c.lat && c.lng ? {
      geo: {
        '@type': 'GeoCoordinates',
        latitude: c.lat,
        longitude: c.lng,
      },
    } : {}),
    url: `https://departmentofconstruction.com/c/${c.slug}`,
  }

  const tierLabelColour = c.verified
    ? { bg: '#e8f0fb', text: '#1B2A4A' }
    : { bg: '#f5f0e8', text: '#8B6F47' }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />

      <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
        <nav className="text-xs mb-4" style={{ color: 'var(--color-sage)' }}>
          <Link href="/" className="hover:underline">Home</Link>
          {' / '}
          {c.state && (
            <>
              <Link href={`/${c.state.toLowerCase()}`} className="hover:underline">
                {c.state}
              </Link>
              {' / '}
            </>
          )}
          <span style={{ color: 'var(--color-ink)' }}>{c.display_name}</span>
        </nav>

        <div
          className="rounded-xl p-6 mb-6"
          style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
        >
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <h1
                className="text-2xl font-bold mb-1"
                style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
              >
                {c.display_name}
              </h1>
              {c.trading_name && c.trading_name !== c.business_name && (
                <p className="text-sm mb-2" style={{ color: 'var(--color-sage)' }}>
                  Trading as {c.trading_name}
                </p>
              )}
              <p className="text-base mb-3" style={{ color: 'var(--color-bronze)' }}>
                {c.trade_label ?? c.doc_category ?? 'Licensed Contractor'}
              </p>
              <div className="flex flex-wrap items-center gap-2">
                <StatusBadge status={c.license_status} />
                {c.verified && (
                  <span
                    className="text-xs font-bold px-2 py-1 rounded-full"
                    style={{ background: tierLabelColour.bg, color: tierLabelColour.text }}
                  >
                    {'✓ Verified'}
                  </span>
                )}
                {c.profile_tier_label && (
                  <span
                    className="text-xs px-2 py-1 rounded-full"
                    style={{ background: 'var(--color-light-gray)', color: 'var(--color-sage)' }}
                  >
                    {c.profile_tier_label}
                  </span>
                )}
              </div>
            </div>

            <div className="flex flex-col items-center gap-2">
              <img
                src={`/api/qr/${c.slug}?size=120&ref=profile`}
                alt={`QR code for ${c.display_name}`}
                width={120}
                height={120}
                className="rounded"
              />
              <span className="text-xs" style={{ color: 'var(--color-sage)' }}>Scan to save contact</span>
              <a href={`/api/vcard/${c.slug}`} className="text-xs underline" style={{ color: 'var(--color-bronze)' }}>Save Contact</a>
            </div>
          </div>
        </div>

        <div
          className="rounded-xl p-6 mb-6"
          style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
        >
          <h2
            className="text-base font-bold mb-4"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
          >
            Licence Details
          </h2>
          <dl className="grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-3 text-sm">
            {c.license_number && (
              <>
                <dt style={{ color: 'var(--color-sage)' }}>Licence Number</dt>
                <dd className="font-mono font-medium">{c.license_number}</dd>
              </>
            )}
            {c.license_status && (
              <>
                <dt style={{ color: 'var(--color-sage)' }}>Status</dt>
                <dd><StatusBadge status={c.license_status} size="sm" /></dd>
              </>
            )}
            {c.expiry_date && (
              <>
                <dt style={{ color: 'var(--color-sage)' }}>Expiry Date</dt>
                <dd>{c.expiry_date}</dd>
              </>
            )}
            {c.trade_label && (
              <>
                <dt style={{ color: 'var(--color-sage)' }}>Trade</dt>
                <dd>{c.trade_label}</dd>
              </>
            )}
            {c.city && (
              <>
                <dt style={{ color: 'var(--color-sage)' }}>Location</dt>
                <dd>{[c.city, c.state, c.zip_code].filter(Boolean).join(', ')}</dd>
              </>
            )}
            {c.source && (
              <>
                <dt style={{ color: 'var(--color-sage)' }}>Data Source</dt>
                <dd className="text-xs" style={{ color: 'var(--color-sage)' }}>{c.source}</dd>
              </>
            )}
          </dl>
        </div>

        {specialistFlags.length > 0 && (
          <div
            className="rounded-xl p-6 mb-6"
            style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
          >
            <h2
              className="text-base font-bold mb-3"
              style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
            >
              Specialist Capabilities
            </h2>
            <div className="flex flex-wrap gap-2">
              {specialistFlags.map(flag => (
                <span
                  key={flag}
                  className="text-xs px-2.5 py-1 rounded-full font-medium"
                  style={{ background: '#e8f0fb', color: 'var(--color-navy)' }}
                >
                  {flag}
                </span>
              ))}
            </div>
          </div>
        )}

        {emergencyFlags.length > 0 && (
          <div
            className="rounded-xl p-6 mb-6"
            style={{ background: '#fdf2f2', border: '1px solid #f5c6c6' }}
          >
            <h2
              className="text-base font-bold mb-3"
              style={{ fontFamily: 'Georgia, serif', color: '#8e1c0e' }}
            >
              Emergency Services
            </h2>
            <div className="flex flex-wrap gap-2 mb-2">
              {emergencyFlags.map(flag => (
                <span
                  key={flag}
                  className="text-xs px-2.5 py-1 rounded-full font-medium"
                  style={{ background: '#fdecea', color: '#c0392b' }}
                >
                  {flag}
                </span>
              ))}
            </div>
            {c.emergency_response_hours && (
              <p className="text-xs mt-2" style={{ color: '#c0392b' }}>
                Response hours: {c.emergency_response_hours}
              </p>
            )}
          </div>
        )}

        {!c.claimed && (
          <div
            className="rounded-xl p-6 mb-6 text-center"
            style={{ background: 'var(--color-light-gray)', border: '1px dashed var(--color-bronze)' }}
          >
            <p
              className="font-semibold mb-1"
              style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
            >
              Is this your business?
            </p>
            <p className="text-sm mb-4" style={{ color: 'var(--color-sage)' }}>
              Claim your profile to add contact details, photos, and a hi-res QR card.
            </p>
            <Link
              href={`/claim/${c.slug}`}
              className="inline-block px-5 py-2 rounded-lg text-sm font-semibold"
              style={{ background: 'var(--color-bronze)', color: 'var(--color-white)' }}
            >
              Claim This Profile
            </Link>
          </div>
        )}

        <p className="text-xs mt-6 text-center" style={{ color: 'var(--color-sage)' }}>
          Licence data sourced from{' '}
          {c.source_url ? (
            <a href={c.source_url} target="_blank" rel="noopener noreferrer" className="underline">
              {c.source ?? 'official registry'}
            </a>
          ) : (
            c.source ?? 'official registry'
          )}
          . Always verify current status directly with the licensing authority.{' '}
          <Link href="/disclaimer" className="underline">Disclaimer</Link>
        </p>
      </div>
    </>
  )
}