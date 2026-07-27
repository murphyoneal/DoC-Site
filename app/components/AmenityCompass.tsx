// The individual badge-compass — the core PIR visual concept.
//
// Each item is its OWN small compass badge: a fixed dial (N always at top, plus
// E/S/W) and a SINGLE pointer that rotates to the item's real bearing — like a
// real compass. It is NOT one shared map with many pins, and the dial itself
// never rotates (only the pointer does). A category with no nearby feature has
// no badge — the presence/absence of badges is itself informative.
//
// The dial is inline SVG (crisp, prints reliably in the PDF); the category icon
// is an HTML emoji overlaid on top (emoji render reliably in HTML across PDF
// engines). Pure presentational — safe in server and client components alike.

import type { NearbyAmenity } from '@/types/amenity'

const ICON: Record<string, string> = {
  droplet: '🚰', bus: '🚌', train: '🚉', book: '📚',
  hospital: '🏥', flame: '🚒', school: '🏫', shield: '🛡️',
  water: '💧', lake: '🌊', wetland: '🪷', ramp: '⛵', park: '🌳',
}

export interface CompassBadgeData {
  icon: string          // emoji, or a key into ICON
  label: string
  sublabel?: string | null
  distanceM: number
  bearingDegrees: number
  tone?: 'gold' | 'sage'
}

function formatDistance(m: number): string {
  const ft = m * 3.28084
  if (ft < 1000) return `${Math.round(ft / 10) * 10} ft`
  return `${(m / 1609.344).toFixed(1)} mi`
}

export function CompassBadge({ icon, label, sublabel, distanceM, bearingDegrees, tone = 'gold' }: CompassBadgeData) {
  const pointer = tone === 'sage' ? 'var(--color-sage)' : 'var(--color-gold)'
  const glyph = ICON[icon] ?? icon
  return (
    <div style={tile} title={sublabel ?? label}>
      <div style={{ position: 'relative', width: 48, height: 48 }}>
        <svg width={48} height={48} viewBox="0 0 48 48" aria-hidden style={{ position: 'absolute', inset: 0 }}>
          <circle cx={24} cy={24} r={20} fill="none" stroke="var(--color-light-gray)" strokeWidth={1.5} />
          {/* fixed cardinal labels — the dial never rotates */}
          <text x={24} y={9.5} textAnchor="middle" fontSize={7} fontWeight={700} fill="var(--color-sage)">N</text>
          <text x={41} y={26.5} textAnchor="middle" fontSize={7} fontWeight={700} fill="var(--color-sage)">E</text>
          <text x={24} y={44} textAnchor="middle" fontSize={7} fontWeight={700} fill="var(--color-sage)">S</text>
          <text x={7} y={26.5} textAnchor="middle" fontSize={7} fontWeight={700} fill="var(--color-sage)">W</text>
          {/* the ONLY thing that rotates: the single pointer, to this item's bearing */}
          <g transform={`rotate(${bearingDegrees} 24 24)`}>
            <polygon points="24,7 20.5,15.5 27.5,15.5" fill={pointer} />
          </g>
        </svg>
        <span style={iconStyle}>{glyph}</span>
      </div>
      <span style={labelStyle}>{label}</span>
      <span style={distStyle}>{formatDistance(distanceM)}</span>
    </div>
  )
}

export function CompassBadgeGrid({ title, badges }: { title?: string; badges: CompassBadgeData[] }) {
  if (!badges.length) return null
  return (
    <div>
      {title && <h4 style={gridTitle}>{title}</h4>}
      <div style={grid}>
        {badges.map((b, i) => <CompassBadge key={`${b.label}-${i}`} {...b} />)}
      </div>
    </div>
  )
}

// Backwards-compatible amenity entry point (used by the map rolodex).
export default function AmenityCompass({ amenities }: { amenities: NearbyAmenity[] }) {
  if (!amenities.length) return null
  const badges: CompassBadgeData[] = amenities.map(a => ({
    icon: a.iconName ?? '📍',
    label: a.displayName,
    sublabel: a.name ?? a.displayName,
    distanceM: a.distanceM,
    bearingDegrees: a.bearingDegrees,
  }))
  return <CompassBadgeGrid title="Nearby amenities" badges={badges} />
}

const tile: React.CSSProperties = {
  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
  padding: '10px 6px', borderRadius: 10,
  background: 'var(--color-white)', border: '1px solid var(--color-light-gray)',
}
const grid: React.CSSProperties = {
  display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(92px, 1fr))', gap: 10,
}
const gridTitle: React.CSSProperties = {
  margin: '0 0 10px', fontSize: 13, color: 'var(--color-navy)',
  fontFamily: 'Georgia, serif', fontWeight: 700,
}
const iconStyle: React.CSSProperties = {
  position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 16,
}
const labelStyle: React.CSSProperties = {
  fontSize: 10.5, color: 'var(--color-ink)', textAlign: 'center', lineHeight: 1.2,
}
const distStyle: React.CSSProperties = {
  fontSize: 12, fontWeight: 700, color: 'var(--color-navy)', fontFamily: 'Georgia, serif',
}
