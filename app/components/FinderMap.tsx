'use client'

import { useEffect, useRef, useState } from 'react'

// The finder's map (work order 697). It plots the RESULT ROWS the page already rendered as a list
// (no second query), highlights the selected one, and keeps the base-map and overlay choices behind
// one small "Layers" button - they are a setting, not a decision, and no longer hold the corner.
// Coordinates arrive rounded to 2 decimals (about 1 km): a pin is near the licence address, never
// on a house.

export type Pin = { slug: string; name: string; lat: number | null; lng: number | null; label: string }

type BaseLayer = 'streets' | 'satellite'
const BASE_STYLES: Record<BaseLayer, string> = {
  streets: 'mapbox://styles/mapbox/streets-v12',
  satellite: 'mapbox://styles/mapbox/satellite-streets-v12',
}
const FLORIDA_CENTER: [number, number] = [-82.4, 27.9]

export default function FinderMap({ pins, selected, onSelect }: {
  pins: Pin[]
  selected: string | null
  onSelect: (slug: string) => void
}) {
  const boxRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const markersRef = useRef<Map<string, { marker: any; el: HTMLDivElement }>>(new Map())
  const onSelectRef = useRef(onSelect)
  onSelectRef.current = onSelect
  const [ready, setReady] = useState(false)
  const [layersOpen, setLayersOpen] = useState(false)
  const [base, setBase] = useState<BaseLayer>('streets')
  const [flood, setFlood] = useState(false)

  useEffect(() => {
    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
    if (!boxRef.current || mapRef.current || !token) return
    let map: any
    import('mapbox-gl').then(({ default: mapboxgl }) => {
      mapboxgl.accessToken = token
      map = new mapboxgl.Map({ container: boxRef.current!, style: BASE_STYLES.streets, center: FLORIDA_CENTER, zoom: 5.6 })
      map.addControl(new mapboxgl.NavigationControl({ showCompass: false }), 'top-right')
      mapRef.current = map
      // Markers and fitBounds do not need the style or tiles, so the pins do not wait for 'load'
      // (which never fires in a background tab, and is slow on a phone).
      setReady(true)
    })
    return () => { if (map) map.remove(); mapRef.current = null; markersRef.current.clear() }
  }, [])

  // Plot the result rows; fit the view to them.
  useEffect(() => {
    const map = mapRef.current
    if (!ready || !map) return
    let cancelled = false
    import('mapbox-gl').then(({ default: mapboxgl }) => {
      if (cancelled) return
      markersRef.current.forEach(m => m.marker.remove())
      markersRef.current.clear()
      const located = pins.filter(p => p.lat != null && p.lng != null)
      const bounds = new mapboxgl.LngLatBounds()
      for (const p of located) {
        const el = document.createElement('div')
        el.className = 'doc-marker'
        el.title = p.name
        el.addEventListener('click', ev => { ev.stopPropagation(); onSelectRef.current(p.slug) })
        const marker = new mapboxgl.Marker({ element: el }).setLngLat([p.lng!, p.lat!]).addTo(map)
        markersRef.current.set(p.slug, { marker, el })
        bounds.extend([p.lng!, p.lat!])
      }
      if (located.length === 1) map.flyTo({ center: [located[0].lng!, located[0].lat!], zoom: 11 })
      else if (located.length > 1) map.fitBounds(bounds, { padding: 48, maxZoom: 12, duration: 0 })
      else map.jumpTo({ center: FLORIDA_CENTER, zoom: 5.6 })
    })
    return () => { cancelled = true }
  }, [pins, ready])

  // Highlight the selected row's pin and bring it into view, with a small label.
  useEffect(() => {
    const map = mapRef.current
    if (!ready || !map) return
    let popup: any
    markersRef.current.forEach(({ el }, slug) => el.classList.toggle('selected', slug === selected))
    const hit = selected ? markersRef.current.get(selected) : null
    if (hit) {
      const p = pins.find(x => x.slug === selected)
      map.easeTo({ center: hit.marker.getLngLat(), duration: 400 })
      import('mapbox-gl').then(({ default: mapboxgl }) => {
        popup = new mapboxgl.Popup({ offset: 12, closeButton: false, maxWidth: '240px' })
          .setLngLat(hit.marker.getLngLat())
          .setHTML(`<a href="/c/${encodeURIComponent(selected!)}" style="font-weight:700;color:#1B2A4A;text-decoration:none">${escapeHtml(p?.name ?? '')}</a><div style="font-size:12px;color:#6B7F6B">${escapeHtml(p?.label ?? '')}</div>`)
          .addTo(map)
      })
    }
    return () => { if (popup) popup.remove() }
  }, [selected, ready, pins])

  function changeBase(next: BaseLayer) {
    const map = mapRef.current
    if (!map || next === base) return
    setBase(next)
    map.setStyle(BASE_STYLES[next])
    map.once('style.load', () => applyFlood(map, flood))
  }
  function toggleFlood() {
    const map = mapRef.current
    const next = !flood
    setFlood(next)
    if (map) applyFlood(map, next)
  }

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      <div ref={boxRef} style={{ width: '100%', height: '100%' }} aria-label="Map of the listed businesses" />
      <div style={{ position: 'absolute', top: 10, left: 10, zIndex: 10 }}>
        <button type="button" onClick={() => setLayersOpen(o => !o)} aria-expanded={layersOpen}
          style={{ background: '#fff', border: '1px solid #d8d2c8', borderRadius: 8, padding: '6px 10px', fontSize: 12, fontWeight: 600, color: 'var(--color-navy)', boxShadow: '0 1px 4px rgba(0,0,0,.15)', cursor: 'pointer' }}>
          Layers {layersOpen ? '▴' : '▾'}
        </button>
        {layersOpen && (
          <div style={{ marginTop: 6, background: '#fff', border: '1px solid #d8d2c8', borderRadius: 8, padding: 8, fontSize: 12, boxShadow: '0 2px 8px rgba(0,0,0,.15)', minWidth: 150 }}>
            {(['streets', 'satellite'] as BaseLayer[]).map(b => (
              <label key={b} style={{ display: 'flex', gap: 6, alignItems: 'center', padding: '3px 0', cursor: 'pointer' }}>
                <input type="radio" name="base" checked={base === b} onChange={() => changeBase(b)} />
                {b === 'streets' ? 'Streets' : 'Aerial'}
              </label>
            ))}
            <hr style={{ border: 0, borderTop: '1px solid #eee', margin: '6px 0' }} />
            <label style={{ display: 'flex', gap: 6, alignItems: 'center', cursor: 'pointer' }}>
              <input type="checkbox" checked={flood} onChange={toggleFlood} />
              FEMA flood zones
            </label>
          </div>
        )}
      </div>
    </div>
  )
}

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c] as string))
}

// FEMA NFHL flood hazard zones as raster tiles (the same source the old map used).
function applyFlood(map: any, show: boolean) {
  const SRC = 'fema-nfhl', LYR = 'fema-flood-fill'
  if (show) {
    if (!map.getSource(SRC)) {
      map.addSource(SRC, {
        type: 'raster', tileSize: 256, attribution: 'FEMA NFHL',
        tiles: ['https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer/export?bbox={bbox-epsg-3857}&bboxSR=3857&layers=show:28&size=256,256&imageSR=3857&format=png32&transparent=true&f=image'],
      })
      map.addLayer({ id: LYR, type: 'raster', source: SRC, paint: { 'raster-opacity': 0.6 } })
    } else map.setLayoutProperty(LYR, 'visibility', 'visible')
  } else if (map.getLayer(LYR)) map.setLayoutProperty(LYR, 'visibility', 'none')
}
