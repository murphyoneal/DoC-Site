// US-customary distance formatting. Source data is metric (meters, PostGIS geography);
// display for a US audience is feet / miles. One place, so every surface agrees.

export const M_TO_FT = 3.28084
export const M_TO_MI = 1 / 1609.344

/**
 * Feet under ~1000 ft (rounded to 10), miles to one decimal above that.
 * Null/undefined renders as an em dash. e.g. 45 → "150 ft", 3000 → "1.9 mi".
 */
export function formatDistance(m?: number | null): string {
  if (m == null) return '—'
  const ft = m * M_TO_FT
  if (ft < 1000) return `${Math.round(ft / 10) * 10} ft`
  return `${(m * M_TO_MI).toFixed(1)} mi`
}

/** Whole (or fixed-digit) feet — for elevations and short spans. e.g. 12.3 → "40 ft". */
export function feet(m?: number | null, digits = 0): string {
  if (m == null) return '—'
  return `${(m * M_TO_FT).toFixed(digits)} ft`
}

/**
 * BANDED distance for narration where the source carries positional error (geocoded
 * environmental points — FGS runs to ±km on some records). Rounds hard so it never implies
 * accuracy the data lacks: "about 1,200 ft", not "1,191 ft". Feet under a mile, miles above.
 * Returns null for null/non-finite so callers can skip the field entirely.
 */
export function formatDistanceBand(m?: number | null): string | null {
  if (m == null || !isFinite(m)) return null
  const ft = m * M_TO_FT
  if (ft < 1000) return `about ${(Math.round(ft / 50) * 50).toLocaleString('en-US')} ft`
  if (ft < 5280) return `about ${(Math.round(ft / 100) * 100).toLocaleString('en-US')} ft`
  return `~${(m * M_TO_MI).toFixed(1)} mi`
}
