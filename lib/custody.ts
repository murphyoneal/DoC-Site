import { clientIp } from '@/lib/rateLimit'

// Chain of custody (ruling 762, part 2): one row in submission_event per upload, claim, profile save
// and self-registration, with the IP and user agent the request came from. An incident record for
// appeals - never rendered. Non-fatal: a failure here is logged and never blocks the submission.

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'

export type SubmissionKind =
  | 'work_upload' | 'logo_upload' | 'logo_remove' | 'contractor_claim'
  | 'agent_claim' | 'profile_save' | 'agent_profile_save' | 'self_registration' | 'work_withdraw' | 'appeal'

const IP_RE = /^(\d{1,3}(\.\d{1,3}){3}|[0-9a-f:]+)$/i

export async function logSubmission(
  req: { headers: Headers },
  e: { kind: SubmissionKind; ref?: string | null; email?: string | null; outcome?: string | null },
): Promise<void> {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  const ip = clientIp(req)
  try {
    const r = await fetch(`${HOST}/rest/v1/submission_event`, {
      method: 'POST', cache: 'no-store',
      headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({
        kind: e.kind,
        subject_ref: e.ref ? String(e.ref).slice(0, 200) : null,
        actor_email: e.email ? String(e.email).trim().toLowerCase().slice(0, 254) : null,
        ip: IP_RE.test(ip) ? ip : null,
        ip_basis: IP_RE.test(ip) ? 'vercel_edge' : 'not_established',
        user_agent: (req.headers.get('user-agent') ?? '').slice(0, 400) || null,
        outcome: e.outcome ? String(e.outcome).slice(0, 120) : null,
      }),
    })
    if (!r.ok) console.error('[custody] not recorded', e.kind, r.status, await r.text())
  } catch (err) {
    console.error('[custody] not recorded', e.kind, err instanceof Error ? err.message : String(err))
  }
}
