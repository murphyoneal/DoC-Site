import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { addressSocket } from '@/lib/sockets/address'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'
// @ts-ignore — plain ESM shared with the fixture test
import { readOriginal, stripForPublic, metadataFree } from '@/lib/work-pipeline.mjs'

// POST /api/work/upload — a claimed business uploads a photo of its work (653 (d); 611, 613).
//
// THE ORDER IS LOAD-BEARING and is exactly this:
//   gate -> read GPS from the ORIGINAL -> resolve the address to a parcel -> CHECK the location
//   -> RECORD the state -> strip (re-encode) -> store original PRIVATE, stripped copy PUBLIC
//   -> READ THE PUBLIC FILE BACK and prove it carries no metadata -> only then mark it servable.
// A copy that fails the read-back is deleted and never marked servable: work_gallery_public
// only shows images with exif_stripped_at set.

export const runtime = 'nodejs'

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const AUTH = { apikey: KEY, Authorization: 'Bearer ' + KEY }
// Vercel caps a function request body near 4.5 MB. Larger files need a signed direct upload to
// the private bucket first — a known limit of this first version, stated to the user.
const MAX_BYTES = 4 * 1024 * 1024
const ACCEPT = ['image/jpeg', 'image/png', 'image/webp']

async function rpc(fn: string, args: object) {
  const r = await fetch(`${HOST}/rest/v1/rpc/${fn}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify(args), cache: 'no-store' })
  if (!r.ok) throw new Error(`${fn} ${r.status}: ${await r.text()}`)
  return r.json()
}
async function insert(table: string, row: object) {
  const r = await fetch(`${HOST}/rest/v1/${table}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': 'application/json', Prefer: 'return=representation' }, body: JSON.stringify(row) })
  if (!r.ok) throw new Error(`${table} insert ${r.status}: ${await r.text()}`)
  return (await r.json())[0]
}
async function putObject(bucket: string, path: string, body: Buffer, type: string) {
  const r = await fetch(`${HOST}/storage/v1/object/${bucket}/${path}`, { method: 'POST', headers: { ...AUTH, 'Content-Type': type, 'x-upsert': 'false' }, body: new Uint8Array(body) })
  if (!r.ok) throw new Error(`storage ${bucket} ${r.status}: ${await r.text()}`)
}
async function deleteObject(bucket: string, path: string) {
  await fetch(`${HOST}/storage/v1/object/${bucket}`, { method: 'DELETE', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: [path] }) })
}
const fail = (status: number, error: string) => NextResponse.json({ ok: false, error }, { status })

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return fail(401, 'Sign in to upload photos.')

  pruneRateLimitStore()
  if (!checkRateLimit('work-upload:' + user.id).allowed) return fail(429, 'Too many uploads. Try again in a minute.')

  let form: FormData
  try { form = await req.formData() } catch { return fail(400, 'Expected a form upload.') }
  const slug = String(form.get('slug') ?? '')
  const address = String(form.get('address') ?? '').trim()
  const description = String(form.get('description') ?? '').trim().slice(0, 500) || null
  const workDate = String(form.get('work_date') ?? '') || null
  const file = form.get('file')
  if (!/^[a-z0-9-]+$/.test(slug)) return fail(400, 'Unknown business.')
  if (!(file instanceof File)) return fail(400, 'Choose a photo to upload.')
  if (!ACCEPT.includes(file.type)) return fail(415, 'Photos must be JPEG, PNG or WebP.')
  if (file.size > MAX_BYTES) return fail(413, 'This first version accepts photos up to 4 MB. Please send a smaller copy.')
  if (workDate && !/^\d{4}-\d{2}-\d{2}$/.test(workDate)) return fail(400, 'Work date must be a date.')

  // Gate: only the requester of an APPROVED claim on this business.
  const gate = await rpc('work_upload_gate', { p_slug: slug, p_email: user.email })
  if (!gate?.allowed) return fail(403, 'Photo uploads open once your claim on this business is approved.')

  const original = Buffer.from(await file.arrayBuffer())
  let orig: { format: string; gps: { lat: number; lng: number } | null }
  try { orig = await readOriginal(original) } catch { return fail(415, 'That file could not be read as an image.') }

  // Address -> parcel over our own roll. Unresolved is recorded as location_not_checked.
  let parcel: { co_no: number; parcel_id: string; label: string } | null = null
  if (address.length >= 3) {
    const hit = (await addressSocket.search(address, 1)).results[0]
    if (hit) parcel = { co_no: hit.co_no, parcel_id: hit.parcel_id, label: hit.label }
  }

  // CHECK and RECORD the location BEFORE anything is stripped.
  const loc = await rpc('check_work_location', {
    p_co_no: parcel?.co_no ?? null, p_parcel_id: parcel?.parcel_id ?? null,
    p_lat: orig.gps?.lat ?? null, p_lng: orig.gps?.lng ?? null,
  })
  const contribution = await insert('work_contribution', {
    contractor_id: gate.contractor_id, submitted_by: user.id,
    co_no: parcel?.co_no ?? null, parcel_id: parcel?.parcel_id ?? null,
    description, work_date: workDate,
    location_state: loc.location_state, location_divergence_m: loc.divergence_m,
    location_checked_at: new Date().toISOString(),
  })

  // Strip, store both copies, then prove the SERVED public copy carries no metadata.
  const pub = await stripForPublic(original)
  const imageId = crypto.randomUUID()
  const ext = orig.format === 'png' ? 'png' : orig.format === 'webp' ? 'webp' : 'jpg'
  const privatePath = `${contribution.id}/${imageId}-original.${ext}`
  const publicPath = `${contribution.id}/${imageId}.jpg`
  await putObject('work-private', privatePath, original, file.type)
  await putObject('work-public', publicPath, pub.data, 'image/jpeg')

  const served = Buffer.from(await (await fetch(`${HOST}/storage/v1/object/public/work-public/${publicPath}`, { cache: 'no-store' })).arrayBuffer())
  const check = await metadataFree(served)
  if (!check.free) {
    await deleteObject('work-public', publicPath)
    console.error('[work/upload] served copy carried metadata; withdrawn', check.found)
    return fail(500, 'The photo could not be published safely and was not published. Nothing is shown on your profile.')
  }
  const now = new Date().toISOString()
  await insert('work_contribution_image', {
    contribution_id: contribution.id, public_path: publicPath, private_path: privatePath,
    exif_stripped_at: now, exif_verified_at: now,
    width: pub.width, height: pub.height, byte_size: pub.data.length,
  })

  return NextResponse.json({
    ok: true,
    location_state: loc.location_state,
    location_note: loc.note,
    matched_address: parcel?.label ?? null,
  })
}
