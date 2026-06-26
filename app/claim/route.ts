import { NextRequest, NextResponse } from 'next/server'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWZxb3J3bWdheWlxbWJ0emNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjMxNjIzOCwiZXhwIjoyMDk3ODkyMjM4fQ.L23cjzASjDbuFQ1zeQt30CThOSX_aRwyWpbl7QLeO-E'
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
      `https://${SB_HOST}/rest/v1/contractors?slug=eq.${encodeURIComponent(slug)}&select=id,claimed&limit=1`,
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