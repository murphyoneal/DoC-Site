import type { Metadata } from 'next'
import Link from 'next/link'
import { contractorSocket } from '@/lib/sockets/contractors'
import ContractorCard from '@/app/components/ContractorCard'

export const metadata: Metadata = {
  title: 'Licensed Contractors in Florida | Department of Construction',
  description:
    'Search 228,000+ active licensed contractors across Florida. Verify DBPR licence status, find emergency services, and connect with local professionals.',
}

const FLORIDA_COUNTIES = [
  { name: 'Volusia County',  slug: 'volusia',   city: 'Daytona Beach' },
  { name: 'Orange County',   slug: 'orange',    city: 'Orlando' },
  { name: 'Broward County',  slug: 'broward',   city: 'Fort Lauderdale' },
  { name: 'Miami-Dade',      slug: 'miami-dade', city: 'Miami' },
  { name: 'Palm Beach',      slug: 'palm-beach', city: 'West Palm Beach' },
  { name: 'Hillsborough',    slug: 'hillsborough', city: 'Tampa' },
  { name: 'Pinellas County', slug: 'pinellas',  city: 'St. Petersburg' },
  { name: 'Duval County',    slug: 'duval',     city: 'Jacksonville' },
]

export default async function FloridaPage() {
  let contractors: Awaited<ReturnType<typeof contractorSocket.forState>> = []
  try {
    contractors = await contractorSocket.forState('FL', 20)
  } catch {
    // DB unavailable at build time
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
      {/* Breadcrumb */}
      <nav className="text-xs mb-4" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>Florida</span>
      </nav>

      {/* Hero */}
      <div className="mb-8">
        <h1
          className="text-3xl font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          Licensed Contractors in Florida
        </h1>
        <p className="text-base mb-4" style={{ color: 'var(--color-sage)' }}>
          228,000+ active licensed contractors registered with the Florida Department
          of Business &amp; Professional Regulation (DBPR). Verify licence status and
          find professionals near you.
        </p>
        <Link
          href="/?state=FL"
          className="inline-block px-4 py-2 rounded-lg text-sm font-semibold"
          style={{ background: 'var(--color-navy)', color: 'var(--color-white)' }}
        >
          View on Map →
        </Link>
      </div>

      {/* Counties */}
      <section className="mb-10">
        <h2
          className="text-xl font-bold mb-4"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
        >
          Browse by County
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {FLORIDA_COUNTIES.map(county => (
            <Link
              key={county.slug}
              href={`/florida/${county.slug}`}
              className="block p-3 rounded-lg text-sm font-medium text-center transition-shadow hover:shadow-md"
              style={{
                background: 'var(--color-white)',
                border: '1px solid var(--color-light-gray)',
                color: 'var(--color-navy)',
              }}
            >
              <span style={{ display: 'block', fontFamily: 'Georgia, serif' }}>{county.name}</span>
              <span className="text-xs mt-0.5 block" style={{ color: 'var(--color-sage)' }}>{county.city}</span>
            </Link>
          ))}
        </div>
      </section>

      {/* Sample contractors */}
      {contractors.length > 0 && (
        <section className="mb-10">
          <h2
            className="text-xl font-bold mb-4"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            Recently Listed in Florida
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {contractors.map(c => (
              <ContractorCard key={c.id} contractor={c} />
            ))}
          </div>
        </section>
      )}

      {/* DBPR info block */}
      <section
        className="rounded-xl p-6"
        style={{ background: 'var(--color-light-gray)', border: '1px solid #ddd8d0' }}
      >
        <h2
          className="text-base font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          About Florida Contractor Licensing
        </h2>
        <p className="text-sm mb-3" style={{ color: 'var(--color-ink)' }}>
          Florida contractor licences are issued by the Florida Department of Business
          and Professional Regulation (DBPR). Licence data on this site is sourced directly
          from DBPR public records and updated monthly.
        </p>
        <a
          href="https://www.myfloridalicense.com/wl11.asp?mode=2&SID=&brd=&typ=&sid=&lic=&nam=&cit=&sta=0&zip=&cou=0&con=&bna=&pho="
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm underline"
          style={{ color: 'var(--color-bronze)' }}
        >
          Verify a licence directly at DBPR →
        </a>
        <p className="text-xs mt-3" style={{ color: 'var(--color-sage)' }}>
          Department of Construction is a technology platform, not a licensing authority.{' '}
          <Link href="/disclaimer" className="underline">Read our disclaimer</Link>
        </p>
      </section>
    </div>
  )
}
