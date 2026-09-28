import type { Metadata } from 'next'
import CoverageMap, { type StateRow } from '../components/CoverageMap'

// /coverage - which state licence registers we hold, as a map (relayed ruling, 2026-09-28). It is the
// honest answer to "do you cover my state?" and the acquisition tracker: demand (self-registrations)
// beside coverage. Read from register_coverage via coverage_map(), service_role only.

export const metadata: Metadata = {
  title: 'Which state registers we hold',
  description: 'The state licence registers we reproduce, the ones we have not collected yet, and the states that keep no register at state level.',
}

const SB = 'https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''

async function getCoverage(): Promise<StateRow[]> {
  try {
    const r = await fetch(`${SB}/rpc/coverage_map`, {
      method: 'POST', headers: { apikey: KEY, Authorization: 'Bearer ' + KEY, 'Content-Type': 'application/json' },
      body: '{}', next: { revalidate: 600 },
    })
    return r.ok ? ((await r.json()) ?? []) : []
  } catch { return [] }
}

export default async function CoveragePage() {
  const rows = await getCoverage()
  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)', padding: '24px 16px 48px' }}>
      <div style={{ maxWidth: 760, margin: '0 auto' }}>
        <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.5rem', margin: '0 0 8px' }}>Which state registers we hold</h1>
        <p style={{ fontSize: '0.9rem', color: 'var(--color-ink)', margin: '0 0 18px', lineHeight: 1.55 }}>
          We reproduce a state&rsquo;s licence register only where we hold a copy of it. Everywhere else we say so, and
          we keep two things apart: a state whose register we have not collected yet, and a state that keeps no register at all.
        </p>
        {rows.length ? <CoverageMap rows={rows} /> : <p>The coverage table could not be read just now.</p>}
      </div>
    </main>
  )
}
