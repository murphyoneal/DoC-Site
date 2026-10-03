import { NextRequest, NextResponse } from 'next/server'
import { takeLimit } from '@/lib/rateLimit'
import { openSubmission, closeSubmission } from '@/lib/custody'
import { getSessionUser } from '@/lib/supabase/ssr-server'

// A claimed business's logo (work order 733). Upload: signed-in owner of an approved claim only ->
// re-encode (sharp: fitted within 512 x 512, never enlarged, PNG so transparency survives; re-encoding
// drops EXIF and every other metadata block) -> PROVE the result carries no metadata -> store it in
// the PRIVATE bucket under our own ids -> record logo_path. The public copy exists only while the
// owner's "show on my profile" switch is on (synced on save, and here if it is already on).
// NOT the gallery pipeline: no GPS read, no location check, no location state. A logo is artwork.
// SVG is refused: it is a document that can carry script, and we would be serving it from our domain.

export const runtime = 'nodejs'

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const AUTH = { apikey: KEY, Authorization: 'Bearer ' + KEY }
const MAX_BYTES = 2 * 1024 * 1024
const ACCEPT = ['image/png', 'image/jpeg', 'image/webp']
const EDGE = 512
const fail = (status: number, error: string) => NextResponse.json({ ok: false, error }, { status })

async function rpc(fn: string, args: object) {
  const r = await fetch(`${HOST}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify(args), cache: 'no-store' })
  if (!r.ok) throw new Error(`${fn} ${r.status}: ${await r.text()}`)
  return r.json()
}
async function current(businessId: string): Promise<{ logo_path: string | null; publish_logo: boolean } | null> {
  const r = await fetch(`${HOST}/rest/v1/business_profile?business_id=eq.${businessId}&select=logo_path,publish_logo`, { headers: AUTH, cache: 'no-store' })
  return r.ok ? ((await r.json())[0] ?? null) : null
}
async function put(bucket: string, path: string, body: Buffer) {
  const r = await fetch(`${HOST}/storage/v1/object/${bucket}/${path}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': 'image/png', 'x-upsert': 'true' }, body: new Uint8Array(body) })
  if (!r.ok) throw new Error(`storage ${bucket} ${r.status}: ${await r.text()}`)
}
async function remove(bucket: string, paths: string[]) {
  if (!paths.length) return
  await fetch(`${HOST}/storage/v1/object/${bucket}`, { method: 'DELETE', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: paths }) })
}

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return fail(401, 'Sign in to add a logo.')
  let form: FormData
  try { form = await req.formData() } catch { return fail(400, 'Expected a form upload.') }
  const slug = String(form.get('slug') ?? '')
  const file = form.get('file')
  if (!/^[a-z0-9-]+$/.test(slug)) return fail(400, 'Unknown business.')
  if (!(file instanceof File)) return fail(400, 'Choose an image.')
  if (!ACCEPT.includes(file.type)) return fail(415, 'A logo must be PNG, JPEG or WebP.')
  if (file.size > MAX_BYTES) return fail(413, 'A logo can be up to 2 MB.')

  const gate = await rpc('work_upload_gate', { p_slug: slug, p_email: user.email })
  if (!gate?.allowed) return fail(403, 'Logos open once your claim on this business is approved.')

  let out: Buffer
  try {
    const sharp = (await import('sharp')).default
    out = await sharp(Buffer.from(await file.arrayBuffer())).rotate()
      .resize(EDGE, EDGE, { fit: 'inside', withoutEnlargement: true }).png().toBuffer()
    // @ts-ignore - plain ESM shared with the gallery
    const { metadataFree } = await import('@/lib/work-pipeline.mjs')
    const check = await metadataFree(out)
    if (!check.free) return fail(500, 'The image could not be cleaned of its hidden data, so it was not saved.')
  } catch (e) {
    console.error('[logo] processing failed', e)
    return fail(415, 'That file could not be read as an image.')
  }

  const before = await current(gate.business_id)
  const path = `${gate.business_id}/${crypto.randomUUID()}.png`
  // 210f: persisted per-account limit
  if (!(await takeLimit('logo:actor:' + user.email.toLowerCase(), 20, 60 * 60_000))) return fail(429, 'Too many logo changes. Try again later.')
  // 210e: custody first; business_logo_set refuses a save that does not cite it
  const eventId = await openSubmission(req, { kind: 'logo_upload', ref: slug, email: user.email })
  if (eventId == null) return fail(503, 'The logo could not be saved just now. Please try again.')
  await put('logo-private', path, out)
  const set = await rpc('business_logo_set', { p_slug: slug, p_email: user.email, p_logo_path: path, p_submission_event_id: eventId })
  if (!set?.saved) { await remove('logo-private', [path]); await closeSubmission(eventId, 'error'); return fail(500, 'The logo could not be saved.') }
  if (before?.logo_path && before.logo_path !== path) await remove('logo-private', [before.logo_path])
  // already switched on: the public copy follows immediately
  if (set.publish_logo) await put('logo-public', `${gate.business_id}.png`, out)
  await closeSubmission(eventId, set.publish_logo ? 'saved:published' : 'saved:private')
  return NextResponse.json({ ok: true, preview: `data:image/png;base64,${out.toString('base64')}`, published: !!set.publish_logo })
}

export async function DELETE(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return fail(401, 'Sign in first.')
  const slug = req.nextUrl.searchParams.get('slug') ?? ''
  if (!/^[a-z0-9-]+$/.test(slug)) return fail(400, 'Unknown business.')
  const gate = await rpc('work_upload_gate', { p_slug: slug, p_email: user.email })
  if (!gate?.allowed) return fail(403, 'Not your business.')
  const before = await current(gate.business_id)
  const eventId = await openSubmission(req, { kind: 'logo_remove', ref: slug, email: user.email })
  if (eventId == null) return fail(503, 'The logo could not be removed just now. Please try again.')
  const del = await rpc('business_logo_set', { p_slug: slug, p_email: user.email, p_logo_path: null, p_submission_event_id: eventId })
  if (!del?.saved) { await closeSubmission(eventId, 'error'); return fail(500, 'The logo could not be removed.') }
  if (before?.logo_path) await remove('logo-private', [before.logo_path])
  await remove('logo-public', [`${gate.business_id}.png`])
  await closeSubmission(eventId, 'removed')
  return NextResponse.json({ ok: true })
}
