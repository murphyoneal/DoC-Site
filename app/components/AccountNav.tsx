'use client'

import Link from 'next/link'
import { useEffect, useState } from 'react'
import { getSupabaseBrowser } from '@/lib/supabase/ssr-browser'

// The header's account link. Signed out: "Sign in". Signed in: "Your account" and "Sign out", so
// a person on a shared device, or signed in with the wrong email, can always leave. Read in the
// browser so the pages themselves stay static.
export default function AccountNav() {
  const [email, setEmail] = useState<string | null | undefined>(undefined)

  useEffect(() => {
    let live = true
    getSupabaseBrowser().auth.getUser().then(({ data }) => { if (live) setEmail(data.user?.email ?? null) }).catch(() => { if (live) setEmail(null) })
    return () => { live = false }
  }, [])

  async function signOut() {
    await getSupabaseBrowser().auth.signOut().catch(() => {})
    window.location.href = '/'
  }

  const style = { color: '#aab4c8', textDecoration: 'none' }
  // Three states, never two (774/815): undefined = still looking, so say nothing rather than tell a signed-in
  // reader they are signed out; null = signed out; a value = signed in.
  if (email === undefined) return <span aria-hidden="true" style={{ display: 'inline-block', minWidth: 48 }} />
  if (email === null) return <Link href="/login" style={style}>Sign in</Link>
  return (
    <>
      <Link href="/account" style={style} title={email}>Your account</Link>
      <button type="button" onClick={signOut} style={{ ...style, background: 'none', border: 0, padding: 0, cursor: 'pointer', font: 'inherit' }}>Sign out</button>
    </>
  )
}
