import { redirect } from 'next/navigation'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import AppShell from '@/app/components/AppShell'
import AgentClaims from '@/app/components/AgentClaims'

// Gated behind the session (the proxy also gates /agent — defence in depth).
export default async function AgentPage() {
  const user = await getSessionUser()
  if (!user) redirect('/login?next=/agent')
  const admin = getSupabaseAdmin()
  const { data } = await admin.from('agent_profile')
    .select('name,license_number,license_verified_at').eq('user_id', user.id).maybeSingle()
  return (
    <AppShell userEmail={user.email ?? ''}>
      <AgentClaims
        userEmail={user.email ?? ''}
        initialName={data?.name ?? ''}
        initialLicense={data?.license_number ?? ''}
        initialVerified={!!data?.license_verified_at}
      />
    </AppShell>
  )
}
