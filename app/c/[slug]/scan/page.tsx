import { notFound } from 'next/navigation'
import ScanLanding from '@/app/components/ScanLanding'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWZxb3J3bWdheWlxbWJ0emNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjMxNjIzOCwiZXhwIjoyMDk3ODkyMjM4fQ.L23cjzASjDbuFQ1zeQt30CThOSX_aRwyWpbl7QLeO-E'
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

const CATEGORY_LABELS: Record<string, string> = {
  general_contractor: 'General Contractor',
  roofing: 'Roofing',
  plumbing: 'Plumbing',
  hvac: 'HVAC',
  electrical: 'Electrical',
  pool_spa: 'Pool & Spa',
  solar: 'Solar',
  painting: 'Painting',
  flooring: 'Flooring',
  masonry: 'Masonry',
  landscaping: 'Landscaping',
  windows_doors: 'Windows & Doors',
  insulation: 'Insulation',
  drywall: 'Drywall',
  fencing: 'Fencing',
  fire_protection: 'Fire Protection',
  residential_contractor: 'Residential Contractor',
  general_engineering: 'General Engineering',
  pressure_washing: 'Pressure Washing',
}

async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors?slug=eq.${encodeURIComponent(slug)}&select=slug,display_name,doc_category,trade_label,city,state,website,claimed&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 60 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Contractor | Department of Construction' }
  return {
    title: `${c.display_name} | Department of Construction`,
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
  const { ref } = await searchParams
  const c = await getContractor(slug)
  if (!c) notFound()

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
