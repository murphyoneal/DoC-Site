'use client'

import { useState } from 'react'
import dynamic from 'next/dynamic'
import FilterChips from './FilterChips'
import AddressAutocomplete from './AddressAutocomplete'

// Dynamic import — Mapbox only runs in browser
const ContractorMap = dynamic(() => import('./ContractorMap'), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center"
      style={{ background: '#e8e4df' }}>
      <p style={{ color: 'var(--color-sage)', fontFamily: 'Georgia, serif' }}>
        Loading map…
      </p>
    </div>
  ),
})

export default function HomeMapShell() {
  const [category, setCategory] = useState<string | null>(null)
  const [emergency, setEmergency] = useState(false)
  const [count, setCount] = useState<number | null>(null)

  const handleCategorySelect = (val: string | null) => {
    setCategory(val)
    if (val) setEmergency(false)
  }

  const handleEmergencyToggle = () => {
    setEmergency(prev => !prev)
    if (!emergency) setCategory(null)
  }

  return (
    <div className="flex flex-col" style={{ height: 'calc(100vh - 96px)' }}>
      {/* Property lookup — the entry point: an address resolves to that parcel's full
          report. Searches our own roll, so every suggestion has a report behind it; a
          non-match says so honestly rather than "not found". Relative + high z-index so
          the suggestion dropdown renders above the Mapbox canvas below. */}
      <div
        className="px-4 py-3 border-b"
        style={{ background: 'var(--color-light-gray)', borderColor: 'var(--color-light-gray)', position: 'relative', zIndex: 30 }}
      >
        <div className="max-w-3xl mx-auto">
          <label
            htmlFor="property-address-search"
            className="text-xs font-semibold uppercase tracking-wide block mb-1.5"
            style={{ color: 'var(--color-bronze)' }}
          >
            Look up a property
          </label>
          <AddressAutocomplete placeholder="Enter a Florida property address…" />
        </div>
      </div>

      {/* Filter bar */}
      <div
        className="px-4 py-2.5 border-b"
        style={{
          background: 'var(--color-white)',
          borderColor: 'var(--color-light-gray)',
        }}
      >
        <div className="max-w-7xl mx-auto flex items-center gap-3">
          {count !== null && (
            <span className="text-sm whitespace-nowrap" style={{ color: 'var(--color-sage)' }}>
              {count} found
            </span>
          )}
          <FilterChips
            selected={category}
            onSelect={handleCategorySelect}
            emergency={emergency}
            onEmergencyToggle={handleEmergencyToggle}
          />
        </div>
      </div>

      {/* Map fills remaining space */}
      <div className="flex-1 relative">
        <ContractorMap
          category={category}
          emergency={emergency}
          onCountChange={setCount}
        />
      </div>
    </div>
  )
}
