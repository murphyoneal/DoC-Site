import { notFound, permanentRedirect } from 'next/navigation'
import { headers } from 'next/headers'
import { after } from 'next/server'
import ScanLanding from '@/app/components/ScanLanding'
import { logScanServer, requestMeta } from '@/lib/scan'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'
import { resolveBusinessSlug, withQuery } from '@/lib/business'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
// Read from the environment — never hardcode the key. Set SUPABASE_SECRET_KEY in
// Vercel (and .env.local for local dev). Matches lib/supabase/server.ts.
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }


async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors_public?slug=eq.${encodeURIComponent(slug)}&select=slug,display_name,doc_category,trade_label,city,state,website,claimed&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 60 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Contractor' }
  return {
    title: `${c.display_name}`,
    description: `${CATEGORY_LABELS[c.doc_category] ?? 'Contractor'} in ${c.city ?? 'Florida'}.`,
  }
}

export default async function ScanPage({
  params,
  searchParams,
}: {
  params: Promise<{ slug: string }>
  searchParams: Promise<{ ref?: string }>
}) {
  const { slug } = await params
  const sp = await searchParams
  const { ref } = sp
  const meta = requestMeta(await headers())

  const business = await resolveBusinessSlug(slug)
  if (business?.redirect) {
    after(() => logScanServer({ slug, ref: ref ?? 'qr', action: 'slug_redirect', meta }))
    permanentRedirect(withQuery(`/c/${business.slug}/scan`, sp))
  }

  const c = await getContractor(slug)
  if (!c) notFound()

  // The landing is logged by the request; ScanLanding logs only the visitor's clicks.
  after(() => logScanServer({
    slug, ref: ref ?? 'qr', action: 'scan_landing',
    tradeCategory: c.doc_category, city: c.city, state: c.state, meta,
  }))

  const tradeLabel = CATEGORY_LABELS[c.doc_category] ?? c.trade_label ?? 'Contractor'

  return (
    <ScanLanding
      slug={slug}
      displayName={c.display_name}
      tradeLabel={tradeLabel}
      city={c.city ?? ''}
      state={c.state ?? ''}
      tradeCategory={c.doc_category ?? ''}
      hasWebsite={!!c.website}
      websiteUrl={c.website ?? null}
      ref_={ref ?? 'qr'}
    />
  )
}
