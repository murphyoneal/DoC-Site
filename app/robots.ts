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
        // /report/ is the $5 product. Its free teaser names the parcel owner, and the
        // product emails permanent report links — so any forwarded link is a crawl path
        // to a page about a named individual at their home address. One page per parcel,
        // 10.7M parcels. The sitemap does not enumerate them; this stops them being
        // crawled if they are found another way.
        disallow: ['/api/', '/claim/', '/report/', '/_next/', '/prototype/'],
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
