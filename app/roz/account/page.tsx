import { redirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import AppShell from '@/app/components/AppShell'
import PasswordChangeForm from '@/app/components/PasswordChangeForm'

// Under /roz so the existing proxy matcher (/roz/:path*) gates it; server session check is defence in depth.
export default async function AccountPage() {
  const user = await getSessionUser()
  if (!user) redirect('/login?next=/roz/account')
  return (
    <AppShell userEmail={user.email ?? ''}>
      <PasswordChangeForm />
    </AppShell>
  )
}
