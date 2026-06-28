import { notFound } from 'next/navigation'
import Link from 'next/link'
import ClaimForm from '@/app/components/ClaimForm'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
const SB_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWZxb3J3bWdheWlxbWJ0emNnIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4MjMxNjIzOCwiZXhwIjoyMDk3ODkyMjM4fQ.L23cjzASjDbuFQ1zeQt30CThOSX_aRwyWpbl7QLeO-E'
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors?slug=eq.${encodeURIComponent(slug)}&select=slug,display_name,license_number,claimed,doc_category,city,state&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 60 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Claim Profile | Department of Construction' }
  return { title: `Claim ${c.display_name} | Department of Construction` }
}

export default async function ClaimPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) notFound()

  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)' }}>

      {/* Header */}
      <div style={{ background: 'var(--color-navy)', padding: '12px 24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <Link href={`/c/${slug}`} style={{ color: 'var(--color-bronze)', textDecoration: 'none', fontSize: '0.82rem' }}>
          ← Back to Profile
        </Link>
      </div>

      <div style={{ maxWidth: '520px', margin: '0 auto', padding: '32px 16px' }}>

        {/* Already claimed */}
        {c.claimed ? (
          <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '32px', textAlign: 'center' }}>
            <div style={{ fontSize: '2.5rem', marginBottom: '12px' }}>✓</div>
            <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', fontWeight: 700, margin: '0 0 8px' }}>
              Already Claimed
            </h1>
            <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: '0 0 20px' }}>
              This profile has already been claimed by the licence holder.
            </p>
            <Link
              href={`/c/${slug}`}
              style={{ fontSize: '0.84rem', color: 'var(--color-bronze)', textDecoration: 'underline' }}
            >
              Back to profile
            </Link>
          </div>
        ) : (
          <>
            {/* Header card */}
            <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '20px', marginBottom: '16px' }}>
              <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', fontWeight: 700, margin: '0 0 4px' }}>
                Claim This Profile
              </h1>
              <p style={{ fontSize: '0.88rem', color: 'var(--color-bronze)', margin: '0 0 12px', fontWeight: 600 }}>
                {c.display_name}
              </p>
              <p style={{ fontSize: '0.82rem', color: 'var(--color-sage)', margin: 0 }}>
                Claiming your profile lets you update contact details, respond to enquiries, and verify your permit history.
                We verify ownership using your DBPR licence number.
              </p>
            </div>

            {/* How it works */}
            <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '16px', marginBottom: '16px' }}>
              <p style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--color-navy)', margin: '0 0 10px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                How it works
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {[
                  ['1', 'Enter your DBPR licence number to verify ownership'],
                  ['2', 'Provide your contact details'],
                  ['3', 'We review and approve within 1–2 business days'],
                ].map(([num, text]) => (
                  <div key={num} style={{ display: 'flex', gap: '10px', alignItems: 'flex-start' }}>
                    <span style={{
                      width: '20px', height: '20px', borderRadius: '50%',
                      background: 'var(--color-navy)', color: 'white',
                      fontSize: '0.72rem', fontWeight: 700,
                      display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                    }}>{num}</span>
                    <p style={{ fontSize: '0.82rem', color: 'var(--color-sage)', margin: 0 }}>{text}</p>
                  </div>
                ))}
              </div>
            </div>

            {/* The form */}
            <ClaimForm
              slug={slug}
              licenseNumber={c.license_number ?? ''}
              displayName={c.display_name}
            />

            <p style={{ fontSize: '0.74rem', color: 'var(--color-sage)', textAlign: 'center', marginTop: '16px' }}>
              Questions? Contact us at{' '}
              <a href="mailto:hello@departmentofconstruction.com" style={{ color: 'var(--color-bronze)' }}>
                hello@departmentofconstruction.com
              </a>
            </p>
          </>
        )}
      </div>
    </main>
  )
}
