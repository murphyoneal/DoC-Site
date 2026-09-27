'use client'

import { useEffect, useRef, useState } from 'react'
import type { Geo } from '@/lib/geo-display'
import { countyDisplay } from '@/lib/geo-display'
import { DOP_URL } from '@/lib/site'

// The self-registration form (work order 699). Declaration and check are separate facts: the form
// collects what the business declares, and the reply shows what we could and could not check.
// Every "show this publicly" box starts unticked; the schema defaults them off too.

type Kind = 'licence' | 'certification' | 'insurance'
type Cred = { kind: Kind; issuing_state: string; trade: string; number: string; issuer: string; expires_on: string; publish: boolean }
type Checked = { kind: Kind; number: string | null; issuing_state: string | null; check_state: string; check_note: string | null }
type Reply =
  | { outcome: 'received'; slug?: string; credentials: Checked[] | null }
  | { outcome: 'existing'; slug: string; note: string }
  | { outcome: 'invalid'; field: string; index?: number }
  | { outcome: 'error' }

const FIELD_NAMES: Record<string, string> = {
  business_name: 'business name', state: 'state', county: 'county', contact_email: 'email address', credentials: 'credentials',
}

const blank = (state: string): Cred => ({ kind: 'licence', issuing_state: state, trade: '', number: '', issuer: '', expires_on: '', publish: false })

export default function SelfRegisterForm({ states, trades }: { states: Geo[]; trades: [string, string][] }) {
  const started = useRef(Date.now())
  const [state, setState] = useState('')
  const [counties, setCounties] = useState<Geo[]>([])
  const [creds, setCreds] = useState<Cred[]>([blank('')])
  const [busy, setBusy] = useState(false)
  const [reply, setReply] = useState<Reply | null>(null)

  useEffect(() => {
    setCounties([])
    if (!state) return
    let live = true
    fetch(`/api/geo?state=${encodeURIComponent(state)}`).then(r => r.json()).then(c => { if (live) setCounties(c) }).catch(() => {})
    // a licence row nobody has touched follows the business's state
    setCreds(cs => cs.map(c => (c.kind === 'licence' && !c.number && !c.issuing_state ? { ...c, issuing_state: state } : c)))
    return () => { live = false }
  }, [state])

  const stateName = (id: string | null) => states.find(s => s.geo_id === id)?.name ?? id ?? ''

  function setCred(i: number, patch: Partial<Cred>) {
    setCreds(cs => cs.map((c, j) => (j === i ? { ...c, ...patch } : c)))
  }

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const f = new FormData(e.currentTarget)
    setBusy(true)
    setReply(null)
    try {
      const r = await fetch('/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          started_at: started.current,
          company_url: f.get('company_url'),
          business_name: f.get('business_name'),
          state, county: f.get('county'), city: f.get('city'),
          trades: f.getAll('trades'),
          other_services: f.get('other_services'),
          contact_name: f.get('contact_name'), contact_email: f.get('contact_email'),
          public_phone: f.get('public_phone'), website: f.get('website'),
          publish_listing: f.get('publish_listing') === 'on', publish_city: f.get('publish_city') === 'on',
          publish_phone: f.get('publish_phone') === 'on', publish_website: f.get('publish_website') === 'on',
          credentials: creds.filter(c => c.number.trim() || c.issuer.trim()),
        }),
      })
      setReply(await r.json())
    } catch {
      setReply({ outcome: 'error' })
    } finally {
      setBusy(false)
    }
  }

  if (reply?.outcome === 'existing') {
    return (
      <div className="reg-card">
        <h2 className="reg-h2">You are already in the Florida register</h2>
        <p className="reg-p">
          The licence you gave belongs to a business of the same name in the state licence file, so it already
          has an entry. One business, one page: claim that entry instead of registering again.
        </p>
        <p className="reg-p" style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <a className="finder-btn" href={`/claim/${reply.slug}`} style={{ textDecoration: 'none' }}>Claim your entry</a>
          <a href={`/c/${reply.slug}`} style={{ color: 'var(--color-bronze)', alignSelf: 'center' }}>See the entry first</a>
        </p>
      </div>
    )
  }

  if (reply?.outcome === 'received') {
    return (
      <div className="reg-card">
        <h2 className="reg-h2">Received. A person will review it.</h2>
        <p className="reg-p">
          Nothing is public yet. Once it has been reviewed, and only if you ticked &ldquo;list my business&rdquo;, your page will
          show the details you chose to show. Here is what you declared and what we could check:
        </p>
        {reply.credentials && reply.credentials.length > 0 ? (
          <ul className="reg-checks">
            {reply.credentials.map((c, i) => (
              <li key={i}>
                <b>{c.kind === 'licence' ? 'Licence' : c.kind === 'insurance' ? 'Insurance' : 'Certification'}{c.number ? ` ${c.number}` : ''}</b>
                {c.issuing_state ? ` (${stateName(c.issuing_state)})` : ''}: declared by you.
                <br />
                <span className={'reg-check ' + c.check_state}>{c.check_note}</span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="reg-p">You did not list any credentials. You can send them later by replying to the review email.</p>
        )}
      </div>
    )
  }

  return (
    <form onSubmit={submit} className="reg-card" style={{ display: 'grid', gap: 14 }}>
      {/* honeypot: people never see or fill this */}
      <div aria-hidden="true" style={{ position: 'absolute', left: '-10000px', width: 1, height: 1, overflow: 'hidden' }}>
        <label>Company URL <input name="company_url" tabIndex={-1} autoComplete="off" /></label>
      </div>

      <h2 className="reg-h2">The business</h2>
      <label className="finder-label" htmlFor="rb-name">Business name</label>
      <input id="rb-name" name="business_name" required minLength={2} maxLength={200} className="finder-input" autoComplete="organization" />

      <div className="reg-row">
        <div>
          <label className="finder-label" htmlFor="rb-state">State</label>
          <select id="rb-state" required value={state} onChange={e => setState(e.target.value)} className="finder-input">
            <option value="">Choose a state</option>
            {states.map(s => <option key={s.geo_id} value={s.geo_id}>{s.name}</option>)}
          </select>
        </div>
        <div>
          <label className="finder-label" htmlFor="rb-county">County <span className="reg-opt">(optional)</span></label>
          <select id="rb-county" name="county" className="finder-input" disabled={!counties.length}>
            <option value="">{state ? (counties.length ? 'Choose one' : 'Loading…') : 'Choose a state first'}</option>
            {counties.map(c => <option key={c.geo_id} value={c.geo_id}>{countyDisplay(c.name, c.level_type)}</option>)}
          </select>
        </div>
      </div>
      <label className="finder-label" htmlFor="rb-city">City or town <span className="reg-opt">(optional)</span></label>
      <input id="rb-city" name="city" maxLength={100} className="finder-input" autoComplete="address-level2" />

      <fieldset className="reg-fieldset">
        <legend className="finder-label">Trades and services</legend>
        <div className="reg-trades">
          {trades.map(([k, label]) => (
            <label key={k}><input type="checkbox" name="trades" value={k} /> {label}</label>
          ))}
        </div>
      </fieldset>
      <label className="finder-label" htmlFor="rb-other">Anything else you do <span className="reg-opt">(optional)</span></label>
      <input id="rb-other" name="other_services" maxLength={500} className="finder-input" />

      <h2 className="reg-h2">Licences, certifications and insurance</h2>
      <p className="reg-p" style={{ margin: 0 }}>
        List everything you hold, whether or not we can check it. Each one shows as declared by you, with our check beside it.
      </p>
      {creds.map((c, i) => (
        <div key={i} className="reg-cred">
          <div className="reg-row">
            <div>
              <label className="finder-label" htmlFor={`rc-kind-${i}`}>Type</label>
              <select id={`rc-kind-${i}`} value={c.kind} className="finder-input"
                onChange={e => setCred(i, { kind: e.target.value as Kind, issuing_state: e.target.value === 'licence' ? (c.issuing_state || state) : c.issuing_state })}>
                <option value="licence">State licence</option>
                <option value="certification">Certification</option>
                <option value="insurance">Insurance</option>
              </select>
            </div>
            {c.kind !== 'insurance' && (
              <div>
                <label className="finder-label" htmlFor={`rc-state-${i}`}>Issuing state{c.kind === 'certification' ? <span className="reg-opt"> (if any)</span> : null}</label>
                <select id={`rc-state-${i}`} value={c.issuing_state} required={c.kind === 'licence'} className="finder-input"
                  onChange={e => setCred(i, { issuing_state: e.target.value })}>
                  <option value="">Choose</option>
                  {states.map(s => <option key={s.geo_id} value={s.geo_id}>{s.name}</option>)}
                </select>
              </div>
            )}
          </div>
          <div className="reg-row">
            <div>
              <label className="finder-label" htmlFor={`rc-num-${i}`}>{c.kind === 'insurance' ? 'Policy number (optional)' : c.kind === 'licence' ? 'Licence number' : 'Certificate number (optional)'}</label>
              <input id={`rc-num-${i}`} value={c.number} maxLength={60} className="finder-input"
                onChange={e => setCred(i, { number: e.target.value })} />
            </div>
            <div>
              <label className="finder-label" htmlFor={`rc-trade-${i}`}>{c.kind === 'insurance' ? 'Cover (e.g. general liability)' : 'Trade it covers'}</label>
              {c.kind === 'insurance' ? (
                <input id={`rc-trade-${i}`} value={c.trade} maxLength={100} className="finder-input" onChange={e => setCred(i, { trade: e.target.value })} />
              ) : (
                <select id={`rc-trade-${i}`} value={c.trade} className="finder-input" onChange={e => setCred(i, { trade: e.target.value })}>
                  <option value="">Choose</option>
                  {trades.map(([k, label]) => <option key={k} value={k}>{label}</option>)}
                </select>
              )}
            </div>
          </div>
          {c.kind !== 'licence' && (
            <div className="reg-row">
              <div>
                <label className="finder-label" htmlFor={`rc-issuer-${i}`}>{c.kind === 'insurance' ? 'Insurer' : 'Certifying body'}</label>
                <input id={`rc-issuer-${i}`} value={c.issuer} maxLength={200} className="finder-input" onChange={e => setCred(i, { issuer: e.target.value })} />
              </div>
              <div>
                <label className="finder-label" htmlFor={`rc-exp-${i}`}>Expires <span className="reg-opt">(optional)</span></label>
                <input id={`rc-exp-${i}`} type="date" value={c.expires_on} className="finder-input" onChange={e => setCred(i, { expires_on: e.target.value })} />
              </div>
            </div>
          )}
          <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, flexWrap: 'wrap' }}>
            <label className="reg-tick"><input type="checkbox" checked={c.publish} onChange={e => setCred(i, { publish: e.target.checked })} /> Show this on my page</label>
            {creds.length > 1 && (
              <button type="button" className="reg-link" onClick={() => setCreds(cs => cs.filter((_, j) => j !== i))}>Remove</button>
            )}
          </div>
        </div>
      ))}
      {creds.length < 20 && (
        <button type="button" className="reg-link" style={{ justifySelf: 'start' }} onClick={() => setCreds(cs => [...cs, blank(state)])}>
          + Add another
        </button>
      )}

      <h2 className="reg-h2">Contact</h2>
      <div className="reg-row">
        <div>
          <label className="finder-label" htmlFor="rb-cname">Your name</label>
          <input id="rb-cname" name="contact_name" maxLength={200} className="finder-input" autoComplete="name" />
        </div>
        <div>
          <label className="finder-label" htmlFor="rb-email">Email <span className="reg-opt">(private, never shown)</span></label>
          <input id="rb-email" name="contact_email" type="email" required maxLength={254} className="finder-input" autoComplete="email" />
        </div>
      </div>
      <div className="reg-row">
        <div>
          <label className="finder-label" htmlFor="rb-phone">Business phone <span className="reg-opt">(optional)</span></label>
          <input id="rb-phone" name="public_phone" maxLength={40} className="finder-input" autoComplete="tel" />
        </div>
        <div>
          <label className="finder-label" htmlFor="rb-web">Website <span className="reg-opt">(optional)</span></label>
          <input id="rb-web" name="website" maxLength={300} className="finder-input" placeholder="yourbusiness.com" autoComplete="url" />
        </div>
      </div>

      <fieldset className="reg-fieldset">
        <legend className="finder-label">What may we show? Nothing is shown until a person has reviewed it.</legend>
        <label className="reg-tick"><input type="checkbox" name="publish_listing" /> List my business publicly: name, state, county, trades</label>
        <label className="reg-tick"><input type="checkbox" name="publish_city" /> Show my city or town</label>
        <label className="reg-tick"><input type="checkbox" name="publish_phone" /> Show my business phone</label>
        <label className="reg-tick"><input type="checkbox" name="publish_website" /> Show my website</label>
      </fieldset>

      <label className="reg-tick">
        <input type="checkbox" required /> I run this business or am authorised to register it, and I agree to the{' '}
        <a href={`${DOP_URL}/terms.html`}>terms of use</a> and <a href={`${DOP_URL}/privacy.html`}>privacy notice</a>.
      </label>

      {reply?.outcome === 'invalid' && (
        <p style={{ color: '#a8332b', fontSize: 13, margin: 0 }}>
          Please check the {FIELD_NAMES[reply.field] ?? reply.field}{reply.index ? ` (item ${reply.index})` : ''}.
          {reply.field === 'credentials' ? ' A state licence needs its number and issuing state.' : ''}
        </p>
      )}
      {reply?.outcome === 'error' && (
        <p style={{ color: '#a8332b', fontSize: 13, margin: 0 }}>Something went wrong on our side and nothing was saved. Please try again.</p>
      )}
      <button type="submit" className="finder-btn" disabled={busy}>{busy ? 'Sending…' : 'Register'}</button>
    </form>
  )
}
