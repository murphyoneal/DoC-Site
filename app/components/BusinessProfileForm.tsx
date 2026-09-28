'use client'

import { useEffect, useState } from 'react'
import type { EditorProfile, DeclaredInsurance } from '@/lib/business-profile'
import { countyDisplay, type Geo } from '@/lib/geo-display'

// The claimed business's editor (work order 712). Each field has its own "show on my profile" switch,
// and every switch starts off - the schema defaults them off too. Counties are chosen from the Census
// list, never typed.

type Ins = DeclaredInsurance & { publish: boolean }
const KIND_LABEL: Record<Ins['kind'], string> = { general_liability: 'General liability', workers_comp: "Workers' comp", other: 'Other cover' }

function Switch({ on, set, label = 'Show on my profile' }: { on: boolean; set: (v: boolean) => void; label?: string }) {
  return <label className="reg-tick" style={{ marginTop: 4 }}><input type="checkbox" checked={on} onChange={e => set(e.target.checked)} /> {label}</label>
}

export default function BusinessProfileForm({ slug, trades, initial, initialInsurance, logoPreview }: {
  slug: string; trades: [string, string][]; initial: EditorProfile | null; initialInsurance: Ins[]; logoPreview?: string | null
}) {
  const [p, setP] = useState({
    public_phone: initial?.public_phone ?? '', public_email: initial?.public_email ?? '', website: initial?.website ?? '',
    description: initial?.description ?? '', specialties: initial?.specialties ?? [], other_specialties: initial?.other_specialties ?? '',
    counties_worked: initial?.counties_worked ?? [], years_in_business: initial?.years_in_business?.toString() ?? '',
    publish_phone: !!initial?.publish_phone, publish_email: !!initial?.publish_email, publish_website: !!initial?.publish_website,
    publish_description: !!initial?.publish_description, publish_specialties: !!initial?.publish_specialties,
    publish_years: !!initial?.publish_years,
    // coverage: the business's own choice, none selected until they choose (733) - never inferred
    coverage_scope: (initial?.coverage_scope ?? '') as '' | 'nationwide' | 'statewide' | 'counties',
    coverage_state: initial?.coverage_state_geo_id ?? '',
    publish_coverage: !!initial?.publish_coverage,
    publish_logo: !!initial?.publish_logo,
  })
  const [logo, setLogo] = useState<string | null>(logoPreview ?? null)
  const [logoMsg, setLogoMsg] = useState<string | null>(null)
  const [logoBusy, setLogoBusy] = useState(false)

  async function uploadLogo(f: File) {
    setLogoBusy(true); setLogoMsg(null)
    const fd = new FormData(); fd.set('slug', slug); fd.set('file', f)
    try {
      const r = await fetch('/api/logo', { method: 'POST', body: fd })
      const j = await r.json()
      if (j.ok) { setLogo(j.preview); setLogoMsg(p.publish_logo ? 'Logo updated on your page.' : 'Logo saved. Switch it on below, then Save, to show it on your page.') }
      else setLogoMsg(j.error ?? 'The logo could not be saved.')
    } catch { setLogoMsg('The logo could not be uploaded.') } finally { setLogoBusy(false) }
  }
  async function removeLogo() {
    setLogoBusy(true)
    await fetch(`/api/logo?slug=${encodeURIComponent(slug)}`, { method: 'DELETE' }).catch(() => null)
    setLogo(null); set('publish_logo', false); setLogoMsg('Logo removed.'); setLogoBusy(false)
  }
  const [ins, setIns] = useState<Ins[]>(initialInsurance)
  const [states, setStates] = useState<Geo[]>([])
  const [st, setSt] = useState('US-12')
  const [counties, setCounties] = useState<Geo[]>([])
  const [names, setNames] = useState<Record<string, string>>({})
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null)
  const [busy, setBusy] = useState(false)
  const [saved, setSaved] = useState(false)
  const LABEL: Record<string, string> = { description: 'description', other_specialties: 'specialties', insurance: 'insurance details', counties_worked: 'counties (choose at least one)', coverage: 'where you work (choose the state)' }
  const set = <K extends keyof typeof p>(k: K, v: (typeof p)[K]) => setP(x => ({ ...x, [k]: v }))

  useEffect(() => { fetch('/api/geo/states').then(r => r.json()).then(setStates).catch(() => {}) }, [])
  // names for counties already saved, whatever state they are in
  useEffect(() => {
    if (!initial?.counties_worked?.length) return
    fetch(`/api/geo?ids=${initial.counties_worked.join(',')}`).then(r => r.json()).then((c: Geo[]) =>
      setNames(n => ({ ...n, ...Object.fromEntries(c.map(g => [g.geo_id, `${countyDisplay(g.name, g.level_type)}, ${g.admin1_abbr}`])) }))).catch(() => {})
  }, [initial])
  useEffect(() => {
    fetch(`/api/geo?state=${st}`).then(r => r.json()).then((c: Geo[]) => {
      setCounties(c)
      setNames(n => ({ ...n, ...Object.fromEntries(c.map(g => [g.geo_id, `${countyDisplay(g.name, g.level_type)}, ${g.admin1_abbr}`])) }))
    }).catch(() => {})
  }, [st])

  async function save() {
    setBusy(true); setMsg(null)
    try {
      const r = await fetch('/api/claim-profile', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ slug, ...p, insurance: ins }),
      })
      const j = await r.json()
      setSaved(!!j.saved)
      setMsg(j.saved ? { ok: true, text: 'Saved. Your page is updated.' }
        : j.reason === 'language' ? { ok: false, text: `Not saved: that wording can't be published on your page. Please change your ${LABEL[j.field] ?? j.field}.` }
        : { ok: false, text: j.field ? `Not saved. Please check your ${LABEL[j.field] ?? String(j.field).replace(/_/g, ' ')}.` : 'Not saved. Please sign in again with the email on your approved claim.' })
    } catch { setMsg({ ok: false, text: 'Not saved: network error.' }) }
    finally { setBusy(false) }
  }

  return (
    <div className="reg-card" style={{ display: 'grid', gap: 14 }}>
      <h2 className="reg-h2">Your logo</h2>
      <div style={{ display: 'flex', gap: 14, alignItems: 'center', flexWrap: 'wrap' }}>
        <div style={{ width: 88, height: 88, border: '1px solid #e2ddd6', borderRadius: 10, display: 'grid', placeItems: 'center', background: '#fff', overflow: 'hidden' }}>
          {logo ? <img src={logo} alt="Your logo" style={{ maxWidth: '100%', maxHeight: '100%' }} /> : <span style={{ fontSize: 11, color: 'var(--color-sage)' }}>No logo</span>}
        </div>
        <div style={{ display: 'grid', gap: 6 }}>
          <input type="file" accept="image/png,image/jpeg,image/webp" disabled={logoBusy}
            onChange={e => { const f = e.target.files?.[0]; if (f) uploadLogo(f); e.currentTarget.value = '' }} />
          <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>PNG, JPEG or WebP, up to 2 MB. We fit it within 512 × 512 and remove hidden data such as camera details. It shows beside your business name, never instead of it.</span>
          {logo && <button type="button" className="reg-link" style={{ justifySelf: 'start' }} onClick={removeLogo} disabled={logoBusy}>Remove logo</button>}
        </div>
      </div>
      {logoMsg && <p style={{ margin: 0, fontSize: 13 }}>{logoMsg}</p>}
      {logo && <Switch on={p.publish_logo} set={v => set('publish_logo', v)} />}

      <h2 className="reg-h2">Contact</h2>
      <div className="reg-row">
        <div><label className="finder-label" htmlFor="bp-phone">Business phone</label>
          <input id="bp-phone" className="finder-input" maxLength={40} value={p.public_phone} onChange={e => set('public_phone', e.target.value)} />
          <Switch on={p.publish_phone} set={v => set('publish_phone', v)} /></div>
        <div><label className="finder-label" htmlFor="bp-email">Business email</label>
          <input id="bp-email" type="email" className="finder-input" maxLength={254} value={p.public_email} onChange={e => set('public_email', e.target.value)} />
          <Switch on={p.publish_email} set={v => set('publish_email', v)} /></div>
      </div>
      <div><label className="finder-label" htmlFor="bp-web">Website</label>
        <input id="bp-web" className="finder-input" maxLength={300} placeholder="yourbusiness.com" value={p.website} onChange={e => set('website', e.target.value)} />
        <Switch on={p.publish_website} set={v => set('publish_website', v)} /></div>

      <h2 className="reg-h2">About the business</h2>
      <div><label className="finder-label" htmlFor="bp-desc">A short description <span className="reg-opt">(600 characters)</span></label>
        <textarea id="bp-desc" className="finder-input" rows={4} maxLength={600} value={p.description} onChange={e => set('description', e.target.value)} />
        <Switch on={p.publish_description} set={v => set('publish_description', v)} /></div>
      <div><label className="finder-label" htmlFor="bp-years">Years in business</label>
        <input id="bp-years" type="number" min={0} max={150} className="finder-input" style={{ maxWidth: 120 }} value={p.years_in_business} onChange={e => set('years_in_business', e.target.value)} />
        <Switch on={p.publish_years} set={v => set('publish_years', v)} /></div>

      <fieldset className="reg-fieldset"><legend className="finder-label">Specialties</legend>
        <div className="reg-trades">
          {trades.map(([k, label]) => (
            <label key={k}><input type="checkbox" checked={p.specialties.includes(k)}
              onChange={e => set('specialties', e.target.checked ? [...p.specialties, k] : p.specialties.filter(x => x !== k))} /> {label}</label>
          ))}
        </div>
        <input className="finder-input" maxLength={200} placeholder="Anything else (200 characters)" value={p.other_specialties} onChange={e => set('other_specialties', e.target.value)} />
        <Switch on={p.publish_specialties} set={v => set('publish_specialties', v)} />
      </fieldset>

      <fieldset className="reg-fieldset"><legend className="finder-label">Where you work</legend>
        <p style={{ margin: 0, fontSize: 12, color: 'var(--color-sage)' }}>Your own statement of where you take work. It is not read from your licence.</p>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', fontSize: 14 }}>
          {([['nationwide', 'Nationwide'], ['statewide', 'Statewide'], ['counties', 'Selected counties']] as const).map(([v, l]) => (
            <label key={v} className="reg-tick"><input type="radio" name="coverage" checked={p.coverage_scope === v} onChange={() => set('coverage_scope', v)} /> {l}</label>
          ))}
        </div>
        {p.coverage_scope === 'statewide' && (
          <select className="finder-input" value={p.coverage_state} onChange={e => set('coverage_state', e.target.value)} aria-label="State">
            <option value="">Choose the state…</option>
            {states.map(s => <option key={s.geo_id} value={s.geo_id}>{s.name}</option>)}
          </select>
        )}
        {p.coverage_scope === 'counties' && (
          <>
            <div className="reg-row">
              <select className="finder-input" value={st} onChange={e => setSt(e.target.value)} aria-label="State">
                {(states.length ? states : [{ geo_id: 'US-12', name: 'Florida', admin1_abbr: 'FL', level_type: 'state' }]).map(s => <option key={s.geo_id} value={s.geo_id}>{s.name}</option>)}
              </select>
              <select className="finder-input" value="" aria-label="Add a county"
                onChange={e => { const v = e.target.value; if (v && !p.counties_worked.includes(v) && p.counties_worked.length < 60) set('counties_worked', [...p.counties_worked, v]) }}>
                <option value="">Add a county…</option>
                {counties.map(c => <option key={c.geo_id} value={c.geo_id}>{countyDisplay(c.name, c.level_type)}</option>)}
              </select>
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
              {p.counties_worked.map(id => (
                <button key={id} type="button" className="reg-link" onClick={() => set('counties_worked', p.counties_worked.filter(x => x !== id))}>
                  {names[id] ?? id} &times;
                </button>
              ))}
            </div>
          </>
        )}
        {p.coverage_scope && <Switch on={p.publish_coverage} set={v => set('publish_coverage', v)} />}
      </fieldset>

      <h2 className="reg-h2">Insurance</h2>
      <p className="reg-p" style={{ margin: 0 }}>Shown as declared by you. We do not hold insurance records, and your profile says so beside each one.</p>
      {ins.map((x, i) => (
        <div key={i} className="reg-cred">
          <div className="reg-row">
            <select className="finder-input" value={x.kind} aria-label="Cover type"
              onChange={e => setIns(a => a.map((y, j) => j === i ? { ...y, kind: e.target.value as Ins['kind'] } : y))}>
              {Object.entries(KIND_LABEL).map(([k, l]) => <option key={k} value={k}>{l}</option>)}
            </select>
            <input className="finder-input" placeholder="Insurer" maxLength={200} value={x.carrier}
              onChange={e => setIns(a => a.map((y, j) => j === i ? { ...y, carrier: e.target.value } : y))} />
          </div>
          <div className="reg-row">
            <input className="finder-input" placeholder="Cover (optional)" maxLength={200} value={x.cover_note ?? ''}
              onChange={e => setIns(a => a.map((y, j) => j === i ? { ...y, cover_note: e.target.value } : y))} />
            <input className="finder-input" type="date" aria-label="Expires" value={x.expires_on ?? ''}
              onChange={e => setIns(a => a.map((y, j) => j === i ? { ...y, expires_on: e.target.value || null } : y))} />
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Switch on={x.publish} set={v => setIns(a => a.map((y, j) => j === i ? { ...y, publish: v } : y))} />
            <button type="button" className="reg-link" onClick={() => setIns(a => a.filter((_, j) => j !== i))}>Remove</button>
          </div>
        </div>
      ))}
      {ins.length < 10 && (
        <button type="button" className="reg-link" style={{ justifySelf: 'start' }}
          onClick={() => setIns(a => [...a, { kind: 'general_liability', carrier: '', cover_note: null, expires_on: null, publish: false }])}>+ Add insurance</button>
      )}

      <button type="button" className="finder-btn" onClick={save} disabled={busy}
        style={saved && !busy ? { background: '#1f5f3a' } : undefined}>
        {busy ? 'Saving…' : saved ? 'Saved ✓' : 'Save'}
      </button>
      {/* The confirmation sits where the click was (work order 730), not above the button. */}
      {msg && !msg.ok && <p role="alert" style={{ margin: 0, fontSize: 13, color: '#a8332b' }}>{msg.text}</p>}
      {msg?.ok && (
        <div role="status" style={{ border: '1px solid #b8d8c4', background: '#eef7f1', borderRadius: 10, padding: 14, display: 'grid', gap: 10 }}>
          <b style={{ color: '#1f5f3a' }}>{msg.text} <a href={`/c/${slug}`} style={{ color: '#1f5f3a' }}>View your page</a></b>
          {/* After save is the one moment an owner is certainly engaged (ruling 731): the print-ready
              QR, earned, and the way into the photo gallery. No price is mentioned. */}
          <div>
            <b style={{ color: 'var(--color-navy)' }}>Here is your high-resolution QR code</b>
            <p style={{ margin: '4px 0 6px', fontSize: 13 }}>Print it on your truck and cards. It opens this page, where people can visit your website or save your contact details.</p>
            <a href={`/api/qr/${slug}?size=1200&ref=download`} download={`qr-${slug}.png`} className="finder-btn" style={{ display: 'inline-block', textDecoration: 'none' }}>Download QR code</a>
          </div>
          <div>
            <b style={{ color: 'var(--color-navy)' }}>Add work you&rsquo;re proud of</b>
            <p style={{ margin: '4px 0 6px', fontSize: 13 }}>Photos of finished jobs are what people look at first.</p>
            <a href={`/claim/${slug}/photos`} className="finder-btn" style={{ display: 'inline-block', textDecoration: 'none', background: 'var(--color-bronze)' }}>Add photos</a>
          </div>
        </div>
      )}
    </div>
  )
}
