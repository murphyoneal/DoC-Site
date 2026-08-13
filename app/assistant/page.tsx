import type { Metadata } from 'next'
import AssistantChat from '@/app/components/AssistantChat'

export const metadata: Metadata = {
  title: 'Property Intelligence Assistant',
  robots: { index: false, follow: false }, // B2B tool — not for indexing
}

export default function AssistantPage() {
  return (
    <div style={{ height: 'calc(100vh - 96px)', display: 'flex', flexDirection: 'column', background: 'var(--color-cream)' }}>
      <header style={{ padding: '10px 16px', borderBottom: '1px solid var(--color-light-gray)', background: 'var(--color-white)' }}>
        <h1 style={{ margin: 0, fontSize: 16, color: 'var(--color-navy)', fontFamily: 'Georgia, serif' }}>Property Intelligence Assistant</h1>
        <p style={{ margin: '2px 0 0', fontSize: 12, color: 'var(--color-sage)' }}>
          B2B demo · Volusia County · tier enforcement + query logging are live (flip the account tier in Supabase to unlock Pro).
        </p>
      </header>
      <div style={{ flex: 1, minHeight: 0 }}>
        <AssistantChat />
      </div>
    </div>
  )
}
