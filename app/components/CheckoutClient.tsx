'use client'

import { useState } from 'react'

interface Product { name: string; amountCents: number; blurb: string }

export default function CheckoutClient({
  productKey, product, reference,
}: { productKey: string; product: Product; reference: string }) {
  const [status, setStatus] = useState<'idle' | 'loading' | 'placeholder' | 'error'>('idle')
  const [msg, setMsg] = useState('')

  const price = `$${(product.amountCents / 100).toFixed(2)}`

  async function handlePay() {
    setStatus('loading')
    try {
      const res = await fetch('/api/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ product: productKey, reference }),
      })
      const j = await res.json()
      if (j.url) { window.location.href = j.url; return }          // real Stripe path
      if (j.placeholder) { setStatus('placeholder'); setMsg(j.message); return }
      setStatus('error'); setMsg(j.error ?? 'Something went wrong.')
    } catch {
      setStatus('error'); setMsg('Network error. Please try again.')
    }
  }

  return (
    <div className="max-w-lg mx-auto px-4 sm:px-6 py-10">
      <h1 className="text-2xl font-bold mb-6" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
        Checkout
      </h1>

      {/* Placeholder notice — remove when Stripe is live */}
      <div
        className="rounded-lg px-4 py-3 mb-6 text-sm"
        style={{ background: '#fbf3df', border: '1px solid var(--color-gold)', color: '#5c4a1f' }}
        role="status"
      >
        <strong>Payments not yet enabled.</strong> This is a placeholder checkout — Stripe wiring
        is pending. The flow below is fully functional except the final payment call.
      </div>

      {/* Order summary */}
      <div className="rounded-xl p-5 mb-5" style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}>
        <div className="flex items-start justify-between gap-4">
          <div>
            <p className="font-semibold" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>{product.name}</p>
            <p className="text-sm mt-1" style={{ color: 'var(--color-sage)' }}>{product.blurb}</p>
            {reference && <p className="text-xs mt-2" style={{ color: 'var(--color-bronze)' }}>Ref: {reference}</p>}
          </div>
          <span className="text-xl font-bold shrink-0" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-ink)' }}>{price}</span>
        </div>
        <div className="flex justify-between mt-4 pt-4 text-sm" style={{ borderTop: '1px solid var(--color-light-gray)' }}>
          <span style={{ color: 'var(--color-sage)' }}>Total due</span>
          <span className="font-bold" style={{ color: 'var(--color-ink)' }}>{price}</span>
        </div>
      </div>

      {(status === 'placeholder' || status === 'error') && (
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
        onClick={handlePay}
        disabled={status === 'loading'}
        className="w-full py-3 rounded-lg text-sm font-semibold"
        style={{
          background: 'var(--color-navy)', color: 'var(--color-white)',
          opacity: status === 'loading' ? 0.6 : 1, cursor: status === 'loading' ? 'wait' : 'pointer',
        }}
      >
        {status === 'loading' ? 'Processing…' : `Proceed to payment · ${price}`}
      </button>

      <p className="text-xs mt-3 text-center" style={{ color: 'var(--color-sage)' }}>
        Secure payment by Stripe. You’ll be redirected to complete your purchase.
      </p>
    </div>
  )
}
