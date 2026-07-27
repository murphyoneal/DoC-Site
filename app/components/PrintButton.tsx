'use client'

import { useEffect, useState, useCallback } from 'react'

// Print gate. The report's maps are WebGL and bake themselves into a static
// <img> once rendered (see PropertyReportMap), flagging their container
// data-map-ready. If the user prints before that happens, the print-media swap
// has no image to show and the maps come out blank. So this button waits for
// every map to report ready (true OR error) before calling window.print().

function mapsPending(): boolean {
  const maps = Array.from(document.querySelectorAll('.pir-map-live'))
  return maps.some(m => !m.getAttribute('data-map-ready'))
}

export default function PrintButton() {
  const [ready, setReady] = useState(false)
  const [preparing, setPreparing] = useState(false)

  // Passively track readiness so the label reflects state before any click.
  useEffect(() => {
    const check = () => setReady(!mapsPending())
    check()
    const id = setInterval(check, 400)
    return () => clearInterval(id)
  }, [])

  const handlePrint = useCallback(async () => {
    if (!mapsPending()) { window.print(); return }
    // Clicked early — wait for the maps to finish baking, then print anyway
    // after a safety timeout so the button can never get stuck.
    setPreparing(true)
    const start = Date.now()
    await new Promise<void>(resolve => {
      const tick = () => {
        if (!mapsPending() || Date.now() - start > 20000) return resolve()
        setTimeout(tick, 300)
      }
      tick()
    })
    setPreparing(false)
    window.print()
  }, [])

  const label = preparing ? 'Preparing maps…' : ready ? '↓ Print / Save PDF' : '↓ Print / Save PDF (maps rendering…)'

  return (
    <button
      onClick={handlePrint}
      disabled={preparing}
      title={ready ? 'Print or save as PDF' : 'Maps are still rendering — printing will wait for them'}
      style={{
        padding: '8px 16px', borderRadius: 8, border: '1px solid var(--color-navy)',
        background: preparing ? 'var(--color-sage)' : 'var(--color-navy)', color: '#fff',
        fontSize: 13, fontWeight: 600, cursor: preparing ? 'wait' : 'pointer', opacity: ready || preparing ? 1 : 0.85,
      }}
    >
      {label}
    </button>
  )
}
