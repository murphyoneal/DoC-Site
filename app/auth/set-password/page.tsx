import { redirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import SetPasswordForm from '@/app/components/SetPasswordForm'

export const metadata = { title: 'Choose a password', robots: { index: false } }

// Reached from /auth/confirm, already signed in by the one-time link.
export default async function SetPasswordPage({ searchParams }: { searchParams: Promise<{ next?: string }> }) {
  const { next } = await searchParams
  const safeNext = next && next.startsWith('/') && !next.startsWith('//') ? next : '/account'
  const user = await getSessionUser()
  if (!user) redirect('/auth/forgot?link=expired')
  return (
    <main style={{ minHeight: '80dvh', display: 'grid', placeItems: 'center', padding: 24, background: 'var(--color-cream)' }}>
      <SetPasswordForm next={safeNext} />
    </main>
  )
}
