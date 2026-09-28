import { NextRequest, NextResponse } from 'next/server'
import { rpc } from '@/lib/agent-profile'
import { DOP_URL } from '@/lib/site'
import { checkRateLimit, clientIp } from '@/lib/rateLimit'

// An agent claims their licence (work order 712). agent_claim_submit records the claim and our check
// (name vs the licence file, and whether the licence is Current/Active) - recorded, never enforced. A
// person reads every claim; Murphy is told through the same Formspree form as contractor claims.

const FORMSPREE_URL = 'https://formspree.io/f/xrpgyrjp'
const s = (v: unknown, n: number) => (typeof v === 'string' ? v.trim().slice(0, n) : '')

export async function POST(req: NextRequest) {
  if (!checkRateLimit('agent-claim:' + clientIp(req), 5, 10 * 60_000).allowed) return NextResponse.json({ outcome: 'limited' }, { status: 429 })
  let b: Record<string, unknown>
  try { b = await req.json() } catch { return NextResponse.json({ outcome: 'invalid', field: 'body' }, { status: 400 }) }
  if (s(b.company_url, 200)) return NextResponse.json({ outcome: 'received' }) // honeypot
  const payload = {
    license_number: s(b.license_number, 20), requester_name: s(b.requester_name, 200),
    requester_email: s(b.requester_email, 254), requester_phone: s(b.requester_phone, 40), message: s(b.message, 2000),
  }
  const r = await rpc<Record<string, unknown>>('agent_claim_submit', { p: payload })
  if (!r) return NextResponse.json({ outcome: 'error' }, { status: 502 })
  if (r.outcome === 'received') {
    try {
      const fs = await fetch(FORMSPREE_URL, {
        method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          _subject: `Agent claim: ${r.licence_name ?? payload.license_number}`,
          source: 'agent claim form (/agents/claim)',
          licence: payload.license_number, licence_name: r.licence_name, rank: r.rank,
          name_check: r.match_verdict, licence_active: r.licence_active,
          name: payload.requester_name, email: payload.requester_email, phone: payload.requester_phone || null, message: payload.message || null,
          review: `select * from agent_claim_review_queue; then select review_agent_claim('${r.id}', 'approved' | 'rejected', 'note');`,
          site: `${DOP_URL}/agents.html`,
        }),
      })
      if (!fs.ok) console.error('[agent-claim] formspree returned', fs.status, await fs.text())
    } catch (e) { console.error('[agent-claim] formspree failed', e) }
  }
  const { id: _id, match_verdict: _m, licence_active: _a, ...safe } = r
  return NextResponse.json(safe, { status: r.outcome === 'invalid' ? 400 : 200 })
}
