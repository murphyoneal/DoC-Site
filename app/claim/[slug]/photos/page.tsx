import Link from 'next/link'
import { permanentRedirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { resolveBusinessSlug } from '@/lib/business'
import WorkUploadForm from '@/app/components/WorkUploadForm'

// /claim/{slug}/photos — upload photos of work (653 (d)). Reachable only by the requester of an
// APPROVED claim on this business. No claim has been approved yet, so today every visitor meets
// the locked door below; it opens when the first claim is approved (ruling 2026-09-25).

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''

async function gate(slug: string, email: string | null) {
  try {
    const r = await fetch(`${HOST}/rest/v1/rpc/work_upload_gate`, {
      method: 'POST', cache: 'no-store',
      headers: { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_slug: slug, p_email: email }),
    })
    return r.ok ? await r.json() : null
  } catch { return null }
}

const LOCKED: Record<string, string> = {
  no_approved_claim: 'Photo uploads open once a claim on this business has been approved.',
  not_the_claimant: 'Photo uploads are open only to the person whose claim on this business was approved.',
  not_in_register: 'This business is not in the register.',
}

export const metadata = { title: 'Photos of your work', robots: { index: false } }

export default async function WorkPhotosPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const business = await resolveBusinessSlug(slug)
  if (business?.redirect) permanentRedirect(`/claim/${business.slug}/photos`)

  const user = await getSessionUser()
  const g = await gate(slug, user?.email ?? null)
  const reason: string = g?.reason ?? 'unavailable'

  return (
    <main style={{ maxWidth: '560px', margin: '0 auto', padding: '32px 16px' }}>
      <Link href={`/c/${slug}`} style={{ color: 'var(--color-bronze)', fontSize: '0.82rem', textDecoration: 'none' }}>← Back to profile</Link>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', fontWeight: 700, margin: '12px 0 8px' }}>
        Photos of your work
      </h1>
      <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 18px' }}>
        Photos appear on your public profile. We do not publish the address of the job, and we remove
        the location and camera data from the published copy. A photo can still show things that
        identify a property — a house number, a vehicle — so choose shots with that in mind.
      </p>

      {g?.allowed ? (
        <WorkUploadForm slug={slug} />
      ) : (
        <div style={{ background: 'var(--color-light-gray)', borderRadius: '12px', padding: '16px', fontSize: '0.86rem' }}>
          <p style={{ margin: 0 }}>{LOCKED[reason] ?? 'Photo uploads are not available right now.'}</p>
          {!user && reason === 'not_the_claimant' && (
            <p style={{ margin: '8px 0 0' }}><Link href={`/login?next=/claim/${slug}/photos`}>Sign in</Link> with the email address on the approved claim.</p>
          )}
          {reason === 'no_approved_claim' && (
            <p style={{ margin: '8px 0 0' }}><Link href={`/claim/${slug}`} style={{ color: 'var(--color-bronze)' }}>Claim this business →</Link></p>
          )}
        </div>
      )}
    </main>
  )
}
