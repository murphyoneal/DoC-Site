import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { logSubmission } from '@/lib/custody'

// A business removes one of its own photos (ruling 762 part 4: delete ships with the cap). WITHDRAW,
// never hard-delete: the row and the private files stay (765.3 - the artefact is the evidence); the photo
// leaves every public read, its public copy is deleted, and it no longer counts toward the 10.

const HOST = 'https://eaifqorwmgayiqmbtzcg.supabase.co'
const KEY = process.env.SUPABASE_SECRET_KEY ?? ''
const AUTH = { apikey: KEY, Authorization: 'Bearer ' + KEY }

const fail = (status: number, error: string) => NextResponse.json({ ok: false, error }, { status })

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return fail(401, 'Sign in first.')
  let b: Record<string, unknown>
  try { b = await req.json() } catch { return fail(400, 'Expected JSON.') }
  const slug = typeof b.slug === 'string' ? b.slug : ''
  const id = typeof b.contribution_id === 'string' ? b.contribution_id : ''
  if (!/^[a-z0-9-]+$/.test(slug) || !/^[0-9a-f-]{36}$/.test(id)) return fail(400, 'Unknown photo.')

  const g = await (await fetch(`${HOST}/rest/v1/rpc/work_upload_gate`, { method: 'POST', cache: 'no-store', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ p_slug: slug, p_email: user.email }) })).json()
  if (!g?.allowed) return fail(403, 'Only the approved owner of this business can remove its photos.')

  const rows = await (await fetch(`${HOST}/rest/v1/work_contribution?id=eq.${id}&contractor_id=eq.${g.contractor_id}&select=id,visibility,work_contribution_image(public_path)`, { headers: AUTH, cache: 'no-store' })).json()
  const row = Array.isArray(rows) ? rows[0] : null
  if (!row) return fail(404, 'That photo is not one of this business\'s.')
  if (String(row.visibility).startsWith('withdrawn')) return NextResponse.json({ ok: true, already: true })

  const r = await fetch(`${HOST}/rest/v1/work_contribution?id=eq.${id}`, {
    method: 'PATCH', cache: 'no-store', headers: { ...AUTH, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify({ visibility: 'withdrawn_by_contractor', withdrawn_at: new Date().toISOString(), withdrawn_reason: 'removed by the business' }),
  })
  if (!r.ok) return fail(500, 'The photo could not be removed. Nothing changed.')
  const pub = (row.work_contribution_image as { public_path: string | null }[]).map(i => i.public_path).filter(Boolean) as string[]
  if (pub.length) await fetch(`${HOST}/storage/v1/object/work-public`, { method: 'DELETE', headers: { ...AUTH, 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: pub }) })

  await logSubmission(req, { kind: 'work_withdraw', ref: id, email: user.email, outcome: `withdrawn_from:${row.visibility}` })
  return NextResponse.json({ ok: true })
}
