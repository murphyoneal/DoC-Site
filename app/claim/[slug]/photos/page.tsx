import Link from 'next/link'
import { permanentRedirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { resolveBusinessSlug } from '@/lib/business'
import WorkUploadForm from '@/app/components/WorkUploadForm'
import PhotoList, { type OwnPhoto } from '@/app/components/PhotoList'

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

// The owner's own photos (not withdrawn), each with a one-hour signed link to its private copy.
async function ownPhotos(contractorId: string): Promise<{ photos: OwnPhoto[]; limit: number }> {
  const H = { apikey: KEY, Authorization: 'Bearer ' + KEY }
  try {
    const [rows, lim] = await Promise.all([
      fetch(`${HOST}/rest/v1/work_contribution?contractor_id=eq.${contractorId}&visibility=not.in.(withdrawn_by_contractor,withdrawn_by_owner)&select=id,visibility,created_at,work_contribution_image(held_path,public_path)&order=created_at.desc`, { headers: H, cache: 'no-store' }).then(r => r.json()),
      fetch(`${HOST}/rest/v1/operating_threshold?name=eq.free_photos_per_business&select=limit_value`, { headers: H, cache: 'no-store' }).then(r => r.json()),
    ])
    const photos: OwnPhoto[] = []
    for (const c of rows as { id: string; visibility: string; created_at: string; work_contribution_image: { held_path: string | null; public_path: string | null }[] }[]) {
      const path = c.work_contribution_image[0]?.held_path
      let thumb: string | null = null
      if (path) {
        const s = await fetch(`${HOST}/storage/v1/object/sign/work-private/${path}`, { method: 'POST', cache: 'no-store', headers: { ...H, 'Content-Type': 'application/json' }, body: JSON.stringify({ expiresIn: 3600 }) })
        const j = s.ok ? await s.json() : null
        thumb = j?.signedURL ? `${HOST}/storage/v1${j.signedURL}` : null
      }
      photos.push({ id: c.id, thumb, visibility: c.visibility, created_at: c.created_at })
    }
    return { photos, limit: Number(lim?.[0]?.limit_value ?? 10) }
  } catch { return { photos: [], limit: 10 } }
}

const LOCKED: Record<string, string> = {
  suspended: 'This business’s page is not being shown, and uploads are paused.',
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
        Photos are reviewed by a person before they appear. Photo galleries are not shown on public pages yet.
        When they are, we will not publish the address of the job, and we remove
        the location and camera data from the published copy. A photo can still show things that
        identify a property — a house number, a vehicle — so choose shots with that in mind.
      </p>

      {g?.allowed ? (
        <>
          {await (async () => { const o = await ownPhotos(g.contractor_id); return <PhotoList slug={slug} photos={o.photos} limit={o.limit} /> })()}
          <WorkUploadForm slug={slug} />
        </>
      ) : (
        <div style={{ background: 'var(--color-light-gray)', borderRadius: '12px', padding: '16px', fontSize: '0.86rem' }}>
          <p style={{ margin: 0 }}>{LOCKED[reason] ?? 'Photo uploads are not available right now.'}</p>
          {reason === 'suspended' && (
            <p style={{ margin: '8px 0 0' }}><Link href={`/claim/${slug}/appeal`} style={{ color: 'var(--color-bronze)' }}>If you think that is wrong, appeal &rarr;</Link></p>
          )}
          {user && reason === 'not_the_claimant' && (
            <p style={{ margin: '8px 0 0' }}>You are signed in as {user.email}. Use &ldquo;Sign out&rdquo; at the top of the page, then sign in with the email address on the approved claim.</p>
          )}
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
