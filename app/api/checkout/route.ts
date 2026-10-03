import { NextRequest, NextResponse } from 'next/server'
import { pirSalesOpen } from '@/lib/pir-sales'
import Stripe from 'stripe'
import { checkRateLimit, pruneRateLimitStore, clientIp } from '@/lib/rateLimit'
import { pirSocket } from '@/lib/sockets/pir'
import { checkoutRefusal } from '@/lib/report-gate.mjs'

// Create a Stripe CHECKOUT session for a single Property Intelligence Report.
// Stripe hosts the page (PCI scope is theirs; Apple/Google Pay + 3DS come free).
// $5, one-off, no login — email is collected by Checkout and is the only delivery
// channel. Fulfilment happens in the webhook (checkout.session.completed), NEVER on
// the success redirect. co_no + parcel_id ride in metadata so the webhook can record
// the purchase against the exact parcel.

export const runtime = 'nodejs' // Stripe SDK needs Node crypto, not Edge

const PIR_PRICE_CENTS = 500 // $5.00, per the build order

// Only headers Vercel's edge sets are trusted (lib/rateLimit clientIp): the domains are not proxied
// through Cloudflare, so a cf-connecting-ip header would be the caller's own choice.
const getIp = (req: NextRequest): string => clientIp(req)

export async function POST(req: NextRequest) {
  // PARKED (work order 712, 2026-09-28): PIR is not on sale. The route and the Stripe wiring stay;
  // it refuses until PIR_SALES_OPEN=true is set in the environment. 503 is what the report page
  // already reads as "payments are not enabled yet".
  // Ruling 976: also refuses while payment confirmation (the webhook) is not configured - never take money that
  // cannot become a delivered report.
  if (!pirSalesOpen()) {
    return NextResponse.json({ error: 'The report is not on sale yet.' }, { status: 503 })
  }
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
  if (!Number.isFinite(coNo) || !parcelId) {
    return NextResponse.json({ error: 'coNo and parcelId are required.' }, { status: 400 })
  }

  // SECOND GATE (181a): the page is not the only way here - a checkout request can be sent for any string.
  // Refuse unless the parcel resolves, and take the address from our own record, never from the request body.
  let preview
  try {
    preview = await pirSocket.previewForParcel(coNo, parcelId)
  } catch (err) {
    console.error('[/api/checkout] parcel lookup failed', err instanceof Error ? err.message : String(err))
    return NextResponse.json({ error: 'Could not start checkout.' }, { status: 503 })
  }
  const refusal = checkoutRefusal(preview, coNo, parcelId)
  if (refusal || !preview) return NextResponse.json(refusal?.body ?? { error: 'Could not start checkout.' }, { status: refusal?.status ?? 503 })
  const address = String(preview.address ?? '').trim().slice(0, 200)

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
