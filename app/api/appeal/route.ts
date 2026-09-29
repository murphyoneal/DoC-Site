import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { checkRateLimit, clientIp } from '@/lib/rateLimit'
import { logSubmission } from '@/lib/custody'
import { rpc } from '@/lib/suspension'

// A suspended business appeals (ruling 762 part 4, 765.4). The explanation is stored VERBATIM as theirs -
// never rewritten, never summarised - by file_business_appeal(), which checks that the signed-in person is
// the approved claimant and that the business is suspended. Murphy is told; he decides.

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return NextResponse.json({ ok: false, error: 'Sign in first.' }, { status: 401 })
  if (!checkRateLimit('appeal:' + clientIp(req), 5, 10 * 60_000).allowed) return NextResponse.json({ ok: false, error: 'Too many attempts. Please wait a few minutes.' }, { status: 429 })
  let b: Record<string, unknown>
  try { b = await req.json() } catch { return NextResponse.json({ ok: false, error: 'Expected JSON.' }, { status: 400 }) }
  const slug = typeof b.slug === 'string' ? b.slug : ''
  const text = typeof b.explanation === 'string' ? b.explanation : ''
  if (!/^[a-z0-9-]+$/.test(slug)) return NextResponse.json({ ok: false, error: 'Unknown business.' }, { status: 400 })
  if (!text.trim()) return NextResponse.json({ ok: false, error: 'Please write your explanation.' }, { status: 400 })
  if (text.length > 5000) return NextResponse.json({ ok: false, error: 'Please keep it under 5,000 characters.' }, { status: 400 })

  const r = await rpc<{ filed: boolean; reason?: string }>('file_business_appeal', { p_slug: slug, p_email: user.email, p_explanation: text })
  await logSubmission(req, { kind: 'appeal', ref: slug, email: user.email, outcome: r?.filed ? 'filed' : `refused:${r?.reason ?? 'error'}` })
  if (!r?.filed) {
    const msg: Record<string, string> = {
      not_the_claimant: 'Only the person whose claim on this business was approved can appeal.',
      not_suspended: 'This business is not suspended, so there is nothing to appeal.',
    }
    return NextResponse.json({ ok: false, error: msg[r?.reason ?? ''] ?? 'The appeal could not be filed. Nothing was saved.' }, { status: r ? 400 : 502 })
  }
  try {
    await fetch('https://formspree.io/f/xrpgyrjp', {
      method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({ _subject: `Appeal filed: ${slug}`, source: 'suspension appeal (/api/appeal)', business: slug, from: user.email,
        explanation: text, note: 'Stored verbatim. Reinstating is logged exactly as a suspension is.' }),
    })
  } catch (e) { console.error('[appeal] notice failed', e) }
  return NextResponse.json({ ok: true })
}
