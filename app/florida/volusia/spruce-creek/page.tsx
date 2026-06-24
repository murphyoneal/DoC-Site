import type { Metadata } from 'next'
import Link from 'next/link'
import { contractorSocket } from '@/lib/sockets/contractors'
import ContractorCard from '@/app/components/ContractorCard'

export const metadata: Metadata = {
  title: 'Spruce Creek Contractors — Port Orange, Volusia County | Department of Construction',
  description:
    'Find licensed contractors serving Spruce Creek Fly-In and Port Orange, Florida. DBPR verified roofing, electrical, plumbing, HVAC and general contractors.',
}

export default async function SpruceCreeKPage() {
  let contractors: Awaited<ReturnType<typeof contractorSocket.forCity>> = []
  try {
    contractors = await contractorSocket.forCity('Port Orange', 'FL', 20)
  } catch {
    // DB unavailable at build time — page renders without contractor list
  }

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
      {/* Breadcrumb */}
      <nav className="text-xs mb-4" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <Link href="/florida" className="hover:underline">Florida</Link>
        {' / '}
        <Link href="/florida/volusia" className="hover:underline">Volusia County</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>Spruce Creek</span>
      </nav>

      {/* Hero */}
      <div className="mb-8">
        <h1
          className="text-3xl font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          Spruce Creek Fly-In Contractors
        </h1>
        <p className="text-base mb-4" style={{ color: 'var(--color-sage)' }}>
          Licensed contractors serving Spruce Creek Fly-In and Port Orange, Volusia County, Florida.
          All records sourced from the Florida DBPR public registry.
        </p>
        <div className="flex flex-wrap gap-2">
          <span
            className="text-xs px-2.5 py-1 rounded-full"
            style={{ background: '#e8f0fb', color: 'var(--color-navy)' }}
          >
            Port Orange, FL
          </span>
          <span
            className="text-xs px-2.5 py-1 rounded-full"
            style={{ background: 'var(--color-light-gray)', color: 'var(--color-sage)' }}
          >
            Volusia County
          </span>
          <span
            className="text-xs px-2.5 py-1 rounded-full"
            style={{ background: 'var(--color-light-gray)', color: 'var(--color-sage)' }}
          >
            32128 · 32127
          </span>
        </div>
      </div>

      {/* About Spruce Creek */}
      <section
        className="rounded-xl p-6 mb-8"
        style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
      >
        <h2
          className="text-base font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          About Spruce Creek Fly-In
        </h2>
        <p className="text-sm" style={{ color: 'var(--color-ink)', lineHeight: 1.7 }}>
          Spruce Creek Fly-In is a private fly-in community in Port Orange, Volusia County,
          one of the world&apos;s largest residential airparks. The community features private
          taxiways connecting residences to a private airstrip. Contractors working in Spruce Creek
          must be licensed with the Florida DBPR and familiar with HOA and airpark requirements.
          Port Orange building permits are issued through the City of Port Orange Building Department.
        </p>
        <a
          href="https://www.portorange.org/departments/building-official/"
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm underline mt-3 inline-block"
          style={{ color: 'var(--color-bronze)' }}
        >
          Port Orange Building Department →
        </a>
      </section>

      {/* Contractors */}
      {contractors.length > 0 && (
        <section className="mb-10">
          <h2
            className="text-xl font-bold mb-4"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            Licensed Contractors — Port Orange
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {contractors.map(c => (
              <ContractorCard key={c.id} contractor={c} />
            ))}
          </div>
          <p className="text-xs mt-4 text-center" style={{ color: 'var(--color-sage)' }}>
            Showing contractors with a Port Orange address.
            Use the <Link href="/" className="underline">map</Link> to search the full area.
          </p>
        </section>
      )}

      {/* Nearby */}
      <section>
        <h2
          className="text-base font-bold mb-3"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          Nearby Communities
        </h2>
        <div className="flex flex-wrap gap-2">
          {[
            { name: 'Daytona Beach', slug: 'daytona-beach' },
            { name: 'New Smyrna Beach', slug: 'new-smyrna-beach' },
            { name: 'Ormond Beach', slug: 'ormond-beach' },
            { name: 'DeLand', slug: 'deland' },
          ].map(c => (
            <Link
              key={c.slug}
              href={`/florida/volusia/${c.slug}`}
              className="text-sm px-3 py-1.5 rounded-full transition-colors"
              style={{
                border: '1px solid var(--color-bronze)',
                color: 'var(--color-bronze)',
              }}
            >
              {c.name}
            </Link>
          ))}
        </div>
      </section>
    </div>
  )
}
