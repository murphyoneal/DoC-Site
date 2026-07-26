'use client'

import { useState, useRef, useEffect } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

// Outbound links: new tab (a user-clicked tab is never popup-blocked, and it preserves her
// conversation), rel="noopener noreferrer" so the opened page can't navigate the parent window,
// type-aware labels (a .tif plat scan downloads to an image viewer — say so, or it looks broken),
// and click telemetry (which documents get opened is the same signal as feed reads).
function docType(url: string): { type: string; publisher: string } {
  const u = url.toLowerCase()
  if (u.includes('maps5.vcgov.org') || u.includes('/plats/')) return { type: 'plat', publisher: 'Volusia Clerk (plat scan)' }
  if (u.includes('connectlivepermits.org')) return { type: 'permit', publisher: 'Volusia ConnectLive (permit file)' }
  if (u.includes('vcpa.vcgov.org')) return { type: 'county_viewer', publisher: 'Volusia County Property Appraiser' }
  if (u.includes('clerk.org') || u.includes('realtaxdeed') || u.includes('lienhub')) return { type: 'official_record', publisher: 'Volusia Clerk / Tax Collector' }
  if (u.includes('fldep') || u.includes('floridadep') || u.includes('arcgis')) return { type: 'fdep_layer', publisher: 'FDEP / GIS' }
  return { type: 'other', publisher: '' }
}
function isTiff(url: string) { return /\.tiff?$/i.test(url.replace(/\s+$/, '')) }

function MdLink({ href, children }: { href?: string; children?: React.ReactNode }) {
  const url = (href ?? '').trim() // plat_link values carry trailing spaces/tabs — trim before use
  const { type } = docType(url)
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" onClick={e => {
      const a = e.currentTarget
      const wrap = a.closest('.roz-md') as HTMLElement | null
      const rank = wrap ? Array.from(wrap.querySelectorAll('a')).indexOf(a) + 1 : 1
      try {
        fetch('/api/roz/doc-click', { method: 'POST', headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ queryLogId: wrap?.dataset.qid || null, parcelId: wrap?.dataset.parcel || null,
            url, label: a.textContent || '', docType: type, rank }) })
      } catch { /* telemetry is best-effort */ }
    }}>
      {children}{isTiff(url) ? <span style={{ color: 'var(--color-sage)', fontSize: 12 }}> (TIFF — downloads, opens in an image viewer)</span> : null}
    </a>
  )
}

interface Msg {
  role: 'user' | 'assistant'
  content: string
  queryLogId?: string | null
  parcelId?: string | null
  shownAt?: number
}

// Feedback under one answer. Open text box FIRST and always visible; enums optional
// beneath. Prompts for the gap ("What would you have needed here?"), not the verdict.
function FeedbackBox({ queryLogId, parcelId, shownAt }: { queryLogId?: string | null; parcelId?: string | null; shownAt?: number }) {
  const [note, setNote] = useState('')
  const [correct, setCorrect] = useState<string | null>(null)
  const [useful, setUseful] = useState<string | null>(null)
  const [gap, setGap] = useState<string | null>(null)
  const [sent, setSent] = useState(false)
  const [busy, setBusy] = useState(false)

  async function submit() {
    if (busy || sent) return
    setBusy(true)
    try {
      await fetch('/api/roz/opinion', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          queryLogId, parcelId, note: note.trim() || null,
          answerCorrect: correct, answerUseful: useful, gapVerdict: gap,
          responseLagMs: shownAt ? Date.now() - shownAt : null,
        }),
      })
      setSent(true)
    } finally { setBusy(false) }
  }

  if (sent) return <div style={{ fontSize: 11, color: 'var(--color-sage)', marginTop: 6 }}>Thanks — logged.</div>

  return (
    <div style={{ marginTop: 8, padding: 10, border: '1px dashed var(--color-light-gray)', borderRadius: 10, background: 'rgba(0,0,0,0.015)' }}>
      <textarea
        value={note} onChange={e => setNote(e.target.value)}
        placeholder="What would you have needed here?"
        rows={2}
        style={{ width: '100%', fontSize: 13, padding: '8px 10px', borderRadius: 8, border: '1px solid var(--color-light-gray)', outline: 'none', resize: 'vertical', boxSizing: 'border-box' }}
      />
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 6, alignItems: 'center' }}>
        <EnumRow label="Correct?" value={correct} set={setCorrect} opts={['correct', 'incorrect', 'partly', 'cant_tell']} />
        <EnumRow label="Useful?" value={useful} set={setUseful} opts={['useful', 'not_useful', 'partly']} />
        <EnumRow label="Gap?" value={gap} set={setGap} opts={['n_a', 'should_exist', 'correctly_withheld', 'wrong_source']} />
        <button onClick={submit} disabled={busy} style={{ marginLeft: 'auto', fontSize: 12, padding: '5px 12px', borderRadius: 8, border: 'none', background: 'var(--color-navy)', color: '#fff', fontWeight: 600, cursor: busy ? 'wait' : 'pointer', opacity: busy ? 0.6 : 1 }}>
          {busy ? '…' : 'Send feedback'}
        </button>
      </div>
    </div>
  )
}

function EnumRow({ label, value, set, opts }: { label: string; value: string | null; set: (v: string | null) => void; opts: string[] }) {
  return (
    <div style={{ display: 'flex', gap: 3, alignItems: 'center' }}>
      <span style={{ fontSize: 10, color: 'var(--color-sage)' }}>{label}</span>
      {opts.map(o => (
        <button key={o} onClick={() => set(value === o ? null : o)} style={{
          fontSize: 10, padding: '2px 6px', borderRadius: 999, cursor: 'pointer',
          border: `1px solid ${value === o ? 'var(--color-navy)' : 'var(--color-light-gray)'}`,
          background: value === o ? 'var(--color-navy)' : '#fff', color: value === o ? '#fff' : 'var(--color-ink)',
        }}>{o.replace(/_/g, ' ')}</button>
      ))}
    </div>
  )
}

export default function RozChat({ userEmail }: { userEmail: string }) {
  const [messages, setMessages] = useState<Msg[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const endRef = useRef<HTMLDivElement>(null)
  const sessionIdRef = useRef<string>(
    typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `s_${Date.now()}`
  )
  useEffect(() => { endRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages, loading])

  async function send() {
    const text = input.trim()
    if (!text || loading) return
    setError(null)
    const history = [...messages, { role: 'user' as const, content: text }]
    setMessages(history); setInput(''); setLoading(true)
    try {
      const res = await fetch('/api/roz', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sessionId: sessionIdRef.current, messages: history.map(m => ({ role: m.role, content: m.content })) }),
      })
      const j = await res.json()
      if (!res.ok) { setError(j.error ?? 'Request failed'); setLoading(false); return }
      setMessages(m => [...m, { role: 'assistant', content: j.reply, queryLogId: j.queryLogId, parcelId: j.trace?.find((t: any) => t)?.parcelId ?? null, shownAt: Date.now() }])
    } catch { setError('Network error.') } finally { setLoading(false) }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', maxWidth: 820, margin: '0 auto', width: '100%' }}>
      <style>{`
        .roz-md > :first-child { margin-top: 0; }
        .roz-md > :last-child { margin-bottom: 0; }
        .roz-md h1, .roz-md h2, .roz-md h3 { font-size: 15px; font-weight: 700; color: var(--color-navy); margin: 12px 0 4px; }
        .roz-md p { margin: 6px 0; }
        .roz-md ul, .roz-md ol { margin: 6px 0; padding-left: 20px; }
        .roz-md li { margin: 2px 0; }
        .roz-md li > p { margin: 0; }
        .roz-md strong { font-weight: 700; }
        .roz-md a { color: var(--color-navy); text-decoration: underline; }
        .roz-md code { background: rgba(0,0,0,0.05); padding: 1px 5px; border-radius: 4px; font-size: 12.5px; }
        .roz-md pre { background: rgba(0,0,0,0.05); padding: 10px; border-radius: 8px; overflow-x: auto; }
        .roz-md pre code { background: none; padding: 0; }
        .roz-md blockquote { margin: 6px 0; padding-left: 10px; border-left: 3px solid var(--color-light-gray); color: var(--color-sage); }
        .roz-md table { border-collapse: collapse; margin: 8px 0; font-size: 13px; display: block; overflow-x: auto; max-width: 100%; }
        .roz-md th, .roz-md td { border: 1px solid var(--color-light-gray); padding: 4px 9px; text-align: left; vertical-align: top; }
        .roz-md th { background: rgba(0,0,0,0.03); font-weight: 700; }
        .roz-md hr { border: none; border-top: 1px solid var(--color-light-gray); margin: 10px 0; }
      `}</style>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '10px 14px', borderBottom: '1px solid var(--color-light-gray)' }}>
        <span style={{ fontSize: 15, fontWeight: 700, color: 'var(--color-navy)' }}>Roz</span>
        <span style={{ fontSize: 11, color: 'var(--color-sage)' }}>{userEmail}</span>
      </div>

      <div style={{ flex: 1, overflowY: 'auto', padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {messages.length === 0 && (
          <div style={{ color: 'var(--color-sage)', fontSize: 13, textAlign: 'center', marginTop: 24 }}>
            Ask Roz about a property — an address, a flood zone, a permit history, or a cross-parcel question across any Florida county.
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} style={{ alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start', maxWidth: '90%', width: m.role === 'assistant' ? '100%' : 'auto' }}>
            {m.role === 'assistant' ? (
              <div className="roz-md" data-qid={m.queryLogId ?? ''} data-parcel={m.parcelId ?? ''} style={{
                padding: '10px 14px', borderRadius: 12, fontSize: 14, lineHeight: 1.55,
                background: 'var(--color-white)', color: 'var(--color-ink)', border: '1px solid var(--color-light-gray)',
              }}>
                <ReactMarkdown remarkPlugins={[remarkGfm]} components={{ a: MdLink }}>{m.content}</ReactMarkdown>
              </div>
            ) : (
              <div style={{
                padding: '10px 12px', borderRadius: 12, fontSize: 14, lineHeight: 1.55, whiteSpace: 'pre-wrap',
                background: 'var(--color-navy)', color: '#fff',
              }}>{m.content}</div>
            )}
            {m.role === 'assistant' && <FeedbackBox queryLogId={m.queryLogId} parcelId={m.parcelId} shownAt={m.shownAt} />}
          </div>
        ))}
        {loading && <div style={{ alignSelf: 'flex-start', fontSize: 13, color: 'var(--color-sage)' }}>Roz is thinking…</div>}
        {error && <div style={{ alignSelf: 'center', fontSize: 13, color: '#8a2a1f', background: '#fdecea', padding: '6px 12px', borderRadius: 8 }}>{error}</div>}
        <div ref={endRef} />
      </div>

      <div style={{ display: 'flex', gap: 8, padding: 12, borderTop: '1px solid var(--color-light-gray)' }}>
        <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') send() }}
          placeholder="Ask Roz…" style={{ flex: 1, fontSize: 14, padding: '10px 12px', borderRadius: 10, border: '1px solid var(--color-light-gray)', outline: 'none' }} />
        <button onClick={send} disabled={loading || !input.trim()} style={{ padding: '10px 18px', borderRadius: 10, border: 'none', background: 'var(--color-navy)', color: '#fff', fontSize: 14, fontWeight: 600, cursor: loading ? 'wait' : 'pointer', opacity: loading || !input.trim() ? 0.6 : 1 }}>Send</button>
      </div>
    </div>
  )
}
