import type { Metadata } from 'next'
import CheckoutClient from '@/app/components/CheckoutClient'

export const metadata: Metadata = {
  title: 'Checkout',
  robots: { index: false, follow: false },
}

// Products the checkout can bill. Keep in sync with PRODUCTS in
// app/api/checkout/route.ts (single source of truth for amounts is the API).
const PRODUCTS: Record<string, { name: string; amountCents: number; blurb: string }> = {
  property_report: {
    name: 'Property Intelligence Report',
    amountCents: 2900,
    blurb: 'Full flood, elevation, nearby-amenity and parcel report for one property.',
  },
  contractor_enhanced: {
    name: 'Enhanced Contractor Profile',
    amountCents: 4900,
    blurb: 'Verified badge, logo, work photos and priority placement — billed annually.',
  },
}

export default async function CheckoutPage({
  searchParams,
}: {
  searchParams: Promise<{ product?: string; ref?: string }>
}) {
  const sp = await searchParams
  const key = sp.product && PRODUCTS[sp.product] ? sp.product : 'property_report'
  return <CheckoutClient productKey={key} product={PRODUCTS[key]} reference={sp.ref ?? ''} />
}
