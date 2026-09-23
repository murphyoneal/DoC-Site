import { NextRequest, NextResponse } from 'next/server'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = process.env.SUPABASE_SECRET_KEY!
const SB_HEADERS = {
  'apikey': SB_KEY,
  'Authorization': 'Bearer ' + SB_KEY,
  'Content-Type': 'application/json',
  'Prefer': 'return=minimal',
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json()
    const {
      slug,
      license_number,
      requester_name,
      requester_email,
      requester_phone,
      message,
    } = body

    if (!slug || !license_number || !requester_name || !requester_email) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    // Get contractor id from slug
    const lookupRes = await fetch(
      `https://${SB_HOST}/rest/v1/contractors_public?slug=eq.${encodeURIComponent(slug)}&select=id,claimed&limit=1`,
      { headers: SB_HEADERS }
    )
    const contractors = await lookupRes.json()
    if (!contractors || contractors.length === 0) {
      return NextResponse.json({ error: 'Contractor not found' }, { status: 404 })
    }
    const contractor = contractors[0]
    if (contractor.claimed) {
      return NextResponse.json({ error: 'This profile has already been claimed' }, { status: 409 })
    }

    // Compare the submitted licence against the record being claimed, and against the other
    // records of the same business. This is RECORDED, never enforced: a mismatch is a claim that
    // needs a person, not a rejection. Our own Terms say a licence number is not proof of
    // authority — the cardholder and the qualifying agent are often different people.
    //
    // A failure here must not block the claim. Losing a verdict is recoverable; losing the claim
    // is not, and the endpoint has never successfully run in production.
    let licenceMatch: { state: string | null; note: string | null } = { state: null, note: null }
    try {
      const matchRes = await fetch(
        `https://${SB_HOST}/rest/v1/rpc/evaluate_claim_licence`,
        {
          method: 'POST',
          headers: { ...SB_HEADERS, 'Content-Type': 'application/json' },
          body: JSON.stringify({ p_contractor_id: contractor.id, p_submitted: license_number }),
        }
      )
      if (matchRes.ok) {
        const m = await matchRes.json()
        licenceMatch = { state: m?.state ?? null, note: m?.note ?? null }
      } else {
        console.error('[claim] licence check returned', matchRes.status, await matchRes.text())
      }
    } catch (e) {
      console.error('[claim] licence check failed', e)
    }

    // Insert claim request
    const insertRes = await fetch(
      `https://${SB_HOST}/rest/v1/claim_requests`,
      {
        method: 'POST',
        headers: SB_HEADERS,
        body: JSON.stringify({
          contractor_id: contractor.id,
          requester_name,
          requester_email,
          requester_phone: requester_phone || null,
          license_number,
          message: message || null,
          status: 'pending',
          // recorded for the reviewer; never a gate. claimed stays manual and is not set here.
          licence_match_state: licenceMatch.state,
          licence_match_note: licenceMatch.note,
        }),
      }
    )

    if (!insertRes.ok) {
      const err = await insertRes.text()
      console.error('[claim] insert error', err)
      return NextResponse.json({ error: 'Failed to submit claim' }, { status: 500 })
    }

    console.log('[claim] submitted', { slug, requester_email })
    return NextResponse.json({ ok: true })

  } catch (err) {
    console.error('[claim]', err)
    return NextResponse.json({ error: 'Server error' }, { status: 500 })
  }
}