import { NextRequest, NextResponse } from 'next/server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'

// Outbound-document click telemetry. Which documents she opens (and at what rank) is the same
// signal as which feed items get read — it tells you whether the plat scan is the killer artifact
// or something nobody touches. Session-gated by proxy.ts (matcher covers /api/roz/:path*).
export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user) return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 })
  const b = await req.json().catch(() => ({} as any))
  if (!b?.url) return NextResponse.json({ error: 'No url.' }, { status: 400 })
  const admin = getSupabaseAdmin()
  try {
    await admin.from('roz_document_click').insert({
      query_log_id: typeof b.queryLogId === 'string' ? b.queryLogId : null,
      parcel_id: typeof b.parcelId === 'string' ? b.parcelId : null,
      url: String(b.url).slice(0, 2000), label: typeof b.label === 'string' ? b.label.slice(0, 300) : null,
      doc_type: typeof b.docType === 'string' ? b.docType : 'other',
      publisher: typeof b.publisher === 'string' ? b.publisher : null,
      rank: Number.isFinite(b.rank) ? Math.trunc(b.rank) : 1,
      clicked_at: new Date().toISOString(),
    })
  } catch { /* best-effort telemetry */ }
  return NextResponse.json({ ok: true })
}
