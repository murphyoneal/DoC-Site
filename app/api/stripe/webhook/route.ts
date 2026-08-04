import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import { getSupabaseAdmin } from '@/lib/supabase/server'

// Stripe webhook — the ONLY place a purchase is fulfilled. The success redirect must
// never fulfil: the browser can close before it fires and the buyer would pay for
// nothing. Fulfilment here is:
//   1. verify the signature (STRIPE_WEBHOOK_SECRET) — reject anything unsigned,
//   2. on checkout.session.completed + paid, record the purchase idempotently
//      (record_pir_purchase keys on session.id, so a re-delivered event is a no-op),
//   3. link the buyer to the consumer identity by email (non-fatal — the purchase
//      record is what matters; a consumer-link error must not fail the webhook).
// Non-2xx makes Stripe retry, which is what we want if the DB write fails.

export const runtime = 'nodejs' // needs Node crypto + the raw request body

export async function POST(req: NextRequest) {
  const key = process.env.STRIPE_SECRET_KEY
  const whSecret = process.env.STRIPE_WEBHOOK_SECRET
  if (!key || !whSecret) {
    // STRIPE_WEBHOOK_SECRET is registered AFTER this endpoint is deployed (the URL has
    // to exist first). Until then, acknowledge without processing so Stripe's initial
    // "add endpoint" test doesn't hard-fail — but never fulfil unsigned.
    console.error('[stripe webhook] missing STRIPE_SECRET_KEY or STRIPE_WEBHOOK_SECRET')
    return NextResponse.json({ error: 'not configured' }, { status: 503 })
  }

  const sig = req.headers.get('stripe-signature')
  const raw = await req.text() // MUST be the raw body for signature verification
  const stripe = new Stripe(key)

  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(raw, sig ?? '', whSecret)
  } catch (err) {
    console.error('[stripe webhook] signature verification failed:', err instanceof Error ? err.message : String(err))
    return NextResponse.json({ error: 'invalid signature' }, { status: 400 })
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session
    if (session.payment_status !== 'paid') {
      return NextResponse.json({ received: true, ignored: 'unpaid' })
    }

    const md = session.metadata ?? {}
    const coNo = Number(md.co_no)
    const parcelId = md.parcel_id ?? ''
    if (!Number.isFinite(coNo) || !parcelId) {
      console.error('[stripe webhook] session missing co_no/parcel_id metadata:', session.id)
      return NextResponse.json({ received: true, ignored: 'no parcel metadata' }) // don't retry — nothing to fulfil
    }

    const email = session.customer_details?.email ?? session.customer_email ?? null
    const sb = getSupabaseAdmin()

    // Consumer link — non-fatal.
    let consumerId: string | null = null
    if (email) {
      try {
        const { data, error } = await sb.rpc('upsert_consumer_by_email', {
          p_email: email,
          p_display_name: session.customer_details?.name ?? null,
        })
        if (!error && typeof data === 'string') consumerId = data
      } catch (e) {
        console.error('[stripe webhook] consumer link failed (non-fatal):', e instanceof Error ? e.message : String(e))
      }
    }

    // Fulfilment — must succeed. Idempotent on session.id.
    const { data: created, error } = await sb.rpc('record_pir_purchase', {
      p_session_id: session.id,
      p_co_no: coNo,
      p_parcel_id: parcelId,
      p_email: email,
      p_amount_cents: session.amount_total,
      p_currency: session.currency,
      p_address: md.address ?? null,
      p_consumer_id: consumerId,
      p_payment_intent: typeof session.payment_intent === 'string' ? session.payment_intent : null,
    })
    if (error) {
      console.error('[stripe webhook] record_pir_purchase failed:', error.message)
      return NextResponse.json({ error: 'fulfilment failed' }, { status: 500 }) // let Stripe retry
    }
    console.log(`[stripe webhook] fulfilled ${session.id} parcel ${coNo}/${parcelId} (new=${created})`)
  }

  return NextResponse.json({ received: true })
}
