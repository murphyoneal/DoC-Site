import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { clientIp } from '@/lib/rateLimit'

// Every action on the review page (ruling 762 part 5). POST from the signed-in operator's page - never a
// link in an email. The database functions are the authority: each refuses a non-operator, requires a
// basis, makes the change and writes its moderation_action row in one transaction. This route only does
// what the database cannot: copy or remove files between buckets. The operator holds or removes a photo; it
// never publishes one (ruling 795) - photo_approve is refused below until the owner-approval store exists.

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const AUTH = { apikey: KEY, Authorization: 'Bearer ' + KEY }
// Flipped only by the change that builds the owner-approval log (ruling 795) - and 163a's trigger with it.
const OWNER_APPROVAL_BUILT = false as boolean

async function rpc(fn: string, args: object): Promise<{ ok: boolean; data?: unknown; error?: string }> {
  const r = await fetch(`${HOST}/rest/v1/rpc/${fn}`, { method: 'POST', cache: 'no-store', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify(args) })
  const text = await r.text()
  if (!r.ok) { try { return { ok: false, error: JSON.parse(text).message ?? text } } catch { return { ok: false, error: text } } }
  try { return { ok: true, data: JSON.parse(text) } } catch { return { ok: true, data: text } }
}
async function deletePublic(bucket: string, paths: string[]) {
  if (paths.length) await fetch(`${HOST}/storage/v1/object/${bucket}`, { method: 'DELETE', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: paths }) })
}

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return NextResponse.json({ ok: false, error: 'Sign in first.' }, { status: 401 })
  const op = await rpc('is_operator', { p_email: user.email })
  if (op.data !== true) return NextResponse.json({ ok: false, error: 'Only an operator can do this.' }, { status: 403 })

  let b: Record<string, unknown>
  try { b = await req.json() } catch { return NextResponse.json({ ok: false, error: 'Expected JSON.' }, { status: 400 }) }
  const basis = typeof b.basis === 'string' ? b.basis.trim().slice(0, 2000) : ''
  const ipRaw = clientIp(req)
  const ip = /^[0-9a-fA-F:.]+$/.test(ipRaw) ? ipRaw : null
  const common = { p_actor: user.email, p_basis: basis, p_ip: ip }

  switch (b.type) {
    case 'photo_approve': {
      // Ruling 795: a work photo publishes only when the homeowner has claimed the property and approved
      // it. That store is not built, so there is no approve. Refused HERE, before any copy reaches the
      // public bucket; trigger work_contribution_publication_gate (163a) refuses it again in the database.
      if (OWNER_APPROVAL_BUILT !== true) return NextResponse.json({ ok: false, error: 'Photos are held against the property until the homeowner claims it and approves them (ruling 795). An operator cannot publish one.' }, { status: 409 })
      const id = String(b.contribution_id ?? '')
      const img = (await (await fetch(`${HOST}/rest/v1/work_contribution_image?contribution_id=eq.${id}&select=held_path`, { headers: AUTH, cache: 'no-store' })).json())[0]
      if (!img?.held_path) return NextResponse.json({ ok: false, error: 'No stored copy for that photo.' }, { status: 404 })
      const src = await fetch(`${HOST}/storage/v1/object/work-private/${img.held_path}`, { headers: AUTH, cache: 'no-store' })
      if (!src.ok) return NextResponse.json({ ok: false, error: 'The stored copy could not be read.' }, { status: 500 })
      const bytes = Buffer.from(await src.arrayBuffer())
      // @ts-ignore - plain ESM shared with the fixture test
      const { metadataFree } = await import('@/lib/work-pipeline.mjs')
      if (!(await metadataFree(bytes)).free) return NextResponse.json({ ok: false, error: 'The copy still carries hidden data; not published.' }, { status: 500 })
      const put = await fetch(`${HOST}/storage/v1/object/work-public/${img.held_path}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': 'image/jpeg', 'x-upsert': 'true' }, body: new Uint8Array(bytes) })
      if (!put.ok) return NextResponse.json({ ok: false, error: 'The public copy could not be written.' }, { status: 500 })
      const r = await rpc('operator_photo_decision', { p_contribution_id: id, p_approve: true, p_public_path: img.held_path, ...common })
      if (!r.ok) { await deletePublic('work-public', [img.held_path]); return NextResponse.json({ ok: false, error: r.error }, { status: 400 }) }
      return NextResponse.json({ ok: true, result: r.data })
    }
    case 'photo_reject': {
      const id = String(b.contribution_id ?? '')
      const r = await rpc('operator_photo_decision', { p_contribution_id: id, p_approve: false, p_public_path: null, ...common })
      if (!r.ok) return NextResponse.json({ ok: false, error: r.error }, { status: 400 })
      const img = (await (await fetch(`${HOST}/rest/v1/work_contribution_image?contribution_id=eq.${id}&select=public_path`, { headers: AUTH, cache: 'no-store' })).json())[0]
      if (img?.public_path) await deletePublic('work-public', [img.public_path])
      return NextResponse.json({ ok: true, result: r.data })
    }
    case 'field_unpublish': {
      const r = await rpc('operator_unpublish_field', { p_business_id: b.business_id, p_field: b.field, p_flag_id: b.flag_id ?? null, ...common })
      if (!r.ok) return NextResponse.json({ ok: false, error: r.error }, { status: 400 })
      if (b.field === 'logo') await deletePublic('logo-public', [`${b.business_id}.png`])
      return NextResponse.json({ ok: true, result: r.data })
    }
    case 'flag_ok': {
      const r = await rpc('operator_flag_ok', { p_flag_id: b.flag_id, ...common })
      return NextResponse.json(r.ok ? { ok: true } : { ok: false, error: r.error }, { status: r.ok ? 200 : 400 })
    }
    case 'review': {
      const r = await rpc('operator_review', { p_kind: b.kind, p_id: b.id, p_decision: b.decision, ...common })
      return NextResponse.json(r.ok ? { ok: true, result: r.data } : { ok: false, error: r.error }, { status: r.ok ? 200 : 400 })
    }
    default:
      return NextResponse.json({ ok: false, error: 'Unknown action.' }, { status: 400 })
  }
}
