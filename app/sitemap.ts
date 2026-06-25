import { MetadataRoute } from 'next'

export const revalidate = 86400

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = 'https://departmentofconstruction.com'

  const staticPages: MetadataRoute.Sitemap = [
    { url: base,                                   lastModified: new Date(), changeFrequency: 'daily',   priority: 1.0 },
    { url: base + '/florida',                      lastModified: new Date(), changeFrequency: 'weekly',  priority: 0.9 },
    { url: base + '/florida/volusia',              lastModified: new Date(), changeFrequency: 'weekly',  priority: 0.9 },
    { url: base + '/florida/volusia/spruce-creek', lastModified: new Date(), changeFrequency: 'monthly', priority: 0.8 },
    { url: base + '/disclaimer',                   lastModified: new Date(), changeFrequency: 'yearly',  priority: 0.3 },
  ]

  return staticPages
}