// The web-vs-public-record panel. Renders a DiscrepancyReport as two clearly-walled columns:
// "On the web" (what a site claims — attributed, perishable) and "Public record" (the anchor).
// Pure presentational: no client hooks, safe in a server or client tree. The wall is visual as
// well as textual — a web number never sits inside a record statement.
import type { DiscrepancyReport, WebVsRecordOutcome } from '@/types/roz-web'

const OUTCOME: Record<WebVsRecordOutcome, { label: string; fg: string; bg: string }> = {
  agrees: { label: 'matches record', fg: '#2f7a55', bg: 'rgba(47,122,85,0.12)' },
  disagrees: { label: 'flagged — record wins', fg: '#b45309', bg: 'rgba(180,83,9,0.13)' },
  unverifiable: { label: 'listing claim only', fg: '#6b7280', bg: 'rgba(0,0,0,0.05)' },
}

const NO_LISTING: Record<'off_market' | 'no_address_match' | 'unretrievable', string> = {
  off_market: 'No active listing found — the property does not appear publicly for sale (it may be off-market or pocket-listed).',
  no_address_match: 'No listing matched this address — a lookup miss, not a statement that it is not for sale.',
  unretrievable: 'A listing may exist but could not be retrieved (behind a login, expired, or a source gap).',
}

function fmtTime(iso: string): string {
  const d = new Date(iso)
  return isNaN(d.getTime()) ? iso : d.toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
}

const cell: React.CSSProperties = { padding: '6px 10px', borderBottom: '1px solid var(--color-light-gray)', verticalAlign: 'top', fontSize: 12.5 }
const src: React.CSSProperties = { display: 'block', fontSize: 10.5, color: 'var(--color-sage)', marginTop: 1 }

export default function DiscrepancyPanel({ report }: { report: DiscrepancyReport }) {
  const { listing, fields, summary } = report
  const retrieved = listing.retrievedAt

  return (
    <div style={{ border: '1px solid var(--color-light-gray)', borderRadius: 12, overflow: 'hidden', marginBottom: 10, background: 'var(--color-white)' }}>
      {/* header — the two worlds, named */}
      <div style={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 8, padding: '8px 12px', borderBottom: '1px solid var(--color-light-gray)', background: 'rgba(0,0,0,0.015)' }}>
        <span style={{ fontSize: 11, fontWeight: 700, letterSpacing: '0.03em', textTransform: 'uppercase', color: 'var(--color-navy)' }}>On the web · Public record</span>
        {listing.status === 'found' && (
          <span style={{ fontSize: 11, color: 'var(--color-sage)' }}>
            listing on {listing.sites.join(', ')} · retrieved {fmtTime(retrieved)}
          </span>
        )}
        <span style={{ marginLeft: 'auto', display: 'flex', gap: 6 }}>
          <Chip n={summary.agrees} label="match" fg={OUTCOME.agrees.fg} bg={OUTCOME.agrees.bg} />
          <Chip n={summary.disagrees} label="flagged" fg={OUTCOME.disagrees.fg} bg={OUTCOME.disagrees.bg} />
          <Chip n={summary.unverifiable} label="unverified" fg={OUTCOME.unverifiable.fg} bg={OUTCOME.unverifiable.bg} />
        </span>
      </div>

      {listing.status === 'none' ? (
        <div style={{ padding: '10px 12px', fontSize: 12.5, color: 'var(--color-ink)' }}>
          {NO_LISTING[listing.reason]}
          <span style={{ display: 'block', fontSize: 10.5, color: 'var(--color-sage)', marginTop: 3 }}>
            Checked {listing.sites.join(', ')} · {fmtTime(retrieved)}. A null is a null — not a finding.
          </span>
        </div>
      ) : (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', tableLayout: 'fixed', minWidth: 460 }}>
            <thead>
              <tr>
                <th style={{ ...cell, width: '22%', fontWeight: 700, color: 'var(--color-sage)', fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Field</th>
                <th style={{ ...cell, width: '30%', fontWeight: 700, color: 'var(--color-sage)', fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }}>On the web</th>
                <th style={{ ...cell, width: '30%', fontWeight: 700, color: 'var(--color-navy)', fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }}>Public record</th>
                <th style={{ ...cell, width: '18%', fontWeight: 700, color: 'var(--color-sage)', fontSize: 10.5, textTransform: 'uppercase', letterSpacing: '0.04em' }} />
              </tr>
            </thead>
            <tbody>
              {fields.map((f, i) => {
                const o = OUTCOME[f.outcome]
                return (
                  <tr key={i}>
                    <td style={{ ...cell, fontWeight: 600, color: 'var(--color-ink)' }}>{f.label}</td>
                    <td style={cell}>
                      {f.webValue ?? '—'}
                      <span style={src}>{f.webSource}</span>
                    </td>
                    <td style={cell}>
                      {f.recordValue ?? <span style={{ color: 'var(--color-sage)' }}>no counterpart</span>}
                      {f.recordSource ? <span style={src}>{f.recordSource}</span> : null}
                    </td>
                    <td style={{ ...cell, textAlign: 'right' }}>
                      <span style={{ display: 'inline-block', fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 999, color: o.fg, background: o.bg, whiteSpace: 'nowrap' }}>{o.label}</span>
                      {f.note ? <span style={{ display: 'block', fontSize: 10.5, color: 'var(--color-sage)', marginTop: 3, textAlign: 'left' }}>{f.note}</span> : null}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}

      <div style={{ padding: '6px 12px', fontSize: 10.5, color: 'var(--color-sage)', borderTop: '1px solid var(--color-light-gray)' }}>
        Web values are what a site shows and can change within the hour. The public record is the anchor; it wins every disagreement.
      </div>
    </div>
  )
}

function Chip({ n, label, fg, bg }: { n: number; label: string; fg: string; bg: string }) {
  return (
    <span style={{ fontSize: 10, fontWeight: 700, padding: '2px 7px', borderRadius: 999, color: fg, background: bg }}>
      {n} {label}
    </span>
  )
}
