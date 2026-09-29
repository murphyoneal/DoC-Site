'use client'

import { useState } from 'react'

// The owner's own photos, with where each one stands and a way to remove it (ruling 762 part 4: delete
// ships with the cap, so a full listing is never stuck with work the owner is not proud of).
export type OwnPhoto = { id: string; thumb: string | null; visibility: string; created_at: string }

const STATE: Record<string, string> = {
  pending_scan: 'Waiting to be checked',
  pending_review: 'Waiting for review',
  held: 'Held for review',
  public: 'Approved',
}

export default function PhotoList({ slug, photos, limit }: { slug: string; photos: OwnPhoto[]; limit: number }) {
  const [list, setList] = useState(photos)
  const [busy, setBusy] = useState<string | null>(null)
  const [msg, setMsg] = useState<string | null>(null)

  async function remove(id: string) {
    setBusy(id); setMsg(null)
    try {
      const r = await fetch('/api/work/withdraw', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ slug, contribution_id: id }) })
      const j = await r.json().catch(() => ({}))
      if (j.ok) { setList(l => l.filter(p => p.id !== id)); setMsg('Removed. That space is free again.') }
      else setMsg(j.error ?? 'The photo could not be removed.')
    } catch { setMsg('Could not reach us. Try again.') } finally { setBusy(null) }
  }

  return (
    <div style={{ display: 'grid', gap: 10, marginBottom: 18 }}>
      <b style={{ fontSize: '0.9rem', color: 'var(--color-navy)' }}>Your photos: {list.length} of {limit}</b>
      {list.length === 0 && <p style={{ margin: 0, fontSize: '0.84rem', color: 'var(--color-sage)' }}>No photos yet.</p>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))', gap: 10 }}>
        {list.map(p => (
          <div key={p.id} style={{ border: '1px solid #e2ddd6', borderRadius: 10, overflow: 'hidden', background: '#fff' }}>
            {p.thumb ? <img src={p.thumb} alt="" style={{ width: '100%', height: 110, objectFit: 'cover', display: 'block' }} />
              : <div style={{ height: 110, display: 'grid', placeItems: 'center', fontSize: 11, color: 'var(--color-sage)' }}>No preview</div>}
            <div style={{ padding: '6px 8px', display: 'grid', gap: 4 }}>
              <span style={{ fontSize: 12 }}>{STATE[p.visibility] ?? p.visibility}</span>
              <button type="button" className="reg-link" style={{ justifySelf: 'start', fontSize: 12 }} disabled={busy === p.id} onClick={() => remove(p.id)}>
                {busy === p.id ? 'Removing…' : 'Remove'}
              </button>
            </div>
          </div>
        ))}
      </div>
      {msg && <p style={{ margin: 0, fontSize: 13 }}>{msg}</p>}
    </div>
  )
}
