'use client'

import { useState } from 'react'
import { useSearchParams } from 'next/navigation'
import { Suspense } from 'react'

// Forgot password / expired link (work order 725).
function Forgot() {
  const params = useSearchParams()
  const link = params.get('link')
  const [email, setEmail] = useState('')
  const [done, setDone] = useState<null | { provider: boolean }>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    const r = await fetch('/api/auth/reset', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email }) })
    const j = await r.json().catch(() => ({}))
    setDone({ provider: !!j.provider }); setBusy(false)
  }

  return (
    <main style={{ minHeight: '80dvh', display: 'grid', placeItems: 'center', padding: 24, background: 'var(--color-cream)' }}>
      <div className="reg-card" style={{ width: 380, maxWidth: '100%', display: 'grid', gap: 12 }}>
        <h1 className="reg-h2" style={{ marginTop: 0 }}>{link ? 'That link has expired or was already used' : 'Reset your password'}</h1>
        {done ? (
          <p className="reg-p" style={{ margin: 0 }}>
            If there is an account for that address, a link to set a new password is on its way to it
            {done.provider ? '.' : ' (a person sends it, so it may take a little while).'} The link works once.
          </p>
        ) : (
          <form onSubmit={submit} style={{ display: 'grid', gap: 10 }}>
            <p className="reg-p" style={{ margin: 0 }}>Enter the email address you claimed with and we will send a new link.</p>
            <input type="email" required className="finder-input" placeholder="Email" value={email} onChange={e => setEmail(e.target.value)} autoComplete="email" />
            <button type="submit" className="finder-btn" disabled={busy}>{busy ? 'Sending…' : 'Send me a link'}</button>
          </form>
        )}
        <a href="/login" style={{ fontSize: 13, color: 'var(--color-bronze)' }}>Back to sign in</a>
      </div>
    </main>
  )
}

export default function ForgotPage() {
  return <Suspense fallback={null}><Forgot /></Suspense>
}
