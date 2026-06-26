'use client'

import { useEffect, useRef, useCallback } from 'react'
import type { ContractorMapPin } from '@/types/contractor'

interface MapProps {
  category: string | null
  emergency: boolean
  onCountChange?: (count: number) => void
}

const DEFAULT_CENTER: [number, number] = [-81.0, 29.1]
const DEFAULT_ZOOM = 10

export default function ContractorMap({ category, emergency, onCountChange }: MapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const markersRef = useRef<any[]>([])
  const abortRef = useRef<AbortController | null>(null)
  const categoryRef = useRef<string | null>(category)
  const emergencyRef = useRef<boolean>(emergency)

  categoryRef.current = category
  emergencyRef.current = emergency

  const clearMarkers = useCallback(() => {
    markersRef.current.forEach(function(m) { m.remove() })
    markersRef.current = []
  }, [])

  const fetchAndPlot = useCallback(async function(map: any) {
    const bounds = map.getBounds()
    if (!bounds) return

    abortRef.current?.abort()
    abortRef.current = new AbortController()

    const parts: string[] = []
    parts.push('north=' + bounds.getNorth())
    parts.push('south=' + bounds.getSouth())
    parts.push('east=' + bounds.getEast())
    parts.push('west=' + bounds.getWest())

    const cat = categoryRef.current
    const emerg = emergencyRef.current

    if (cat) parts.push('category=' + encodeURIComponent(cat))
    if (emerg) parts.push('emergency=true')

    const url = '/api/contractors?' + parts.join('&')

    try {
      const res = await fetch(url, { signal: abortRef.current.signal })
      if (!res.ok) return
      const json = await res.json() as { contractors: ContractorMapPin[] }
      const contractors = json.contractors

      clearMarkers()
      if (onCountChange) onCountChange(contractors.length)

      const mapboxgl = (await import('mapbox-gl')).default

      contractors.forEach(function(c) {
        if (c.lat == null || c.lng == null) return

        const el = document.createElement('div')
        const classes = ['doc-marker']
        if (c.emergency_available) classes.push('emergency')
        else if (c.verified) classes.push('verified')
        el.className = classes.join(' ')

        const statusColour =
          c.license_status === 'active' ? '#2d7d46' :
          c.license_status === 'expired' ? '#c0392b' : '#8B6F47'

        const popupHtml =
          '<div style="font-family:Arial,sans-serif;padding:2px">' +
          '<a href="/c/' + c.slug + '" style="font-weight:700;font-size:0.9rem;color:#1B2A4A;text-decoration:none">' + c.display_name + '</a>' +
          '<p style="margin:3px 0 0;font-size:0.78rem;color:#6B7F6B">' + (c.trade_label || c.doc_category || 'Contractor') + '</p>' +
          (c.city ? '<p style="margin:2px 0 0;font-size:0.75rem;color:#888">' + c.city + ', ' + c.state + '</p>' : '') +
          '<p style="margin:4px 0 0;font-size:0.74rem;font-weight:600;color:' + statusColour + '">' +
          (c.license_status ? c.license_status.charAt(0).toUpperCase() + c.license_status.slice(1) : '') +
          (c.verified ? ' · \u2713 Verified' : '') +
          '</p>' +
          (c.emergency_available ? '<p style="margin:3px 0 0;font-size:0.74rem;color:#c0392b;font-weight:600">\uD83D\uDEA8 Emergency Available</p>' : '') +
          '<a href="/c/' + c.slug + '" style="display:inline-block;margin-top:6px;font-size:0.74rem;color:#8B6F47;text-decoration:underline">View Profile \u2192</a>' +
          '</div>'

        const popup = new mapboxgl.Popup({ offset: 12, maxWidth: '260px' }).setHTML(popupHtml)

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
  }, [clearMarkers, onCountChange])

  useEffect(function() {
    if (!mapContainerRef.current) return
    if (mapRef.current) return

    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
    if (!token) return

    let map: any
    let moveTimer: ReturnType<typeof setTimeout>

    import('mapbox-gl').then(function(mod) {
      const mapboxgl = mod.default
      mapboxgl.accessToken = token

      map = new mapboxgl.Map({
        container: mapContainerRef.current!,
        style: 'mapbox://styles/mapbox/light-v11',
        center: DEFAULT_CENTER,
        zoom: DEFAULT_ZOOM,
      })

      mapRef.current = map

      map.addControl(new mapboxgl.NavigationControl(), 'top-right')
      map.addControl(
        new mapboxgl.GeolocateControl({
          positionOptions: { enableHighAccuracy: true },
          trackUserLocation: false,
        }),
        'top-right'
      )

      map.on('load', function() { fetchAndPlot(map) })

      map.on('moveend', function() {
        clearTimeout(moveTimer)
        moveTimer = setTimeout(function() { fetchAndPlot(map) }, 400)
      })
    })

    return function() {
      abortRef.current?.abort()
      clearMarkers()
      clearTimeout(moveTimer)
      if (map) map.remove()
      mapRef.current = null
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Re-fetch when category or emergency changes
  useEffect(function() {
    if (mapRef.current) fetchAndPlot(mapRef.current)
  }, [category, emergency, fetchAndPlot])

  return (
    <div
      ref={mapContainerRef}
      style={{ width: '100%', height: '100%', minHeight: '100%' }}
      aria-label="Contractor map"
    />
  )
}