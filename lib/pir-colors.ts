// Shared colour + label maps for the PIR maps and their on-page legends, so the
// rendered layers and the legend swatches never drift apart.
//
// Zoning follows the standard industry land-use convention called for in the
// spec: yellow/tan residential, red/orange commercial, purple/grey industrial,
// green parks/conservation, blue institutional, grey utilities/other.
// Flood follows the usual FEMA severity ramp.

export const FLOOD_STYLE: Record<string, { color: string; label: string }> = {
  VE: { color: '#B03A2E', label: 'Coastal high-risk (VE)' },
  V:  { color: '#B03A2E', label: 'Coastal high-risk (V)' },
  AE: { color: '#E67E22', label: '1% annual chance (AE)' },
  AH: { color: '#E8A93A', label: 'Shallow flooding (AH)' },
  AO: { color: '#E8A93A', label: 'Sheet flow (AO)' },
  A:  { color: '#EB984E', label: '1% annual, no BFE (A)' },
  X:  { color: '#AED6B5', label: 'Minimal risk (X)' },
  D:  { color: '#B8B3AE', label: 'Undetermined (D)' },
}
export const FLOOD_FALLBACK = { color: '#B8B3AE', label: 'Other zone' }

export const ZONING_STYLE: Record<string, { color: string; label: string }> = {
  residential:  { color: '#E9D66B', label: 'Residential' },
  planned:      { color: '#D2B48C', label: 'Planned unit (PUD)' },
  commercial:   { color: '#E06B5A', label: 'Commercial' },
  industrial:   { color: '#9B8AA6', label: 'Industrial' },
  rural:        { color: '#C4D6A0', label: 'Rural / agricultural' },
  conservation: { color: '#6FA96F', label: 'Conservation' },
  public:       { color: '#7FA9D6', label: 'Public / institutional' },
  other:        { color: '#B8B3AE', label: 'Other' },
}
export const ZONING_FALLBACK = { color: '#B8B3AE', label: 'Other' }

export function floodStyle(zone: string | null | undefined) {
  return (zone && FLOOD_STYLE[zone.toUpperCase()]) || FLOOD_FALLBACK
}
export function zoningStyle(category: string | null | undefined) {
  return (category && ZONING_STYLE[category.toLowerCase()]) || ZONING_FALLBACK
}
