'use client'

/**
 * PropertyRolodex — right-side "rolodex" panel for the property map.
 *
 * Feed it `items` (PropertyCardData). Wiring path:
 *   /api/properties → parcelSocket.forMapWithIntel → parcels_staging
 *   + get_site_intelligence() (flood zone + elevation spatial join).
 *
 * Interaction:
 *  - Desktop → vertical scroll-snap column with a 3D "spindle" tilt.
 *  - Narrow  → horizontal bottom-sheet carousel (same cards, axis swapped).
 *  - Each card flips (rotateY) to reveal secondary parcel data (owner etc.).
 *  - Two-way binding with the map via `activeId` / `onActiveChange`.
 *
 * Card-front priority (per product): address → PIR teaser → flood flag
 * (biggest conversion driver, so it's the hero) → just value → acreage.
 * Owner name lives on the back only (privacy/framing).
 */

import { useEffect, useRef, useState, useCallback } from 'react'
import type { PropertyCardData } from '@/types/property'

export type { PropertyCardData } // re-export for existing importers

interface PropertyRolodexProps {
  items: PropertyCardData[]
  /** Currently-focused parcel, usually driven by the map. */
  activeId?: string | null
  /** Fired when scrolling/keyboard settles a new card into focus → parent flies map. */
  onActiveChange?: (id: string) => void
  /** Fired when a card is explicitly clicked → parent opens the full report. */
  onCardSelect?: (id: string) => void
}

// ── HELPERS ───────────────────────────────────────────────────────────────────
function useIsNarrow(breakpoint = 768) {
  const [narrow, setNarrow] = useState(false)
  useEffect(() => {
    const mq = window.matchMedia(`(max-width: ${breakpoint - 1}px)`)
    const sync = () => setNarrow(mq.matches)
    sync()
    mq.addEventListener('change', sync)
    return () => mq.removeEventListener('change', sync)
  }, [breakpoint])
  return narrow
}

const usd = (n: number) =>
  n >= 1_000_000
    ? `$${(n / 1_000_000).toFixed(2)}M`
    : `$${Math.round(n).toLocaleString('en-US')}`

// Flood zone is the conversion hero: high-risk reads alarming, minimal reassuring.
function floodInfo(zone: string | null) {
  if (!zone) return { bg: '#F0EDEA', fg: '#6B7F6B', icon: '○', label: 'Flood data pending', risk: '' }
  const z = zone.toUpperCase()
  if (z.startsWith('V')) return { bg: '#f6d7d1', fg: '#7a241a', icon: '⚠', label: `Zone ${z}`, risk: 'Coastal high risk' }
  if (z.startsWith('A')) return { bg: '#fae1cb', fg: '#8a4a17', icon: '⚠', label: `Zone ${z}`, risk: 'High flood risk' }
  return { bg: '#e4efe4', fg: '#3f5a3f', icon: '✓', label: `Zone ${z}`, risk: 'Minimal risk' }
}

// ── COMPONENT ───────────────────────────────────────────────────────────────────
export default function PropertyRolodex({
  items,
  activeId,
  onActiveChange,
  onCardSelect,
}: PropertyRolodexProps) {
  const narrow = useIsNarrow()
  const scrollRef = useRef<HTMLDivElement>(null)
  const cardRefs = useRef<(HTMLDivElement | null)[]>([])
  const focusedIdxRef = useRef<number>(0)
  const rafRef = useRef<number | null>(null)
  const idleTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const suppressReport = useRef(false) // ignore our own programmatic scrolls

  const [focusedIdx, setFocusedIdx] = useState(0)
  const [flipped, setFlipped] = useState<Set<string>>(new Set())

  // ── the spindle: recompute per-card transform from scroll offset ──────────────
  const applyTransforms = useCallback(() => {
    const container = scrollRef.current
    if (!container) return
    const cr = container.getBoundingClientRect()
    const axisCenter = narrow ? cr.left + cr.width / 2 : cr.top + cr.height / 2

    let best = { i: focusedIdxRef.current, dist: Infinity }

    cardRefs.current.forEach((el, i) => {
      if (!el) return
      const r = el.getBoundingClientRect()
      const c = narrow ? r.left + r.width / 2 : r.top + r.height / 2
      const size = narrow ? r.width : r.height
      const off = (c - axisCenter) / size            // distance in card-units
      const k = Math.max(-2.4, Math.min(2.4, off))
      const dist = Math.abs(off)

      if (narrow) {
        const scale = Math.max(0.86, 1 - Math.abs(k) * 0.09)
        const rotY = k * 12                            // slight page-turn on the carousel
        el.style.transform = `rotateY(${rotY}deg) scale(${scale})`
        el.style.opacity = String(Math.max(0.5, 1 - Math.abs(k) * 0.32))
      } else {
        const rotX = k * -20                           // tilt away from viewer
        const scale = Math.max(0.82, 1 - Math.abs(k) * 0.10)
        const ty = k * -6
        el.style.transform = `translateY(${ty}px) rotateX(${rotX}deg) scale(${scale})`
        el.style.opacity = String(Math.max(0.34, 1 - Math.abs(k) * 0.34))
      }
      el.style.zIndex = String(200 - Math.round(dist * 10))
      if (dist < best.dist) best = { i, dist }
    })

    if (best.i !== focusedIdxRef.current) {
      focusedIdxRef.current = best.i
      setFocusedIdx(best.i)
    }
  }, [narrow])

  const onScroll = useCallback(() => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current)
    rafRef.current = requestAnimationFrame(applyTransforms)

    // report focus only after scrolling settles, and never for our own scrolls
    if (idleTimer.current) clearTimeout(idleTimer.current)
    idleTimer.current = setTimeout(() => {
      if (suppressReport.current) { suppressReport.current = false; return }
      const item = items[focusedIdxRef.current]
      if (item) onActiveChange?.(item.id)
    }, 140)
  }, [applyTransforms, items, onActiveChange])

  // initial layout + on resize/orientation switch
  useEffect(() => { applyTransforms() }, [applyTransforms, items.length])

  // ── external focus (map marker click) → snap that card to center ──────────────
  const scrollCardToCenter = useCallback((idx: number, smooth = true) => {
    const container = scrollRef.current
    const el = cardRefs.current[idx]
    if (!container || !el) return
    suppressReport.current = true
    const cr = container.getBoundingClientRect()
    const r = el.getBoundingClientRect()
    if (narrow) {
      const delta = (r.left + r.width / 2) - (cr.left + cr.width / 2)
      container.scrollBy({ left: delta, behavior: smooth ? 'smooth' : 'auto' })
    } else {
      const delta = (r.top + r.height / 2) - (cr.top + cr.height / 2)
      container.scrollBy({ top: delta, behavior: smooth ? 'smooth' : 'auto' })
    }
  }, [narrow])

  useEffect(() => {
    if (!activeId) return
    const idx = items.findIndex(p => p.id === activeId)
    if (idx >= 0 && idx !== focusedIdxRef.current) scrollCardToCenter(idx)
  }, [activeId, items, scrollCardToCenter])

  // ── keyboard: arrow through the stack ─────────────────────────────────────────
  const onKeyDown = useCallback((e: React.KeyboardEvent) => {
    const fwd = narrow ? 'ArrowRight' : 'ArrowDown'
    const back = narrow ? 'ArrowLeft' : 'ArrowUp'
    if (e.key === fwd) { e.preventDefault(); scrollCardToCenter(Math.min(items.length - 1, focusedIdxRef.current + 1)) }
    else if (e.key === back) { e.preventDefault(); scrollCardToCenter(Math.max(0, focusedIdxRef.current - 1)) }
  }, [narrow, items.length, scrollCardToCenter])

  const toggleFlip = useCallback((id: string) => {
    setFlipped(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id); else next.add(id)
      return next
    })
  }, [])

  // ── render ────────────────────────────────────────────────────────────────────
  return (
    <div style={narrow ? shellNarrow : shellWide} aria-label="Properties in view">
      {!narrow && (
        <div style={headerStyle}>
          <span style={{ fontFamily: 'Georgia, serif', fontWeight: 600, color: 'var(--color-navy)' }}>
            In view
          </span>
          <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>{items.length} parcels</span>
        </div>
      )}

      <div
        ref={scrollRef}
        onScroll={onScroll}
        onKeyDown={onKeyDown}
        tabIndex={0}
        style={narrow ? trackNarrow : trackWide}
      >
        {items.map((p, i) => {
          const isFocused = i === focusedIdx
          const isFlipped = flipped.has(p.id)
          const flood = floodInfo(p.floodZone)
          return (
            <div
              key={p.id}
              ref={el => { cardRefs.current[i] = el }}
              style={narrow ? cardSlotNarrow : cardSlotWide}
            >
              <div style={{ ...flipInner, transform: isFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)' }}>
                {/* ── FRONT ── */}
                <button
                  onClick={() => { scrollCardToCenter(i); onCardSelect?.(p.id) }}
                  style={{ ...cardFace, ...cardFront, ...(isFocused ? cardFocused : null) }}
                >
                  {/* 1 · address */}
                  <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
                    <p style={addressStyle}>{p.situsAddress}</p>
                    <span
                      role="button"
                      tabIndex={0}
                      onClick={(e) => { e.stopPropagation(); toggleFlip(p.id) }}
                      style={flipHint}
                      title="Flip for parcel details"
                    >
                      ↻
                    </span>
                  </div>
                  <p style={cityStyle}>{p.city} · {p.landUse}</p>

                  {/* 2 · PIR price teaser (conversion hook) */}
                  {p.pirPriceTeaser && (
                    <span style={pirPill}>{p.pirPriceTeaser}</span>
                  )}

                  {/* 3 · flood zone flag — the hero */}
                  <div style={{ ...floodFlag, background: flood.bg, color: flood.fg }}>
                    <span style={{ fontSize: 13 }}>{flood.icon}</span>
                    <span style={{ fontWeight: 700 }}>{flood.label}</span>
                    {flood.risk && <span style={{ opacity: 0.85 }}>· {flood.risk}</span>}
                  </div>

                  {/* 4 · just value  5 · acreage */}
                  <div style={metaRow}>
                    <span style={valueStyle}>{usd(p.justValue)}</span>
                    <span style={metaStyle}>
                      {p.acreage.toFixed(2)} ac{p.yearBuilt ? ` · ${p.yearBuilt}` : ''}
                    </span>
                  </div>
                </button>

                {/* ── BACK ── */}
                <div style={{ ...cardFace, ...cardBack }}>
                  <div style={{ flex: 1 }}>
                    <p style={backTitle}>Parcel {p.parcelId}</p>
                    <Row label="Owner" value={p.ownerName} />
                    <Row label="Assessor lot" value={`${p.acreage.toFixed(2)} ac`} />
                    <Row label="Site (GIS-calc)" value={p.gisAcres != null ? `${p.gisAcres.toFixed(2)} ac` : '—'} />
                    <Row label="Flood zone" value={p.floodZone ?? '—'} />
                    <Row label="Elevation" value={p.elevationFt != null ? `${p.elevationFt} ft` : '—'} />
                  </div>
                  <button onClick={() => toggleFlip(p.id)} style={backFlipBtn}>← Back to card</button>
                </div>
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, padding: '3px 0', borderBottom: '1px solid #F0EDEA' }}>
      <span style={{ fontSize: 11, color: 'var(--color-sage)' }}>{label}</span>
      <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--color-ink)', textAlign: 'right', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: 160 }}>{value}</span>
    </div>
  )
}

// ── STYLES ──────────────────────────────────────────────────────────────────────
const shellWide: React.CSSProperties = {
  position: 'absolute', top: 0, right: 0, bottom: 0, width: 340, zIndex: 20,
  display: 'flex', flexDirection: 'column',
  background: 'linear-gradient(180deg, rgba(250,247,242,0.96), rgba(250,247,242,0.86))',
  backdropFilter: 'blur(2px)', borderLeft: '1px solid var(--color-light-gray)',
  boxShadow: '-6px 0 20px rgba(0,0,0,0.10)',
}
const shellNarrow: React.CSSProperties = {
  position: 'absolute', left: 0, right: 0, bottom: 0, height: 184, zIndex: 20,
  display: 'flex', flexDirection: 'column', pointerEvents: 'none',
}
const headerStyle: React.CSSProperties = {
  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
  padding: '12px 16px', borderBottom: '1px solid var(--color-light-gray)',
}
const trackWide: React.CSSProperties = {
  flex: 1, overflowY: 'auto', overflowX: 'hidden', perspective: 1100,
  scrollSnapType: 'y mandatory', outline: 'none',
  padding: '40vh 20px', display: 'flex', flexDirection: 'column', gap: 14,
}
const trackNarrow: React.CSSProperties = {
  flex: 1, overflowX: 'auto', overflowY: 'hidden', perspective: 1000,
  scrollSnapType: 'x mandatory', outline: 'none', pointerEvents: 'auto',
  padding: '12px max(16px, calc(50% - 150px))',
  display: 'flex', flexDirection: 'row', gap: 14, alignItems: 'center',
}
const cardSlotWide: React.CSSProperties = {
  scrollSnapAlign: 'center', flex: '0 0 auto', height: 158,
  transformStyle: 'preserve-3d', willChange: 'transform, opacity',
  transition: 'opacity 0.12s linear',
}
const cardSlotNarrow: React.CSSProperties = {
  scrollSnapAlign: 'center', flex: '0 0 min(300px, 82vw)', height: 152,
  transformStyle: 'preserve-3d', willChange: 'transform, opacity',
}
const flipInner: React.CSSProperties = {
  position: 'relative', width: '100%', height: '100%',
  transformStyle: 'preserve-3d', transition: 'transform 0.5s cubic-bezier(0.4,0.15,0.2,1)',
}
const cardFace: React.CSSProperties = {
  position: 'absolute', inset: 0, backfaceVisibility: 'hidden',
  padding: 12, borderRadius: 12,
  background: 'var(--color-white)', border: '1px solid var(--color-light-gray)',
  boxShadow: '0 4px 14px rgba(0,0,0,0.12)', cursor: 'pointer', textAlign: 'left',
}
const cardFront: React.CSSProperties = {
  display: 'flex', flexDirection: 'column', gap: 6,
}
const cardFocused: React.CSSProperties = {
  border: '1.5px solid var(--color-gold)', boxShadow: '0 8px 24px rgba(27,42,74,0.18)',
}
const cardBack: React.CSSProperties = {
  transform: 'rotateY(180deg)', display: 'flex', flexDirection: 'column', gap: 4,
  cursor: 'default', background: 'var(--color-cream)',
}
const addressStyle: React.CSSProperties = {
  flex: 1, minWidth: 0, fontFamily: 'Georgia, serif', fontWeight: 600, fontSize: 15,
  color: 'var(--color-navy)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
}
const cityStyle: React.CSSProperties = { fontSize: 11, color: 'var(--color-bronze)', marginTop: -2 }
const pirPill: React.CSSProperties = {
  alignSelf: 'flex-start', fontSize: 11, fontWeight: 700, color: '#5c4a1f',
  background: 'rgba(201,168,76,0.22)', border: '1px solid rgba(201,168,76,0.55)',
  padding: '2px 8px', borderRadius: 999,
}
const floodFlag: React.CSSProperties = {
  display: 'flex', alignItems: 'center', gap: 6, fontSize: 12,
  padding: '6px 9px', borderRadius: 8, letterSpacing: '0.01em',
}
const metaRow: React.CSSProperties = {
  display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 8, marginTop: 'auto',
}
const valueStyle: React.CSSProperties = {
  fontSize: 16, fontWeight: 700, color: 'var(--color-ink)', fontFamily: 'Georgia, serif',
}
const metaStyle: React.CSSProperties = { fontSize: 11, color: 'var(--color-sage)' }
const flipHint: React.CSSProperties = {
  flexShrink: 0, width: 22, height: 22, borderRadius: '50%',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  background: 'var(--color-light-gray)', color: 'var(--color-bronze)', fontSize: 13,
}
const backTitle: React.CSSProperties = {
  fontFamily: 'Georgia, serif', fontWeight: 600, fontSize: 12, color: 'var(--color-navy)',
  marginBottom: 4, textTransform: 'uppercase', letterSpacing: '0.04em',
}
const backFlipBtn: React.CSSProperties = {
  alignSelf: 'flex-start', marginTop: 2, background: 'transparent', border: 'none',
  color: 'var(--color-bronze)', fontSize: 11, cursor: 'pointer', padding: 0,
}
