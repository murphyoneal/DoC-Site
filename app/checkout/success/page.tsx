import type { Metadata } from 'next'
import { Suspense } from 'react'
import CheckoutSuccessClient from '@/app/components/CheckoutSuccessClient'

export const metadata: Metadata = {
  title: 'Payment confirmed',
  robots: { index: false, follow: false },
}

export default function CheckoutSuccessPage() {
  return (
    <Suspense fallback={<div className="max-w-lg mx-auto px-4 py-12 text-sm" style={{ color: 'var(--color-sage)' }}>Loading…</div>}>
      <CheckoutSuccessClient />
    </Suspense>
  )
}
