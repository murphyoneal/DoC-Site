import Link from 'next/link'
import { notFound } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import ReviewBoard, { type Queue } from '@/app/components/ReviewBoard'

// /review - the operator's page (ruling 762 part 5). The operator CLEARS or REMOVES; it does not publish.
// A work photo becomes public only when the homeowner has claimed the property and approved that photo
// (ruling 795) - until that store exists nothing publishes, and trigger work_contribution_publication_gate
// (163a) refuses it in the database. Here a photo can only be held. Anything the language check flagged is pinned
// at the top. Every action is a POST that records who, when, what and why (765.7).
// Signed out: a sign-in link. Signed in but not an operator: 404 - the page does not advertise itself.

export const metadata = { title: 'Review', robots: { index: false, follow: false } }
export const dynamic = 'force-dynamic'

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const AUTH = { apikey: KEY, Authorization: 'Bearer ' + KEY }

async function rpc<T>(fn: string, args: object): Promise<T | null> {
  try {
    const r = await fetch(`${HOST}/rest/v1/rpc/${fn}`, { method: 'POST', cache: 'no-store', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify(args) })
    return r.ok ? ((await r.json()) as T) : null
  } catch { return null }
}
async function sign(bucket: string, path: string | null | undefined): Promise<string | null> {
  if (!path) return null
  try {
    const r = await fetch(`${HOST}/storage/v1/object/sign/${bucket}/${path}`, { method: 'POST', cache: 'no-store', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ expiresIn: 3600 }) })
    const j = r.ok ? await r.json() : null
    return j?.signedURL ? `${HOST}/storage/v1${j.signedURL}` : null
  } catch { return null }
}

export default async function ReviewPage() {
  const user = await getSessionUser()
  if (!user?.email) {
    return (
      <main style={{ maxWidth: 560, margin: '0 auto', padding: '48px 16px' }}>
        <p><Link href="/login?next=/review">Sign in</Link> to continue.</p>
      </main>
    )
  }
  if ((await rpc<boolean>('is_operator', { p_email: user.email })) !== true) notFound()

  const q = await rpc<Queue>('review_queue', {})
  if (!q) return <main style={{ padding: 32 }}>The review list could not be read just now. Reload to try again.</main>
  for (const p of q.photos) p.thumb = await sign('work-private', p.held_path)
  for (const p of q.profiles) p.logo = await sign('logo-private', p.logo_path)

  return (
    <main style={{ maxWidth: 980, margin: '0 auto', padding: '28px 16px' }}>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', margin: '0 0 4px' }}>Review</h1>
      <p style={{ fontSize: 13, color: 'var(--color-sage)', margin: '0 0 18px' }}>
        Signed in as {user.email}. Every action is recorded with who, when and why, and cannot be edited afterwards.
      </p>
      <ReviewBoard queue={q} />
    </main>
  )
}
