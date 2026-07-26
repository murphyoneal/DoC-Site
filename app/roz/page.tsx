import { redirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import RozChat from '@/app/components/RozChat'
import AppShell from '@/app/components/AppShell'

// Gated behind the session (the proxy also gates /roz, this is defence in depth).
export default async function RozPage() {
  const user = await getSessionUser()
  if (!user) redirect('/login?next=/roz')
  return (
    <AppShell userEmail={user.email ?? ''}>
      <RozChat userEmail={user.email ?? ''} />
    </AppShell>
  )
}
