import type { MetadataRoute } from 'next'
import { requestBrand } from '@/lib/brand'
import { fixtureContractorPaths } from '@/lib/test-fixture'

// Site-wide indexing kill-switch. Crawling is blocked entirely until the
// SITE_INDEXABLE env var is explicitly set to 'true' (evaluated at build time;
// flipping it requires a redeploy). This pairs with the global noindex in
// app/layout.tsx so robots.txt and the meta robots tag never disagree.
const INDEXABLE = process.env.SITE_INDEXABLE === 'true'

// SITE_URL (the canonical apex) is imported from lib/site. It is only advertised
// as sitemap host once indexing is switched on.
// Per host (one app serves both domains, ruling 2026-09-27): each advertises its own sitemap.
export default async function robots(): Promise<MetadataRoute.Robots> {
  const base = (await requestBrand()).url
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
        // Registered test fixtures (ruling 927): their own pages are reachable by direct URL under the 922 interim
        // and must never be crawled. Listed from the test_fixture registry, by key.
        disallow: ['/api/', '/claim/', '/report/', '/_next/', '/prototype/', ...(await fixtureContractorPaths())],
      },
      // Known SEO scrapers we don't want crawling regardless.
      {
        userAgent: ['AhrefsBot', 'SemrushBot', 'MJ12bot', 'DotBot'],
        disallow: '/',
      },
    ],
    sitemap: `${base}/sitemap.xml`,
    host: base,
  }
}
