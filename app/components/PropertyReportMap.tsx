'use client'

// Single-parcel report maps. Three layer modes, all from real geometry:
//   • flood   — dissolved FEMA flood zones over a 5-mi radius ring (Page 3)
//   • zoning  — industry-colour-coded zoning over a 5-mi radius ring (Page 4)
//   • parcels — tight close-up of the subject parcel + its neighbours (Page 1)
//
// PDF-export safety: Mapbox is WebGL and only paints while the tab is visible
// (rAF runs). A headless print/PDF pass that snapshots too early captures a blank
// canvas. So we create the map with preserveDrawingBuffer, and once it goes idle
// we bake the rendered canvas into a <img> (shown in print) and flag the
// container `data-map-ready="true"` so an export pipeline can wait for it.

import { useEffect, useRef, useState } from 'react'
import type { PirMapGeoJson, PirParcelCloseup } from '@/types/pir'
import { FLOOD_STYLE, FLOOD_FALLBACK, ZONING_STYLE, ZONING_FALLBACK } from '@/lib/pir-colors'

interface Props {
  coNo: number
  parcelId: string
  layer: 'flood' | 'zoning' | 'parcels'
  radiusM?: number
  height?: number | string
}

function circlePolygon(lng: number, lat: number, r: number, steps = 72): number[][] {
  const coords: number[][] = []
  const latR = (lat * Math.PI) / 180
  for (let i = 0; i <= steps; i++) {
    const t = (i / steps) * 2 * Math.PI
    coords.push([lng + ((r * Math.sin(t)) / (111320 * Math.cos(latR))), lat + ((r * Math.cos(t)) / 110540)])
  }
  return coords
}

// bbox [[minLng,minLat],[maxLng,maxLat]] of a GeoJSON Polygon/MultiPolygon geometry
function geomBounds(geom: any): [[number, number], [number, number]] | null {
  if (!geom || !geom.coordinates) return null
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
  const walk = (a: any) => {
    if (typeof a[0] === 'number') {
      minX = Math.min(minX, a[0]); maxX = Math.max(maxX, a[0])
      minY = Math.min(minY, a[1]); maxY = Math.max(maxY, a[1])
    } else a.forEach(walk)
  }
  walk(geom.coordinates)
  return isFinite(minX) ? [[minX, minY], [maxX, maxY]] : null
}

function matchColor(prop: string, style: Record<string, { color: string }>, fallback: string): any {
  const expr: any[] = ['match', ['get', prop]]
  for (const [k, v] of Object.entries(style)) expr.push(k, v.color)
  expr.push(fallback)
  return expr
}

export default function PropertyReportMap({ coNo, parcelId, layer, radiusM, height = 380 }: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const mapRef = useRef<any>(null)
  const capturedRef = useRef(false)
  const [snapshot, setSnapshot] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  // A map that fails still reports "ready" (as an error) so the print gate,
  // which waits for every map, is never held up by a broken one.
  useEffect(() => {
    if (error && containerRef.current && !containerRef.current.getAttribute('data-map-ready')) {
      containerRef.current.setAttribute('data-map-ready', 'error')
    }
  }, [error])

  useEffect(() => {
    let cancelled = false
    let map: any
    const token = process.env.NEXT_PUBLIC_MAPBOX_TOKEN
    const rad = radiusM ?? (layer === 'parcels' ? 46 : 8047)

    async function run() {
      if (!token) { setError('Map unavailable (no token configured)'); setLoading(false); return }
      const url = layer === 'parcels'
        ? `/api/pir/closeup?co_no=${coNo}&parcel_id=${encodeURIComponent(parcelId)}&radius=${rad}`
        : `/api/pir/map?co_no=${coNo}&parcel_id=${encodeURIComponent(parcelId)}&radius=${rad}`

      let data: PirMapGeoJson | PirParcelCloseup | null = null
      try {
        const res = await fetch(url)
        if (res.ok) data = await res.json()
      } catch { /* handled below */ }
      if (cancelled) return
      if (!data || !data.center) { setError('Map data unavailable'); setLoading(false); return }

      const mod = await import('mapbox-gl')
      if (cancelled) return
      const mapboxgl = mod.default
      mapboxgl.accessToken = token

      map = new mapboxgl.Map({
        container: containerRef.current!,
        style: 'mapbox://styles/mapbox/light-v11',
        center: [data.center.lng, data.center.lat],
        zoom: layer === 'parcels' ? 17 : 11,
        interactive: true,
        attributionControl: true,
        preserveDrawingBuffer: true, // required so the canvas can be baked to an image for PDF
      })
      mapRef.current = map

      // Bake a static snapshot once the map settles, for reliable PDF capture.
      map.on('idle', () => {
        if (cancelled || capturedRef.current) return
        try {
          setSnapshot(map.getCanvas().toDataURL('image/png'))
          capturedRef.current = true
          if (containerRef.current) containerRef.current.setAttribute('data-map-ready', 'true')
        } catch { /* cross-origin/blank buffer — leave live map only */ }
      })

      map.on('load', () => {
        if (cancelled) return
        try {
          if (layer === 'parcels') {
            const d = data as PirParcelCloseup
            if (d.neighbors) {
              map.addSource('neighbors', { type: 'geojson', data: d.neighbors as any })
              map.addLayer({ id: 'neighbors-fill', type: 'fill', source: 'neighbors', paint: { 'fill-color': '#D8D2C8', 'fill-opacity': 0.35 } })
              map.addLayer({ id: 'neighbors-line', type: 'line', source: 'neighbors', paint: { 'line-color': '#8B6F47', 'line-width': 0.8, 'line-opacity': 0.7 } })
            }
            map.addSource('subject', { type: 'geojson', data: { type: 'Feature', properties: {}, geometry: d.subject } as any })
            map.addLayer({ id: 'subject-fill', type: 'fill', source: 'subject', paint: { 'fill-color': '#C9A84C', 'fill-opacity': 0.35 } })
            map.addLayer({ id: 'subject-line', type: 'line', source: 'subject', paint: { 'line-color': '#1B2A4A', 'line-width': 2.5 } })
            const b = geomBounds(d.subject)
            if (b) map.fitBounds(b, { padding: 48, duration: 0, maxZoom: 19 })
          } else {
            const d = data as PirMapGeoJson
            const ring = circlePolygon(d.center.lng, d.center.lat, d.radiusM)
            if (layer === 'flood' && d.flood) {
              map.addSource('flood', { type: 'geojson', data: d.flood as any })
              map.addLayer({ id: 'flood-fill', type: 'fill', source: 'flood', paint: { 'fill-color': matchColor('zone', FLOOD_STYLE, FLOOD_FALLBACK.color), 'fill-opacity': 0.45 } })
              map.addLayer({ id: 'flood-line', type: 'line', source: 'flood', paint: { 'line-color': matchColor('zone', FLOOD_STYLE, FLOOD_FALLBACK.color), 'line-width': 0.6, 'line-opacity': 0.7 } })
            }
            if (layer === 'zoning' && d.zoning) {
              map.addSource('zoning', { type: 'geojson', data: d.zoning as any })
              map.addLayer({ id: 'zoning-fill', type: 'fill', source: 'zoning', paint: { 'fill-color': matchColor('category', ZONING_STYLE, ZONING_FALLBACK.color), 'fill-opacity': 0.5 } })
              map.addLayer({ id: 'zoning-line', type: 'line', source: 'zoning', paint: { 'line-color': '#ffffff', 'line-width': 0.4, 'line-opacity': 0.5 } })
            }
            map.addSource('radius', { type: 'geojson', data: { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: ring } } as any })
            map.addLayer({ id: 'radius-line', type: 'line', source: 'radius', paint: { 'line-color': '#1B2A4A', 'line-width': 1.4, 'line-dasharray': [3, 2], 'line-opacity': 0.8 } })
            if (d.parcel) {
              map.addSource('parcel', { type: 'geojson', data: { type: 'Feature', properties: {}, geometry: d.parcel } as any })
              map.addLayer({ id: 'parcel-fill', type: 'fill', source: 'parcel', paint: { 'fill-color': '#1B2A4A', 'fill-opacity': 0.25 } })
              map.addLayer({ id: 'parcel-line', type: 'line', source: 'parcel', paint: { 'line-color': '#C9A84C', 'line-width': 2 } })
            }
            const lons = ring.map(c => c[0]), lats = ring.map(c => c[1])
            map.fitBounds([[Math.min(...lons), Math.min(...lats)], [Math.max(...lons), Math.max(...lats)]], { padding: 24, duration: 0 })
          }
        } catch (e) {
          console.error('[PropertyReportMap] layer error:', e)
          setError('Map layers failed to draw')
        } finally {
          setLoading(false)
        }
      })
    }

    run()
    return () => { cancelled = true; if (map) map.remove(); mapRef.current = null; capturedRef.current = false }
  }, [coNo, parcelId, layer, radiusM])

  return (
    <div style={{ position: 'relative', width: '100%', height, borderRadius: 10, overflow: 'hidden', border: '1px solid var(--color-light-gray)' }}>
      <div ref={containerRef} className="pir-map-live" style={{ position: 'absolute', inset: 0, background: '#e8e4df' }} aria-label={`${layer} map`} />
      {snapshot && (
        // Shown only in print (see report CSS) so the PDF captures a rendered image.
        <img className="pir-map-snapshot" src={snapshot} alt={`${layer} map`} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover' }} />
      )}
      {loading && !error && <div style={overlayMsg}>Loading map…</div>}
      {error && <div style={overlayMsg}>{error}</div>}
    </div>
  )
}

const overlayMsg: React.CSSProperties = {
  position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
  color: 'var(--color-sage)', fontFamily: 'Georgia, serif', fontSize: 13, background: 'rgba(232,228,223,0.6)',
}
