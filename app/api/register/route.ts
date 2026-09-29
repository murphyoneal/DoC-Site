import { NextRequest, NextResponse } from 'next/server'
import { SB_HEADERS, SB_REST } from '@/lib/registration'
import { CONTRACTOR_URL } from '@/lib/site'
import { checkRateLimit, clientIp } from '@/lib/rateLimit'
import { logSubmission } from '@/lib/custody'
import { notifyLanguageFlags, type LanguageFlag } from '@/lib/language-notice'

// The self-registration form's one write (work order 699). self_register() validates, checks each
// declared credential against the registers we hold, applies the Florida duplicate rule, and either
// inserts (review_state 'received' - nothing is public until Murphy approves it AND the business
// switched the listing on) or returns the existing Florida profile to claim instead.
//
// Spam: a honeypot field and a minimum fill time. A human review sits between every submission and
// anything public, so these only need to keep the queue readable.

const FORMSPREE_URL = 'https://formspree.io/f/xrpgyrjp'
const MIN_FILL_MS = 4000

type Credential = {
  kind?: string; issuing_state?: string; profession?: string; trade?: string
  number?: string; issuer?: string; expires_on?: string; publish?: boolean
}

function str(v: unknown, max: number): string | null {
  if (typeof v !== 'string') return null
  const s = v.trim()
  return s ? s.slice(0, max) : null
}

export async function POST(req: NextRequest) {
  if (!checkRateLimit('register:' + clientIp(req), 5, 10 * 60_000).allowed) return NextResponse.json({ outcome: 'limited' }, { status: 429 })
  let body: Record<string, unknown>
  try { body = await req.json() } catch { return NextResponse.json({ outcome: 'invalid', field: 'body' }, { status: 400 }) }

  // Bots fill every field and submit instantly. Answer as if it worked, so there is nothing to tune against.
  const started = Number(body.started_at)
  if (str(body.company_url, 200) || !Number.isFinite(started) || Date.now() - started < MIN_FILL_MS) {
    return NextResponse.json({ outcome: 'received', credentials: [] })
  }

  const creds: Credential[] = Array.isArray(body.credentials) ? (body.credentials as Credential[]).slice(0, 20) : []
  const payload = {
    business_name: str(body.business_name, 200),
    state: str(body.state, 8),
    county: str(body.county, 12),
    // a Census place geo_id from the dropdown, or the fixed value 'unincorporated'; never typed text
    place: str(body.place, 20),
    trades: Array.isArray(body.trades) ? (body.trades as unknown[]).filter(t => typeof t === 'string').slice(0, 30) : [],
    other_services: str(body.other_services, 500),
    contact_name: str(body.contact_name, 200),
    contact_email: str(body.contact_email, 254),
    public_phone: str(body.public_phone, 40),
    website: (() => { const w = str(body.website, 300); return w && !/^https?:\/\//i.test(w) ? 'https://' + w : w })(),
    publish: {
      listing: body.publish_listing === true, city: body.publish_city === true,
      phone: body.publish_phone === true, website: body.publish_website === true,
    },
    credentials: creds.map(c => ({
      kind: str(c.kind, 20), issuing_state: str(c.issuing_state, 8),
      profession: c.trade === 'electrical' ? 'electrical' : 'construction',
      trade: str(c.trade, 100), number: str(c.number, 60), issuer: str(c.issuer, 200),
      expires_on: /^\d{4}-\d{2}-\d{2}$/.test(String(c.expires_on ?? '')) ? c.expires_on : null,
      publish: c.publish === true,
    })),
  }

  let result: Record<string, unknown>
  try {
    const r = await fetch(`${SB_REST}/rpc/self_register`, {
      method: 'POST', headers: SB_HEADERS, body: JSON.stringify({ p: payload }), cache: 'no-store',
    })
    if (!r.ok) {
      console.error('[register] self_register returned', r.status, await r.text())
      return NextResponse.json({ outcome: 'error' }, { status: 502 })
    }
    result = await r.json()
  } catch (e) {
    console.error('[register] self_register failed', e)
    return NextResponse.json({ outcome: 'error' }, { status: 502 })
  }

  await logSubmission(req, { kind: 'self_registration', ref: String(result.slug ?? result.id ?? ''), email: String(payload.contact_email ?? ''), outcome: `${result.outcome}${result.field ? ':' + result.field : ''}` })
  if (result.outcome === 'invalid') return NextResponse.json(result, { status: 400 })

  // Tell a person. The row is the durable record; a Formspree failure is logged and never fails the request.
  if (result.outcome === 'received') {
    try {
      const fs = await fetch(FORMSPREE_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
        body: JSON.stringify({
          _subject: `Self-registration to review: ${payload.business_name} (${payload.state})`,
          source: 'self-registration form (/register-your-business)',
          business: payload.business_name,
          state: payload.state,
          florida_duplicate: result.florida_duplicate_state,
          florida_register_entries: (result.florida_duplicate_slugs as string[] | null)?.map(s => `${CONTRACTOR_URL}/c/${s}`) ?? null,
          credentials: result.credentials,
          asked_to_be_listed: payload.publish.listing,
          name: payload.contact_name,
          email: payload.contact_email,
          review: `select * from registration_review_queue where id = '${result.id}'; then select review_registration('${result.id}', 'approved' | 'rejected', 'note');`,
        }),
      })
      if (!fs.ok) console.error('[register] formspree returned', fs.status, await fs.text())
    } catch (e) {
      console.error('[register] formspree failed', e)
    }
  }

  // The id and the private review detail stay server-side.
  await notifyLanguageFlags(result.flags as LanguageFlag[] | undefined, { what: 'registration', subject: String(result.slug ?? ''), page: null })
  const { id: _id, florida_duplicate_slugs: _s, florida_duplicate_state: _d, flags: _f, ...safe } = result
  return NextResponse.json(safe)
}
