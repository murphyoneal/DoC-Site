'use client'

import { useState } from 'react'

// Preview shown when a parcel's report has not been purchased. States what the property
// IS and what the report covers — the enticement — then "address in, price stated, buy".
// The specific findings stay gated; buying unlocks the full report at this same URL.
const COVERS = [
  'Flood zone & elevation',
  'Contamination & environmental hazards',
  'Zoning & land-use restrictions',
  'Assessed & market values, tax history',
  'Ownership & transaction history',
  'Building permits & construction-defect window',
  'Wetlands, water & nearby amenities',
  'Schools, census & neighborhood context',
]

export default function ReportPaywall({
  coNo,
  parcelId,
  address,
  identity,
}: {
  coNo: number
  parcelId: string
  address: string
  identity?: string
}) {
  const [status, setStatus] = useState<'idle' | 'loading' | 'error' | 'unavailable'>('idle')
  const [msg, setMsg] = useState('')

  async function buy() {
    setStatus('loading')
    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ coNo, parcelId, address }),
      })
      if (res.status === 503) { setStatus('unavailable'); setMsg('Payments are not enabled yet — check back shortly.'); return }
      const j = await res.json()
      if (j.url) { window.location.href = j.url; return }
      setStatus('error'); setMsg(j.error ?? 'Could not start checkout. Please try again.')
    } catch {
      setStatus('error'); setMsg('Network error. Please try again.')
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 sm:px-6 py-10">
      <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: 'var(--color-bronze)' }}>
        Property Intelligence Report
      </p>
      <h1 className="text-3xl font-bold mb-2" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
        {address || `Parcel ${parcelId}`}
      </h1>
      {identity && (
        <p className="text-base mb-6" style={{ color: 'var(--color-ink)' }}>{identity}</p>
      )}

      <div className="rounded-xl p-6 mb-6" style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}>
        <div className="flex items-baseline justify-between mb-4">
          <span className="text-sm font-semibold" style={{ color: 'var(--color-navy)', fontFamily: 'Georgia, serif' }}>
            What the full report covers
          </span>
          <span className="text-2xl font-bold" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-ink)' }}>$5</span>
        </div>
        <ul className="grid sm:grid-cols-2 gap-x-6 gap-y-2 mb-2">
          {COVERS.map(c => (
            <li key={c} className="text-sm flex items-start gap-2" style={{ color: 'var(--color-ink)' }}>
              <span style={{ color: 'var(--color-bronze)' }}>›</span>{c}
            </li>
          ))}
        </ul>
      </div>

      {(status === 'error' || status === 'unavailable') && (
        <div
          className="rounded-lg px-4 py-3 mb-4 text-sm"
          style={
            status === 'error'
              ? { background: '#fdecea', border: '1px solid #f0a9a2', color: '#8a2a1f' }
              : { background: 'var(--color-light-gray)', border: '1px solid #ddd8d0', color: 'var(--color-ink)' }
          }
        >
          {msg}
        </div>
      )}

      <button
        onClick={buy}
        disabled={status === 'loading'}
        className="w-full py-3.5 rounded-lg text-base font-semibold"
        style={{
          background: 'var(--color-navy)', color: 'var(--color-white)',
          opacity: status === 'loading' ? 0.6 : 1, cursor: status === 'loading' ? 'wait' : 'pointer',
        }}
      >
        {status === 'loading' ? 'Redirecting to secure checkout…' : 'Unlock the full report — $5'}
      </button>
      <p className="text-xs mt-3 text-center" style={{ color: 'var(--color-sage)' }}>
        Secure one-off payment by Stripe. No account needed — your report link is emailed to you and
        stays live permanently. Apple Pay & Google Pay accepted.
      </p>
    </div>
  )
}
