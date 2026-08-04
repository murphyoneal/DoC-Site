'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'

// Confirms fulfilment by polling the ledger the webhook writes — it does NOT fulfil.
// The webhook usually lands within a couple of seconds of the redirect, but the
// browser can arrive first, so we poll briefly and stay honest while we wait.
type Found = { coNo: number; parcelId: string; address: string | null; reportUrl: string }

export default function CheckoutSuccessClient() {
  const sp = useSearchParams()
  const sessionId = sp.get('session_id') ?? ''
  const [found, setFound] = useState<Found | null>(null)
  const [waited, setWaited] = useState(false)

  useEffect(() => {
    if (!sessionId) return
    let tries = 0
    let stop = false
    const tick = async () => {
      tries++
      try {
        const res = await fetch(`/api/checkout/status?session_id=${encodeURIComponent(sessionId)}`)
        const j = await res.json()
        if (j.found) { if (!stop) setFound(j as Found); return }
      } catch { /* keep polling */ }
      if (tries >= 15) { if (!stop) setWaited(true); return } // ~30s
      setTimeout(tick, 2000)
    }
    tick()
    return () => { stop = true }
  }, [sessionId])

  const wrap = 'max-w-lg mx-auto px-4 sm:px-6 py-12'
  const H = { fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }

  if (!sessionId) {
    return (
      <div className={wrap}>
        <h1 className="text-2xl font-bold mb-3" style={H}>Something's not right</h1>
        <p className="text-sm" style={{ color: 'var(--color-ink)' }}>
          We couldn't read your checkout session. If you were charged, your receipt is in your
          email — reply to it and we'll sort it out.
        </p>
      </div>
    )
  }

  if (found) {
    return (
      <div className={wrap}>
        <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: 'var(--color-bronze)' }}>
          Payment confirmed
        </p>
        <h1 className="text-2xl font-bold mb-3" style={H}>Your report is ready.</h1>
        {found.address && (
          <p className="text-base mb-4" style={{ color: 'var(--color-ink)' }}>{found.address}</p>
        )}
        <Link
          href={found.reportUrl}
          className="inline-block px-5 py-3 rounded-lg text-sm font-semibold mb-5"
          style={{ background: 'var(--color-navy)', color: 'var(--color-white)' }}
        >
          Open your report →
        </Link>
        <div className="rounded-lg p-4 text-sm" style={{ background: 'var(--color-light-gray)', border: '1px solid #ddd8d0', color: 'var(--color-ink)' }}>
          <p className="font-semibold mb-1" style={{ color: 'var(--color-navy)' }}>This link is permanent.</p>
          Bookmark it — it stays live and always shows the current version of the report as our
          data improves. We've also emailed it to you. Share it freely.
        </div>
      </div>
    )
  }

  return (
    <div className={wrap}>
      <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: 'var(--color-bronze)' }}>
        Payment received
      </p>
      <h1 className="text-2xl font-bold mb-3" style={H}>Preparing your report…</h1>
      <p className="text-sm mb-2" style={{ color: 'var(--color-ink)' }}>
        Your payment went through. We're recording it now — this usually takes a few seconds.
        This page will update on its own.
      </p>
      {waited && (
        <p className="text-sm mt-4" style={{ color: 'var(--color-sage)' }}>
          Still working. Your payment is safe and your receipt is in your email — if this doesn't
          resolve in a minute, reply to that receipt and we'll send your link directly.
        </p>
      )}
    </div>
  )
}
