import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { saveBusinessProfile } from '@/lib/business-profile'

// Saves a claimed business's own details (work order 712). The email is the SIGNED-IN session's,
// never a value from the request body; business_profile_save re-checks the approved-claim gate.
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
  return NextResponse.json(r, { status: r.allowed ? (r.saved ? 200 : 400) : 403 })
}
