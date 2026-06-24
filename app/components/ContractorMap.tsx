'use client'

import { useEffect, useRef, useCallback } from 'react'
import type { ContractorMapPin } from '@/types/contractor'

interface MapProps {
  category: string | null
  emergency: boolean
  onCountChange?: (count: number) => void
}

declare global {
  interface Window {
    mapboxgl: typeof import('mapbox-gl')
  }
}

// Default center — Port Orange / Volusia County, FL
const DEFAULT_CENTER: [number, number] = [-81.0, 29.1]
const DEFAULT_ZOOM = 10

export default function ContractorMap({ category, emergency, onCountChange }: MapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<import('mapbox-gl').Map | null>(null)
  const markersRef = useRef<import('mapbox-gl').Marker[]>([])
  const abortRef = useRef<AbortController | null>(null)

  const clearMarkers = useCallback(() => {
    markersRef.current.forEach(m => m.remove())
    markersRef.current = []
  }, [])

  const fetchAndPlot = useCallback(async (map: import('mapbox-gl').Map) => {
    const bounds = map.getBounds()
    if (!bounds) return

    // Abort any in-flight request
    abortRef.current?.abort()
    abortRef.current = new AbortController()

    const params = new URLSearchParams({
      north: String(bounds.getNorth()),
      south: String(bounds.getSouth()),
      east:  String(bounds.getEast()),
      west:  String(bounds.getWest()),
    })
    if (category) params.set('category', category)
    if (emergency) params.set('emergency', 'true')

    try {
      const res = await fetch(`/api/contractors?${params}`, {
        signal: abortRef.current.signal,
      })
      if (!res.ok) return
      const { contractors } = (await res.json()) as { contractors: ContractorMapPin[] }

      clearMarkers()
      onCountChange?.(contractors.length)

      const mapboxgl = (await import('mapbox-gl')).default

      contractors.forEach(c => {
        if (c.lat == null || c.lng == null) return

        // Marker element
        const el = document.createElement('div')
        el.className = [
          'doc-marker',
          c.emergency_available ? 'emergency' : '',
          c.verified ? 'verified' : '',
        ].filter(Boolean).join(' ')

        // Popup content
        const statusColour =
          c.license_status === 'active' ? '#2d7d46' :
          c.license_status === 'expired' ? '#c0392b' : '#8B6F47'

        const popup = new mapboxgl.Popup({ offset: 12, maxWidth: '260px' }).setHTML(`
          <div style="font-family:Arial,sans-serif;padding:2px">
            <a href="/c/${c.slug}" style="font-weight:700;font-size:0.9rem;color:#1B2A4A;text-decoration:none">
              ${c.display_name}
            </a>
            <p style="margin:3px 0 0;font-size:0.78rem;color:#6B7F6B">${c.trade_label ?? c.doc_category ?? 'Contractor'}</p>
            ${c.city ? `<p style="margin:2px 0 0;font-size:0.75rem;color:#888">${c.city}, ${c.state}</p>` : ''}
            <p style="margin:4px 0 0;font-size:0.74rem;font-weight:600;color:${statusColour}">
              ${c.license_status ? c.license_status.charAt(0).toUpperCase() + c.license_status.slice(1) : ''}
              ${c.verified ? '· ✓ Verified' : ''}
            </p>
            ${c.emergency_available ? '<p style="margin:3px 0 0;font-size:0.74rem;color:#c0392b;font-weight:600">🚨 Emergency Available</p>' : ''}
            <a href="/c/${c.slug}" style="display:inline-block;margin-top:6px;font-size:0.74rem;color:#8B6F47;text-decoration:underline">
              View Profile →
            </a>
          </div>
        `)

        const marker = new mapboxgl.Marker({ element: el })
          .setLngLat([c.lng, c.lat])
          .setPopup(popup)
          .addTo(map)

        markersRef.current.push(marker)
      })
    } catch (err: unknown) {
      if (err instanceof Error && err.name === 'AbortError') return
      console.error('[Map] fetch error:', err)
    }
  }, [category, emergency, clearMarkers, onCountChange])

  useEffect(() => {
    if (!mapContainerRef.current) return
    if (mapRef.current) return // Already initialised

    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
    if (!token) {
      console.error('NEXT_PUBLIC_MAPBOX_TOKEN not set')
      return
    }

    let map: import('mapbox-gl').Map

    import('mapbox-gl').then(({ default: mapboxgl }) => {
      mapboxgl.accessToken = token

      map = new mapboxgl.Map({
        container: mapContainerRef.current!,
        style: 'mapbox://styles/mapbox/light-v11',
        center: DEFAULT_CENTER,
        zoom: DEFAULT_ZOOM,
      })

      mapRef.current = map

      // Controls
      map.addControl(new mapboxgl.NavigationControl(), 'top-right')
      map.addControl(
        new mapboxgl.GeolocateControl({
          positionOptions: { enableHighAccuracy: true },
          trackUserLocation: false,
          showUserHeading: false,
        }),
        'top-right'
      )

      // Load markers when map first loads
      map.on('load', () => fetchAndPlot(map))

      // Reload on pan/zoom end (debounced)
      let timer: NodeJS.Timeout
      map.on('moveend', () => {
        clearTimeout(timer)
        timer = setTimeout(() => fetchAndPlot(map), 400)
      })
    })

    return () => {
      abortRef.current?.abort()
      clearMarkers()
      map?.remove()
      mapRef.current = null
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Re-fetch when filters change
  useEffect(() => {
    if (mapRef.current) fetchAndPlot(mapRef.current)
  }, [category, emergency, fetchAndPlot])

  return (
    <div
      ref={mapContainerRef}
      className="w-full h-full"
      style={{ minHeight: '100%' }}
      aria-label="Contractor map"
    />
  )
}
