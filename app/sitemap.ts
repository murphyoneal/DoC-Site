```typescript
import { MetadataRoute } from 'next'
import { getSupabaseAdmin } from '@/lib/supabase/server'

export const revalidate = 86400

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = 'https://departmentofconstruction.com'

  const staticPages: MetadataRoute.Sitemap = [
    { url: base,                                    lastModified: new Date(), changeFrequency: 'daily',   priority: 1.0 },
    { url: `${base}/florida`,                       lastModified: new Date(), changeFrequency: 'weekly',  priority: 0.9 },
    { url: `${base}/florida/volusia`,               lastModified: new Date(), changeFrequency: 'weekly',  priority: 0.9 },
    { url: `${base}/florida/volusia/spruce-creek`,  lastModified: new Date(), changeFrequency: 'monthly', priority: 0.8 },
    { url: `${base}/disclaimer`,                    lastModified: new Date(), changeFrequency: 'yearly',  priority: 0.3 },
  ]

  let contractorPages: MetadataRoute.Sitemap = []
  try {
    const { data } = await getSupabaseAdmin()
      .from('contractors')
      .select('slug, updated_at, verified')
      .eq('active', true)
      .order('verified', { ascending: false })
      .limit(5000)

    contractorPages = (data ?? []).map((c: { slug: string; updated_at: string | null; verified: boolean | null }) => ({
      url: `${base}/c/${c.slug}`,
      lastModified: c.updated_at ? new Date(c.updated_at) : new Date(),
      changeFrequency: 'monthly' as const,
      priority: c.verified ? 0.8 : 0.5,
    }))
  } catch (err) {
    console.error('[sitemap]', err)
  }

  return [...staticPages, ...contractorPages]
}
```