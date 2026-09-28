import { NextRequest, NextResponse } from 'next/server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { sendMail, mailConfigured } from '@/lib/mail'
import { DOC_URL, DOP_URL } from '@/lib/site'

// Step 3 of the claim cycle (work order 725): an APPROVED claim gets a set-password link, so the
// claimant can sign in and reach the business - or licence page - they just claimed.
//
// Called by the database (trigger on approval + a 10-minute sweep, migration 150b) with
// {kind, id} or {sweep: true}. It acts only on what the database says: the claim must be approved
// and not yet issued a link. So a stray call can do no more than send the claimant their own link
// once. No secret is needed for that, and none is stored.
//
// The link is our own (/auth/confirm?token_hash=...), made with the admin API's generateLink, which
// creates the account (invite) or, if one already exists, a reset (recovery). Supabase sends nothing.
// With no mail provider configured the link goes to Murphy through the Formspree form he already
// reads, to forward - the claimant is never left at a door with no key.

const FORMSPREE_URL = 'https://formspree.io/f/xrpgyrjp'
type Kind = 'contractor' | 'agent'
type Target = { kind: Kind; id: string; email: string; name: string; next: string; host: string }

async function targets(body: { kind?: string; id?: string; sweep?: boolean }): Promise<Target[]> {
  const db = getSupabaseAdmin()
  const out: Target[] = []
  if (body.sweep || body.kind === 'contractor') {
    let q = db.from('claim_requests').select('id, requester_email, requester_name, contractor_id, account_invite_state').eq('status', 'approved')
    if (!body.sweep) q = q.eq('id', body.id ?? '')
    q = q.is('account_invite_state', null)
    const { data } = await q
    for (const c of data ?? []) {
      const { data: bl } = await db.from('business_licences').select('business_id, businesses(slug, display_name)').eq('contractor_id', c.contractor_id).limit(1).maybeSingle()
      const biz = (bl as unknown as { businesses?: { slug: string; display_name: string | null } } | null)?.businesses
      if (!biz?.slug) continue
      out.push({ kind: 'contractor', id: c.id, email: c.requester_email, name: biz.display_name ?? biz.slug, next: `/claim/${biz.slug}/profile`, host: DOC_URL })
    }
  }
  if (body.sweep || body.kind === 'agent') {
    let q = db.from('agent_claim_request').select('id, requester_email, license_number, account_invite_state').eq('status', 'approved')
    if (!body.sweep) q = q.eq('id', body.id ?? '')
    q = q.is('account_invite_state', null)
    const { data } = await q
    for (const a of data ?? []) {
      const { data: ap } = await db.from('agent_public_profile').select('slug').eq('license_number', a.license_number).maybeSingle()
      if (!ap?.slug) continue
      out.push({ kind: 'agent', id: a.id, email: a.requester_email, name: `Florida real estate licence ${a.license_number}`, next: `/a/${ap.slug}/edit`, host: DOP_URL })
    }
  }
  return out
}

async function link(t: Target): Promise<{ url: string; type: 'invite' | 'recovery' } | { error: string }> {
  const admin = getSupabaseAdmin()
  let r = await admin.auth.admin.generateLink({ type: 'invite', email: t.email })
  let type: 'invite' | 'recovery' = 'invite'
  if (r.error) {
    // an account already exists for this email: issue a reset instead, which sets a new password
    r = await admin.auth.admin.generateLink({ type: 'recovery', email: t.email })
    type = 'recovery'
  }
  const token = r.data?.properties?.hashed_token
  if (r.error || !token) return { error: r.error?.message ?? 'no token returned' }
  const u = new URL('/auth/confirm', t.host)
  u.searchParams.set('token_hash', token)
  u.searchParams.set('type', type)
  u.searchParams.set('next', t.next)
  return { url: u.toString(), type }
}

async function record(t: Target, state: 'emailed' | 'sent_to_murphy' | 'failed', note: string) {
  const db = getSupabaseAdmin()
  await db.from(t.kind === 'contractor' ? 'claim_requests' : 'agent_claim_request')
    .update({ account_invite_state: state, account_invite_at: new Date().toISOString(), account_invite_note: note.slice(0, 500) })
    .eq('id', t.id)
}

export async function POST(req: NextRequest) {
  let body: { kind?: string; id?: string; sweep?: boolean }
  try { body = await req.json() } catch { body = {} }
  if (!body.sweep && !(body.kind === 'contractor' || body.kind === 'agent') ) return NextResponse.json({ error: 'kind and id, or sweep' }, { status: 400 })
  const list = await targets(body)
  const results = []
  for (const t of list) {
    const l = await link(t)
    if ('error' in l) { await record(t, 'failed', `link: ${l.error}`); results.push({ id: t.id, state: 'failed' }); continue }
    const text =
      `Your claim for ${t.name} has been approved.\n\n` +
      `Set your password here to sign in and manage it:\n${l.url}\n\n` +
      `The link works once and expires. If it has expired, go to ${t.host}/auth/forgot and enter this email address.\n\n` +
      `After that, sign in any time at ${t.host}/login with ${t.email}.`
    if (mailConfigured()) {
      const m = await sendMail(t.email, 'Your claim is approved: set your password', text)
      if (m.sent) { await record(t, 'emailed', `sent ${m.id ?? ''} (${l.type})`); results.push({ id: t.id, state: 'emailed' }); continue }
      const why = 'reason' in m ? `${m.reason} ${m.detail ?? ''}` : 'unknown'
      await record(t, 'failed', `mail: ${why}`)
      results.push({ id: t.id, state: 'failed' }); continue
    }
    // No mail provider: hand the link to Murphy, who forwards it. Recorded as such.
    const fs = await fetch(FORMSPREE_URL, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        _subject: `FORWARD TO CLAIMANT: set-password link for ${t.name}`,
        source: 'claim approved (/api/claims/approved) - no mail provider is configured, so this link comes to you to forward',
        send_to: t.email, message_to_forward: text,
      }),
    }).catch(() => null)
    if (fs?.ok) { await record(t, 'sent_to_murphy', `no provider; link (${l.type}) sent to Murphy via Formspree`); results.push({ id: t.id, state: 'sent_to_murphy' }) }
    else { await record(t, 'failed', `no provider and Formspree returned ${fs?.status ?? 'no response'}`); results.push({ id: t.id, state: 'failed' }) }
  }
  return NextResponse.json({ processed: results.length, results })
}
