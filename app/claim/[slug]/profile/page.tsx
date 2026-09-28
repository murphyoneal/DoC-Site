import Link from 'next/link'
import { permanentRedirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { resolveBusinessSlug } from '@/lib/business'
import { getEditorProfile } from '@/lib/business-profile'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'
import BusinessProfileForm from '@/app/components/BusinessProfileForm'

// /claim/{slug}/profile - a claimed business fills in what the state file does not carry (work order
// 712 item 3). The same locked door as /claim/{slug}/photos: open only to the person whose claim on
// this business was APPROVED, signed in with that claim's email. Every "show this" switch starts off.

export const metadata = { title: 'Your business details', robots: { index: false } }

const LOCKED: Record<string, string> = {
  no_approved_claim: 'Your details can be added once a claim on this business has been approved. A person reads every claim.',
  not_the_claimant: 'Only the person whose claim on this business was approved can edit its details.',
  not_in_register: 'This business is not in the register.',
}

const TRADES = Object.entries(CATEGORY_LABELS)
  .filter(([k]) => k !== 'education_provider' && k !== 'qualifier_business')
  .sort((a, b) => a[1].localeCompare(b[1]))

export default async function ProfileEditPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const business = await resolveBusinessSlug(slug)
  if (business?.redirect) permanentRedirect(`/claim/${business.slug}/profile`)

  const user = await getSessionUser()
  const g = await getEditorProfile(slug, user?.email ?? null)
  const reason = g?.reason ?? 'unavailable'

  return (
    <main style={{ maxWidth: '640px', margin: '0 auto', padding: '32px 16px' }}>
      <Link href={`/c/${slug}`} style={{ color: 'var(--color-bronze)', fontSize: '0.82rem', textDecoration: 'none' }}>&larr; Back to profile</Link>
      <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', fontWeight: 700, margin: '12px 0 8px' }}>
        Your business details
      </h1>
      <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 18px', lineHeight: 1.55 }}>
        Add what the state licence file doesn&rsquo;t carry. It appears on your profile under &ldquo;From the business&rdquo;,
        separate from the register, and only the items you switch on are shown. Nothing is shown until you switch it on.
        {' '}<Link href={`/claim/${slug}/photos`} style={{ color: 'var(--color-bronze)' }}>Add photos of your work</Link>.
      </p>
      {g?.allowed ? (
        <BusinessProfileForm slug={slug} trades={TRADES} initial={g.profile ?? null} initialInsurance={g.insurance ?? []} />
      ) : (
        <div style={{ background: 'var(--color-light-gray)', borderRadius: '12px', padding: '16px', fontSize: '0.86rem' }}>
          <p style={{ margin: 0 }}>{LOCKED[reason] ?? 'Editing is not available right now.'}</p>
          {!user && reason === 'not_the_claimant' && (
            <p style={{ margin: '8px 0 0' }}><Link href={`/login?next=/claim/${slug}/profile`}>Sign in</Link> with the email address on the approved claim.</p>
          )}
          {reason === 'no_approved_claim' && (
            <p style={{ margin: '8px 0 0' }}><Link href={`/claim/${slug}`} style={{ color: 'var(--color-bronze)' }}>Claim this business &rarr;</Link></p>
          )}
        </div>
      )}
    </main>
  )
}
