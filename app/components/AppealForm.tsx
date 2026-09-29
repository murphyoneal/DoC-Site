'use client'

import { useState } from 'react'

// The business's own explanation, sent as written (ruling 765.4: stored verbatim, never rewritten).
export default function AppealForm({ slug }: { slug: string }) {
  const [text, setText] = useState('')
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  async function submit(e: React.FormEvent) {
    e.preventDefault(); setBusy(true); setErr(null)
    try {
      const r = await fetch('/api/appeal', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ slug, explanation: text }) })
      const j = await r.json().catch(() => ({}))
      if (j.ok) setDone(true); else setErr(j.error ?? 'The appeal could not be filed.')
    } catch { setErr('Could not reach us. Check your connection and try again.') } finally { setBusy(false) }
  }

  if (done) return (
    <div className="reg-card">
      <p className="reg-p" style={{ margin: 0 }}>Your appeal is filed, exactly as you wrote it. A person reads every appeal and will email you with the outcome. Questions: register@departmentofproperty.com.</p>
    </div>
  )
  return (
    <form onSubmit={submit} className="reg-card" style={{ display: 'grid', gap: 10 }}>
      <label htmlFor="appeal" className="finder-label">Your explanation</label>
      <textarea id="appeal" rows={8} maxLength={5000} className="finder-input" value={text} onChange={e => setText(e.target.value)} required />
      <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>Kept exactly as you write it. It is not published.</span>
      {err && <p style={{ color: '#a8332b', fontSize: 13, margin: 0 }}>{err}</p>}
      <button type="submit" className="finder-btn" disabled={busy}>{busy ? 'Sending…' : 'Send appeal'}</button>
    </form>
  )
}
