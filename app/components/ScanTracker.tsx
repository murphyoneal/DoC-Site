'use client'

import { useEffect } from 'react'

interface Props {
  slug: string
  tradeCategory?: string | null
  city?: string | null
  state?: string | null
}

export default function ScanTracker({ slug, tradeCategory, city, state }: Props) {
  useEffect(() => {
    const ref = new URLSearchParams(window.location.search).get('ref') ?? 'direct'
    fetch('/api/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        slug,
        ref,
        action: 'page_view',
        trade_category: tradeCategory ?? null,
        city: city ?? null,
        state: state ?? null,
      }),
    }).catch(() => {})
  }, [slug, tradeCategory, city, state])

  return null
}
