import Link from 'next/link'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { getAgentEditor } from '@/lib/agent-profile'
import AgentProfileForm from '@/app/components/AgentProfileForm'

// /a/{slug}/edit - an approved agent edits their own details. Open only to the person whose claim on
// this licence was approved, signed in with that claim's email.
export const metadata = { title: 'Your details', robots: { index: false } }

const LOCKED: Record<string, string> = {
  no_approved_claim: 'There is no approved claim for this page.',
  not_the_claimant: 'Only the person whose claim on this licence was approved can edit this page.',
}

export default async function AgentEditPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const user = await getSessionUser()
  const g = await getAgentEditor(slug, user?.email ?? null)
  return (
    <main style={{ maxWidth: 640, margin: '0 auto', padding: '32px 16px' }}>
      <Link href={`/a/${slug}`} style={{ color: 'var(--color-bronze)', fontSize: '0.82rem', textDecoration: 'none' }}>&larr; Back to your page</Link>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', margin: '12px 0 8px' }}>Your details</h1>
      <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 18px' }}>
        These appear under &ldquo;From the agent&rdquo;, separate from your licence record, and only the items you switch on are shown.
      </p>
      {g?.allowed && g.profile ? (
        <AgentProfileForm slug={slug} initial={g.profile} registerBrokerage={g.register_brokerage ?? null} vocab={g.classes_vocab ?? []} />
      ) : (
        <div style={{ background: 'var(--color-light-gray)', borderRadius: 12, padding: 16, fontSize: '0.86rem' }}>
          <p style={{ margin: 0 }}>{LOCKED[g?.reason ?? ''] ?? 'Editing is not available right now.'}</p>
          {user && g?.reason === 'not_the_claimant' && (
            <p style={{ margin: '8px 0 0' }}>You are signed in as {user.email}. Use &ldquo;Sign out&rdquo; at the top of the page, then sign in with the email address on the approved claim.</p>
          )}
          {!user && g?.reason === 'not_the_claimant' && (
            <p style={{ margin: '8px 0 0' }}><Link href={`/login?next=/a/${slug}/edit`}>Sign in</Link> with the email on the approved claim.</p>
          )}
        </div>
      )}
    </main>
  )
}
