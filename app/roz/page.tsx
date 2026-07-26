import { redirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import RozChat from '@/app/components/RozChat'

// Gated behind the session (the proxy also gates /roz, this is defence in depth).
export default async function RozPage() {
  const user = await getSessionUser()
  if (!user) redirect('/login?next=/roz')
  return (
    <main style={{ height: '100dvh', display: 'flex', flexDirection: 'column' }}>
      <RozChat userEmail={user.email ?? ''} />
    </main>
  )
}
