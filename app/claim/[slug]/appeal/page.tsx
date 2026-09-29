import Link from 'next/link'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { rpc } from '@/lib/suspension'
import AppealForm from '@/app/components/AppealForm'

// /claim/{slug}/appeal - the approved claimant of a SUSPENDED business explains, in their own words
// (ruling 762 part 4, 765.4). No reason for the suspension is rendered here or anywhere public.

export const metadata = { title: 'Appeal', robots: { index: false } }

export default async function AppealPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const user = await getSessionUser()
  const g = user?.email ? await rpc<{ reason?: string; claimant?: boolean }>('work_upload_gate', { p_slug: slug, p_email: user.email }) : null
  const suspendedClaimant = g?.reason === 'suspended' && g?.claimant === true

  return (
    <main style={{ maxWidth: '560px', margin: '0 auto', padding: '32px 16px' }}>
      <Link href={`/claim/${slug}/profile`} style={{ color: 'var(--color-bronze)', fontSize: '0.82rem', textDecoration: 'none' }}>← Back</Link>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', fontWeight: 700, margin: '12px 0 8px' }}>Appeal</h1>
      {suspendedClaimant ? (
        <>
          <p style={{ fontSize: '0.86rem', margin: '0 0 14px' }}>
            Your page is not being shown and editing is paused. If you think that is wrong, tell us why. A person reads every appeal.
          </p>
          <AppealForm slug={slug} />
        </>
      ) : !user ? (
        <p style={{ fontSize: '0.86rem' }}><Link href={`/login?next=/claim/${slug}/appeal`}>Sign in</Link> with the email address on the approved claim.</p>
      ) : (
        <p style={{ fontSize: '0.86rem' }}>There is nothing to appeal for this business from this account.</p>
      )}
    </main>
  )
}
