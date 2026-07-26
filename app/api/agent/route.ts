import { NextRequest, NextResponse } from 'next/server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'

// Agent surface (items 51 + 59). Three actions, all authenticated as the logged-in agent:
//  - verify:  match a FL real-estate licence to the DBPR roster and, if Current/Active AND the name
//             matches, stamp agent_profile.license_verified_at (item 51).
//  - preview: resolve a pasted block of addresses to Volusia parcels + their latest recorded sale,
//             so she can confirm the ones she actually handled (item 59). NO file upload — addresses
//             are firsthand knowledge; an MLS export is a licensed compilation and is not accepted.
//  - confirm: licence-gated insert of the confirmed parcels as sale_agent claims (closes item 50).
const VOLUSIA = 74

export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user) return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 })
  const body = await req.json().catch(() => ({} as any))
  const action = String(body.action ?? '')
  const admin = getSupabaseAdmin()

  if (action === 'verify') {
    const license = String(body.license ?? '').trim()
    const name = String(body.name ?? '').trim()
    if (!license || !name) return NextResponse.json({ error: 'Licence number and name are required.' }, { status: 400 })
    const { data, error } = await admin.rpc('agent_verify_license', {
      p_user_id: user.id, p_license: license, p_name: name, p_email: user.email ?? null,
    })
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json(data)
  }

  if (action === 'preview') {
    // Accept a pasted block (newline/comma-per-line) up to a sane cap.
    const raw = String(body.addresses ?? '')
    const addresses = raw.split(/\r?\n/).map(s => s.trim()).filter(Boolean).slice(0, 200)
    if (!addresses.length) return NextResponse.json({ error: 'Paste at least one address (one per line).' }, { status: 400 })
    const { data, error } = await admin.rpc('agent_claim_preview', { p_co_no: VOLUSIA, p_addresses: addresses })
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json({ results: data ?? [] })
  }

  if (action === 'confirm') {
    const parcelIds: string[] = Array.isArray(body.parcel_ids) ? body.parcel_ids.map(String).filter(Boolean).slice(0, 200) : []
    if (!parcelIds.length) return NextResponse.json({ error: 'No parcels selected to claim.' }, { status: 400 })
    const { data, error } = await admin.rpc('agent_claim_confirm', { p_user_id: user.id, p_co_no: VOLUSIA, p_parcel_ids: parcelIds })
    if (error) return NextResponse.json({ error: error.message }, { status: 500 })
    return NextResponse.json(data)
  }

  return NextResponse.json({ error: 'Unknown action.' }, { status: 400 })
}
