import AddressAutocomplete from './AddressAutocomplete'
import { CONTRACTOR_URL } from '@/lib/site'

// Department of Property's home once the contractor finder has moved to its own domain (ruling
// 2026-09-27): the property lookup that already existed on the map page, on its own, plus the
// two registers. Deliberately not a redesign - only what is already built and true.
export default function PropertyHome() {
  return (
    <div className="px-4 py-10" style={{ background: 'var(--color-light-gray)' }}>
      <div className="max-w-3xl mx-auto" style={{ position: 'relative', zIndex: 30 }}>
        <h1 className="text-2xl font-bold" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', margin: 0 }}>
          The public record for a Florida property.
        </h1>
        <p className="text-sm" style={{ color: 'var(--color-sage)', margin: '8px 0 16px' }}>
          Look up an address to see what government registers hold about it &mdash; flood zone, zoning,
          ownership, permits and more. Every suggestion is a parcel on our own copy of the county roll.
        </p>
        <label htmlFor="property-address-search" className="text-xs font-semibold uppercase tracking-wide block mb-1.5" style={{ color: 'var(--color-bronze)' }}>
          Look up a property
        </label>
        <AddressAutocomplete placeholder="Enter a Florida property address…" />
        <div className="mt-8 grid gap-3 sm:grid-cols-2">
          <a href={`${CONTRACTOR_URL}/c`} className="block p-4 rounded-lg" style={{ background: 'var(--color-white)', border: '1px solid #e2ddd6', textDecoration: 'none' }}>
            <span className="block font-semibold" style={{ color: 'var(--color-navy)' }}>Florida contractors &rarr;</span>
            <span className="block text-sm" style={{ color: 'var(--color-sage)' }}>Search the state construction licence file on Department of Construction.</span>
          </a>
          <a href="/agents.html" className="block p-4 rounded-lg" style={{ background: 'var(--color-white)', border: '1px solid #e2ddd6', textDecoration: 'none' }}>
            <span className="block font-semibold" style={{ color: 'var(--color-navy)' }}>Florida real estate agents &rarr;</span>
            <span className="block text-sm" style={{ color: 'var(--color-sage)' }}>Search the state real estate licence file.</span>
          </a>
        </div>
      </div>
    </div>
  )
}
