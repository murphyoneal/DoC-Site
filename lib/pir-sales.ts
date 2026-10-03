// Whether the $5 report can actually be bought - checked on the server, in ONE place (ruling 976).
// Sales are open only when the switch is on AND payment confirmation is wired: without the Stripe secret and the
// webhook secret, a sale would take money that the webhook can never turn into a delivered report. The report page
// renders its offer from this, and /api/checkout refuses on it, so the page can never offer what checkout refuses.
export function pirSalesOpen(): boolean {
  return process.env.PIR_SALES_OPEN === 'true'
    && !!process.env.STRIPE_SECRET_KEY
    && !!process.env.STRIPE_WEBHOOK_SECRET
}
