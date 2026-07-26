'use client'

import { useState } from 'react'

// Agent claim surface (items 51 + 59). Two steps: verify a FL real-estate licence, then paste the
// addresses you personally represented — we resolve each to a Volusia parcel + its last recorded sale,
// and you confirm the ones that are yours. No file/MLS upload: an MLS export is a licensed compilation;
// a firsthand list of your own deals is yours to share.

interface PreviewRow {
  input: string; matched: boolean; parcel_id: string | null; address: string | null; city: string | null
  latest_sale: { date: string; price: number | null; instrument: string | null; instr_no: string | null } | null
}
const usd = (n?: number | null) => n == null ? '—' : `$${Math.round(n).toLocaleString('en-US')}`

export default function AgentClaims({ initialName, initialLicense, initialVerified }: {
  userEmail: string; initialName: string; initialLicense: string; initialVerified: boolean
}) {
  const [verified, setVerified] = useState(initialVerified)
  const [name, setName] = useState(initialName)
  const [license, setLicense] = useState(initialLicense)
  const [verifyNote, setVerifyNote] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const [paste, setPaste] = useState('')
  const [rows, setRows] = useState<PreviewRow[] | null>(null)
  const [checked, setChecked] = useState<Record<string, boolean>>({})
  const [confirmMsg, setConfirmMsg] = useState<string | null>(null)

  async function verify() {
    if (busy) return
    setBusy(true); setError(null); setVerifyNote(null)
    try {
      const res = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'verify', license: license.trim(), name: name.trim() }) })
      const j = await res.json()
      if (!res.ok) { setError(j.error ?? 'Verification failed'); return }
      setVerifyNote(j.note ?? null)
      if (j.verified) setVerified(true)
    } catch { setError('Network error.') } finally { setBusy(false) }
  }

  async function preview() {
    if (busy) return
    setBusy(true); setError(null); setConfirmMsg(null)
    try {
      const res = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'preview', addresses: paste }) })
      const j = await res.json()
      if (!res.ok) { setError(j.error ?? 'Lookup failed'); return }
      const r: PreviewRow[] = j.results ?? []
      setRows(r)
      // pre-check every matched row
      const init: Record<string, boolean> = {}
      r.forEach(row => { if (row.matched && row.parcel_id) init[row.parcel_id] = true })
      setChecked(init)
    } catch { setError('Network error.') } finally { setBusy(false) }
  }

  async function confirm() {
    if (busy) return
    const ids = Object.entries(checked).filter(([, v]) => v).map(([k]) => k)
    if (!ids.length) { setError('Select at least one property to claim.'); return }
    setBusy(true); setError(null)
    try {
      const res = await fetch('/api/agent', { method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'confirm', parcel_ids: ids }) })
      const j = await res.json()
      if (!res.ok || j.ok === false) { setError(j.message ?? j.error ?? 'Could not save claims'); return }
      setConfirmMsg(`${j.inserted} propert${j.inserted === 1 ? 'y' : 'ies'} claimed. They now carry you as the sales agent.`)
      setRows(null); setPaste(''); setChecked({})
    } catch { setError('Network error.') } finally { setBusy(false) }
  }

  const box: React.CSSProperties = { maxWidth: 760, margin: '0 auto', width: '100%', padding: 20 }
  const input: React.CSSProperties = { fontSize: 14, padding: '9px 11px', borderRadius: 8, border: '1px solid var(--color-light-gray)', outline: 'none', width: '100%', boxSizing: 'border-box' }
  const btn: React.CSSProperties = { padding: '9px 18px', borderRadius: 9, border: 'none', background: 'var(--color-navy)', color: '#fff', fontSize: 14, fontWeight: 600, cursor: busy ? 'wait' : 'pointer', opacity: busy ? 0.6 : 1 }

  return (
    <div style={box}>
      <h2 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: 20, margin: '0 0 4px' }}>Claim your properties</h2>
      <p style={{ fontSize: 13, color: 'var(--color-sage)', marginTop: 0 }}>
        Add yourself as the sales agent on Volusia properties you personally represented. Your firsthand list —
        not a file or MLS export.
      </p>

      {!verified ? (
        <div style={{ marginTop: 16, padding: 16, border: '1px solid var(--color-light-gray)', borderRadius: 12 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-navy)', marginBottom: 10 }}>Step 1 — Verify your Florida real-estate licence</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <label style={{ fontSize: 12, color: 'var(--color-sage)' }}>Name (as it appears on the licence)
              <input value={name} onChange={e => setName(e.target.value)} style={{ ...input, marginTop: 4 }} placeholder="Jane Q Agent" /></label>
            <label style={{ fontSize: 12, color: 'var(--color-sage)' }}>DBPR licence number
              <input value={license} onChange={e => setLicense(e.target.value)} style={{ ...input, marginTop: 4 }} placeholder="e.g. 3012345" /></label>
            <button onClick={verify} disabled={busy || !name.trim() || !license.trim()} style={btn}>Verify licence</button>
            {verifyNote && <div style={{ fontSize: 12.5, color: 'var(--color-ink)' }}>{verifyNote}</div>}
          </div>
        </div>
      ) : (
        <div style={{ marginTop: 16 }}>
          <div style={{ fontSize: 12.5, color: '#3f5a3f', background: '#e4efe4', padding: '6px 12px', borderRadius: 8, display: 'inline-block' }}>
            ✓ Licence verified{name ? ` — ${name}` : ''}
          </div>

          <div style={{ marginTop: 16, padding: 16, border: '1px solid var(--color-light-gray)', borderRadius: 12 }}>
            <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--color-navy)', marginBottom: 6 }}>Step 2 — Paste the addresses you represented</div>
            <div style={{ fontSize: 12, color: 'var(--color-sage)', marginBottom: 8 }}>One address per line (Volusia County). We resolve each to the county parcel and its last recorded sale — you confirm.</div>
            <textarea value={paste} onChange={e => setPaste(e.target.value)} rows={6} style={{ ...input, resize: 'vertical', fontFamily: 'inherit' }}
              placeholder={'128 Logenberry Ct, Daytona Beach\n214 Wellington, Port Orange'} />
            <button onClick={preview} disabled={busy || !paste.trim()} style={{ ...btn, marginTop: 10 }}>Look up</button>
          </div>

          {rows && (
            <div style={{ marginTop: 16 }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
                <thead><tr>{['', 'You pasted', 'Resolved parcel', 'Last recorded sale'].map(h =>
                  <th key={h} style={{ textAlign: 'left', padding: '6px 8px', borderBottom: '2px solid var(--color-light-gray)', fontSize: 11, color: 'var(--color-sage)', textTransform: 'uppercase' }}>{h}</th>)}</tr></thead>
                <tbody>
                  {rows.map((r, i) => (
                    <tr key={i} style={{ opacity: r.matched ? 1 : 0.55 }}>
                      <td style={{ padding: '6px 8px', borderBottom: '1px solid var(--color-light-gray)' }}>
                        {r.matched && r.parcel_id
                          ? <input type="checkbox" checked={!!checked[r.parcel_id]} onChange={e => setChecked(c => ({ ...c, [r.parcel_id!]: e.target.checked }))} />
                          : <span title="No Volusia parcel matched this line" style={{ color: '#8a4a17' }}>—</span>}
                      </td>
                      <td style={{ padding: '6px 8px', borderBottom: '1px solid var(--color-light-gray)' }}>{r.input}</td>
                      <td style={{ padding: '6px 8px', borderBottom: '1px solid var(--color-light-gray)' }}>
                        {r.matched ? <>{r.address}{r.city ? <span style={{ color: 'var(--color-sage)' }}> · {r.city}</span> : null}<br /><span style={{ fontSize: 11, color: 'var(--color-sage)' }}>parcel {r.parcel_id}</span></> : <span style={{ color: '#8a4a17' }}>not found in Volusia</span>}
                      </td>
                      <td style={{ padding: '6px 8px', borderBottom: '1px solid var(--color-light-gray)' }}>
                        {r.latest_sale ? <>{r.latest_sale.date} · {usd(r.latest_sale.price)}<br /><span style={{ fontSize: 11, color: 'var(--color-sage)' }}>{r.latest_sale.instrument} {r.latest_sale.instr_no}</span></> : <span style={{ color: 'var(--color-sage)' }}>none on file</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <button onClick={confirm} disabled={busy} style={{ ...btn, marginTop: 12 }}>Confirm selected as mine</button>
            </div>
          )}

          {confirmMsg && <div style={{ marginTop: 14, fontSize: 13.5, color: '#3f5a3f', background: '#e4efe4', padding: '8px 12px', borderRadius: 8 }}>{confirmMsg}</div>}
        </div>
      )}

      {error && <div style={{ marginTop: 12, fontSize: 13, color: '#8a2a1f', background: '#fdecea', padding: '6px 12px', borderRadius: 8 }}>{error}</div>}
    </div>
  )
}
