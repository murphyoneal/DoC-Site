import type { Metadata } from 'next'
import './globals.css'
import Link from 'next/link'
import JsonLd from './components/JsonLd'
import AccountNav from './components/AccountNav'
import { requestBrand } from '@/lib/brand'

// ONE APP, TWO HOSTS (ruling 2026-09-27). departmentofconstruction.com is Department of
// Construction (contractors); departmentofproperty.com is Department of Property (land, PIR,
// agents). The chrome, metadata and JSON-LD come from the request host via lib/brand, so a page
// always names the site it is on. No legal entity is named anywhere - none exists yet (ruling
// 2026-09-24).

export async function generateMetadata(): Promise<Metadata> {
  const b = await requestBrand()
  return {
    title: { default: b.titleDefault, template: `%s | ${b.name}` },
    description: b.description,
    metadataBase: new URL(b.url),
    applicationName: b.name,
    // Site-wide indexing kill-switch: everything is noindex until SITE_INDEXABLE === 'true', on
    // both hosts. Pairs with app/robots.ts so the meta tag and robots.txt agree. The page-scoped
    // `robots: { index: false }` entries (assistant, checkout, checkout/success, report) override
    // this and stay noindex even after the switch is flipped on.
    robots: process.env.SITE_INDEXABLE === 'true' ? undefined : { index: false, follow: false },
    openGraph: {
      type: 'website',
      siteName: b.name,
      title: b.titleDefault,
      description: b.description,
      url: '/',
      images: [{ url: '/og-image.png', width: 512, height: 512, alt: b.name }],
    },
    twitter: { card: 'summary', title: b.titleDefault, description: b.description, images: ['/og-image.png'] },
  }
}

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const b = await requestBrand()
  const orgJsonLd = {
    '@context': 'https://schema.org', '@type': 'Organization',
    name: b.name, url: b.url, logo: `${b.url}/og-image.png`, description: b.description,
  }
  const siteJsonLd = { '@context': 'https://schema.org', '@type': 'WebSite', name: b.name, url: b.url }

  return (
    <html lang="en">
      <head>
        <link
          href="https://api.mapbox.com/mapbox-gl-js/v3.3.0/mapbox-gl.css"
          rel="stylesheet"
        />
      </head>
      <body className="min-h-screen flex flex-col" style={{ backgroundColor: 'var(--color-cream)' }}>
        <JsonLd data={orgJsonLd} />
        <JsonLd data={siteJsonLd} />
        <div className="disclaimer-banner">
          This site is a technology platform, not a licensing authority.
          Always verify licence status directly with the relevant government registry.{' '}
          <Link href="/disclaimer">Learn more</Link>
        </div>
        <header style={{ background: 'var(--color-navy)', borderBottom: '1px solid #2a3f6b' }}>
          <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between gap-4">
            <Link href="/" className="flex items-center gap-3" style={{ textDecoration: 'none' }}>
              {/* The mark was 9 units wide in 12 px type and read as a smudge; it is the one brand
                  cue on a phone, where the name beside it is hidden. */}
              <div className="w-11 h-11 rounded-full flex items-center justify-center font-bold"
                style={{ background: 'var(--color-bronze)', color: 'var(--color-white)', fontSize: '15px', fontFamily: 'Georgia, serif', letterSpacing: '0.02em' }}>
                {b.mark}
              </div>
              <span className="text-lg font-bold tracking-wide hidden sm:block"
                style={{ fontFamily: 'Georgia, serif', color: 'var(--color-white)' }}>
                {b.name}
              </span>
            </Link>
            <nav className="flex items-center gap-4 text-sm">
              {b.nav.filter(l => l.href !== '/login').map(l => (
                <Link key={l.href} href={l.href} style={{ color: '#aab4c8', textDecoration: 'none' }}>{l.label}</Link>
              ))}
              <AccountNav />
            </nav>
          </div>
        </header>
        <main className="flex-1">{children}</main>
        <footer style={{ background: 'var(--color-navy)', borderTop: '1px solid #2a3f6b' }} className="py-6 mt-auto">
          <div className="max-w-7xl mx-auto px-4 sm:px-6">
            <div className="flex flex-col sm:flex-row justify-between gap-4 text-xs" style={{ color: '#7a8faa' }}>
              <div>
                <p className="font-semibold mb-1" style={{ color: '#aab4c8', fontFamily: 'Georgia, serif' }}>
                  {b.name}
                </p>
                <p>{b.footerLine}</p>
              </div>
              <div className="flex flex-col gap-1 sm:items-end">
                {/* These rendered as default browser blue: the links carried no colour of their own. */}
                {b.footer.map(l => (
                  <Link key={l.href} href={l.href} className="hover:underline" style={{ color: '#aab4c8', textDecoration: 'none' }}>{l.label}</Link>
                ))}
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
