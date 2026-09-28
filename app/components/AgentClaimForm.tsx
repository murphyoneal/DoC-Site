'use client'

import { useState } from 'react'

// The agent's claim form (work order 712): a PERSON claims their own licence. Different subject from a
// contractor's claim (a business), so a different form. A person reads every claim.
type Reply = { outcome: string; field?: string; note?: string; licence_name?: string; rank?: string }

export default function AgentClaimForm({ licence }: { licence: string }) {
  const [reply, setReply] = useState<Reply | null>(null)
  const [busy, setBusy] = useState(false)

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const f = new FormData(e.currentTarget)
    setBusy(true); setReply(null)
    try {
      const r = await fetch('/api/agent-claim', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(Object.fromEntries(f.entries())),
      })
      setReply(await r.json())
    } catch { setReply({ outcome: 'error' }) } finally { setBusy(false) }
  }

  if (reply?.outcome === 'received') return (
    <div className="reg-card">
      <h2 className="reg-h2">Received. A person will review your claim.</h2>
      <p className="reg-p">Licence {reply.licence_name ? `for ${reply.licence_name}` : ''}{reply.rank ? ` (${reply.rank})` : ''}. We will reply by email.
        Once it is approved, your page goes live with your licence details from the state file, and you can sign in to add your own.</p>
    </div>
  )
  if (reply?.outcome === 'already_claimed') return (
    <div className="reg-card"><p className="reg-p" style={{ margin: 0 }}>This licence has already been claimed. If that was not you, email register@departmentofproperty.com.</p></div>
  )

  return (
    <form onSubmit={submit} className="reg-card" style={{ display: 'grid', gap: 12 }}>
      <div aria-hidden="true" style={{ position: 'absolute', left: '-10000px' }}><input name="company_url" tabIndex={-1} autoComplete="off" /></div>
      <label className="finder-label" htmlFor="ac-lic">Florida real estate licence number</label>
      <input id="ac-lic" name="license_number" required defaultValue={licence} className="finder-input" maxLength={20} placeholder="e.g. 3578412" />
      <label className="finder-label" htmlFor="ac-name">Your name, as licensed</label>
      <input id="ac-name" name="requester_name" required minLength={2} maxLength={200} className="finder-input" autoComplete="name" />
      <div className="reg-row">
        <div><label className="finder-label" htmlFor="ac-email">Email <span className="reg-opt">(private; how we reply)</span></label>
          <input id="ac-email" name="requester_email" type="email" required maxLength={254} className="finder-input" autoComplete="email" /></div>
        <div><label className="finder-label" htmlFor="ac-phone">Phone <span className="reg-opt">(optional, private)</span></label>
          <input id="ac-phone" name="requester_phone" maxLength={40} className="finder-input" autoComplete="tel" /></div>
      </div>
      <label className="finder-label" htmlFor="ac-msg">Anything we should know <span className="reg-opt">(optional)</span></label>
      <textarea id="ac-msg" name="message" rows={3} maxLength={2000} className="finder-input" />
      <label className="reg-tick"><input type="checkbox" required /> This is my licence, and I agree to the <a href="/terms.html">terms of use</a> and <a href="/privacy.html">privacy notice</a>.</label>
      {reply?.outcome === 'invalid' && <p style={{ color: '#a8332b', fontSize: 13, margin: 0 }}>{reply.note ?? `Please check the ${String(reply.field ?? '').replace(/_/g, ' ')}.`}</p>}
      {reply?.outcome === 'error' && <p style={{ color: '#a8332b', fontSize: 13, margin: 0 }}>Something went wrong on our side and nothing was saved. Please try again.</p>}
      <button type="submit" className="finder-btn" disabled={busy}>{busy ? 'Sending…' : 'Claim my licence'}</button>
    </form>
  )
}
