import { NextRequest, NextResponse } from 'next/server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { sendMail, mailConfigured } from '@/lib/mail'
import { clientIp, takeLimit } from '@/lib/rateLimit'

// "Forgot your password?" (work order 725). A reset link for an EXISTING account, emailed to that
// account's address. The answer is the same whether or not an account exists, so the form cannot be
// used to find out who has one. With no mail provider, the link goes to Murphy to forward to that
// address - never to the person who typed it.

const FORMSPREE_URL = 'https://formspree.io/f/xrpgyrjp'

export async function POST(req: NextRequest) {
  if (!(await takeLimit('reset:' + clientIp(req), 5, 10 * 60_000))) return NextResponse.json({ ok: false, limited: true }, { status: 429 })
  let email = ''
  try { email = String((await req.json()).email ?? '').trim().toLowerCase() } catch {}
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return NextResponse.json({ ok: false, field: 'email' }, { status: 400 })
  const host = req.nextUrl.origin
  const r = await getSupabaseAdmin().auth.admin.generateLink({ type: 'recovery', email })
  const token = r.data?.properties?.hashed_token
  if (!r.error && token) {
    const u = new URL('/auth/confirm', host)
    u.searchParams.set('token_hash', token); u.searchParams.set('type', 'recovery'); u.searchParams.set('next', '/account')
    const text = `Someone asked to reset the password for ${email}.\n\nSet a new one here:\n${u.toString()}\n\nIf it was not you, ignore this email; nothing changes.`
    if (mailConfigured()) await sendMail(email, 'Reset your password', text)
    else await fetch(FORMSPREE_URL, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ _subject: `FORWARD TO ${email}: password reset link`, source: 'password reset (/api/auth/reset) - no mail provider is configured', send_to: email, message_to_forward: text }),
    }).catch(() => null)
  }
  return NextResponse.json({ ok: true, provider: mailConfigured() })
}
