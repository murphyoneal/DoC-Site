'use client'

import { useRouter } from 'next/navigation'
import { useState } from 'react'

// Shown when a parcel IS purchased but the report failed to generate. The buyer must
// never see a blank page: their purchase is safe (recorded in the ledger by the
// webhook), and generation is retryable — the payload is built on view, so a refresh
// re-attempts it.
export default function ReportError({ address }: { address?: string }) {
  const router = useRouter()
  const [retrying, setRetrying] = useState(false)

  return (
    <div className="max-w-lg mx-auto px-4 sm:px-6 py-12">
      <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: 'var(--color-bronze)' }}>
        Your purchase is safe
      </p>
      <h1 className="text-2xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
        We hit a snag building this report.
      </h1>
      {address && <p className="text-base mb-3" style={{ color: 'var(--color-ink)' }}>{address}</p>}
      <p className="text-sm mb-5" style={{ color: 'var(--color-ink)' }}>
        Your payment went through and is recorded — you have not lost it, and this link stays live.
        Report data is assembled fresh each time you open it, so this is almost always temporary.
        Try again in a moment.
      </p>
      <button
        onClick={() => { setRetrying(true); router.refresh() }}
        disabled={retrying}
        className="px-5 py-3 rounded-lg text-sm font-semibold"
        style={{ background: 'var(--color-navy)', color: 'var(--color-white)', opacity: retrying ? 0.6 : 1 }}
      >
        {retrying ? 'Retrying…' : 'Try again'}
      </button>
      <p className="text-xs mt-4" style={{ color: 'var(--color-sage)' }}>
        If it keeps failing, reply to your emailed receipt and we'll generate it for you directly.
      </p>
    </div>
  )
}
