import type { Metadata } from 'next'
import Link from 'next/link'
import { contractorSocket } from '@/lib/sockets/contractors'
import ContractorCard from '@/app/components/ContractorCard'

export const metadata: Metadata = {
  title: 'Volusia County Licensed Contractors | Department of Construction',
  description:
    'Find licensed contractors in Volusia County, Florida — Daytona Beach, Port Orange, New Smyrna Beach, Ormond Beach and surrounding areas. DBPR verified licence data.',
}

const VOLUSIA_COMMUNITIES = [
  { name: 'Spruce Creek Fly-In', slug: 'spruce-creek', desc: 'Port Orange aviation community' },
  { name: 'Daytona Beach',       slug: 'daytona-beach', desc: 'County seat' },
  { name: 'Port Orange',         slug: 'port-orange', desc: 'South of Daytona' },
  { name: 'New Smyrna Beach',    slug: 'new-smyrna-beach', desc: 'Coastal community' },
  { name: 'Ormond Beach',        slug: 'ormond-beach', desc: 'North Volusia' },
  { name: 'DeLand',              slug: 'deland', desc: 'County interior' },
]

export default async function VolusiaPage() {
  let contractors: Awaited<ReturnType<typeof contractorSocket.forVolusia>> = []
  let total = 0
  try {
    contractors = await contractorSocket.forVolusia(20)
    total = await contractorSocket.countInVolusia()
  } catch {
    // DB unavailable at build time
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
      {/* Breadcrumb */}
      <nav className="text-xs mb-4" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <Link href="/florida" className="hover:underline">Florida</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>Volusia County</span>
      </nav>

      {/* Hero */}
      <div className="mb-8">
        <h1
          className="text-3xl font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          Volusia County Licensed Contractors
        </h1>
        <p className="text-base mb-2" style={{ color: 'var(--color-sage)' }}>
          {total > 0 ? `${total.toLocaleString()} licensed contractors` : '2,007 licensed contractors'} in
          Volusia County — from Daytona Beach to New Smyrna Beach and inland to DeLand.
        </p>
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

      {/* Communities */}
      <section className="mb-10">
        <h2
          className="text-xl font-bold mb-4"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
        >
          Volusia County Communities
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {VOLUSIA_COMMUNITIES.map(c => (
            <Link
              key={c.slug}
              href={`/florida/volusia/${c.slug}`}
              className="block p-3 rounded-lg text-sm transition-shadow hover:shadow-md"
              style={{
                background: 'var(--color-white)',
                border: '1px solid var(--color-light-gray)',
              }}
            >
              <span
                className="font-semibold block"
                style={{ color: 'var(--color-navy)', fontFamily: 'Georgia, serif' }}
              >
                {c.name}
              </span>
              <span className="text-xs mt-0.5 block" style={{ color: 'var(--color-sage)' }}>
                {c.desc}
              </span>
            </Link>
          ))}
        </div>
      </section>

      {/* Contractors */}
      {contractors.length > 0 && (
        <section className="mb-10">
          <h2
            className="text-xl font-bold mb-4"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            Licensed Contractors in Volusia County
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {contractors.map(c => (
              <ContractorCard key={c.id} contractor={c} />
            ))}
          </div>
        </section>
      )}

      {/* Permitting info */}
      <section
        className="rounded-xl p-6"
        style={{ background: 'var(--color-light-gray)', border: '1px solid #ddd8d0' }}
      >
        <h2
          className="text-base font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          Volusia County Building &amp; Permitting
        </h2>
        <p className="text-sm mb-3" style={{ color: 'var(--color-ink)' }}>
          Building permits in Volusia County are issued through the Volusia County
          Building and Code Administration and individual municipal building departments.
        </p>
        <div className="flex flex-col gap-2 text-sm">
          <a
            href="https://www.vcgov.org/government/building-and-code-administration/"
            target="_blank"
            rel="noopener noreferrer"
            className="underline"
            style={{ color: 'var(--color-bronze)' }}
          >
            Volusia County Building &amp; Code Administration →
          </a>
          <a
            href="https://www.myfloridalicense.com/wl11.asp"
            target="_blank"
            rel="noopener noreferrer"
            className="underline"
            style={{ color: 'var(--color-bronze)' }}
          >
            Verify Florida Contractor Licence (DBPR) →
          </a>
        </div>
      </section>
    </div>
  )
}
