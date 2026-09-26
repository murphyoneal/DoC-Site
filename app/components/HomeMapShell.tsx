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
  const [count, setCount] = useState<number | null>(null)

  return (
    <div className="flex flex-col" style={{ height: 'calc(100vh - 96px)' }}>
      {/* What this is, in one breath. The page had no heading or sentence at all: the title
          promised contractors, and the only text box was a property-address lookup. */}
      <div className="px-4 pt-3" style={{ background: 'var(--color-light-gray)' }}>
        <div className="max-w-3xl mx-auto">
          <h1 className="text-lg font-bold" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', margin: 0 }}>
            Florida&rsquo;s licensed construction contractors, on a map.
          </h1>
          <p className="text-sm" style={{ color: 'var(--color-sage)', margin: '4px 0 0' }}>
            Every business here holds a licence in the state&rsquo;s construction licence file, placed near
            the address on that licence, which is not always where it works. Pick a trade below, or{' '}
            <a href="/c" style={{ color: 'var(--color-bronze)', textDecoration: 'underline' }}>search by name, licence number, city or county</a>.
            To see the public record for a property, look up its address.
          </p>
        </div>
      </div>

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
          <FilterChips selected={category} onSelect={setCategory} />
        </div>
      </div>

      {/* Map fills remaining space */}
      <div className="flex-1 relative">
        <ContractorMap
          category={category}
          emergency={false}
          onCountChange={setCount}
        />
      </div>
    </div>
  )
}
