import type { Metadata } from 'next'
import './globals.css'
import Link from 'next/link'

export const metadata: Metadata = {
  title: {
    default: 'Find Licensed Contractors Near You | Department of Construction',
    template: '%s | Department of Construction',
  },
  description:
    'Search licensed contractors by trade and location. Verify licence status, find emergency services, and connect with local professionals — powered by official government registry data.',
  metadataBase: new URL('https://departmentofconstruction.com'),
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
        <div className="disclaimer-banner">
          Department of Construction is a technology platform, not a licensing authority.
          Always verify licence status directly with the relevant government registry.{' '}
          <Link href="/disclaimer">Learn more</Link>
        </div>
        <header style={{ background: 'var(--color-navy)', borderBottom: '1px solid #2a3f6b' }}>
          <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3 flex items-center justify-between">
            <Link href="/" className="flex items-center gap-3">
              <div className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-bold"
                style={{ background: 'var(--color-bronze)', color: 'var(--color-white)' }}>
                DoC
              </div>
              <span className="text-lg font-bold tracking-wide hidden sm:block"
                style={{ fontFamily: 'Georgia, serif', color: 'var(--color-white)' }}>
                Department of Construction
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
                  Department of Construction
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
              © {new Date().getFullYear()} Department of Construction. Technology platform only. Not affiliated with any government agency.
            </p>
          </div>
        </footer>
      </body>
    </html>
  )
}
