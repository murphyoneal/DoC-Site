'use client'

import { useState } from 'react'

const STATE_TEXT: Record<string, string> = {
  location_confirmed: 'The photo was taken at the address you gave.',
  location_divergent: 'The photo was taken somewhere other than the address you gave. It is still published; the difference is recorded.',
  location_not_available: 'The photo carries no location data, so it could not be matched to the address.',
  location_not_checked: 'The address could not be matched to a property, so the photo location was not checked.',
}

export default function WorkUploadForm({ slug }: { slug: string }) {
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(null)

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    setBusy(true); setResult(null)
    const fd = new FormData(e.currentTarget)
    fd.set('slug', slug)
    try {
      const res = await fetch('/api/work/upload', { method: 'POST', body: fd })
      const j = await res.json()
      if (!j.ok) setResult({ ok: false, text: j.error ?? 'Upload failed.' })
      else setResult({ ok: true, text: `Published. ${STATE_TEXT[j.location_state] ?? ''}${j.matched_address ? ` (Matched: ${j.matched_address}.)` : ''}` })
    } catch {
      setResult({ ok: false, text: 'Upload failed. Nothing was published.' })
    }
    setBusy(false)
  }

  const field = { width: '100%', padding: '9px 11px', borderRadius: '8px', border: '1px solid #cfc8bd', fontSize: '0.86rem' } as const
  return (
    <form onSubmit={submit} style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
      <label style={{ fontSize: '0.8rem' }}>Photo (JPEG, PNG or WebP, up to 4 MB)
        <input name="file" type="file" accept="image/jpeg,image/png,image/webp" required style={{ display: 'block', marginTop: 4 }} />
      </label>
      <label style={{ fontSize: '0.8rem' }}>Address of the job
        <input name="address" type="text" placeholder="e.g. 123 Main St, DeLand" style={field} />
      </label>
      <label style={{ fontSize: '0.8rem' }}>What was done (optional)
        <input name="description" type="text" maxLength={500} placeholder="e.g. Re-roof, architectural shingle" style={field} />
      </label>
      <label style={{ fontSize: '0.8rem' }}>When (optional)
        <input name="work_date" type="date" style={field} />
      </label>
      <button type="submit" disabled={busy} style={{ padding: '10px 18px', borderRadius: '8px', border: 'none', background: 'var(--color-navy)', color: 'white', fontWeight: 600 }}>
        {busy ? 'Uploading…' : 'Upload photo'}
      </button>
      {result && <p role="status" style={{ fontSize: '0.84rem', color: result.ok ? '#2d7d46' : '#8a4a17', margin: 0 }}>{result.text}</p>}
    </form>
  )
}
