import type { MetadataRoute } from 'next'
import { SITE_URL } from '@/lib/site'

// Site-wide indexing kill-switch. Crawling is blocked entirely until the
// SITE_INDEXABLE env var is explicitly set to 'true' (evaluated at build time;
// flipping it requires a redeploy). This pairs with the global noindex in
// app/layout.tsx so robots.txt and the meta robots tag never disagree.
const INDEXABLE = process.env.SITE_INDEXABLE === 'true'

// SITE_URL (the canonical apex) is imported from lib/site. It is only advertised
// as sitemap host once indexing is switched on.
export default function robots(): MetadataRoute.Robots {
  if (!INDEXABLE) {
    return { rules: { userAgent: '*', disallow: '/' } }
  }

  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/claim/', '/_next/', '/prototype/'],
      },
      // Known SEO scrapers we don't want crawling regardless.
      {
        userAgent: ['AhrefsBot', 'SemrushBot', 'MJ12bot', 'DotBot'],
        disallow: '/',
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
    host: SITE_URL,
  }
}
