import type { Metadata } from 'next'
import Link from 'next/link'
import AgentClaimForm from '@/app/components/AgentClaimForm'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { rpc } from '@/lib/agent-profile'

type ClaimState = { state: 'none' | 'pending' | 'approved'; mine: boolean; on: string | null; slug: string | null }

// /agents/claim - an agent claims their own licence (work order 712 item 2). Linked from each person
// in the agent register search. Unclaimed licences stay searchable and never get a page; an approved
// claim is what creates one.
export const metadata: Metadata = { title: 'Claim your licence', robots: { index: false } }

export default async function AgentClaimPage({ searchParams }: { searchParams: Promise<{ [k: string]: string | string[] | undefined }> }) {
  const sp = await searchParams
  const licence = (Array.isArray(sp.licence) ? sp.licence[0] : sp.licence ?? '').replace(/[^A-Za-z0-9]/g, '').slice(0, 20)
  // Known at LOAD (work order 727): a claimed or under-review licence never shows a form that will reject.
  const user = await getSessionUser()
  const cs = licence ? await rpc<ClaimState>('claim_state_for_licence', { p_licence: licence, p_email: user?.email ?? null }) : null
  const mail = <a href="mailto:register@departmentofproperty.com?subject=Agent%20claim%20query" style={{ color: 'var(--color-bronze)' }}>register@departmentofproperty.com</a>
  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '24px 16px 48px' }}>
      <div style={{ maxWidth: 620, margin: '0 auto' }}>
        <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.4rem', margin: '0 0 8px' }}>Claim your licence</h1>
        <p style={{ fontSize: '0.88rem', color: 'var(--color-ink)', margin: '0 0 8px', lineHeight: 1.55 }}>
          For Florida real estate licensees. We check the name you give against the state licence file and whether the licence
          is current, and a person reviews every claim before anything is published.
        </p>
        <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 18px', lineHeight: 1.55 }}>
          Once approved, you get a page showing your licence as the state records it (type, status, expiry and brokerage, each
          with the date of the file) and you can add your own details: contact, website, a short bio, the counties and property
          types you work. Each one is off until you switch it on.
        </p>
        {cs && cs.state !== 'none' ? (
          <div className="reg-card">
            <h2 className="reg-h2" style={{ marginTop: 0 }}>
              {cs.state === 'approved' ? (cs.mine ? 'This is your licence' : 'This licence has been claimed') : (cs.mine ? 'Your claim is under review' : 'A claim on this licence is under review')}
            </h2>
            {cs.state === 'approved' && cs.mine && cs.slug && (
              <p className="reg-p" style={{ display: 'flex', gap: 16, flexWrap: 'wrap', margin: 0 }}>
                <Link href={`/a/${cs.slug}/edit`} className="finder-btn" style={{ textDecoration: 'none' }}>Edit your page</Link>
                <Link href={`/a/${cs.slug}`} style={{ color: 'var(--color-bronze)', alignSelf: 'center' }}>View your page</Link>
              </p>
            )}
            {cs.state === 'approved' && !cs.mine && (
              <p className="reg-p" style={{ margin: 0 }}>
                {!user && cs.slug ? <>If the claim is yours, <Link href={`/login?next=/a/${cs.slug}/edit`} style={{ color: 'var(--color-bronze)' }}>sign in</Link> with the email you claimed with. </> : null}
                If you hold this licence and believe the claim is wrong, email {mail}.
              </p>
            )}
            {cs.state === 'pending' && (
              <p className="reg-p" style={{ margin: 0 }}>
                {cs.mine ? 'A person reads every claim. When yours is approved we will send a link to your email to set your password.'
                         : <>A person is reviewing it. If you hold this licence and believe the claim is not yours, email {mail}.</>}
              </p>
            )}
          </div>
        ) : (
          <AgentClaimForm licence={licence} />
        )}
      </div>
    </main>
  )
}
