// Transactional email (work order 725). One sender for the account cycle: the set-password link after
// a claim is approved, and a password reset. Resend when RESEND_API_KEY is set; otherwise it reports
// that no provider is configured, and the caller decides what to do - never a silent success.
//
// Supabase's own mailer is not used: it is rate-limited to a few sends an hour and only delivers to
// the project's team members, so it cannot reach a claimant.

export type MailResult = { sent: true; id: string | null } | { sent: false; reason: 'no_provider' | 'provider_error'; detail?: string }

export function mailConfigured(): boolean {
  return !!(process.env.RESEND_API_KEY ?? '').trim()
}

export async function sendMail(to: string, subject: string, text: string): Promise<MailResult> {
  const key = (process.env.RESEND_API_KEY ?? '').trim()
  if (!key) return { sent: false, reason: 'no_provider' }
  const from = (process.env.RESEND_FROM_EMAIL ?? 'noreply@departmentofconstruction.com').trim()
  try {
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from, to: [to], subject, text }),
    })
    const j = await r.json().catch(() => ({}))
    if (!r.ok) return { sent: false, reason: 'provider_error', detail: `${r.status} ${JSON.stringify(j).slice(0, 300)}` }
    return { sent: true, id: (j as { id?: string }).id ?? null }
  } catch (e) {
    return { sent: false, reason: 'provider_error', detail: String(e).slice(0, 300) }
  }
}
