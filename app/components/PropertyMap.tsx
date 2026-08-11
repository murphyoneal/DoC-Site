'use client'

import { useEffect, useRef, useCallback } from 'react'
import type { PropertyCardData } from '@/types/property'
import type { BoundingBox } from '@/types/contractor'

interface PropertyMapProps {
  items: PropertyCardData[]
  activeId: string | null
  onBoundsChange: (bounds: BoundingBox) => void
  onActiveChange: (id: string) => void
}

// Centered on Lee County (co_no 36) where we've verified parcel + intelligence data.
const DEFAULT_CENTER: [number, number] = [-81.32, 26.75]
const DEFAULT_ZOOM = 14

export default function PropertyMap({ items, activeId, onBoundsChange, onActiveChange }: PropertyMapProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const markersRef = useRef<Map<string, any>>(new Map())
  const onBoundsRef = useRef(onBoundsChange)
  const onActiveRef = useRef(onActiveChange)
  const suppressMove = useRef(false) // ignore our own programmatic pans
  const itemsRef = useRef(items)

  onBoundsRef.current = onBoundsChange
  onActiveRef.current = onActiveChange
  itemsRef.current = items

  const emitBounds = useCallback((map: any) => {
    const b = map.getBounds()
    if (!b) return
    onBoundsRef.current({ north: b.getNorth(), south: b.getSouth(), east: b.getEast(), west: b.getWest() })
  }, [])

  // ── init map ──────────────────────────────────────────────────────────────
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return
    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
    if (!token) return

    let map: any
    let moveTimer: ReturnType<typeof setTimeout>

    import('mapbox-gl').then(mod => {
      const mapboxgl = mod.default
      mapboxgl.accessToken = token
      map = new mapboxgl.Map({
        container: containerRef.current!,
        style: 'mapbox://styles/mapbox/satellite-streets-v12',
        center: DEFAULT_CENTER,
        zoom: DEFAULT_ZOOM,
      })
      mapRef.current = map
      map.addControl(new mapboxgl.NavigationControl(), 'top-right')

      map.on('load', () => emitBounds(map))
      map.on('moveend', () => {
        if (suppressMove.current) { suppressMove.current = false; return }
        clearTimeout(moveTimer)
        moveTimer = setTimeout(() => emitBounds(map), 400)
      })
    })

    return () => {
      clearTimeout(moveTimer)
      markersRef.current.forEach(m => m.remove())
      markersRef.current.clear()
      if (map) map.remove()
      mapRef.current = null
    }
  }, [emitBounds])

  // ── plot markers when items change ──────────────────────────────────────────
  useEffect(() => {
    const map = mapRef.current
    if (!map) return
    let cancelled = false

    import('mapbox-gl').then(mod => {
      if (cancelled) return
      const mapboxgl = mod.default
      markersRef.current.forEach(m => m.remove())
      markersRef.current.clear()

      items.forEach(p => {
        if (p.lat == null || p.lng == null) return
        const el = document.createElement('div')
        styleMarker(el, p.id === activeId)
        el.addEventListener('click', ev => { ev.stopPropagation(); onActiveRef.current(p.id) })
        const marker = new mapboxgl.Marker({ element: el }).setLngLat([p.lng, p.lat]).addTo(map)
        markersRef.current.set(p.id, marker)
      })
    })

    return () => { cancelled = true }
  }, [items]) // eslint-disable-line react-hooks/exhaustive-deps

  // ── reflect active selection: restyle markers + gently pan ───────────────────
  useEffect(() => {
    markersRef.current.forEach((marker, id) => {
      styleMarker(marker.getElement(), id === activeId)
    })
    const map = mapRef.current
    if (!map || !activeId) return
    const active = itemsRef.current.find(p => p.id === activeId)
    if (!active) return
    if (!map.getBounds()?.contains([active.lng, active.lat])) {
      suppressMove.current = true // pan without triggering a refetch
      map.easeTo({ center: [active.lng, active.lat], duration: 500 })
    }
  }, [activeId])

  return (
    <div ref={containerRef} style={{ position: 'absolute', inset: 0 }} aria-label="Property map" />
  )
}

function styleMarker(el: HTMLElement, active: boolean) {
  el.style.cssText = [
    'width:' + (active ? '18px' : '12px'),
    'height:' + (active ? '18px' : '12px'),
    'border-radius:50%',
    'background:' + (active ? 'var(--color-gold, #C9A84C)' : 'var(--color-bronze, #8B6F47)'),
    'border:2px solid #fff',
    'cursor:pointer',
    'box-shadow:' + (active ? '0 0 0 6px rgba(201,168,76,0.35)' : '0 1px 3px rgba(0,0,0,0.4)'),
    'transition:all 0.2s ease',
  ].join(';')
}
