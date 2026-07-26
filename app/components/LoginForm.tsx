'use client'

import { useState } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { getSupabaseBrowser } from '@/lib/supabase/ssr-browser'

export default function LoginForm() {
  const router = useRouter()
  const params = useSearchParams()
  const next = params.get('next') || '/roz'
  const expired = params.get('expired') === '1'
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setError(null); setBusy(true)
    const supabase = getSupabaseBrowser()
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    if (error) { setError(error.message); setBusy(false); return }
    // Full navigation so the proxy re-reads the refreshed session cookie.
    router.push(next)
    router.refresh()
  }

  return (
    <form onSubmit={submit} style={{ width: 320, display: 'flex', flexDirection: 'column', gap: 12,
      padding: 24, border: '1px solid var(--color-light-gray)', borderRadius: 14, background: 'var(--color-white)' }}>
      <div style={{ fontSize: 18, fontWeight: 700, color: 'var(--color-navy)' }}>Roz — sign in</div>
      {expired && <div style={{ fontSize: 13, color: '#8a5a1f', background: '#fdf3e0', padding: '6px 10px', borderRadius: 8 }}>Your session expired. Please sign in again.</div>}
      <input type="email" required placeholder="Email" value={email} onChange={e => setEmail(e.target.value)}
        autoComplete="email" style={inp} />
      <input type="password" required placeholder="Password" value={password} onChange={e => setPassword(e.target.value)}
        autoComplete="current-password" style={inp} />
      {error && <div style={{ fontSize: 13, color: '#8a2a1f', background: '#fdecea', padding: '6px 10px', borderRadius: 8 }}>{error}</div>}
      <button type="submit" disabled={busy} style={{ padding: '10px 16px', borderRadius: 10, border: 'none',
        background: 'var(--color-navy)', color: '#fff', fontSize: 14, fontWeight: 600, cursor: busy ? 'wait' : 'pointer', opacity: busy ? 0.6 : 1 }}>
        {busy ? 'Signing in…' : 'Sign in'}
      </button>
    </form>
  )
}
const inp: React.CSSProperties = { fontSize: 14, padding: '10px 12px', borderRadius: 10, border: '1px solid var(--color-light-gray)', outline: 'none' }
