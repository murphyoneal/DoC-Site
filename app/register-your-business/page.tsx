import type { Metadata } from 'next'
import SelfRegisterForm from '../components/SelfRegisterForm'
import { getStates } from '@/lib/registration'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'

// Self-registration for a business in any of the 50 states or DC (work order 699). It does not need
// a licence record we already hold: a business declares who it is and what it holds, we check what
// we can, and we say plainly what we cannot. Nothing is public until a person has reviewed it and
// the business has switched each field on.

export const metadata: Metadata = {
  title: 'Register your business',
  description: 'List a contracting business from any US state. Tell us your licences, certifications and insurance; we check what we can against the state registers we hold and say which ones we cannot.',
}

// Trades a business can offer. Not the two keys that are neither a trade nor a scope.
const TRADES = Object.entries(CATEGORY_LABELS)
  .filter(([k]) => k !== 'education_provider' && k !== 'qualifier_business')
  .sort((a, b) => a[1].localeCompare(b[1]))

export default async function RegisterYourBusiness() {
  const states = await getStates()
  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '24px 16px 48px' }}>
      <div style={{ maxWidth: 720, margin: '0 auto' }}>
        <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.5rem', margin: '0 0 8px' }}>
          Register your business
        </h1>
        <p style={{ fontSize: '0.9rem', color: 'var(--color-ink)', margin: '0 0 8px', lineHeight: 1.55 }}>
          For contracting businesses in any US state. Tell us who you are, where you work and what you hold:
          licences, certifications and insurance. We check each licence against the state register where we
          hold it, and where we don&rsquo;t, we say so.
        </p>
        <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 20px', lineHeight: 1.55 }}>
          Today we hold one state register: Florida construction licences. A Utah licence, for example, will
          read &ldquo;Not verified. We don&rsquo;t yet hold Utah&rsquo;s licence records&rdquo;. That says
          nothing about you, only about what we hold. A person reads every registration, and nothing appears
          publicly until it has been reviewed and you have chosen to show it.
        </p>
        <SelfRegisterForm states={states} trades={TRADES} />
      </div>
    </main>
  )
}
