'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { getSupabaseBrowser } from '@/lib/supabase/ssr-browser'

// Choose a password (work order 725). The person arrives here signed in by the one-time link; on save
// they go straight on to the page they claimed.
export default function SetPasswordForm({ next }: { next: string }) {
  const router = useRouter()
  const [pw, setPw] = useState('')
  const [pw2, setPw2] = useState('')
  const [err, setErr] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: React.FormEvent) {
    e.preventDefault()
    setErr(null)
    if (pw.length < 8) return setErr('Use at least 8 characters.')
    if (pw !== pw2) return setErr('The two passwords do not match.')
    setBusy(true)
    const { error } = await getSupabaseBrowser().auth.updateUser({ password: pw })
    if (error) { setErr(error.message); setBusy(false); return }
    router.push(next)
    router.refresh()
  }

  return (
    <form onSubmit={submit} className="reg-card" style={{ display: 'grid', gap: 12, width: 360, maxWidth: '100%' }}>
      <h1 className="reg-h2" style={{ marginTop: 0 }}>Choose a password</h1>
      <p className="reg-p" style={{ margin: 0 }}>You will use it with this email address to sign in from now on.</p>
      <label className="finder-label" htmlFor="sp-1">New password</label>
      <input id="sp-1" type="password" required minLength={8} autoComplete="new-password" className="finder-input" value={pw} onChange={e => setPw(e.target.value)} />
      <label className="finder-label" htmlFor="sp-2">The same again</label>
      <input id="sp-2" type="password" required minLength={8} autoComplete="new-password" className="finder-input" value={pw2} onChange={e => setPw2(e.target.value)} />
      {err && <p style={{ margin: 0, fontSize: 13, color: '#a8332b' }}>{err}</p>}
      <button type="submit" className="finder-btn" disabled={busy}>{busy ? 'Saving…' : 'Save and continue'}</button>
    </form>
  )
}
