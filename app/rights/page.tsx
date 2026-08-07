import type { Metadata } from 'next'
import Link from 'next/link'
import JsonLd from '@/app/components/JsonLd'
import { legalSocket } from '@/lib/sockets/legal'
import { SITE_URL } from '@/lib/site'

const BASE = SITE_URL

export const metadata: Metadata = {
  title: 'Construction-defect deadlines by state — what you can still do',
  description:
    'The deadline to sue over a construction defect is a state-by-state accident of geography — five years in Virginia, twelve in Pennsylvania, none at all in New York. Find your state.',
  alternates: { canonical: '/rights' },
}

export default async function Page() {
  const states = await legalSocket.listVerifiedStates()

  // Shortest deadline first; no-repose (NY) last — the extremes are the story.
  const ranked = [...states].sort((a, b) => {
    if (a.repose_years == null) return 1
    if (b.repose_years == null) return -1
    if (a.repose_years !== b.repose_years) return a.repose_years - b.repose_years
    return a.state_name.localeCompare(b.state_name)
  })

  const shortest = ranked.find(s => s.repose_years != null)
  const longest = [...ranked].reverse().find(s => s.repose_years != null)
  const fraudStates = states.filter(s => s.fraud_exempts_repose === true)

  const itemList = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: 'Construction-defect deadlines by state',
    itemListElement: ranked.map((s, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: s.state_name,
      url: `${BASE}/rights/${s.slug}`,
    })),
  }

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
      <JsonLd data={itemList} />

      <nav className="text-xs mb-6" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>Your rights by state</span>
      </nav>

      <header className="mb-8">
        <h1 className="text-3xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          Here is what you have, and here is how to keep it.
        </h1>
        <p className="text-base leading-relaxed mb-2" style={{ color: 'var(--color-ink)' }}>
          The deadline to do something about a construction defect is not a fact about your house.
          It is a fact about your state.
          {shortest && longest && (
            <>
              {' '}The same crack in the same wall gives you{' '}
              <strong>{shortest.repose_years} years in {shortest.state_name}</strong>,{' '}
              <strong>{longest.repose_years} in {longest.state_name}</strong>, and — in New York —{' '}
              <strong>no repose deadline at all</strong>. Dead in one state, live in another.
            </>
          )}
        </p>
        <p className="text-sm" style={{ color: 'var(--color-sage)' }}>
          {states.length} states verified against their primary statutory text. Find yours.
        </p>
      </header>

      <section className="mb-8">
        <div className="rounded-xl overflow-hidden" style={{ border: '1px solid var(--color-light-gray)' }}>
          {ranked.map((s, i) => (
            <Link
              key={s.slug}
              href={`/rights/${s.slug}`}
              className="flex items-center justify-between px-4 py-3 hover:opacity-80"
              style={{
                background: i % 2 ? 'var(--color-white)' : 'var(--color-light-gray)',
                borderTop: i ? '1px solid #e6e2da' : 'none',
              }}
            >
              <span className="font-semibold" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
                {s.state_name}
              </span>
              <span className="flex items-center gap-3">
                {s.fraud_exempts_repose === true && (
                  <span className="text-xs" style={{ color: 'var(--color-terracotta, #b5502f)' }} title="Fraud is not cut off by the deadline">
                    fraud exempt
                  </span>
                )}
                <span className="text-sm font-bold tabular-nums" style={{ color: 'var(--color-bronze)' }}>
                  {s.repose_years == null ? 'no repose' : `${s.repose_years} yr`}
                </span>
              </span>
            </Link>
          ))}
        </div>
      </section>

      {fraudStates.length > 0 && (
        <section className="mb-8 rounded-lg p-4" style={{ background: 'rgba(181,80,47,0.06)', border: '1px solid var(--color-terracotta, #b5502f)' }}>
          <h2 className="text-base font-bold mb-1" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-terracotta, #b5502f)' }}>
            In {fraudStates.length} of these states, the deadline does not protect fraud.
          </h2>
          <p className="text-sm" style={{ color: 'var(--color-ink)' }}>
            A builder who concealed the problem cannot hide behind the clock in{' '}
            {fraudStates.map(s => s.state_name).sort().join(', ')}. Where a state is not listed here,
            assume the deadline is firm.
          </p>
        </section>
      )}

      <footer className="text-xs leading-relaxed pt-4" style={{ color: 'var(--color-sage)', borderTop: '1px solid var(--color-light-gray)' }}>
        <p>
          General information about statutory deadlines, not legal advice. Deadlines have
          fact-specific exceptions — confirm your own situation with a lawyer licensed in your state.{' '}
          <Link href="/disclaimer" className="underline" style={{ color: 'var(--color-bronze)' }}>Full disclaimer</Link>.
        </p>
      </footer>
    </div>
  )
}
