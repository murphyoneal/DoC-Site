'use client'

import { useState, useRef, useEffect } from 'react'

interface TraceItem { tool: string; county: number | null; allowed: boolean; denialReason: string | null }
interface Msg { role: 'user' | 'assistant'; content: string; trace?: TraceItem[]; tier?: string }

export default function AssistantChat() {
  const [apiKey, setApiKey] = useState('dop_demo_key_volusia_001')
  const [messages, setMessages] = useState<Msg[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const endRef = useRef<HTMLDivElement>(null)
  // Stable id for this chat session — lets the server group requests (observe-only
  // session-anomaly detection). Regenerated per mount; not persisted.
  const sessionIdRef = useRef<string>(
    typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `s_${Date.now()}_${Math.random().toString(36).slice(2)}`
  )

  useEffect(() => { endRef.current?.scrollIntoView({ behavior: 'smooth' }) }, [messages, loading])

  async function send() {
    const text = input.trim()
    if (!text || loading) return
    setError(null)
    const history = [...messages, { role: 'user' as const, content: text }]
    setMessages(history)
    setInput('')
    setLoading(true)
    try {
      const res = await fetch('/api/assistant', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ apiKey, sessionId: sessionIdRef.current, messages: history.map(m => ({ role: m.role, content: m.content })) }),
      })
      const j = await res.json()
      if (!res.ok) { setError(j.error ?? 'Request failed'); setLoading(false); return }
      setMessages(m => [...m, { role: 'assistant', content: j.reply, trace: j.trace, tier: j.tier }])
    } catch {
      setError('Network error.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', maxWidth: 780, margin: '0 auto', width: '100%' }}>
      {/* Account bar */}
      <div style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '10px 14px', borderBottom: '1px solid var(--color-light-gray)', flexWrap: 'wrap' }}>
        <span style={{ fontSize: 12, color: 'var(--color-sage)' }}>Account key</span>
        <input
          value={apiKey}
          onChange={e => setApiKey(e.target.value)}
          style={{ flex: 1, minWidth: 180, fontSize: 12, padding: '5px 8px', borderRadius: 6, border: '1px solid var(--color-light-gray)', fontFamily: 'monospace' }}
        />
        {messages.find(m => m.tier) && (
          <span style={{ fontSize: 11, fontWeight: 700, textTransform: 'uppercase', padding: '3px 8px', borderRadius: 999, background: 'var(--color-navy)', color: '#fff' }}>
            {messages.filter(m => m.tier).slice(-1)[0].tier}
          </span>
        )}
      </div>

      {/* Messages */}
      <div style={{ flex: 1, overflowY: 'auto', padding: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
        {messages.length === 0 && (
          <div style={{ color: 'var(--color-sage)', fontSize: 13, textAlign: 'center', marginTop: 24 }}>
            Ask about a Volusia property — e.g. <em>“Tell me about 1778 Earhart Ct in Port Orange”</em>.<br />
            On Pro, try <em>“How many single-family homes over $1M are in Volusia?”</em>
          </div>
        )}
        {messages.map((m, i) => (
          <div key={i} style={{ alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start', maxWidth: '88%' }}>
            <div style={{
              padding: '10px 12px', borderRadius: 12, fontSize: 14, lineHeight: 1.5, whiteSpace: 'pre-wrap',
              background: m.role === 'user' ? 'var(--color-navy)' : 'var(--color-white)',
              color: m.role === 'user' ? '#fff' : 'var(--color-ink)',
              border: m.role === 'user' ? 'none' : '1px solid var(--color-light-gray)',
            }}>
              {m.content}
            </div>
            {m.trace && m.trace.length > 0 && (
              <div style={{ marginTop: 4, display: 'flex', flexWrap: 'wrap', gap: 4 }}>
                {m.trace.map((t, j) => (
                  <span key={j} title={t.denialReason ?? undefined} style={{
                    fontSize: 10, padding: '2px 7px', borderRadius: 999,
                    background: t.allowed ? '#eaf1ea' : '#fdecea',
                    color: t.allowed ? '#3f5a3f' : '#8a2a1f',
                    border: `1px solid ${t.allowed ? '#cfe0cf' : '#f0c0ba'}`,
                  }}>
                    {t.allowed ? '✓' : '✕'} {t.tool}
                  </span>
                ))}
              </div>
            )}
          </div>
        ))}
        {loading && <div style={{ alignSelf: 'flex-start', fontSize: 13, color: 'var(--color-sage)' }}>Thinking…</div>}
        {error && <div style={{ alignSelf: 'center', fontSize: 13, color: '#8a2a1f', background: '#fdecea', padding: '6px 12px', borderRadius: 8 }}>{error}</div>}
        <div ref={endRef} />
      </div>

      {/* Composer */}
      <div style={{ display: 'flex', gap: 8, padding: 12, borderTop: '1px solid var(--color-light-gray)' }}>
        <input
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => { if (e.key === 'Enter') send() }}
          placeholder="Ask about a property…"
          style={{ flex: 1, fontSize: 14, padding: '10px 12px', borderRadius: 10, border: '1px solid var(--color-light-gray)', outline: 'none' }}
        />
        <button
          onClick={send}
          disabled={loading || !input.trim()}
          style={{ padding: '10px 18px', borderRadius: 10, border: 'none', background: 'var(--color-navy)', color: '#fff', fontSize: 14, fontWeight: 600, cursor: loading ? 'wait' : 'pointer', opacity: loading || !input.trim() ? 0.6 : 1 }}
        >
          Send
        </button>
      </div>
    </div>
  )
}
