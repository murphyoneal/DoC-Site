'use client'

import { useState } from 'react'

// The coverage map (relayed ruling, 2026-09-28): which state registers we hold, as a fact you can see.
// Three states, never two - HELD, NOT YET COLLECTED (a register exists; we have not pulled it - a fact
// about us), NO STATE REGISTER (the state does not license this at state level - a fact about the
// state). Demand is shown beside it: self-registrations received from each state, as a count only.

export type Cov = {
  state: 'held' | 'not_yet_collected' | 'no_register_exists'
  retrieved: string | null; source: string | null; authority: string | null; access_type: string | null
  source_url: string | null; cadence: string | null; posted_date: string | null; surveyed_at: string | null; notes: string | null
  scope?: string | null
}
export type StateRow = { geo_id: string; abbr: string; name: string; coverage: Record<string, Cov>; registrations: number }

// A tile-grid map: every state the same size, placed roughly where it sits.
const GRID: Record<string, [number, number]> = {
  AK: [0, 0], ME: [11, 0], VT: [10, 1], NH: [11, 1],
  WA: [1, 2], ID: [2, 2], MT: [3, 2], ND: [4, 2], MN: [5, 2], IL: [6, 2], WI: [7, 2], MI: [8, 2], NY: [9, 2], RI: [10, 2], MA: [11, 2],
  OR: [1, 3], NV: [2, 3], WY: [3, 3], SD: [4, 3], IA: [5, 3], IN: [6, 3], OH: [7, 3], PA: [8, 3], NJ: [9, 3], CT: [10, 3],
  CA: [1, 4], UT: [2, 4], CO: [3, 4], NE: [4, 4], MO: [5, 4], KY: [6, 4], WV: [7, 4], VA: [8, 4], MD: [9, 4], DE: [10, 4],
  AZ: [2, 5], NM: [3, 5], KS: [4, 5], AR: [5, 5], TN: [6, 5], NC: [7, 5], SC: [8, 5], DC: [9, 5],
  OK: [4, 6], LA: [5, 6], MS: [6, 6], AL: [7, 6], GA: [8, 6],
  HI: [0, 7], TX: [4, 7], FL: [9, 7],
}

const PROFESSIONS: { key: string; label: string }[] = [
  { key: 'construction', label: 'Contractors' },
  { key: 'real_estate', label: 'Real estate agents' },
]

const STATE_LABEL: Record<Cov['state'], string> = {
  held: 'Held',
  not_yet_collected: 'Not yet collected',
  no_register_exists: 'No state register',
}
const STATE_NOTE: Record<Cov['state'], string> = {
  held: 'We hold a copy of this state register.',
  not_yet_collected: 'The state keeps a register; we have not collected it yet. That is a fact about us, not about the businesses.',
  no_register_exists: 'This state does not license this at state level, so there is no state register to hold.',
}
const FILL: Record<Cov['state'], string> = { held: '#1B2A4A', not_yet_collected: '#efe9e0', no_register_exists: '#ffffff' }
const INK: Record<Cov['state'], string> = { held: '#ffffff', not_yet_collected: '#1B2A4A', no_register_exists: '#8a8a8a' }
const SCOPE: Record<string, string> = {
  licence: 'The state licenses general or building contractors.',
  registration: 'The state registers contractors; registration is not an exam-based licence.',
  home_improvement_only: 'The state registers or licenses home-improvement contractors only; general contractors are licensed locally, if at all.',
  residential_only: 'The state licenses or registers residential builders only.',
  trades_only: 'The state does not license general contractors. Only some trades (such as electrical or plumbing) are licensed at state level; general contractors are licensed locally, if at all.',
  none: 'The state does not license contractors at state level; licensing is local.',
}
const ACCESS: Record<string, string> = {
  bulk_download: 'Published as a bulk download', api: 'Published through an API', lookup_form_only: 'A lookup form only (not a register we can copy)',
  records_request: 'Available by public-records request', paid: 'Sold, not free', none: 'Not published', not_established: 'Not yet established',
}

function fmt(d: string | null) {
  if (!d) return null
  const m = d.match(/^(\d{4})-(\d{2})-(\d{2})/)
  const M = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
  return m ? `${Number(m[3])} ${M[Number(m[2]) - 1]} ${m[1]}` : d
}

export default function CoverageMap({ rows }: { rows: StateRow[] }) {
  const [prof, setProf] = useState('construction')
  const [sel, setSel] = useState<string>('FL')
  const byAbbr = Object.fromEntries(rows.map(r => [r.abbr, r]))
  const cov = (r: StateRow): Cov => r.coverage?.[prof] ?? ({ state: 'not_yet_collected' } as Cov)
  const s = byAbbr[sel]
  const c = s ? cov(s) : null
  const counts = rows.reduce((a, r) => { a[cov(r).state] = (a[cov(r).state] ?? 0) + 1; return a }, {} as Record<string, number>)
  const T = 46, G = 4

  return (
    <div style={{ display: 'grid', gap: 16 }}>
      <div role="tablist" aria-label="Profession" style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {PROFESSIONS.map(p => (
          <button key={p.key} role="tab" aria-selected={prof === p.key} onClick={() => setProf(p.key)} className="finder-btn"
            style={prof === p.key ? {} : { background: '#fff', color: 'var(--color-navy)', border: '1px solid #d8d2c8' }}>{p.label}</button>
        ))}
      </div>

      <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', fontSize: 12 }}>
        {(['held', 'not_yet_collected', 'no_register_exists'] as Cov['state'][]).map(k => (
          <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 14, height: 14, borderRadius: 3, background: FILL[k], border: '1px solid #c9c2b6', display: 'inline-block',
              backgroundImage: k === 'no_register_exists' ? 'repeating-linear-gradient(45deg,#ddd 0 2px,transparent 2px 6px)' : undefined }} />
            {STATE_LABEL[k]} ({counts[k] ?? 0})
          </span>
        ))}
        <span style={{ color: 'var(--color-sage)' }}>● registrations received from that state</span>
      </div>

      <div style={{ overflowX: 'auto' }}>
        <svg viewBox={`0 0 ${12 * (T + G)} ${8 * (T + G)}`} style={{ width: '100%', maxWidth: 620, display: 'block' }} role="img"
          aria-label={`Map of state ${PROFESSIONS.find(p => p.key === prof)?.label.toLowerCase()} registers: held, not yet collected, or no state register`}>
          <defs>
            <pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">
              <rect width="6" height="6" fill="#fff" /><line x1="0" y1="0" x2="0" y2="6" stroke="#d6d6d6" strokeWidth="2" />
            </pattern>
          </defs>
          {rows.filter(r => GRID[r.abbr]).map(r => {
            const [x, y] = GRID[r.abbr]; const k = cov(r).state
            return (
              <g key={r.abbr} transform={`translate(${x * (T + G)},${y * (T + G)})`} onClick={() => setSel(r.abbr)} style={{ cursor: 'pointer' }}>
                <title>{`${r.name}: ${STATE_LABEL[k]}`}</title>
                <rect width={T} height={T} rx={5} fill={k === 'no_register_exists' ? 'url(#hatch)' : FILL[k]}
                  stroke={sel === r.abbr ? '#C9A84C' : '#c9c2b6'} strokeWidth={sel === r.abbr ? 3 : 1} />
                <text x={T / 2} y={T / 2 + 5} textAnchor="middle" fontSize="14" fontWeight="700" fill={INK[k]}>{r.abbr}</text>
                {r.registrations > 0 && <circle cx={T - 8} cy={8} r={5} fill="#C9A84C" />}
              </g>
            )
          })}
        </svg>
      </div>

      {s && c && (
        <div className="reg-card" aria-live="polite">
          <h2 className="reg-h2" style={{ marginTop: 0 }}>{s.name}: {PROFESSIONS.find(p => p.key === prof)?.label.toLowerCase()}</h2>
          <p className="reg-p" style={{ margin: '6px 0' }}><b>{STATE_LABEL[c.state]}.</b> {c.state === 'not_yet_collected' && !c.surveyed_at
            ? 'We have not collected this state’s register, and have not yet established whether the state keeps one.'
            : c.state === 'no_register_exists' && c.scope && SCOPE[c.scope] ? SCOPE[c.scope] : STATE_NOTE[c.state]}</p>
          {c.state !== 'no_register_exists' && c.scope && SCOPE[c.scope] && prof === 'construction' && (
            <p className="reg-p" style={{ margin: '0 0 6px' }}>{SCOPE[c.scope]}</p>
          )}
          {c.state === 'held' && c.source && <p className="reg-p" style={{ margin: '0 0 6px' }}>Source: {c.source}{c.retrieved ? `, retrieved ${fmt(c.retrieved)}` : ''}.</p>}
          {c.authority && <p className="reg-p" style={{ margin: '0 0 6px' }}>Issued by: {c.authority}.</p>}
          {c.access_type && <p className="reg-p" style={{ margin: '0 0 6px' }}>{ACCESS[c.access_type] ?? c.access_type}{c.cadence && c.cadence !== 'unknown' ? `, updated ${c.cadence}` : ''}.</p>}
          {c.source_url && c.access_type !== 'none' && <p className="reg-p" style={{ margin: '0 0 6px' }}><a href={c.source_url} target="_blank" rel="noopener noreferrer" style={{ color: 'var(--color-bronze)' }}>The issuing authority&rsquo;s source &rarr;</a></p>}
          {c.surveyed_at && c.state !== 'held' && (
            <details style={{ margin: '0 0 8px' }}>
              <summary style={{ cursor: 'pointer', fontSize: 12, color: 'var(--color-sage)' }}>Survey notes ({fmt(c.surveyed_at)})</summary>
              <p className="reg-p" style={{ fontSize: 12, margin: '6px 0 0', color: 'var(--color-ink)' }}>{c.notes}</p>
            </details>
          )}
          <p className="reg-p" style={{ margin: 0, color: 'var(--color-sage)' }}>
            Self-registrations received from {s.name}: {s.registrations.toLocaleString()}.
          </p>
        </div>
      )}

      <details>
        <summary style={{ cursor: 'pointer', fontSize: 13, color: 'var(--color-navy)' }}>Every state as a list</summary>
        <ul style={{ columns: 2, fontSize: 13, padding: '8px 0 0 18px', margin: 0 }}>
          {rows.map(r => <li key={r.abbr}>{r.name}: {STATE_LABEL[cov(r).state]}{r.registrations ? ` (${r.registrations} registered)` : ''}</li>)}
        </ul>
      </details>
    </div>
  )
}
