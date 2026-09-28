import Link from 'next/link'
import { redirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { requestBrand } from '@/lib/brand'
import { DOC_URL, DOP_URL } from '@/lib/site'

// Where a signed-in person lands (work order 725): what they have claimed, and a way into each.
// One approved claim on this site goes straight to its editor; otherwise they choose.
export const metadata = { title: 'Your account', robots: { index: false } }

type Item = { label: string; kind: 'business' | 'agent'; edit: string; page: string; photos?: string; host: string }

export default async function AccountPage() {
  const user = await getSessionUser()
  if (!user?.email) redirect('/login?next=/account')
  const brand = await requestBrand()
  const here = brand.key === 'doc' ? DOC_URL : DOP_URL
  const db = getSupabaseAdmin()
  const email = user.email.toLowerCase()
  const items: Item[] = []

  const { data: claims } = await db.from('claim_requests').select('contractor_id, status').ilike('requester_email', email)
  for (const c of claims ?? []) {
    if (c.status !== 'approved') continue
    const { data: bl } = await db.from('business_licences').select('businesses(slug, display_name)').eq('contractor_id', c.contractor_id).limit(1).maybeSingle()
    const b = (bl as unknown as { businesses?: { slug: string; display_name: string | null } } | null)?.businesses
    if (b?.slug && !items.some(i => i.page.endsWith(`/c/${b.slug}`)))
      items.push({ label: b.display_name ?? b.slug, kind: 'business', edit: `/claim/${b.slug}/profile`, photos: `/claim/${b.slug}/photos`, page: `/c/${b.slug}`, host: DOC_URL })
  }
  const { data: agents } = await db.from('agent_claim_request').select('license_number, status').ilike('requester_email', email)
  for (const a of agents ?? []) {
    if (a.status !== 'approved') continue
    const { data: ap } = await db.from('agent_public_profile').select('slug').eq('license_number', a.license_number).maybeSingle()
    if (ap?.slug) items.push({ label: `Florida real estate licence ${a.license_number}`, kind: 'agent', edit: `/a/${ap.slug}/edit`, page: `/a/${ap.slug}`, host: DOP_URL })
  }
  const pending = (claims ?? []).filter(c => c.status === 'pending').length + (agents ?? []).filter(a => a.status === 'pending').length

  const onThisSite = items.filter(i => i.host === here)
  if (items.length === 1 && onThisSite.length === 1) redirect(onThisSite[0].edit)

  return (
    <main style={{ minHeight: '80dvh', background: 'var(--color-cream)', padding: '32px 16px' }}>
      <div style={{ maxWidth: 620, margin: '0 auto', display: 'grid', gap: 14 }}>
        <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', margin: 0 }}>Your account</h1>
        <p className="reg-p" style={{ margin: 0 }}>Signed in as {user.email}.</p>
        {items.length === 0 && (
          <div className="reg-card">
            <p className="reg-p" style={{ margin: 0 }}>
              {pending ? 'Your claim is waiting for review. A person reads every claim; once it is approved you can edit your page from here.'
                       : 'Nothing is claimed with this email address yet.'}
            </p>
          </div>
        )}
        {items.map(i => {
          const abs = (p: string) => (i.host === here ? p : `${i.host}${p}`)
          return (
            <div key={i.page} className="reg-card" style={{ display: 'grid', gap: 6 }}>
              <b style={{ color: 'var(--color-navy)' }}>{i.label}</b>
              <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', fontSize: 14 }}>
                <Link href={abs(i.edit)} style={{ color: 'var(--color-bronze)' }}>Edit details</Link>
                {i.photos && <Link href={abs(i.photos)} style={{ color: 'var(--color-bronze)' }}>Photos of your work</Link>}
                <Link href={abs(i.page)} style={{ color: 'var(--color-bronze)' }}>View your page</Link>
              </div>
              {i.host !== here && <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>This one is on {i.host.replace('https://', '')}; you may be asked to sign in there too, with the same email and password.</span>}
            </div>
          )
        })}
      </div>
    </main>
  )
}
