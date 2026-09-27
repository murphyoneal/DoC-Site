'use client'

import { useMemo, useState } from 'react'
import dynamic from 'next/dynamic'
import type { FinderResult, FinderRow, RegisteredRow } from '@/lib/finder'
import type { Pin } from './FinderMap'
import { CATEGORY_LABELS } from '@/lib/tradeCategories'
import { COUNTY_KEYS_BY_LABEL, byCountyLabel, countyLabel } from '@/lib/county'
import { countyDisplay } from '@/lib/geo-display'

// The contractor finder (work order 697). LEFT: the decisions - search, county, trades as a list,
// and the RESULTS LIST, which is the page's indexable content (text ranks, pins do not). It is a
// client component only so a row can highlight its pin; it still renders on the server, so every
// name and link is in the HTML. RIGHT: the map of those same rows.
// Order: claimed first, then alphabetical. Never a ranking.

const FinderMap = dynamic(() => import('./FinderMap'), {
  ssr: false,
  loading: () => <div style={{ width: '100%', height: '100%', background: '#e8e4df' }} />,
})

function href(q: string, county: string, trade: string, page = 1) {
  const p = new URLSearchParams()
  if (q) p.set('q', q)
  if (county) p.set('county', county)
  if (trade) p.set('trade', trade)
  if (page > 1) p.set('page', String(page))
  const s = p.toString()
  return '/map' + (s ? '?' + s : '')
}

function tradeNames(r: FinderRow): string {
  const keys = r.trades?.length ? r.trades : r.trade_key ? [r.trade_key] : []
  const labels = keys.map(k => CATEGORY_LABELS[k] ?? k).filter(Boolean)
  return labels.length ? labels.join(', ') : (r.trade ?? 'Contractor')
}

export default function FinderShell({ data, registered = [], q, county, trade, page = 1 }: { data: FinderResult; registered?: RegisteredRow[]; q: string; county: string; trade: string; page?: number }) {
  const [selected, setSelected] = useState<string | null>(null)
  const rows = data.mode === 'results' ? data.results : []
  const pins: Pin[] = useMemo(
    () => rows.map(r => ({ slug: r.slug, name: r.name, lat: r.lat, lng: r.lng, label: [tradeNames(r), r.city].filter(Boolean).join(' · ') })),
    [rows]
  )

  function select(slug: string) {
    setSelected(slug)
    document.getElementById('row-' + slug)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }

  const where = county ? `${countyLabel(county)} County` : 'Florida'
  // Matches the page title: "Roofing contractors in Volusia County", "Licensed contractors in Florida".
  const what = trade ? `${CATEGORY_LABELS[trade] ?? trade} contractors` : 'Licensed contractors'

  return (
    <div className="finder">
      <aside className="finder-side">
        <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.15rem', margin: '0 0 2px' }}>
          {trade || county ? `${what} in ${where}` : 'Find a licensed contractor'}
        </h1>
        <p style={{ fontSize: 12, color: 'var(--color-sage)', margin: '0 0 12px' }}>
          From the Florida construction licence file. Electrical contractors are licensed separately and are not in it.
          {' '}Outside Florida, or not in the file? <a href="/register-your-business" style={{ color: 'var(--color-bronze)' }}>Register your business</a>.
        </p>

        <form action="/map" method="get" style={{ display: 'grid', gap: 8 }}>
          <label className="finder-label" htmlFor="finder-q">Search</label>
          <input id="finder-q" name="q" defaultValue={q} placeholder="Business name, licence number, trade or town"
            className="finder-input" />
          <label className="finder-label" htmlFor="finder-county">County</label>
          <select id="finder-county" name="county" defaultValue={county} className="finder-input">
            <option value="">All Florida counties</option>
            {COUNTY_KEYS_BY_LABEL.map(k => <option key={k} value={k}>{countyLabel(k)}</option>)}
          </select>
          {trade && <input type="hidden" name="trade" value={trade} />}
          <button type="submit" className="finder-btn">Search</button>
        </form>

        {data.mode === 'error' && <p style={{ color: '#a8332b', fontSize: 13 }}>{data.message}</p>}

        {data.mode === 'counties' && (
          <section style={{ marginTop: 16 }}>
            <h2 className="finder-h2">Pick a county</h2>
            <ul className="finder-list">
              {[...data.counties].sort((a, b) => byCountyLabel(a.county, b.county)).map(c => (
                <li key={c.county}>
                  <a href={href('', c.county, '')} className="finder-county">
                    <span>{countyLabel(c.county)}</span>
                    <span style={{ color: 'var(--color-sage)' }}>{c.businesses.toLocaleString()}</span>
                  </a>
                </li>
              ))}
            </ul>
          </section>
        )}

        {data.mode === 'results' && (
          <>
            {data.trades.length > 0 && (
              <section style={{ marginTop: 16 }}>
                <h2 className="finder-h2">Trade</h2>
                <ul className="finder-trades">
                  <li><a href={href(q, county, '')} className={'finder-trade' + (trade ? '' : ' on')}>All trades</a></li>
                  {data.trades.map(t => (
                    <li key={t.trade}>
                      <a href={href(q, county, trade === t.trade ? '' : t.trade)} className={'finder-trade' + (trade === t.trade ? ' on' : '')}>
                        <span>{CATEGORY_LABELS[t.trade] ?? t.trade}</span>
                        <span style={{ color: 'var(--color-sage)' }}>{t.businesses.toLocaleString()}</span>
                      </a>
                    </li>
                  ))}
                </ul>
              </section>
            )}

            <section style={{ marginTop: 16 }}>
              <h2 className="finder-h2">
                {data.field_status === 'not_run' ? data.note
                  : data.count === 0 ? 'No licence record matches'
                  : `${data.count.toLocaleString()} ${data.count === 1 ? 'business' : 'businesses'}`}
              </h2>
              {data.count > data.returned && (
                <p style={{ fontSize: 12, color: 'var(--color-sage)', margin: '0 0 8px' }}>
                  Showing {(data.offset ?? 0) + 1}–{(data.offset ?? 0) + data.returned}. Pick a trade or add a word to narrow it, or page through below.
                </p>
              )}
              <p style={{ fontSize: 11, color: 'var(--color-sage)', margin: '0 0 8px' }}>
                Claimed businesses first, then alphabetical. Not a ranking or a recommendation.
              </p>
              <ol className="finder-results">
                {rows.map(r => (
                  <li key={r.slug} id={'row-' + r.slug} className={'finder-row' + (selected === r.slug ? ' on' : '')}
                    onClick={() => select(r.slug)}>
                    <a href={`/c/${r.slug}`} className="finder-name" onClick={e => e.stopPropagation()}>{r.name}</a>
                    <div className="finder-meta">
                      {tradeNames(r)}
                      {r.city ? ` · ${r.city}` : ''}
                      {r.county ? ` · ${countyLabel(r.county)} County` : ''}
                    </div>
                    <div className="finder-badges">
                      {r.claimed && <span className="badge claimed">Claimed</span>}
                      {r.absent_from_latest_file
                        ? <span className="badge dated">Not in the latest state file</span>
                        : r.record_dated && <span className="badge dated">Record dated</span>}
                      {(r.lat == null || r.lng == null) && <span className="badge nomap">Not on the map</span>}
                    </div>
                  </li>
                ))}
              </ol>
              {/* Real links, so every business is reachable by a crawler, not only the first page. */}
              {data.count > data.returned && (
                <nav aria-label="Pages" style={{ display: 'flex', justifyContent: 'space-between', gap: 8, margin: '8px 0 0', fontSize: 13 }}>
                  {page > 1 ? <a href={href(q, county, trade, page - 1)} rel="prev" style={{ color: 'var(--color-bronze)' }}>&larr; Previous</a> : <span />}
                  <span style={{ color: 'var(--color-sage)' }}>Page {page} of {Math.ceil(data.count / 60)}</span>
                  {(data.offset ?? 0) + data.returned < data.count ? <a href={href(q, county, trade, page + 1)} rel="next" style={{ color: 'var(--color-bronze)' }}>Next &rarr;</a> : <span />}
                </nav>
              )}
              {data.coverage_note && (
                <p style={{ fontSize: 11, color: 'var(--color-sage)', margin: '12px 0 0' }}>
                  {data.coverage_note} Source: Florida DBPR public licence file, retrieved {data.source_retrieved}.
                </p>
              )}
            </section>
          </>
        )}

        {registered.length > 0 && (
          <section style={{ marginTop: 16 }} aria-labelledby="self-registered">
            <h2 id="self-registered" className="finder-h2">Self-registered businesses</h2>
            <p style={{ fontSize: 11, color: 'var(--color-sage)', margin: '0 0 8px' }}>
              These businesses registered themselves. They are not entries from a state licence file: each page shows what the
              business declared and what we could check.
            </p>
            <ol className="finder-results">
              {registered.map(r => (
                <li key={r.slug} className="finder-row" style={{ cursor: 'default' }}>
                  <a href={`/r/${r.slug}`} className="finder-name">{r.business_name}</a>
                  <div className="finder-meta">
                    {(r.trades ?? []).map(t => CATEGORY_LABELS[t] ?? t).join(', ') || 'Contractor'}
                    {r.city ? ` · ${r.city}` : ''}
                    {r.county ? ` · ${countyDisplay(r.county, r.county_level)}` : ''}
                    {` · ${r.state}`}
                  </div>
                  <div className="finder-badges"><span className="badge">Self-registered</span></div>
                </li>
              ))}
            </ol>
          </section>
        )}
      </aside>

      <div className="finder-map">
        <FinderMap pins={pins} selected={selected} onSelect={select} />
      </div>
    </div>
  )
}
