import { NextRequest, NextResponse } from 'next/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { clientIp } from '@/lib/rateLimit'
import { rpc, applySuspensionToStorage, businessIdFor } from '@/lib/suspension'

// Suspend or reinstate a business (ruling 762 part 4). POST only, from a signed-in session - never a
// link in an email. The database function is the authority: it refuses anyone who is not an operator,
// requires a basis, and writes the append-only moderation_action row. Reinstatement goes through the
// same function and is logged exactly as heavily (765.5). Called from the review page (part 5).

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user?.email) return NextResponse.json({ ok: false, error: 'Sign in first.' }, { status: 401 })
  let b: Record<string, unknown>
  try { b = await req.json() } catch { return NextResponse.json({ ok: false, error: 'Expected JSON.' }, { status: 400 }) }
  const slug = typeof b.slug === 'string' ? b.slug : ''
  const action = b.action === 'suspend' ? true : b.action === 'reinstate' ? false : null
  const basis = typeof b.basis === 'string' ? b.basis.trim().slice(0, 2000) : ''
  if (!/^[a-z0-9-]+$/.test(slug) || action === null) return NextResponse.json({ ok: false, error: 'slug and action (suspend | reinstate) are required.' }, { status: 400 })

  const businessId = await businessIdFor(slug)
  if (!businessId) return NextResponse.json({ ok: false, error: 'No such business.' }, { status: 404 })

  const ip = clientIp(req)
  const r = await rpc<{ changed: boolean; suspended: boolean }>('set_business_suspension', {
    p_business_id: businessId, p_suspend: action, p_actor: user.email, p_basis: basis,
    p_ip: /^[0-9a-fA-F:.]+$/.test(ip) ? ip : null, p_via: '/api/admin/suspension',
  })
  // The function raises for a non-operator or a missing basis; rpc() returns null on any refusal.
  if (!r) return NextResponse.json({ ok: false, error: 'Refused: only an operator can do this, and a basis of at least a sentence is required.' }, { status: 403 })
  const storage = r.changed ? await applySuspensionToStorage(businessId, r.suspended) : []
  // What the action did to storage is part of what changed: logged by the same actor, same standard (765.7).
  if (r.changed) await recordStorageEffect(user.email, businessId, r.suspended, storage, ip)
  return NextResponse.json({ ok: true, changed: r.changed, suspended: r.suspended, storage })
}

async function recordStorageEffect(actor: string, businessId: string, suspended: boolean, storage: string[], ip: string) {
  const key = process.env.SUPABASE_SECRET_KEY ?? ''
  try {
    await fetch('https://eaifqorwmgayiqmbtzcg.supabase.co/rest/v1/moderation_action', {
      method: 'POST', cache: 'no-store',
      headers: { apikey: key, Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify({
        occurred_at: new Date().toISOString(), actor: actor.toLowerCase(), actor_kind: 'operator',
        action: suspended ? 'suspension_storage_removed' : 'suspension_storage_restored',
        target_table: 'businesses', target_ids: [businessId], after_state: { storage },
        basis: `effect of the ${suspended ? 'suspension' : 'reinstatement'} just recorded for this business`,
        via: '/api/admin/suspension', ip: /^[0-9a-fA-F:.]+$/.test(ip) ? ip : null,
      }),
    })
  } catch (e) { console.error('[admin/suspension] storage effect not recorded', e) }
}
