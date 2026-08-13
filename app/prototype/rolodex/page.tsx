import PropertyMapShell from '@/app/components/PropertyMapShell'

// Prototype harness — now wired to real data:
//   Mapbox moveend → /api/properties → parcels_staging (parcels_in_view)
//   + get_site_intelligence_batch (flood zone, elevation, owner, just value…).
// Pan/zoom the map to load parcels in view. Click a marker → its card snaps &
// highlights; scroll the rolodex → the marker activates. Needs NEXT_PUBLIC_MAPBOX_TOKEN.

export default function RolodexPrototypePage() {
  return (
    <div style={{ height: '100vh', display: 'flex', flexDirection: 'column', background: 'var(--color-cream)' }}>
      <header style={{ padding: '10px 16px', borderBottom: '1px solid var(--color-light-gray)', background: 'var(--color-white)' }}>
        <h1 style={{ margin: 0, fontSize: 16, color: 'var(--color-navy)' }}>Property rolodex</h1>
        <p style={{ margin: '2px 0 0', fontSize: 12, color: 'var(--color-sage)' }}>
          Live parcels in view. Click a marker → card snaps &amp; highlights. Scroll cards → marker activates. ↻ flips a card.
        </p>
      </header>
      <div style={{ flex: 1, position: 'relative' }}>
        <PropertyMapShell />
      </div>
    </div>
  )
}
