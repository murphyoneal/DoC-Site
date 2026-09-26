import type { Metadata } from 'next'
import './globals.css'
import Link from 'next/link'
import JsonLd from './components/JsonLd'
import { SITE_URL } from '@/lib/site'

// The canonical identity a crawler reads for this domain. departmentofproperty.com is
// Department of Property; Department of Construction is a separate live product on its own
// domain (lib/site.ts). No legal entity is named anywhere — none exists yet (ruling 2026-09-24).
const ORG_JSONLD = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'Department of Property',
  url: SITE_URL,
  logo: `${SITE_URL}/og-image.png`,
  description:
    'Licensed contractor search powered by official government registry data.',
}

const WEBSITE_JSONLD = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  name: 'Department of Property',
  url: SITE_URL,
}

const SITE_NAME = 'Department of Property'
const SITE_DESC =
  'Search Florida construction contractors by trade and location, and see each licence’s status as recorded in the state licence file.'

export const metadata: Metadata = {
  title: {
    default: 'Find Licensed Contractors Near You | Department of Property',
    template: '%s | Department of Property',
  },
  description: SITE_DESC,
  metadataBase: new URL(SITE_URL),
  applicationName: SITE_NAME,
  // Site-wide indexing kill-switch: everything is noindex until SITE_INDEXABLE
  // === 'true'. Pairs with app/robots.ts so the meta tag and robots.txt agree.
  // The four page-scoped `robots: { index: false }` entries (assistant,
  // checkout, checkout/success, report/[coNo]/[parcelId]) override this object
  // and therefore stay noindex even after the switch is flipped on.
  robots:
    process.env.SITE_INDEXABLE === 'true'
      ? undefined
      : { index: false, follow: false },
  openGraph: {
    type: 'website',
    siteName: SITE_NAME,
    title: 'Find Licensed Contractors Near You | Department of Property',
    description: SITE_DESC,
    url: '/',
    images: [{ url: '/og-image.png', width: 512, height: 512, alt: SITE_NAME }],
  },
  twitter: {
    card: 'summary',
    title: 'Find Licensed Contractors Near You | Department of Property',
    description: SITE_DESC,
    images: ['/og-image.png'],
  },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <link
          href="https://api.mapbox.com/mapbox-gl-js/v3.3.0/mapbox-gl.css"
          rel="stylesheet"
        />
      </head>
      <body className="min-h-screen flex flex-col" style={{ backgroundColor: 'var(--color-cream)' }}>
        <JsonLd data={ORG_JSONLD} />
        <JsonLd data={WEBSITE_JSONLD} />
        <div className="disclaimer-banner">
          This site is a technology platform, not a licensing authority.
          Always verify licence status directly with the relevant government registry.{' '}
          <Link href="/disclaimer">Learn more</Link>
        </div>
        <header style={{ background: 'var(--color-navy)', borderBottom: '1px solid #2a3f6b' }}>
          <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between">
            <Link href="/" className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold"
                style={{ background: 'var(--color-bronze)', color: 'var(--color-white)' }}>
                DoP
              </div>
              <span className="text-lg font-bold tracking-wide hidden sm:block"
                style={{ fontFamily: 'Georgia, serif', color: 'var(--color-white)' }}>
                Department of Property
              </span>
            </Link>
            <nav className="flex items-center gap-4 text-sm">
              <Link href="/florida" style={{ color: '#aab4c8' }}>Florida</Link>
              <Link href="/disclaimer" style={{ color: '#aab4c8' }}>Disclaimer</Link>
            </nav>
          </div>
        </header>
        <main className="flex-1">{children}</main>
        <footer style={{ background: 'var(--color-navy)', borderTop: '1px solid #2a3f6b' }} className="py-6 mt-auto">
          <div className="max-w-7xl mx-auto px-4 sm:px-6">
            <div className="flex flex-col sm:flex-row justify-between gap-4 text-xs" style={{ color: '#7a8faa' }}>
              <div>
                <p className="font-semibold mb-1" style={{ color: '#aab4c8', fontFamily: 'Georgia, serif' }}>
                  Department of Property
                </p>
                <p>Licensed contractor search powered by official government registry data.</p>
              </div>
              <div className="flex flex-col gap-1 sm:items-end">
                <Link href="/florida" className="hover:underline">Florida Contractors</Link>
                <Link href="/florida/volusia" className="hover:underline">Volusia County</Link>
                <Link href="/disclaimer" className="hover:underline">Disclaimer</Link>
              </div>
            </div>
            <p className="mt-4 text-xs text-center" style={{ color: '#4a5f7a' }}>
              {/* No legal entity is named: none exists yet, and naming one would invent a
                  relationship (ruling 2026-09-24). Added when an entity exists. */}
              Technology platform only. Not affiliated with any government agency.
            </p>
          </div>
        </footer>
      </body>
    </html>
  )
}
