'use client'

import { useRouter, usePathname } from 'next/navigation'
import { getSupabaseBrowser } from '@/lib/supabase/ssr-browser'

// Item 57 — the authenticated app shell: a top nav that hosts sign-out (54), the account/
// password page (55), and where items 51-53 (profile, listings) will live. Every gated page
// renders inside it so the frontend is no longer just a login form and one chat page.
export default function AppShell({ userEmail, children }: { userEmail: string; children: React.ReactNode }) {
  const router = useRouter()
  const path = usePathname()
  async function signOut() {
    await getSupabaseBrowser().auth.signOut() // item 54 — clears the session cookie
    router.replace('/login')
    router.refresh()
  }
  const link = (href: string, label: string) => (
    <a href={href} style={{
      fontSize: 13, textDecoration: 'none', padding: '4px 8px', borderRadius: 8,
      color: path === href ? '#fff' : 'var(--color-navy)',
      background: path === href ? 'var(--color-navy)' : 'transparent',
    }}>{label}</a>
  )
  return (
    <div style={{ height: '100dvh', display: 'flex', flexDirection: 'column' }}>
      <nav style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 14px',
        borderBottom: '1px solid var(--color-light-gray)', background: 'var(--color-white)' }}>
        <span style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-navy)' }}>Department of Property</span>
        <div style={{ display: 'flex', gap: 4 }}>{link('/roz', 'Roz')}{link('/agent', 'My properties')}{link('/roz/account', 'Account')}</div>
        <span style={{ marginLeft: 'auto', fontSize: 11, color: 'var(--color-sage)' }}>{userEmail}</span>
        <button onClick={signOut} style={{ fontSize: 12, padding: '5px 12px', borderRadius: 8, cursor: 'pointer',
          border: '1px solid var(--color-light-gray)', background: 'var(--color-white)', color: 'var(--color-ink)' }}>Sign out</button>
      </nav>
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>{children}</div>
    </div>
  )
}
