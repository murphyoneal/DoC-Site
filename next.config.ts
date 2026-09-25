import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
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
