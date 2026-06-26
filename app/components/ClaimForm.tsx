'use client'

import { useState } from 'react'

interface Props {
  slug: string
  licenseNumber: string
  displayName: string
}

type Step = 'verify' | 'details' | 'submitted'

export default function ClaimForm({ slug, licenseNumber, displayName }: Props) {
  const [step, setStep] = useState<Step>('verify')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [enteredLicense, setEnteredLicense] = useState('')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [message, setMessage] = useState('')

  function handleVerify() {
    setError(null)
    if (!enteredLicense.trim()) {
      setError('Please enter your licence number.')
      return
    }
    if (enteredLicense.trim().toUpperCase() !== licenseNumber.toUpperCase()) {
      setError('Licence number does not match our records. Please check and try again.')
      return
    }
    setStep('details')
  }

  async function handleSubmit() {
    setError(null)
    if (!name.trim()) { setError('Please enter your name.'); return }
    if (!email.trim()) { setError('Please enter your email.'); return }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { setError('Please enter a valid email address.'); return }

    setLoading(true)
    try {
      const res = await fetch('/api/claim', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          slug,
          license_number: enteredLicense.trim(),
          requester_name: name.trim(),
          requester_email: email.trim(),
          requester_phone: phone.trim(),
          message: message.trim(),
        }),
      })
      const data = await res.json()
      if (!res.ok) {
        setError(data.error ?? 'Something went wrong. Please try again.')
        return
      }
      setStep('submitted')
    } catch {
      setError('Network error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  if (step === 'submitted') {
    return (
      <div
        className="rounded-xl p-8 text-center"
        style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
      >
        <div className="text-4xl mb-4">✓</div>
        <h2
          className="text-xl font-bold mb-2"
          style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
        >
          Claim Request Submitted
        </h2>
        <p className="text-sm mb-4" style={{ color: 'var(--color-sage)' }}>
          We will review your request and contact you at {email} within 1-2 business days.
        </p>
        
          href={`/c/${slug}`}
          className="text-sm underline"
          style={{ color: 'var(--color-bronze)' }}
        >
          Back to profile
        </a>
      </div>
    )
  }

  return (
    <div
      className="rounded-xl p-6"
      style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}
    >
      {step === 'verify' && (
        <>
          <h3
            className="text-base font-bold mb-1"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
          >
            Step 1 — Verify Your Licence
          </h3>
          <p className="text-sm mb-4" style={{ color: 'var(--color-sage)' }}>
            Enter your licence number to confirm you are the licence holder for {displayName}.
          </p>

          <label className="block text-xs font-semibold mb-1" style={{ color: 'var(--color-ink)' }}>
            Licence Number
          </label>
          <input
            type="text"
            value={enteredLicense}
            onChange={e => setEnteredLicense(e.target.value)}
            placeholder="e.g. CCC1234567"
            className="w-full px-3 py-2 rounded-lg text-sm mb-4"
            style={{
              border: '1px solid var(--color-light-gray)',
              background: 'var(--color-cream)',
              color: 'var(--color-ink)',
              outline: 'none',
            }}
          />

          {error && (
            <p className="text-xs mb-4" style={{ color: '#c0392b' }}>{error}</p>
          )}

          <button
            onClick={handleVerify}
            className="w-full py-3 rounded-lg text-sm font-semibold"
            style={{ background: 'var(--color-navy)', color: 'white', border: 'none', cursor: 'pointer' }}
          >
            Verify Licence
          </button>
        </>
      )}

      {step === 'details' && (
        <>
          <div
            className="flex items-center gap-2 mb-4 px-3 py-2 rounded-lg"
            style={{ background: '#e8f0fb' }}
          >
            <span style={{ color: 'var(--color-navy)', fontSize: '0.85rem' }}>
              {'✓ Licence verified — ' + enteredLicense.toUpperCase()}
            </span>
          </div>

          <h3
            className="text-base font-bold mb-1"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
          >
            Step 2 — Your Contact Details
          </h3>
          <p className="text-sm mb-4" style={{ color: 'var(--color-sage)' }}>
            We will use these to contact you about your claim. Your email will not be published.
          </p>

          <label className="block text-xs font-semibold mb-1" style={{ color: 'var(--color-ink)' }}>
            Your Name
          </label>
          <input
            type="text"
            value={name}
            onChange={e => setName(e.target.value)}
            placeholder="Full name"
            className="w-full px-3 py-2 rounded-lg text-sm mb-4"
            style={{
              border: '1px solid var(--color-light-gray)',
              background: 'var(--color-cream)',
              color: 'var(--color-ink)',
              outline: 'none',
            }}
          />

          <label className="block text-xs font-semibold mb-1" style={{ color: 'var(--color-ink)' }}>
            Email Address
          </label>
          <input
            type="email"
            value={email}
            onChange={e => setEmail(e.target.value)}
            placeholder="you@example.com"
            className="w-full px-3 py-2 rounded-lg text-sm mb-4"
            style={{
              border: '1px solid var(--color-light-gray)',
              background: 'var(--color-cream)',
              color: 'var(--color-ink)',
              outline: 'none',
            }}
          />

          <label className="block text-xs font-semibold mb-1" style={{ color: 'var(--color-ink)' }}>
            Phone Number <span style={{ color: 'var(--color-sage)', fontWeight: 400 }}>(optional)</span>
          </label>
          <input
            type="tel"
            value={phone}
            onChange={e => setPhone(e.target.value)}
            placeholder="(555) 000-0000"
            className="w-full px-3 py-2 rounded-lg text-sm mb-4"
            style={{
              border: '1px solid var(--color-light-gray)',
              background: 'var(--color-cream)',
              color: 'var(--color-ink)',
              outline: 'none',
            }}
          />

          <label className="block text-xs font-semibold mb-1" style={{ color: 'var(--color-ink)' }}>
            Message <span style={{ color: 'var(--color-sage)', fontWeight: 400 }}>(optional)</span>
          </label>
          <textarea
            value={message}
            onChange={e => setMessage(e.target.value)}
            placeholder="Anything you would like us to know..."
            rows={3}
            className="w-full px-3 py-2 rounded-lg text-sm mb-4"
            style={{
              border: '1px solid var(--color-light-gray)',
              background: 'var(--color-cream)',
              color: 'var(--color-ink)',
              outline: 'none',
              resize: 'vertical',
            }}
          />

          {error && (
            <p className="text-xs mb-4" style={{ color: '#c0392b' }}>{error}</p>
          )}

          <button
            onClick={handleSubmit}
            disabled={loading}
            className="w-full py-3 rounded-lg text-sm font-semibold"
            style={{
              background: loading ? 'var(--color-sage)' : 'var(--color-bronze)',
              color: 'white',
              border: 'none',
              cursor: loading ? 'not-allowed' : 'pointer',
            }}
          >
            {loading ? 'Submitting...' : 'Submit Claim Request'}
          </button>

          <p className="text-xs mt-3 text-center" style={{ color: 'var(--color-sage)' }}>
            By submitting you confirm you are the licence holder or authorised representative.
          </p>
        </>
      )}
    </div>
  )
}