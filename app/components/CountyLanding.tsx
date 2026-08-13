import Link from 'next/link'
import JsonLd from './JsonLd'
import type { FloridaCounty } from '@/lib/florida-counties'
import { SITE_URL } from '@/lib/site'

const BASE = SITE_URL

// Shared county contractor landing page. Mirrors /florida/volusia; data-driven.
export default function CountyLanding({ county }: { county: FloridaCounty }) {
  const url = `${BASE}/florida/${county.slug}`

  const breadcrumb = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: 'Home', item: BASE },
      { '@type': 'ListItem', position: 2, name: 'Florida', item: `${BASE}/florida` },
      { '@type': 'ListItem', position: 3, name: county.name, item: url },
    ],
  }

  const collection = {
    '@context': 'https://schema.org',
    '@type': 'CollectionPage',
    name: `${county.name} Licensed Contractors`,
    description: `Licensed contractors in ${county.name}, Florida — ${county.cities.map(c => c.name).join(', ')}. DBPR verified licence data.`,
    url,
    isPartOf: { '@type': 'WebSite', name: 'Department of Construction', url: BASE },
    about: {
      '@type': 'Place',
      name: county.name,
      address: { '@type': 'PostalAddress', addressRegion: 'FL', addressCountry: 'US' },
    },
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
      <JsonLd data={breadcrumb} />
      <JsonLd data={collection} />

      {/* Breadcrumb */}
      <nav className="text-xs mb-4" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <Link href="/florida" className="hover:underline">Florida</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>{county.name}</span>
      </nav>

      {/* Hero */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          {county.name} Licensed Contractors
        </h1>
        <p className="text-base mb-2" style={{ color: 'var(--color-sage)' }}>{county.blurb}</p>
        <p className="text-sm mb-4" style={{ color: 'var(--color-sage)' }}>
          Licence data sourced from the Florida DBPR and updated monthly.
        </p>
        <Link
          href="/"
          className="inline-block px-4 py-2 rounded-lg text-sm font-semibold"
          style={{ background: 'var(--color-navy)', color: 'var(--color-white)' }}
        >
          View on Map →
        </Link>
      </div>

      {/* Cities */}
      <section className="mb-10">
        <h2 className="text-xl font-bold mb-4" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}>
          {county.shortName} County Cities
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {county.cities.map(city => (
            <div
              key={city.name}
              className="block p-3 rounded-lg text-sm"
              style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
            >
              <span className="font-semibold block" style={{ color: 'var(--color-navy)', fontFamily: 'Georgia, serif' }}>
                {city.name}
              </span>
              <span className="text-xs mt-0.5 block" style={{ color: 'var(--color-sage)' }}>{city.desc}</span>
            </div>
          ))}
        </div>
      </section>

      {/* Permitting info */}
      <section className="rounded-xl p-6" style={{ background: 'var(--color-light-gray)', border: '1px solid #ddd8d0' }}>
        <h2 className="text-base font-bold mb-2" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          {county.shortName} County Building &amp; Permitting
        </h2>
        <p className="text-sm mb-3" style={{ color: 'var(--color-ink)' }}>
          Building permits in {county.name} are issued through the {county.permitAuthority} and
          individual municipal building departments.
        </p>
        <div className="flex flex-col gap-2 text-sm">
          <a href={county.permitUrl} target="_blank" rel="noopener noreferrer" className="underline" style={{ color: 'var(--color-bronze)' }}>
            {county.permitAuthority} →
          </a>
          <a href="https://www.myfloridalicense.com/wl11.asp" target="_blank" rel="noopener noreferrer" className="underline" style={{ color: 'var(--color-bronze)' }}>
            Verify Florida Contractor Licence (DBPR) →
          </a>
        </div>
      </section>
    </div>
  )
}
