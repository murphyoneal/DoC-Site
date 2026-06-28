'use client'

import { useEffect, useRef, useCallback, useState } from 'react'
import type { ContractorMapPin } from '@/types/contractor'

// ── MAP LAYER TYPES ───────────────────────────────────────────────────────────
type BaseLayer = 'streets' | 'satellite' | 'terrain'
type OverlayLayer = 'flood' | 'wind' | 'heat'

const BASE_STYLES: Record<BaseLayer, string> = {
  streets:   'mapbox://styles/mapbox/streets-v12',
  satellite: 'mapbox://styles/mapbox/satellite-streets-v12',
  terrain:   'mapbox://styles/mapbox/outdoors-v12',
}

const BASE_LAYERS: { id: BaseLayer; label: string; icon: string }[] = [
  { id: 'streets',   label: 'Streets',  icon: '🗺' },
  { id: 'satellite', label: 'Aerial',   icon: '🛰' },
  { id: 'terrain',   label: 'Terrain',  icon: '⛰' },
]

const OVERLAY_LAYERS: { id: OverlayLayer; label: string; icon: string; available: boolean }[] = [
  { id: 'flood', label: 'Flood Zones', icon: '💧', available: true },
  { id: 'wind',  label: 'Wind Zones',  icon: '🌀', available: false },
  { id: 'heat',  label: 'Heat Risk',   icon: '🌡', available: false },
]

const FLOOD_LEGEND = [
  { color: '#2166ac', label: 'High Risk (A / AE)' },
  { color: '#053061', label: 'Coastal High Risk (VE)' },
  { color: '#a6cee3', label: 'Moderate / Minimal (X)' },
  { color: '#fdbf6f', label: 'Undetermined (D)' },
]

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

  const [activeBase, setActiveBase] = useState<BaseLayer>('satellite')
  const [activeOverlays, setActiveOverlays] = useState<Set<OverlayLayer>>(new Set())

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

      const CATEGORY_LABELS: Record<string, string> = {
        general_contractor: 'General Contractor',
        roofing: 'Roofing',
        plumbing: 'Plumbing',
        hvac: 'HVAC',
        electrical: 'Electrical',
        pool_spa: 'Pool & Spa',
        solar: 'Solar',
        painting: 'Painting',
        flooring: 'Flooring',
        masonry: 'Masonry',
        landscaping: 'Landscaping',
        windows_doors: 'Windows & Doors',
        insulation: 'Insulation',
        drywall: 'Drywall',
        fencing: 'Fencing',
        fire_protection: 'Fire Protection',
        residential_contractor: 'Residential Contractor',
        general_engineering: 'General Engineering',
        qualifier_business: 'General Contractor',
        pressure_washing: 'Pressure Washing',
      }

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

        const tradeDisplay = c.doc_category
          ? (CATEGORY_LABELS[c.doc_category] || c.doc_category)
          : 'Contractor'

        const addressLine = c.address_line_1
          ? c.address_line_1 + (c.city ? ', ' + c.city : '') + (c.state ? ', ' + c.state : '') + (c.zip_code ? ' ' + c.zip_code : '')
          : c.city ? c.city + (c.state ? ', ' + c.state : '') : ''

        const popupHtml =
          '<div style="font-family:Arial,sans-serif;padding:2px">' +
          '<a href="/c/' + c.slug + '" style="font-weight:700;font-size:0.9rem;color:#1B2A4A;text-decoration:none">' + c.display_name + '</a>' +
          '<p style="margin:3px 0 0;font-size:0.78rem;color:#6B7F6B">' + tradeDisplay + '</p>' +
          (addressLine ? '<p style="margin:2px 0 0;font-size:0.74rem;color:#888">' + addressLine + '</p>' : '') +
          '<p style="margin:4px 0 0;font-size:0.74rem;font-weight:600;color:' + statusColour + '">' +
          (c.license_status ? c.license_status.charAt(0).toUpperCase() + c.license_status.slice(1) : '') +
          (c.verified ? ' \u00b7 \u2713 Verified' : '') +
          '</p>' +
          (c.emergency_available ? '<p style="margin:3px 0 0;font-size:0.74rem;color:#c0392b;font-weight:600">\uD83D\uDEA8 Emergency Available</p>' : '') +
          '<a href="/c/' + c.slug + '" style="display:inline-block;margin-top:6px;font-size:0.74rem;color:#8B6F47;text-decoration:underline">View Profile \u2192</a>' +
          '</div>'

        const popup = new mapboxgl.Popup({ offset: 12, maxWidth: '280px' }).setHTML(popupHtml)

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
        style: BASE_STYLES['satellite'],
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
      if (map) map.remove()
      mapRef.current = null
    }
  }, [])

  useEffect(function() {
    if (mapRef.current) fetchAndPlot(mapRef.current)
  }, [category, emergency, fetchAndPlot])

  const handleBaseChange = useCallback((layer: BaseLayer) => {
    if (!mapRef.current) return
    setActiveBase(layer)
    mapRef.current.setStyle(BASE_STYLES[layer])
    mapRef.current.once('style.load', () => {
      applyFloodOverlay(mapRef.current, activeOverlays.has('flood'))
    })
  }, [activeOverlays])

  const handleOverlayToggle = useCallback((layer: OverlayLayer) => {
    setActiveOverlays(prev => {
      const next = new Set(prev)
      if (next.has(layer)) next.delete(layer)
      else next.add(layer)
      return next
    })
  }, [])

  useEffect(() => {
    if (!mapRef.current) return
    const map = mapRef.current
    if (map.isStyleLoaded()) {
      applyFloodOverlay(map, activeOverlays.has('flood'))
    } else {
      map.once('style.load', () => applyFloodOverlay(map, activeOverlays.has('flood')))
    }
  }, [activeOverlays])

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%', minHeight: '100%' }}>
      <div
        ref={mapContainerRef}
        style={{ width: '100%', height: '100%', minHeight: '100%' }}
        aria-label="Contractor map"
      />

      <div style={{
        position: 'absolute',
        top: '56px',
        left: '10px',
        zIndex: 10,
        display: 'flex',
        flexDirection: 'column',
        gap: '6px',
        pointerEvents: 'auto',
      }}>
        <div style={panelStyle}>
          <div style={panelHeaderStyle}>Base Map</div>
          {BASE_LAYERS.map(layer => (
            <button
              key={layer.id}
              onClick={() => handleBaseChange(layer.id)}
              style={{
                ...layerBtnStyle,
                background: activeBase === layer.id ? '#EBF4FF' : 'transparent',
                color: activeBase === layer.id ? '#1B4F8A' : '#374151',
                fontWeight: activeBase === layer.id ? 600 : 400,
              }}
            >
              <span style={{ fontSize: '14px' }}>{layer.icon}</span>
              <span>{layer.label}</span>
              {activeBase === layer.id && (
                <span style={{
                  marginLeft: 'auto', width: '6px', height: '6px',
                  borderRadius: '50%', background: '#3B82F6', flexShrink: 0,
                }} />
              )}
            </button>
          ))}
        </div>

        <div style={panelStyle}>
          <div style={panelHeaderStyle}>Overlays</div>
          {OVERLAY_LAYERS.map(layer => {
            const isOn = activeOverlays.has(layer.id)
            return (
              <button
                key={layer.id}
                onClick={() => layer.available && handleOverlayToggle(layer.id)}
                disabled={!layer.available}
                title={layer.available ? undefined : 'Coming soon'}
                style={{
                  ...layerBtnStyle,
                  opacity: layer.available ? 1 : 0.45,
                  cursor: layer.available ? 'pointer' : 'not-allowed',
                  background: isOn && layer.available ? '#F0FDF4' : 'transparent',
                  color: isOn && layer.available ? '#166534' : '#374151',
                }}
              >
                <span style={{ fontSize: '14px' }}>{layer.icon}</span>
                <span>{layer.label}</span>
                {!layer.available
                  ? <span style={{ marginLeft: 'auto', fontSize: '10px', color: '#9CA3AF' }}>Soon</span>
                  : (
                    <span style={{
                      marginLeft: 'auto', width: '28px', height: '14px',
                      borderRadius: '7px',
                      background: isOn ? '#22C55E' : '#D1D5DB',
                      position: 'relative', flexShrink: 0, transition: 'background 0.2s',
                    }}>
                      <span style={{
                        position: 'absolute', top: '2px',
                        left: isOn ? '14px' : '2px',
                        width: '10px', height: '10px',
                        borderRadius: '50%', background: '#fff',
                        boxShadow: '0 1px 2px rgba(0,0,0,0.2)',
                        transition: 'left 0.2s',
                      }} />
                    </span>
                  )
                }
              </button>
            )
          })}
        </div>

        {activeOverlays.has('flood') && (
          <div style={panelStyle}>
            <div style={panelHeaderStyle}>FEMA Flood Zones</div>
            <div style={{ padding: '6px 10px 8px' }}>
              {FLOOD_LEGEND.map(item => (
                <div key={item.label} style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '4px' }}>
                  <span style={{
                    width: '14px', height: '10px', borderRadius: '2px',
                    background: item.color, opacity: 0.75, flexShrink: 0,
                  }} />
                  <span style={{ fontSize: '11px', color: '#4B5563' }}>{item.label}</span>
                </div>
              ))}
              <p style={{ fontSize: '10px', color: '#9CA3AF', marginTop: '4px', borderTop: '1px solid #F3F4F6', paddingTop: '4px' }}>
                Source: FEMA FIRM (live)
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

// ── FLOOD OVERLAY ─────────────────────────────────────────────────────────────
// Uses FEMA ArcGIS REST export endpoint as XYZ-style tiles
// Layer 28 = Flood Hazard Zones (the main FIRM zones layer)
function applyFloodOverlay(map: any, show: boolean) {
  const SOURCE_ID = 'fema-nfhl'
  const LAYER_ID  = 'fema-flood-fill'

  if (show) {
    if (!map.getSource(SOURCE_ID)) {
      map.addSource(SOURCE_ID, {
        type: 'raster',
        tiles: [
          'https://hazards.fema.gov/arcgis/rest/services/public/NFHL/MapServer/export' +
          '?bbox={bbox-epsg-3857}' +
          '&bboxSR=3857' +
          '&layers=show:28' +
          '&size=256,256' +
          '&imageSR=3857' +
          '&format=png32' +
          '&transparent=true' +
          '&f=image'
        ],
        tileSize: 256,
        attribution: 'FEMA NFHL',
      })
      map.addLayer({
        id: LAYER_ID,
        type: 'raster',
        source: SOURCE_ID,
        paint: { 'raster-opacity': 0.6 },
      })
    } else {
      map.setLayoutProperty(LAYER_ID, 'visibility', 'visible')
    }
  } else {
    if (map.getLayer(LAYER_ID)) {
      map.setLayoutProperty(LAYER_ID, 'visibility', 'none')
    }
  }
}

// ── STYLES ────────────────────────────────────────────────────────────────────
const panelStyle: React.CSSProperties = {
  background: '#fff',
  borderRadius: '10px',
  boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
  border: '1px solid #E5E7EB',
  overflow: 'hidden',
  minWidth: '140px',
}

const panelHeaderStyle: React.CSSProperties = {
  padding: '5px 10px',
  background: '#F9FAFB',
  borderBottom: '1px solid #E5E7EB',
  fontSize: '10px',
  fontWeight: 600,
  color: '#6B7280',
  textTransform: 'uppercase',
  letterSpacing: '0.06em',
}

const layerBtnStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: '7px',
  width: '100%',
  padding: '7px 10px',
  border: 'none',
  cursor: 'pointer',
  fontSize: '12px',
  textAlign: 'left',
  transition: 'background 0.15s',
}