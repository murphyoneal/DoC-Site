import type { NextConfig } from 'next'
import { DOMAIN_SPLIT, DOC_URL, DOP_URL } from './lib/site'

// ── ONE APP, TWO HOSTS: the permanent cross-domain redirects (ruling 2026-09-27) ──────────────
// Contractor paths on departmentofproperty.com 308 to the same path on departmentofconstruction.com,
// and property/agent paths requested on the DoC host 308 back. Next passes the query string through
// on every redirect, so ?ref=qr survives (QR scan attribution). A retired business slug takes two
// permanent hops: this host move, then the page's own slug redirect on the DoC host.
//
// PERMANENT INFRASTRUCTURE. Every QR code printed so far encodes departmentofproperty.com/api/qr and
// /c/{slug}. Never remove these. Off until DOMAIN_SPLIT (lib/site.ts) flips, after the domain is
// attached to this project and verified.
const DOP_HOST = '(www\\.|app\\.)?departmentofproperty\\.com'
const DOC_HOST = '(www\\.)?departmentofconstruction\\.com'

const TO_DOC = ['/c', '/c/:path*', '/claim/:slug', '/claim/:slug/:rest*', '/api/qr/:path*', '/api/vcard/:path*',
  '/map', '/florida', '/florida/:path*', '/rights', '/rights/:path*',
  // self-registration (work order 699): the form, its API and the /r/ pages are DoC's
  '/register-your-business', '/r/:path*', '/api/register', '/api/geo', '/api/places']
const TO_DOP = ['/report/:path*', '/checkout', '/checkout/:path*', '/agent', '/agent/:path*', '/roz', '/roz/:path*',
  '/prototype/:path*', '/about.html', '/register.html', '/privacy.html', '/terms.html', '/agents.html',
  // the agent claim (work order 712): the form, its API, the agent pages and their editor are DoP's
  '/agents/claim', '/a/:path*', '/api/agent-claim', '/api/agent-profile']

// /login is deliberately on BOTH hosts: sign-in cookies are per host, so a page on DoC that needs a
// session (the claim photos page) must sign in on DoC.
async function domainRedirects() {
  if (!DOMAIN_SPLIT) return []
  return [
    // www <-> apex is NOT decided here. It is Vercel's domain setting, one place, so the two can never
    // loop (the apex 308ed to www when the domain came over from do-c-public). Vercel keeps path and query.
    ...TO_DOC.map(source => ({ source, has: [{ type: 'host' as const, value: DOP_HOST }], destination: `${DOC_URL}${source}`, permanent: true })),
    ...TO_DOP.map(source => ({ source, has: [{ type: 'host' as const, value: DOC_HOST }], destination: `${DOP_URL}${source}`, permanent: true })),
  ]
}

const nextConfig: NextConfig = {
  redirects: domainRedirects,

  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'SAMEORIGIN' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          { key: 'Permissions-Policy', value: 'geolocation=(self)' },
        ],
      },
      {
        source: '/api/qr/:path*',
        headers: [
          { key: 'Cache-Control', value: 'public, max-age=86400, stale-while-revalidate=604800' },
        ],
      },
    ]
  },

  productionBrowserSourceMaps: false,

  // sharp loads a native libvips shared library that file tracing does not follow, so the
  // deployed /api/work/upload function failed with "libvips-cpp.so ... cannot open shared object
  // file" (production, 2026-09-25). Ship sharp's linux binaries with that route explicitly.
  outputFileTracingIncludes: {
    '/api/work/upload': [
      './node_modules/@img/sharp-linux-x64/**/*',
      './node_modules/@img/sharp-libvips-linux-x64/**/*',
    ],
  },

  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'eaifqorwmgayiqmbtzcg.supabase.co',
      },
    ],
  },
}

export default nextConfig
