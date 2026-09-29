import { NextRequest, NextResponse } from 'next/server'
import { logSubmission } from '@/lib/custody'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { rpc } from '@/lib/agent-profile'

// Saves an approved agent's own details. The email is the signed-in session's, never the body's;
// agent_profile_save re-checks that it is the approved claim's.
export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return NextResponse.json({ allowed: false, reason: 'not_signed_in' }, { status: 401 })
  let b: Record<string, unknown>
  try { b = await req.json() } catch { return NextResponse.json({ saved: false, field: 'body' }, { status: 400 }) }
  const slug = typeof b.slug === 'string' ? b.slug : ''
  if (!/^[a-z0-9-]+$/.test(slug)) return NextResponse.json({ saved: false, field: 'slug' }, { status: 400 })
  const web = typeof b.website === 'string' ? b.website.trim() : ''
  const p = { ...b, website: web && !/^https?:\/\//i.test(web) ? 'https://' + web : web }
  delete (p as Record<string, unknown>).slug
  const r = await rpc<{ allowed: boolean; saved?: boolean; field?: string }>('agent_profile_save', { p_slug: slug, p_email: user.email, p })
  if (!r) return NextResponse.json({ saved: false, reason: 'error' }, { status: 502 })
  await logSubmission(req, { kind: 'agent_profile_save', ref: slug, email: user.email, outcome: r.saved ? 'saved' : `refused:${r.field ?? 'not_allowed'}` })
  return NextResponse.json(r, { status: r.allowed ? (r.saved ? 200 : 400) : 403 })
}
