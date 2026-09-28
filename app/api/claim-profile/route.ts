import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { saveBusinessProfile } from '@/lib/business-profile'

// Saves a claimed business's own details (work order 712). The email is the SIGNED-IN session's,
// never a value from the request body; business_profile_save re-checks the approved-claim gate.
// The public logo exists only while the owner's switch is on (work order 733): copy the private,
// already-cleaned file across when it is on; remove the public copy when it is off.
const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
async function syncPublicLogo(businessId: string) {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  const auth = { apikey: key, Authorization: 'Bearer ' + key }
  try {
    const r = await fetch(`${HOST}/rest/v1/business_profile?business_id=eq.${businessId}&select=logo_path,publish_logo`, { headers: auth, cache: 'no-store' })
    const row = r.ok ? (await r.json())[0] : null
    const publicPath = `${HOST}/storage/v1/object/logo-public/${businessId}.png`
    if (row?.publish_logo && row.logo_path) {
      const file = await fetch(`${HOST}/storage/v1/object/logo-private/${row.logo_path}`, { headers: auth, cache: 'no-store' })
      if (!file.ok) return
      await fetch(publicPath, { method: 'POST', headers: { ...auth, 'Content-Type': 'image/png', 'x-upsert': 'true' }, body: new Uint8Array(await file.arrayBuffer()) })
    } else {
      await fetch(`${HOST}/storage/v1/object/logo-public`, { method: 'DELETE', headers: { ...auth, 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: [`${businessId}.png`] }) })
    }
  } catch (e) { console.error('[claim-profile] logo sync failed', e) }
}

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return NextResponse.json({ allowed: false, reason: 'not_signed_in' }, { status: 401 })
  let body: Record<string, unknown>
  try { body = await req.json() } catch { return NextResponse.json({ saved: false, field: 'body' }, { status: 400 }) }
  const slug = typeof body.slug === 'string' ? body.slug : ''
  if (!/^[a-z0-9-]+$/.test(slug)) return NextResponse.json({ saved: false, field: 'slug' }, { status: 400 })
  const web = typeof body.website === 'string' ? body.website.trim() : ''
  const payload = { ...body, website: web && !/^https?:\/\//i.test(web) ? 'https://' + web : web }
  delete (payload as Record<string, unknown>).slug
  const r = await saveBusinessProfile(slug, user.email, payload)
  if (!r) return NextResponse.json({ saved: false, reason: 'error' }, { status: 502 })
  if (r.saved && r.business_id) await syncPublicLogo(r.business_id)
  return NextResponse.json(r, { status: r.allowed ? (r.saved ? 200 : 400) : 403 })
}
