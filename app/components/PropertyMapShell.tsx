'use client'

import { useState, useCallback, useRef, useEffect } from 'react'
import dynamic from 'next/dynamic'
import PropertyRolodex from './PropertyRolodex'
import AmenityCompass from './AmenityCompass'
import type { PropertyCardData } from '@/types/property'
import type { NearbyAmenity } from '@/types/amenity'
import type { BoundingBox } from '@/types/contractor'

// Mapbox only runs in the browser — dynamic import, like HomeMapShell.
const PropertyMap = dynamic(() => import('./PropertyMap'), {
  ssr: false,
  loading: () => (
    <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#e8e4df' }}>
      <p style={{ color: 'var(--color-sage)', fontFamily: 'Georgia, serif' }}>Loading map…</p>
    </div>
  ),
})

export default function PropertyMapShell() {
  const [items, setItems] = useState<PropertyCardData[]>([])
  const [activeId, setActiveId] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [amenities, setAmenities] = useState<NearbyAmenity[]>([])
  const abortRef = useRef<AbortController | null>(null)
  const amenityAbortRef = useRef<AbortController | null>(null)

  const handleBoundsChange = useCallback(async (b: BoundingBox) => {
    abortRef.current?.abort()
    const ac = new AbortController()
    abortRef.current = ac
    setLoading(true)
    const qs = `north=${b.north}&south=${b.south}&east=${b.east}&west=${b.west}`
    try {
      const res = await fetch(`/api/properties?${qs}`, { signal: ac.signal })
      if (!res.ok) return
      const json = (await res.json()) as { properties: PropertyCardData[] }
      const props = json.properties ?? []
      setItems(props)
      // keep current selection if still in view, else focus the first result
      setActiveId(prev => (prev && props.some(p => p.id === prev) ? prev : props[0]?.id ?? null))
    } catch (err) {
      if (err instanceof Error && err.name === 'AbortError') return
      console.error('[PropertyMapShell] fetch error:', err)
    } finally {
      setLoading(false)
    }
  }, [])

  // Fetch nearby amenities for the focused parcel (coverage-aware; DB returns only
  // types with data for its county).
  const active = items.find(p => p.id === activeId)
  useEffect(() => {
    if (!active) { setAmenities([]); return }
    amenityAbortRef.current?.abort()
    const ac = new AbortController()
    amenityAbortRef.current = ac
    const qs = `co_no=${active.coNo}&parcel_id=${encodeURIComponent(active.parcelId)}`
    fetch(`/api/amenities?${qs}`, { signal: ac.signal })
      .then(r => (r.ok ? r.json() : { amenities: [] }))
      .then((j: { amenities: NearbyAmenity[] }) => setAmenities(j.amenities ?? []))
      .catch(err => { if (!(err instanceof Error && err.name === 'AbortError')) console.error('[amenities]', err) })
    return () => ac.abort()
  }, [active])

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', overflow: 'hidden' }}>
      <PropertyMap
        items={items}
        activeId={activeId}
        onBoundsChange={handleBoundsChange}
        onActiveChange={setActiveId}
      />

      {items.length > 0 && (
        <PropertyRolodex
          items={items}
          activeId={activeId}
          onActiveChange={setActiveId}
          onCardSelect={setActiveId}
        />
      )}

      {loading && (
        <div style={{
          position: 'absolute', top: 12, left: 12, zIndex: 30,
          background: 'rgba(255,255,255,0.9)', borderRadius: 8, padding: '4px 10px',
          fontSize: 12, color: 'var(--color-sage)', boxShadow: '0 1px 4px rgba(0,0,0,0.15)',
        }}>
          Loading parcels…
        </div>
      )}

      {amenities.length > 0 && (
        <div style={{
          position: 'absolute', bottom: 12, left: 12, zIndex: 25, maxWidth: 340,
          background: 'rgba(250,247,242,0.96)', borderRadius: 12, padding: '12px 14px',
          border: '1px solid var(--color-light-gray)', boxShadow: '0 4px 16px rgba(0,0,0,0.15)',
        }}>
          <AmenityCompass amenities={amenities} />
        </div>
      )}
    </div>
  )
}
