import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import { checkRateLimit, pruneRateLimitStore } from '@/lib/rateLimit'

// Create a Stripe CHECKOUT session for a single Property Intelligence Report.
// Stripe hosts the page (PCI scope is theirs; Apple/Google Pay + 3DS come free).
// $5, one-off, no login — email is collected by Checkout and is the only delivery
// channel. Fulfilment happens in the webhook (checkout.session.completed), NEVER on
// the success redirect. co_no + parcel_id ride in metadata so the webhook can record
// the purchase against the exact parcel.

export const runtime = 'nodejs' // Stripe SDK needs Node crypto, not Edge

const PIR_PRICE_CENTS = 500 // $5.00, per the build order

function getIp(req: NextRequest): string {
  return (
    req.headers.get('cf-connecting-ip') ??
    req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    req.headers.get('x-real-ip') ??
    'unknown'
  )
}

export async function POST(req: NextRequest) {
  const key = process.env.STRIPE_SECRET_KEY
  if (!key) {
    return NextResponse.json({ error: 'Payments are not configured.' }, { status: 503 })
  }

  const ip = getIp(req)
  pruneRateLimitStore()
  const { allowed, resetAt } = checkRateLimit(ip)
  if (!allowed) {
    return NextResponse.json(
      { error: 'Too many requests.' },
      { status: 429, headers: { 'Retry-After': String(Math.ceil((resetAt - Date.now()) / 1000)) } }
    )
  }

  const body = await req.json().catch(() => ({} as Record<string, unknown>))
  const coNo = Number(body.coNo ?? body.co_no)
  const parcelId = String(body.parcelId ?? body.parcel_id ?? '').trim()
  const address = String(body.address ?? '').trim().slice(0, 200)
  if (!Number.isFinite(coNo) || !parcelId) {
    return NextResponse.json({ error: 'coNo and parcelId are required.' }, { status: 400 })
  }

  try {
    const stripe = new Stripe(key)
    const origin = req.nextUrl.origin
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: 'Property Intelligence Report',
              description: address ? `Full report — ${address}` : `Parcel ${parcelId}, county ${coNo}`,
            },
            unit_amount: PIR_PRICE_CENTS,
          },
          quantity: 1,
        },
      ],
      // The webhook reads these to fulfil against the exact parcel.
      metadata: { co_no: String(coNo), parcel_id: parcelId, address },
      // Stripe Checkout collects the buyer's email in payment mode; it comes back on the session.
      success_url: `${origin}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/report/${coNo}/${encodeURIComponent(parcelId)}?canceled=1`,
    })
    return NextResponse.json({ url: session.url })
  } catch (err) {
    const detail = err instanceof Error ? err.message : String(err)
    console.error('[/api/checkout]', detail)
    return NextResponse.json({ error: 'Could not start checkout.', detail }, { status: 500 })
  }
}
