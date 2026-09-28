'use client'

import { useEffect, useState } from 'react'
import { countyDisplay, type Geo } from '@/lib/geo-display'

// An approved agent's editor (work order 712). Every "show on my page" switch starts off; the schema
// defaults them off too. The register's brokerage is shown read-only: a different one can be declared,
// and the page shows it beside the register's, never instead of it.

type Prof = Record<string, unknown>
function Switch({ on, set }: { on: boolean; set: (v: boolean) => void }) {
  return <label className="reg-tick" style={{ marginTop: 4 }}><input type="checkbox" checked={on} onChange={e => set(e.target.checked)} /> Show on my page</label>
}

export default function AgentProfileForm({ slug, initial, registerBrokerage, vocab }: {
  slug: string; initial: Prof; registerBrokerage: string | null; vocab: { code: string; label: string }[]
}) {
  const str = (k: string) => (typeof initial[k] === 'string' ? (initial[k] as string) : '')
  const arr = (k: string) => (Array.isArray(initial[k]) ? (initial[k] as string[]) : [])
  const [p, setP] = useState({
    public_phone: str('public_phone'), public_email: str('public_email'), website: str('website'), bio: str('bio'),
    counties_served: arr('counties_served'), property_classes: arr('property_classes'), declared_brokerage: str('declared_brokerage'),
    publish_phone: !!initial.publish_phone, publish_email: !!initial.publish_email, publish_website: !!initial.publish_website,
    publish_bio: !!initial.publish_bio, publish_counties: !!initial.publish_counties, publish_classes: !!initial.publish_classes,
    publish_declared_brokerage: !!initial.publish_declared_brokerage,
  })
  const set = <K extends keyof typeof p>(k: K, v: (typeof p)[K]) => setP(x => ({ ...x, [k]: v }))
  const [counties, setCounties] = useState<Geo[]>([])
  const [names, setNames] = useState<Record<string, string>>({})
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    fetch('/api/geo?state=US-12').then(r => r.json()).then((c: Geo[]) => {
      setCounties(c)
      setNames(n => ({ ...n, ...Object.fromEntries(c.map(g => [g.geo_id, `${countyDisplay(g.name, g.level_type)}, FL`])) }))
    }).catch(() => {})
    const saved = Array.isArray(initial.counties_served) ? (initial.counties_served as string[]) : []
    if (saved.length) fetch(`/api/geo?ids=${saved.join(',')}`).then(r => r.json()).then((c: Geo[]) =>
      setNames(n => ({ ...n, ...Object.fromEntries(c.map(g => [g.geo_id, `${countyDisplay(g.name, g.level_type)}, ${g.admin1_abbr}`])) }))).catch(() => {})
  }, [initial])

  async function save() {
    setBusy(true); setMsg(null)
    try {
      const r = await fetch('/api/agent-profile', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ slug, ...p }) })
      const j = await r.json()
      setMsg(j.saved ? { ok: true, text: 'Saved. Your page is updated.' }
        : j.reason === 'language' ? { ok: false, text: `Not saved: that wording can't be published on your page. Please change your ${String(j.field).replace(/_/g, ' ')}.` }
        : { ok: false, text: j.field ? `Not saved. Please check your ${String(j.field).replace(/_/g, ' ')}.` : 'Not saved. Please sign in again with the email on your approved claim.' })
    } catch { setMsg({ ok: false, text: 'Not saved: network error.' }) } finally { setBusy(false) }
  }

  return (
    <div className="reg-card" style={{ display: 'grid', gap: 14 }}>
      <div className="reg-row">
        <div><label className="finder-label" htmlFor="ap-phone">Phone</label>
          <input id="ap-phone" className="finder-input" maxLength={40} value={p.public_phone} onChange={e => set('public_phone', e.target.value)} />
          <Switch on={p.publish_phone} set={v => set('publish_phone', v)} /></div>
        <div><label className="finder-label" htmlFor="ap-email">Email</label>
          <input id="ap-email" type="email" className="finder-input" maxLength={254} value={p.public_email} onChange={e => set('public_email', e.target.value)} />
          <Switch on={p.publish_email} set={v => set('publish_email', v)} /></div>
      </div>
      <div><label className="finder-label" htmlFor="ap-web">Website</label>
        <input id="ap-web" className="finder-input" maxLength={300} value={p.website} onChange={e => set('website', e.target.value)} />
        <Switch on={p.publish_website} set={v => set('publish_website', v)} /></div>
      <div><label className="finder-label" htmlFor="ap-bio">A short bio <span className="reg-opt">(800 characters)</span></label>
        <textarea id="ap-bio" rows={4} maxLength={800} className="finder-input" value={p.bio} onChange={e => set('bio', e.target.value)} />
        <Switch on={p.publish_bio} set={v => set('publish_bio', v)} /></div>
      <fieldset className="reg-fieldset"><legend className="finder-label">Property you work</legend>
        <div style={{ display: 'flex', gap: 14, flexWrap: 'wrap', fontSize: 13 }}>
          {vocab.map(v => (
            <label key={v.code}><input type="checkbox" checked={p.property_classes.includes(v.code)}
              onChange={e => set('property_classes', e.target.checked ? [...p.property_classes, v.code] : p.property_classes.filter(x => x !== v.code))} /> {v.label}</label>
          ))}
        </div>
        <Switch on={p.publish_classes} set={v => set('publish_classes', v)} />
      </fieldset>
      <fieldset className="reg-fieldset"><legend className="finder-label">Counties you serve</legend>
        <select className="finder-input" value="" aria-label="Add a county"
          onChange={e => { const v = e.target.value; if (v && !p.counties_served.includes(v) && p.counties_served.length < 67) set('counties_served', [...p.counties_served, v]) }}>
          <option value="">Add a Florida county…</option>
          {counties.map(c => <option key={c.geo_id} value={c.geo_id}>{countyDisplay(c.name, c.level_type)}</option>)}
        </select>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
          {p.counties_served.map(id => (
            <button key={id} type="button" className="reg-link" onClick={() => set('counties_served', p.counties_served.filter(x => x !== id))}>{names[id] ?? id} &times;</button>
          ))}
        </div>
        <Switch on={p.publish_counties} set={v => set('publish_counties', v)} />
      </fieldset>
      <div><label className="finder-label" htmlFor="ap-brk">Brokerage</label>
        <p className="reg-p" style={{ margin: '4px 0' }}>
          The state file shows: <b>{registerBrokerage ?? 'no brokerage recorded'}</b>. That always appears on your page. If you have moved,
          say so here; it is shown beside the state&rsquo;s, labelled as yours.
        </p>
        <input id="ap-brk" className="finder-input" maxLength={200} value={p.declared_brokerage} onChange={e => set('declared_brokerage', e.target.value)} />
        <Switch on={p.publish_declared_brokerage} set={v => set('publish_declared_brokerage', v)} /></div>
      <button type="button" className="finder-btn" onClick={save} disabled={busy}
        style={msg?.ok && !busy ? { background: '#1f5f3a' } : undefined}>{busy ? 'Saving…' : msg?.ok ? 'Saved ✓' : 'Save'}</button>
      {msg && <p role={msg.ok ? 'status' : 'alert'} style={{ margin: 0, fontSize: 13, color: msg.ok ? '#1f5f3a' : '#a8332b' }}>
        {msg.text} {msg.ok && <a href={`/a/${slug}`} style={{ color: '#1f5f3a' }}>View your page</a>}</p>}
    </div>
  )
}
