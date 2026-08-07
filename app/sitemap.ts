import { MetadataRoute } from 'next'
import { legalSocket } from '@/lib/sockets/legal'
import { SITE_URL } from '@/lib/site'

export const revalidate = 86400

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = SITE_URL

  const COUNTY_SLUGS = ['volusia', 'miami-dade', 'orange', 'seminole', 'osceola', 'lake']

  // Construction-defect rights hub + one page per primary-verified state.
  const verifiedStates = await legalSocket.listVerifiedStates()
  const rightsPages: MetadataRoute.Sitemap = [
    { url: `${base}/rights`, lastModified: new Date(), changeFrequency: 'monthly', priority: 0.8 },
    ...verifiedStates.map(s => ({
      url: `${base}/rights/${s.slug}`,
      lastModified: new Date(),
      changeFrequency: 'monthly' as const,
      priority: 0.7,
    })),
  ]

  const countyPages: MetadataRoute.Sitemap = COUNTY_SLUGS.map(slug => ({
    url: `${base}/florida/${slug}`,
    lastModified: new Date(),
    changeFrequency: 'weekly',
    priority: 0.9,
  }))

  const staticPages: MetadataRoute.Sitemap = [
    { url: base,                                   lastModified: new Date(), changeFrequency: 'daily',   priority: 1.0 },
    { url: base + '/florida',                      lastModified: new Date(), changeFrequency: 'weekly',  priority: 0.9 },
    { url: base + '/florida/volusia/spruce-creek', lastModified: new Date(), changeFrequency: 'monthly', priority: 0.8 },
    { url: base + '/disclaimer',                   lastModified: new Date(), changeFrequency: 'yearly',  priority: 0.3 },
  ]

  return [...staticPages, ...countyPages, ...rightsPages]
}