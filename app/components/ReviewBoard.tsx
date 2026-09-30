'use client'

import { useState } from 'react'

// The review page's working surface (ruling 762 part 5). Each action posts with a typed basis - why we are
// entitled to act - which the database requires and records. Unpublish, never edit. Held and unchecked
// photos are blurred until clicked, so a person is not shown an unfiltered image by surprise.

type Flag = { id: number; table: string; key: string; field: string; text: string; rules: string[]; slug: string | null; business_id: string | null }
type Photo = { id: string; visibility: string; created_at: string; description: string | null; held_path: string | null; slug: string | null; name: string | null; unchecked: boolean; scans: { slot: string; state: string; provider: string }[] | null; thumb?: string | null }
type Profile = { business_id: string; slug: string; name: string; updated_at: string; description?: string; specialties?: string[]; other_specialties?: string; website?: string; logo_path?: string; suspended: boolean; logo?: string | null }
type Claim = { id: string; kind: string; licence?: string; name?: string; email?: string; match?: string; slug?: string; at: string; duplicate?: string }
type Suspended = { business_id: string; slug: string; name: string; appeals: { explanation: string; from: string; at: string }[] | null }
export type Queue = { flags: Flag[]; photos: Photo[]; profiles: Profile[]; claims: Claim[]; registrations: Claim[]; suspended: Suspended[]; volume: { uploads_24h: number; limit: number; warn_at: number } | null }

// Fields operator_unpublish_field can switch off. Anything else (insurance lines, agent and registration text) is not offered.
const SWITCHABLE = ['description', 'other_specialties', 'specialties', 'website', 'phone', 'email', 'coverage', 'years', 'logo']

const card = { border: '1px solid #e2ddd6', borderRadius: 10, padding: 12, background: '#fff', display: 'grid', gap: 8 } as const
const h2 = { fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.05rem', margin: '22px 0 8px' } as const

// Same floor as _operator_check and set_business_suspension (162a). The database is the authority; this only
// says so before the round trip.
const MIN_BASIS = 10
type Result = { ok: boolean; message: string }

// Every click says what happened, where the click was (786). The button is never silently disabled: a
// basis that is too short gets a sentence, a refusal keeps the box open with the reason so it can be fixed.
function Act({ label, danger, onRun }: { label: string; danger?: boolean; onRun: (basis: string) => Promise<Result> }) {
  const [basis, setBasis] = useState('')
  const [open, setOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const [done, setDone] = useState<string | null>(null)
  const [refusal, setRefusal] = useState<string | null>(null)
  if (done) return <span style={{ fontSize: 12 }}>{done}</span>
  if (!open) return <button type="button" className="reg-link" style={{ fontSize: 12, color: danger ? '#a8332b' : undefined }} onClick={() => setOpen(true)}>{label}</button>
  const run = async () => {
    if (busy) return
    if (basis.trim().length < MIN_BASIS) { setRefusal(`Not done: write the reason in at least ${MIN_BASIS} characters - it is recorded and shown on appeal.`); return }
    setBusy(true); setRefusal(null)
    try { const r = await onRun(basis); if (r.ok) setDone(r.message); else setRefusal(r.message) } finally { setBusy(false) }
  }
  return (
    <span style={{ display: 'inline-flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
      <input className="finder-input" style={{ fontSize: 12, padding: '4px 6px', minWidth: 220 }} aria-label="Why this is the right call - recorded and shown on appeal"
        placeholder="Why this is the right call - recorded and shown on appeal" value={basis} autoFocus
        onChange={e => { setBasis(e.target.value); setRefusal(null) }} onKeyDown={e => { if (e.key === 'Enter') run() }} />
      <button type="button" className="finder-btn" style={{ fontSize: 12, padding: '4px 10px' }} aria-busy={busy} onClick={run}>{busy ? '…' : label}</button>
      <button type="button" className="reg-link" style={{ fontSize: 12 }} onClick={() => { setOpen(false); setRefusal(null) }}>Cancel</button>
      {refusal && <span role="alert" style={{ fontSize: 12, color: '#a8332b', flexBasis: '100%' }}>{refusal}</span>}
    </span>
  )
}

async function post(url: string, body: object): Promise<Result> {
  try {
    const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })
    const j = await r.json().catch(() => ({}))
    return j.ok ? { ok: true, message: 'Done - recorded.' } : { ok: false, message: `Not done: ${j.error ?? `the server answered ${r.status}`}` }
  } catch { return { ok: false, message: 'Not done: could not reach the server.' } }
}
const act = (body: object) => (basis: string) => post('/api/review/action', { ...body, basis })
const suspend = (slug: string, action: 'suspend' | 'reinstate') => (basis: string) => post('/api/admin/suspension', { slug, action, basis })

function Thumb({ src, blur }: { src: string | null | undefined; blur: boolean }) {
  const [shown, setShown] = useState(!blur)
  if (!src) return <div style={{ width: 160, height: 120, display: 'grid', placeItems: 'center', fontSize: 11, background: '#f4f1ec' }}>No preview</div>
  return (
    <button type="button" onClick={() => setShown(true)} style={{ padding: 0, border: 0, background: 'none', cursor: shown ? 'default' : 'pointer' }} title={shown ? '' : 'Click to show'}>
      <img src={src} alt="" style={{ width: 160, height: 120, objectFit: 'cover', display: 'block', borderRadius: 6, filter: shown ? 'none' : 'blur(14px)' }} />
    </button>
  )
}

export default function ReviewBoard({ queue: q }: { queue: Queue }) {
  const empty = !q.flags.length && !q.photos.length && !q.claims.length && !q.registrations.length && !q.suspended.length
  return (
    <div>
      {q.volume && (
        <p style={{ fontSize: 13, margin: 0, color: q.volume.uploads_24h >= q.volume.warn_at ? '#a8332b' : 'var(--color-sage)' }}>
          {q.volume.uploads_24h} photo upload{q.volume.uploads_24h === 1 ? '' : 's'} in the last 24 hours. One person can review about {q.volume.limit} a day; past that, this design needs rethinking.
        </p>
      )}
      {empty && <p style={{ fontSize: 14 }}>Nothing is waiting for review.</p>}

      {q.flags.length > 0 && <>
        <h2 style={h2}>Language flags ({q.flags.length})</h2>
        {q.flags.map(f => (
          <div key={f.id} style={{ ...card, borderColor: '#e0b4a8' }}>
            <div style={{ fontSize: 13 }}><b>{f.field}</b> on {f.slug ? <a href={f.table === 'agent_public_profile' ? `/a/${f.slug}` : `/c/${f.slug}`} target="_blank" rel="noreferrer">{f.slug}</a> : f.table}: &ldquo;{f.text}&rdquo; <span style={{ color: 'var(--color-sage)' }}>({f.rules.join(', ')})</span></div>
            <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
              <Act label="Looks fine" onRun={act({ type: 'flag_ok', flag_id: f.id })} />
              {f.business_id && SWITCHABLE.includes(f.field)
                ? <Act label="Switch this field off" danger onRun={act({ type: 'field_unpublish', business_id: f.business_id, field: f.field, flag_id: f.id })} />
                : <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>No switch-off for this field here yet</span>}
            </div>
          </div>
        ))}
      </>}

      {q.photos.length > 0 && <>
        <h2 style={h2}>Photos waiting ({q.photos.length})</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))', gap: 10 }}>
          {q.photos.map(p => (
            <div key={p.id} style={card}>
              <Thumb src={p.thumb} blur={p.visibility === 'held' || p.unchecked} />
              <div style={{ fontSize: 12 }}>
                {p.slug ? <a href={`/c/${p.slug}`} target="_blank" rel="noreferrer">{p.name ?? p.slug}</a> : 'Unknown business'}
                {' · '}{p.visibility === 'held' ? 'held' : p.unchecked ? 'unchecked (no automatic check ran)' : 'passed the automatic check'}
                {p.description ? <div style={{ color: 'var(--color-sage)' }}>{p.description}</div> : null}
              </div>
              <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap' }}>
                <Act label="Approve - make public" onRun={act({ type: 'photo_approve', contribution_id: p.id })} />
                {p.visibility !== 'held' && <Act label="Hold" danger onRun={act({ type: 'photo_reject', contribution_id: p.id })} />}
              </div>
            </div>
          ))}
        </div>
      </>}

      {(q.claims.length > 0 || q.registrations.length > 0) && <>
        <h2 style={h2}>Claims and registrations ({q.claims.length + q.registrations.length})</h2>
        {[...q.claims, ...q.registrations].map(c => (
          <div key={c.kind + c.id} style={card}>
            <div style={{ fontSize: 13 }}>
              <b>{c.kind === 'registration' ? 'Registration' : c.kind === 'agent_claim' ? 'Agent claim' : 'Contractor claim'}</b>: {c.name} &lt;{c.email}&gt;
              {c.licence ? ` · licence ${c.licence}` : ''}{c.match ? ` · ${c.match}` : ''}{c.duplicate ? ` · Florida duplicate check: ${c.duplicate}` : ''}
              {c.slug ? <> · <a href={c.kind === 'registration' ? `/r/${c.slug}` : `/c/${c.slug}`} target="_blank" rel="noreferrer">{c.slug}</a></> : null}
            </div>
            <div style={{ display: 'flex', gap: 14 }}>
              <Act label="Approve" onRun={act({ type: 'review', kind: c.kind, id: c.id, decision: 'approved' })} />
              <Act label="Reject" danger onRun={act({ type: 'review', kind: c.kind, id: c.id, decision: 'rejected' })} />
            </div>
          </div>
        ))}
      </>}

      {q.profiles.length > 0 && <>
        <h2 style={h2}>Recently saved profiles ({q.profiles.length})</h2>
        {q.profiles.map(p => (
          <div key={p.business_id} style={card}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              {p.logo ? <img src={p.logo} alt="" style={{ width: 48, height: 48, objectFit: 'contain', border: '1px solid #eee' }} /> : null}
              <a href={`/c/${p.slug}`} target="_blank" rel="noreferrer"><b>{p.name}</b></a>
              {p.suspended ? <span style={{ fontSize: 12, color: '#a8332b' }}>suspended</span> : null}
            </div>
            {p.description && <div style={{ fontSize: 13 }}>&ldquo;{p.description}&rdquo; <Act label="Switch off" danger onRun={act({ type: 'field_unpublish', business_id: p.business_id, field: 'description' })} /></div>}
            {(p.specialties?.length || p.other_specialties) && <div style={{ fontSize: 13 }}>Services: {[...(p.specialties ?? []), p.other_specialties].filter(Boolean).join(', ')} <Act label="Switch off" danger onRun={act({ type: 'field_unpublish', business_id: p.business_id, field: 'specialties' })} /></div>}
            {p.website && <div style={{ fontSize: 13 }}>Website: {p.website} <Act label="Switch off" danger onRun={act({ type: 'field_unpublish', business_id: p.business_id, field: 'website' })} /></div>}
            {p.logo && <div style={{ fontSize: 13 }}>Logo <Act label="Switch off" danger onRun={act({ type: 'field_unpublish', business_id: p.business_id, field: 'logo' })} /></div>}
            {!p.suspended && <div><Act label="Suspend this business" danger onRun={suspend(p.slug, 'suspend')} /></div>}
          </div>
        ))}
      </>}

      {q.suspended.length > 0 && <>
        <h2 style={h2}>Suspended ({q.suspended.length})</h2>
        {q.suspended.map(s => (
          <div key={s.business_id} style={card}>
            <b style={{ fontSize: 13 }}>{s.name}</b>
            {(s.appeals ?? []).map((a, i) => (
              <blockquote key={i} style={{ margin: 0, padding: '6px 10px', borderLeft: '3px solid #ccc', fontSize: 13, whiteSpace: 'pre-wrap' }}>
                {a.explanation}<div style={{ fontSize: 11, color: 'var(--color-sage)' }}>{a.from}, {new Date(a.at).toLocaleString()}</div>
              </blockquote>
            ))}
            <Act label="Reinstate" onRun={suspend(s.slug, 'reinstate')} />
          </div>
        ))}
      </>}
    </div>
  )
}
