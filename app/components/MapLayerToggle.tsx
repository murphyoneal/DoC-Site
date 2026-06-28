'use client';

import { useCallback } from 'react';

export type MapLayer =
  | 'streets'
  | 'satellite'
  | 'flood'
  | 'wind'
  | 'heat'
  | 'terrain';

interface LayerConfig {
  id: MapLayer;
  label: string;
  icon: string;
  description: string;
  mapboxStyle?: string;       // full style swap
  overlay?: boolean;          // true = add layer on top, not swap base
  overlaySourceId?: string;   // Mapbox source id for overlay layers
  available: boolean;
}

const LAYERS: LayerConfig[] = [
  {
    id: 'streets',
    label: 'Streets',
    icon: '🗺',
    description: 'Standard street map',
    mapboxStyle: 'mapbox://styles/mapbox/streets-v12',
    available: true,
  },
  {
    id: 'satellite',
    label: 'Aerial',
    icon: '🛰',
    description: 'Satellite imagery with streets',
    mapboxStyle: 'mapbox://styles/mapbox/satellite-streets-v12',
    available: true,
  },
  {
    id: 'terrain',
    label: 'Terrain',
    icon: '⛰',
    description: 'Topographic with elevation',
    mapboxStyle: 'mapbox://styles/mapbox/outdoors-v12',
    available: true,
  },
  {
    id: 'flood',
    label: 'Flood Zones',
    icon: '💧',
    description: 'FEMA flood zone overlay',
    overlay: true,
    overlaySourceId: 'fema-flood-zones',
    available: true,
  },
  {
    id: 'wind',
    label: 'Wind Zones',
    icon: '🌀',
    description: 'FL Building Code wind speed zones',
    overlay: true,
    overlaySourceId: 'fl-wind-zones',
    available: true,
  },
  {
    id: 'heat',
    label: 'Heat Risk',
    icon: '🌡',
    description: 'Extreme heat days per year',
    overlay: true,
    overlaySourceId: 'heat-risk',
    available: false, // enabled when data is populated
  },
];

// FEMA flood zone colour mapping
export const FLOOD_ZONE_COLORS: Record<string, string> = {
  'A':   '#2166ac',  // High risk — blue
  'AE':  '#2166ac',
  'AH':  '#2166ac',
  'AO':  '#2166ac',
  'VE':  '#053061',  // Coastal high risk — dark blue
  'V':   '#053061',
  'X':   '#a6cee3',  // Moderate/minimal — light blue
  'D':   '#fdbf6f',  // Undetermined — orange
};

export const FLOOD_ZONE_LABELS: Record<string, string> = {
  'A':  'High Risk (A)',
  'AE': 'High Risk (AE)',
  'VE': 'Coastal High Risk',
  'X':  'Moderate / Minimal Risk',
  'D':  'Undetermined Risk',
};

interface MapLayerToggleProps {
  activeBase: MapLayer;
  activeOverlays: Set<MapLayer>;
  onBaseChange: (layer: MapLayer) => void;
  onOverlayToggle: (layer: MapLayer) => void;
}

export function MapLayerToggle({
  activeBase,
  activeOverlays,
  onBaseChange,
  onOverlayToggle,
}: MapLayerToggleProps) {
  const baseLayers = LAYERS.filter(l => !l.overlay);
  const overlayLayers = LAYERS.filter(l => l.overlay);

  return (
    <div className="absolute top-3 right-3 z-10 flex flex-col gap-2 pointer-events-auto">
      {/* Base layer selector */}
      <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
        <div className="px-3 py-1.5 bg-gray-50 border-b border-gray-200">
          <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Base Map
          </span>
        </div>
        <div className="flex flex-col">
          {baseLayers.map((layer) => (
            <button
              key={layer.id}
              onClick={() => onBaseChange(layer.id)}
              title={layer.description}
              className={`
                flex items-center gap-2.5 px-3 py-2 text-sm transition-colors
                ${activeBase === layer.id
                  ? 'bg-blue-50 text-blue-700 font-medium'
                  : 'text-gray-700 hover:bg-gray-50'
                }
              `}
            >
              <span className="text-base leading-none">{layer.icon}</span>
              <span>{layer.label}</span>
              {activeBase === layer.id && (
                <span className="ml-auto w-1.5 h-1.5 rounded-full bg-blue-500" />
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Overlay toggles */}
      <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
        <div className="px-3 py-1.5 bg-gray-50 border-b border-gray-200">
          <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
            Overlays
          </span>
        </div>
        <div className="flex flex-col">
          {overlayLayers.map((layer) => {
            const isActive = activeOverlays.has(layer.id);
            return (
              <button
                key={layer.id}
                onClick={() => layer.available && onOverlayToggle(layer.id)}
                title={layer.available ? layer.description : 'Coming soon'}
                disabled={!layer.available}
                className={`
                  flex items-center gap-2.5 px-3 py-2 text-sm transition-colors
                  ${!layer.available
                    ? 'opacity-40 cursor-not-allowed text-gray-400'
                    : isActive
                      ? 'bg-teal-50 text-teal-700 font-medium'
                      : 'text-gray-700 hover:bg-gray-50'
                  }
                `}
              >
                <span className="text-base leading-none">{layer.icon}</span>
                <span>{layer.label}</span>
                {!layer.available && (
                  <span className="ml-auto text-xs text-gray-400">Soon</span>
                )}
                {layer.available && (
                  <span
                    className={`
                      ml-auto w-8 h-4 rounded-full transition-colors relative flex-shrink-0
                      ${isActive ? 'bg-teal-500' : 'bg-gray-200'}
                    `}
                  >
                    <span
                      className={`
                        absolute top-0.5 w-3 h-3 rounded-full bg-white shadow transition-transform
                        ${isActive ? 'translate-x-4' : 'translate-x-0.5'}
                      `}
                    />
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Flood zone legend — shows when flood overlay is active */}
      {activeOverlays.has('flood') && (
        <div className="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
          <div className="px-3 py-1.5 bg-gray-50 border-b border-gray-200">
            <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
              FEMA Flood Zones
            </span>
          </div>
          <div className="px-3 py-2 flex flex-col gap-1.5">
            {Object.entries(FLOOD_ZONE_LABELS).map(([zone, label]) => (
              <div key={zone} className="flex items-center gap-2">
                <span
                  className="w-4 h-3 rounded flex-shrink-0 opacity-70"
                  style={{ backgroundColor: FLOOD_ZONE_COLORS[zone] || '#ccc' }}
                />
                <span className="text-xs text-gray-600">{label}</span>
              </div>
            ))}
            <p className="text-xs text-gray-400 mt-1 border-t border-gray-100 pt-1">
              Source: FEMA FIRM
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

// ── HOOK: useMapLayers ────────────────────────────────────────────────────────
// Use this in the parent map component to manage layer state
// and apply changes to the Mapbox map instance.

import { useState, useEffect, useRef } from 'react';
import type mapboxgl from 'mapbox-gl';

export function useMapLayers(map: mapboxgl.Map | null) {
  const [activeBase, setActiveBase] = useState<MapLayer>('satellite');
  const [activeOverlays, setActiveOverlays] = useState<Set<MapLayer>>(new Set());
  const overlaysRef = useRef(activeOverlays);
  overlaysRef.current = activeOverlays;

  // Base map style change
  const handleBaseChange = useCallback((layer: MapLayer) => {
    if (!map) return;
    const config = LAYERS.find(l => l.id === layer);
    if (!config?.mapboxStyle) return;
    setActiveBase(layer);
    map.setStyle(config.mapboxStyle);
  }, [map]);

  // Overlay toggle
  const handleOverlayToggle = useCallback((layer: MapLayer) => {
    setActiveOverlays(prev => {
      const next = new Set(prev);
      if (next.has(layer)) {
        next.delete(layer);
      } else {
        next.add(layer);
      }
      return next;
    });
  }, []);

  // Apply overlay visibility when overlays change
  useEffect(() => {
    if (!map) return;

    const floodLayerId = 'fema-flood-fill';
    const floodSourceId = 'fema-flood-zones';

    const applyOverlays = () => {
      // Flood zone overlay
      if (activeOverlays.has('flood')) {
        // Add FEMA flood zone source if not present
        // Source: FEMA National Flood Hazard Layer WMS
        if (!map.getSource(floodSourceId)) {
          map.addSource(floodSourceId, {
            type: 'raster',
            tiles: [
              'https://hazards.fema.gov/gis/nfhl/services/public/NFHL/MapServer/WMSServer?bbox={bbox-epsg-3857}&service=WMS&request=GetMap&version=1.1.1&layers=28&width=256&height=256&srs=EPSG:3857&format=image/png&transparent=true&styles='
            ],
            tileSize: 256,
          });
          map.addLayer({
            id: floodLayerId,
            type: 'raster',
            source: floodSourceId,
            paint: { 'raster-opacity': 0.55 },
          });
        } else {
          map.setLayoutProperty(floodLayerId, 'visibility', 'visible');
        }
      } else {
        if (map.getLayer(floodLayerId)) {
          map.setLayoutProperty(floodLayerId, 'visibility', 'none');
        }
      }

      // Wind zone overlay
      const windLayerId = 'fl-wind-fill';
      const windSourceId = 'fl-wind-zones';
      if (activeOverlays.has('wind')) {
        if (!map.getSource(windSourceId)) {
          // FL Building Code wind zones — placeholder for future WMS/GeoJSON source
          // Will connect to FL DEM wind zone shapefile when geocoding complete
          console.log('[MapLayers] Wind zone source pending data population');
        } else {
          map.setLayoutProperty(windLayerId, 'visibility', 'visible');
        }
      } else {
        if (map.getLayer(windLayerId)) {
          map.setLayoutProperty(windLayerId, 'visibility', 'none');
        }
      }
    };

    // Wait for style to load before adding layers
    if (map.isStyleLoaded()) {
      applyOverlays();
    } else {
      map.once('style.load', applyOverlays);
    }
  }, [map, activeOverlays]);

  return {
    activeBase,
    activeOverlays,
    handleBaseChange,
    handleOverlayToggle,
  };
}

// ── USAGE IN ContractorMap.tsx ────────────────────────────────────────────────
//
// import { MapLayerToggle, useMapLayers } from './MapLayerToggle';
//
// Inside your map component:
//   const { activeBase, activeOverlays, handleBaseChange, handleOverlayToggle } = useMapLayers(mapRef.current);
//
// In JSX alongside the map container:
//   <MapLayerToggle
//     activeBase={activeBase}
//     activeOverlays={activeOverlays}
//     onBaseChange={handleBaseChange}
//     onOverlayToggle={handleOverlayToggle}
//   />
//
// Default base is 'satellite' — aerial view appropriate for property platform.
// FEMA flood overlay uses the public FEMA WMS endpoint — no API key required.
// Wind zones pending FL DEM shapefile integration after geocoding completes.
// Heat risk pending property_hazard_risk data population.
