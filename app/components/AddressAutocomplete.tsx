'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter } from 'next/navigation'

type Hit = {
  co_no: number
  parcel_id: string
  phy_addr1: string
  phy_city: string | null
  label: string
  score: number
}

// Address autocomplete over our own parcel roll. Every suggestion routes to a real
// report; a non-match says so honestly rather than "not found".
export default function AddressAutocomplete({
  placeholder = 'Enter a property address…',
  autoFocus = false,
  id = 'property-address-search',
}: {
  placeholder?: string
  autoFocus?: boolean
  id?: string
}) {
  const router = useRouter()
  const [q, setQ] = useState('')
  const [hits, setHits] = useState<Hit[]>([])
  const [message, setMessage] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [open, setOpen] = useState(false)
  const [active, setActive] = useState(-1)
  const boxRef = useRef<HTMLDivElement>(null)
  const seq = useRef(0)

  // Debounced search. Each request is tagged so a slow earlier response can't
  // overwrite a newer one.
  useEffect(() => {
    const term = q.trim()
    if (term.length < 3) {
      setHits([]); setMessage(null); setLoading(false)
      return
    }
    setLoading(true)
    const id = ++seq.current
    const t = setTimeout(async () => {
      try {
        const res = await fetch(`/api/address-search?q=${encodeURIComponent(term)}`)
        const data = await res.json()
        if (id !== seq.current) return // a newer keystroke already fired
        setHits(Array.isArray(data.results) ? data.results : [])
        setMessage(data.held ? null : (data.message ?? null))
        setActive(-1)
      } catch {
        if (id === seq.current) { setHits([]); setMessage(null) }
      } finally {
        if (id === seq.current) setLoading(false)
      }
    }, 200)
    return () => clearTimeout(t)
  }, [q])

  // Close on outside click.
  useEffect(() => {
    function onDoc(e: MouseEvent) {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false)
    }
    document.addEventListener('mousedown', onDoc)
    return () => document.removeEventListener('mousedown', onDoc)
  }, [])

  function go(h: Hit) {
    router.push(`/report/${h.co_no}/${encodeURIComponent(h.parcel_id)}`)
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (!open) return
    if (e.key === 'ArrowDown') { e.preventDefault(); setActive(a => Math.min(a + 1, hits.length - 1)) }
    else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(a => Math.max(a - 1, 0)) }
    else if (e.key === 'Enter' && active >= 0 && hits[active]) { e.preventDefault(); go(hits[active]) }
    else if (e.key === 'Escape') { setOpen(false) }
  }

  const showPanel = Boolean(open && q.trim().length >= 3 && (hits.length > 0 || message || loading))

  return (
    <div ref={boxRef} style={{ position: 'relative', width: '100%' }}>
      <input
        id={id}
        type="text"
        value={q}
        autoFocus={autoFocus}
        placeholder={placeholder}
        onChange={e => { setQ(e.target.value); setOpen(true) }}
        onFocus={() => setOpen(true)}
        onKeyDown={onKeyDown}
        role="combobox"
        aria-expanded={showPanel}
        aria-autocomplete="list"
        aria-controls="address-autocomplete-list"
        className="w-full px-4 py-3 rounded-lg text-base"
        style={{ border: '1px solid var(--color-light-gray, #ddd8d0)', background: 'var(--color-white, #fff)', color: 'var(--color-ink, #2b2b2b)' }}
      />

      {showPanel && (
        <div
          id="address-autocomplete-list"
          role="listbox"
          className="absolute left-0 right-0 mt-1 rounded-lg overflow-hidden z-20"
          style={{ background: 'var(--color-white, #fff)', border: '1px solid var(--color-light-gray, #ddd8d0)', boxShadow: '0 6px 24px rgba(0,0,0,0.10)' }}
        >
          {hits.map((h, i) => (
            <button
              key={`${h.co_no}-${h.parcel_id}`}
              role="option"
              aria-selected={i === active}
              onMouseEnter={() => setActive(i)}
              onClick={() => go(h)}
              className="block w-full text-left px-4 py-2.5"
              style={{
                background: i === active ? 'var(--color-light-gray, #f3f0ea)' : 'transparent',
                borderTop: i ? '1px solid #efece5' : 'none',
              }}
            >
              <span className="text-sm font-semibold" style={{ color: 'var(--color-navy, #1f3a5f)' }}>{h.phy_addr1}</span>
              {h.phy_city && (
                <span className="text-xs ml-2" style={{ color: 'var(--color-sage, #7d8471)' }}>
                  {h.phy_city.replace(/\b\w/g, c => c.toUpperCase())}
                </span>
              )}
            </button>
          ))}

          {!loading && hits.length === 0 && message && (
            <div className="px-4 py-3 text-sm" style={{ color: 'var(--color-ink, #2b2b2b)' }}>
              <span className="font-semibold block mb-1" style={{ color: 'var(--color-bronze, #9a6a3a)' }}>
                Address not in our roll
              </span>
              {message}
            </div>
          )}

          {loading && hits.length === 0 && (
            <div className="px-4 py-3 text-sm" style={{ color: 'var(--color-sage, #7d8471)' }}>Searching…</div>
          )}
        </div>
      )}
    </div>
  )
}
