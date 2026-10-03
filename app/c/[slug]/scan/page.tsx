import { notFound, permanentRedirect } from 'next/navigation'
import { isTestFixture } from '@/lib/test-fixture'
import { headers } from 'next/headers'
import { after } from 'next/server'
import ScanLanding from '@/app/components/ScanLanding'
import { getPublicBusinessProfile } from '@/lib/business-profile'
import { isSuspended } from '@/lib/suspension'
import { logScanServer, requestMeta } from '@/lib/scan'
import { rowTradeLabel } from '@/lib/tradeCategories'
import { resolveBusinessSlug, withQuery } from '@/lib/business'
import { fileDate, ABSENT } from '@/lib/licence-status'
import { requestBrand } from '@/lib/brand'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
// Read from the environment — never hardcode the key. Set SUPABASE_SECRET_KEY in
// Vercel (and .env.local for local dev). Matches lib/supabase/server.ts.
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }


async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors_public_direct?slug=eq.${encodeURIComponent(slug)}&select=*&limit=1`,
    { headers: SB_HEADERS, cache: 'no-store' }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

// The date of the state file the licence fields come from — the same stamp the profile shows.
async function getRecordDate(): Promise<string | null> {
  try {
    const res = await fetch(
      `https://${SB_HOST}/rest/v1/dbpr_snapshot_log?is_register_source=eq.true&select=capture_date&limit=1`,
      { headers: SB_HEADERS, next: { revalidate: 3600 } }
    )
    if (!res.ok) return null
    const rows = await res.json()
    const d = rows?.[0]?.capture_date
    return d ? new Date(d).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }) : null
  } catch {
    return null
  }
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Contractor' }
  const fixture = await isTestFixture('contractors', c.license_number)  // ruling 927: fixtures are never indexed
  return {
    title: `${c.display_name}`,
    description: `${rowTradeLabel(c)} in ${c.city ?? 'Florida'}.`,
    ...(fixture ? { robots: { index: false, follow: false } } : {}),
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

  // Suspended (ruling 762 part 4): the same neutral page as the profile, since printed QR codes land here.
  if (await isSuspended(slug)) {
    return (
      <main style={{ maxWidth: '560px', margin: '0 auto', padding: '48px 16px', textAlign: 'center' }}>
        <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', margin: '0 0 10px' }}>This profile is not currently available</h1>
        <p style={{ fontSize: '0.9rem', margin: '0 0 18px' }}><a href="/c" style={{ color: 'var(--color-bronze)' }}>Search the register</a></p>
      </main>
    )
  }

  // The landing is logged by the request; ScanLanding logs only the visitor's clicks.
  after(() => logScanServer({
    slug, ref: ref ?? 'qr', action: 'scan_landing',
    tradeCategory: c.doc_category, city: c.city, state: c.state, meta,
  }))

  const tradeLabel = rowTradeLabel(c)  // ruling 957
  // A website only exists once the owner has claimed and published one (work order 730); the state
  // file's website column is empty and is never offered.
  const ownWebsite = c.claimed ? ((await getPublicBusinessProfile(slug))?.website ?? null) : null
  // Per-licence file date (138a); the register's single date until that column exists.
  const recordDate = fileDate(c.register_file_date) ?? await getRecordDate()

  return (
    <ScanLanding
      slug={slug}
      displayName={c.display_name}
      tradeLabel={tradeLabel}
      city={c.city ?? ''}
      state={c.state ?? ''}
      tradeCategory={c.doc_category ?? ''}
      hasWebsite={!!ownWebsite}
      websiteUrl={ownWebsite}
      ref_={ref ?? 'qr'}
      licenseNumber={c.license_number ?? null}
      licenseStatus={c.license_status ?? null}
      expiryDate={c.expiry_date ?? null}
      recordDate={recordDate}
      absent={c.register_file_state === ABSENT}
      siteName={(await requestBrand()).name}
    />
  )
}
