import Link from 'next/link'
import JsonLd from './JsonLd'
import type { LegalStateRow } from '@/lib/sockets/legal'
import { SITE_URL } from '@/lib/site'

const BASE = SITE_URL

// State construction-defect rights landing page. Order is fixed by product rule
// (website_copy.framing_rights_not_fear): RIGHTS first, then the DEADLINE, then
// the ACTION. The fraud carve-out is a headline ONLY where fraud_exempts_repose
// is true; where it is false we say nothing rather than imply protection.
export default function StateRightsLanding({
  state,
  compare,
}: {
  state: LegalStateRow
  compare: { slug: string; state_name: string; repose_years: number | null }[]
}) {
  const url = `${BASE}/rights/${state.slug}`
  const hasRepose = state.repose_years != null
  const fraud = state.fraud_exempts_repose === true

  // Two non-fraud levers worth a headline, pulled by canonical tag from other_exceptions
  // (never a prose search). Description keeps the DB's cite; the headline is ours.
  const oe = state.other_exceptions ?? []
  const strip = (tag: string) => oe.find(e => e.startsWith(tag + ' '))?.replace(new RegExp('^' + tag + '\\s*—\\s*'), '')
  const contractSurvives = strip('contract_warranty_survives')
  const possession = strip('possession_control')

  const deadlineHeadline = hasRepose
    ? `${state.repose_years} years to bring a construction-defect claim`
    : `${state.state_name} has no general statute of repose for construction`

  const article = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: `Construction-defect deadline in ${state.state_name}`,
    description: state.homeowner_summary ?? undefined,
    isPartOf: { '@type': 'WebSite', name: 'Department of Construction', url: BASE },
    url,
    ...(state.primary_source_url ? { citation: state.primary_source_url } : {}),
  }
  const breadcrumb = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: 'Home', item: BASE },
      { '@type': 'ListItem', position: 2, name: 'Your rights by state', item: `${BASE}/rights` },
      { '@type': 'ListItem', position: 3, name: state.state_name, item: url },
    ],
  }

  // The spread, sorted shortest→longest, NULL (no repose) last. This state marked.
  const ranked = [...compare].sort((a, b) => {
    if (a.repose_years == null) return 1
    if (b.repose_years == null) return -1
    return a.repose_years - b.repose_years
  })

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-8">
      <JsonLd data={breadcrumb} />
      <JsonLd data={article} />

      {/* Breadcrumb */}
      <nav className="text-xs mb-6" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <Link href="/rights" className="hover:underline">Your rights by state</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>{state.state_name}</span>
      </nav>

      {/* Hero — rights framing, never fear framing */}
      <header className="mb-8">
        <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: 'var(--color-bronze)' }}>
          {state.state_name} · Construction-defect rights
        </p>
        <h1 className="text-3xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          Here is what you have, and here is how to keep it.
        </h1>
        {state.homeowner_summary && (
          <p className="text-base leading-relaxed" style={{ color: 'var(--color-ink)' }}>
            {state.homeowner_summary}
          </p>
        )}
      </header>

      {/* 1 · RIGHTS (lead) */}
      <section className="mb-8">
        <h2 className="text-xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          What you have
        </h2>
        {fraud && (
          <div
            className="rounded-lg p-4 mb-4"
            style={{ background: 'rgba(181,80,47,0.08)', border: '1px solid var(--color-terracotta, #b5502f)' }}
          >
            <p className="text-sm font-semibold mb-1" style={{ color: 'var(--color-terracotta, #b5502f)' }}>
              The deadline does not protect a builder who concealed the problem.
            </p>
            <p className="text-sm" style={{ color: 'var(--color-ink)' }}>
              In {state.state_name}, a claim of fraud, concealment or serious misconduct is not
              cut off by the ordinary construction deadline
              {state.fraud_exception_cite ? ` (${state.fraud_exception_cite})` : ''}.
            </p>
          </div>
        )}
        {contractSurvives && (
          <div className="rounded-lg p-4 mb-4" style={{ background: 'rgba(154,106,58,0.08)', border: '1px solid var(--color-bronze, #9a6a3a)' }}>
            <p className="text-sm font-semibold mb-1" style={{ color: 'var(--color-bronze, #9a6a3a)' }}>
              Past the deadline for a defect? A contract claim may still be alive.
            </p>
            <p className="text-sm" style={{ color: 'var(--color-ink)' }}>
              The construction deadline here bars tort claims — but {contractSurvives} Someone told
              &ldquo;you&rsquo;re past the deadline&rdquo; may still have a live contract or warranty
              claim, and typically no one volunteers that.
            </p>
          </div>
        )}
        {possession && (
          <div className="rounded-lg p-4 mb-4" style={{ background: 'rgba(154,106,58,0.08)', border: '1px solid var(--color-bronze, #9a6a3a)' }}>
            <p className="text-sm font-semibold mb-1" style={{ color: 'var(--color-bronze, #9a6a3a)' }}>
              If the builder or developer still controls the property, the deadline isn&rsquo;t theirs to raise.
            </p>
            <p className="text-sm" style={{ color: 'var(--color-ink)' }}>
              The exception most homeowners would never think to ask about: {possession} It matters
              most where a builder still controls part of a project — a phased subdivision, an
              unfinished condo association.
            </p>
          </div>
        )}
        {state.rights_you_have && (
          <p className="text-base leading-relaxed whitespace-pre-line" style={{ color: 'var(--color-ink)' }}>
            {state.rights_you_have}
          </p>
        )}
      </section>

      {/* 2 · DEADLINE */}
      <section className="mb-8">
        <h2 className="text-xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          The deadline
        </h2>
        <div
          className="rounded-lg p-4 mb-3"
          style={{ background: 'var(--color-light-gray)', border: '1px solid #ddd8d0' }}
        >
          <p className="text-lg font-bold mb-1" style={{ color: 'var(--color-navy)', fontFamily: 'Georgia, serif' }}>
            {deadlineHeadline}
          </p>
          {state.repose_cite && (
            <p className="text-xs" style={{ color: 'var(--color-sage)' }}>{state.repose_cite}</p>
          )}
        </div>
        {state.repose_note && (
          <p className="text-sm leading-relaxed whitespace-pre-line mb-3" style={{ color: 'var(--color-ink)' }}>
            {state.repose_note}
          </p>
        )}
        {state.statute_quote && (
          <blockquote
            className="text-sm italic pl-3 my-3"
            style={{ borderLeft: '3px solid var(--color-bronze)', color: 'var(--color-sage)' }}
          >
            &ldquo;{state.statute_quote}&rdquo;
          </blockquote>
        )}
        {(state.presuit_required || state.presuit_note) && (
          <p className="text-sm leading-relaxed" style={{ color: 'var(--color-ink)' }}>
            <span className="font-semibold">Before you sue: </span>
            {state.presuit_note
              ? state.presuit_note
              : `${state.state_name} generally requires written notice to the builder first` +
                (state.presuit_days ? ` (about ${state.presuit_days} days)` : '') + '.'}
            {state.presuit_cite ? ` (${state.presuit_cite})` : ''}
          </p>
        )}
      </section>

      {/* 3 · ACTION — identical on every state page, the conversion line */}
      {state.what_to_do_now && (
        <section className="mb-8">
          <h2 className="text-xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
            What to do now
          </h2>
          <p className="text-base leading-relaxed" style={{ color: 'var(--color-ink)' }}>
            {state.what_to_do_now}
          </p>
        </section>
      )}

      {/* The spread — the same defect is dead in one state and live in another */}
      <section className="mb-8">
        <h2 className="text-xl font-bold mb-2" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          The same defect, a different answer next door
        </h2>
        <p className="text-sm mb-4" style={{ color: 'var(--color-sage)' }}>
          The construction-defect deadline is a state-by-state accident of geography. The identical
          crack in the identical house can be dead in one state and live in another.
        </p>
        <div className="flex flex-wrap gap-2">
          {ranked.map(s => {
            const isThis = s.slug === state.slug
            const label = s.repose_years == null ? 'no repose' : `${s.repose_years} yr`
            return (
              <Link
                key={s.slug}
                href={`/rights/${s.slug}`}
                className="text-xs px-2.5 py-1 rounded-full"
                style={
                  isThis
                    ? { background: 'var(--color-navy)', color: 'var(--color-white)', fontWeight: 700 }
                    : { background: 'var(--color-white)', color: 'var(--color-ink)', border: '1px solid var(--color-light-gray)' }
                }
              >
                {s.state_name} · {label}
              </Link>
            )
          })}
        </div>
      </section>

      {/* Provenance + disclaimer */}
      <footer className="text-xs leading-relaxed pt-4" style={{ color: 'var(--color-sage)', borderTop: '1px solid var(--color-light-gray)' }}>
        {state.primary_source_url && (
          <p className="mb-2">
            Statute verified against the primary source:{' '}
            <a href={state.primary_source_url} target="_blank" rel="noopener noreferrer" className="underline" style={{ color: 'var(--color-bronze)' }}>
              official statutory text →
            </a>
          </p>
        )}
        <p>
          This is general information about statutory deadlines, not legal advice, and deadlines
          have exceptions that turn on facts. Confirm your own situation with a lawyer licensed in{' '}
          {state.state_name} before relying on any date here.{' '}
          <Link href="/disclaimer" className="underline" style={{ color: 'var(--color-bronze)' }}>Full disclaimer</Link>.
        </p>
      </footer>
    </div>
  )
}
