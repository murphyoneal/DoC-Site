import { NextRequest, NextResponse } from 'next/server'
import { getSupabaseAdmin } from '@/lib/supabase/server'

// Read-only: has the webhook recorded this session's purchase yet? The success page
// polls this. It never fulfils — fulfilment is the webhook's job alone. Keyed on the
// Stripe session_id, which only the buyer holds (it's in their redirect URL).

export const runtime = 'nodejs'

export async function GET(req: NextRequest) {
  const sid = (req.nextUrl.searchParams.get('session_id') ?? '').trim()
  if (!sid) return NextResponse.json({ found: false }, { status: 400 })

  try {
    const sb = getSupabaseAdmin()
    const { data, error } = await sb.rpc('get_pir_purchase', { p_session_id: sid })
    if (error || !data) return NextResponse.json({ found: false })
    const p = data as { co_no: number; parcel_id: string; address: string | null }
    return NextResponse.json({
      found: true,
      coNo: p.co_no,
      parcelId: p.parcel_id,
      address: p.address ?? null,
      reportUrl: `/report/${p.co_no}/${encodeURIComponent(p.parcel_id)}`,
    })
  } catch (err) {
    console.error('[/api/checkout/status]', err instanceof Error ? err.message : String(err))
    return NextResponse.json({ found: false }, { status: 500 })
  }
}
