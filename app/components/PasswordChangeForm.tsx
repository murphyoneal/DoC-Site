'use client'

import { useState } from 'react'
import { getSupabaseBrowser } from '@/lib/supabase/ssr-browser'

// Item 55 — password change via Supabase's own flow (auth.updateUser). The user is already
// authenticated (page is gated), so no reset email is needed; this just sets a new password.
export default function PasswordChangeForm() {
  const [pw, setPw] = useState('')
  const [confirm, setConfirm] = useState('')
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setMsg(null)
    if (pw.length < 8) { setMsg({ ok: false, text: 'Use at least 8 characters.' }); return }
    if (pw !== confirm) { setMsg({ ok: false, text: 'The two passwords do not match.' }); return }
    setBusy(true)
    const { error } = await getSupabaseBrowser().auth.updateUser({ password: pw })
    setBusy(false)
    if (error) { setMsg({ ok: false, text: error.message }); return }
    setPw(''); setConfirm(''); setMsg({ ok: true, text: 'Password updated.' })
  }

  const inp: React.CSSProperties = { fontSize: 14, padding: '10px 12px', borderRadius: 10, border: '1px solid var(--color-light-gray)', outline: 'none' }
  return (
    <div style={{ maxWidth: 420, margin: '32px auto', padding: '0 16px', width: '100%' }}>
      <h1 style={{ fontSize: 18, fontWeight: 700, color: 'var(--color-navy)', marginBottom: 4 }}>Account</h1>
      <p style={{ fontSize: 13, color: 'var(--color-sage)', marginBottom: 16 }}>Change the password set for your account.</p>
      <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <input type="password" placeholder="New password" value={pw} onChange={e => setPw(e.target.value)} autoComplete="new-password" required style={inp} />
        <input type="password" placeholder="Confirm new password" value={confirm} onChange={e => setConfirm(e.target.value)} autoComplete="new-password" required style={inp} />
        {msg && <div style={{ fontSize: 13, padding: '6px 10px', borderRadius: 8,
          color: msg.ok ? 'var(--color-sage)' : '#8a2a1f', background: msg.ok ? 'rgba(0,0,0,0.03)' : '#fdecea' }}>{msg.text}</div>}
        <button type="submit" disabled={busy} style={{ padding: '10px 16px', borderRadius: 10, border: 'none',
          background: 'var(--color-navy)', color: '#fff', fontSize: 14, fontWeight: 600, cursor: busy ? 'wait' : 'pointer', opacity: busy ? 0.6 : 1 }}>
          {busy ? 'Updating…' : 'Update password'}
        </button>
      </form>
    </div>
  )
}
