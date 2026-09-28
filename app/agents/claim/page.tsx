import type { Metadata } from 'next'
import AgentClaimForm from '@/app/components/AgentClaimForm'

// /agents/claim - an agent claims their own licence (work order 712 item 2). Linked from each person
// in the agent register search. Unclaimed licences stay searchable and never get a page; an approved
// claim is what creates one.
export const metadata: Metadata = { title: 'Claim your licence', robots: { index: false } }

export default async function AgentClaimPage({ searchParams }: { searchParams: Promise<{ [k: string]: string | string[] | undefined }> }) {
  const sp = await searchParams
  const licence = (Array.isArray(sp.licence) ? sp.licence[0] : sp.licence ?? '').replace(/[^A-Za-z0-9]/g, '').slice(0, 20)
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
        <AgentClaimForm licence={licence} />
      </div>
    </main>
  )
}
