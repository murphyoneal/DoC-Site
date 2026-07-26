import { NextRequest, NextResponse } from 'next/server'
import { getSupabaseAdmin } from '@/lib/supabase/server'
import { getSessionUser } from '@/lib/supabase/ssr-server'

// Q&A&O — the opinion under each answer. Open text (`note`) is primary; enums optional.
// account_id carries the alpha user; query_log_id links to the exchange being judged.
export async function POST(req: NextRequest) {
  const user = await getSessionUser()
  if (!user) return NextResponse.json({ error: 'Not authenticated.' }, { status: 401 })
  const b = await req.json().catch(() => ({} as any))
  const admin = getSupabaseAdmin()
  const { error } = await admin.from('assistant_exchange_opinion').insert({
    query_log_id: b.queryLogId ?? null,
    account_id: user.id,
    parcel_id: b.parcelId ?? null,
    note: b.note ?? null,
    expected_instead: b.expectedInstead ?? null,
    correction_claim: b.correctionClaim ?? null,
    field_reference: b.fieldReference ?? null,
    answer_correct: b.answerCorrect ?? null,
    answer_useful: b.answerUseful ?? null,
    gap_verdict: b.gapVerdict ?? null,
    mls_comparison: b.mlsComparison ?? null,
    response_lag_ms: typeof b.responseLagMs === 'number' ? Math.round(b.responseLagMs) : null,
  })
  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ ok: true })
}
