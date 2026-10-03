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

// 210e (rulings 973-975): for writes to a claimed business's details the custody record comes FIRST and the save cites
// it. business_profile_save / business_logo_set refuse a save without a matching submission_event, and every changed
// field is versioned against that id - so "who changed what, from where, under which claim" is a record, not an
// inference. openSubmission returns the id (null if it could not be recorded - the caller must then NOT save);
// closeSubmission fills in the outcome afterwards.
export async function openSubmission(
  req: { headers: Headers },
  e: { kind: SubmissionKind; ref: string; email: string },
): Promise<number | null> {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  const ip = clientIp(req)
  try {
    const r = await fetch(`${HOST}/rest/v1/submission_event?select=id`, {
      method: 'POST', cache: 'no-store',
      headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', Prefer: 'return=representation' },
      body: JSON.stringify({
        kind: e.kind,
        subject_ref: String(e.ref).slice(0, 200),
        actor_email: String(e.email).trim().toLowerCase().slice(0, 254),
        ip: IP_RE.test(ip) ? ip : null,
        ip_basis: IP_RE.test(ip) ? 'vercel_edge' : 'not_established',
        user_agent: (req.headers.get('user-agent') ?? '').slice(0, 400) || null,
        outcome: 'pending',
      }),
    })
    if (!r.ok) { console.error('[custody] not opened', e.kind, r.status, await r.text()); return null }
    const rows = await r.json()
    return typeof rows?.[0]?.id === 'number' ? rows[0].id : null
  } catch (err) {
    console.error('[custody] not opened', e.kind, err instanceof Error ? err.message : String(err))
    return null
  }
}

export async function closeSubmission(id: number, outcome: string): Promise<void> {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  try {
    await fetch(`${HOST}/rest/v1/submission_event?id=eq.${id}`, {
      method: 'PATCH', cache: 'no-store',
      headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({ outcome: String(outcome).slice(0, 120) }),
    })
  } catch (err) {
    console.error('[custody] outcome not recorded', id, err instanceof Error ? err.message : String(err))
  }
}
