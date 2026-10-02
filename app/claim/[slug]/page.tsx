import { notFound, permanentRedirect } from 'next/navigation'
import Link from 'next/link'
import ClaimForm from '@/app/components/ClaimForm'
import { getSessionUser } from '@/lib/supabase/ssr-server'
import { resolveBusinessSlug } from '@/lib/business'

const SB_HOST = 'eaifqorwmgayiqmbtzcg.supabase.co'
// Read from the environment — never hardcode the key. Set SUPABASE_SECRET_KEY in
// Vercel (and .env.local for local dev). Matches lib/supabase/server.ts.
const SB_KEY  = process.env.SUPABASE_SECRET_KEY ?? ''
const SB_HEADERS = { 'apikey': SB_KEY, 'Authorization': 'Bearer ' + SB_KEY }

async function getContractor(slug: string) {
  const res = await fetch(
    `https://${SB_HOST}/rest/v1/contractors_public_direct?slug=eq.${encodeURIComponent(slug)}&select=slug,display_name,license_number,claimed,doc_category,city,state&limit=1`,
    { headers: SB_HEADERS, next: { revalidate: 60 } }
  )
  if (!res.ok) return null
  const rows = await res.json()
  return rows?.[0] ?? null
}

type ClaimState = { state: 'none' | 'pending' | 'approved'; mine: boolean; on: string | null }

// Asked fresh on every load (no cache): a page that thinks a claimed business is unclaimed lets a
// person fill the whole form before rejecting them.
async function claimState(slug: string, email: string | null): Promise<ClaimState> {
  try {
    const r = await fetch(`https://${SB_HOST}/rest/v1/rpc/claim_state_for_business`, {
      method: 'POST', cache: 'no-store',
      headers: { ...SB_HEADERS, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_slug: slug, p_email: email }),
    })
    if (r.ok) return await r.json()
  } catch {}
  return { state: 'none', mine: false, on: null }
}

function fmtDay(d: string) {
  const m = d.match(/^(\d{4})-(\d{2})-(\d{2})/)
  const M = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
  return m ? `${Number(m[3])} ${M[Number(m[2]) - 1]} ${m[1]}` : d
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const c = await getContractor(slug)
  if (!c) return { title: 'Claim Profile' }
  return { title: `Claim ${c.display_name}` }
}

export default async function ClaimPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params

  // A business is claimed once, under its own slug — never per licence record.
  const business = await resolveBusinessSlug(slug)
  if (business?.redirect) permanentRedirect(`/claim/${business.slug}`)

  const c = await getContractor(slug)
  if (!c) notFound()
  const user = await getSessionUser()
  const signedIn = !!user?.email
  const cs = await claimState(slug, user?.email ?? null)

  return (
    <main style={{ minHeight: '100vh', background: 'var(--color-cream)' }}>

      {/* Header */}
      <div style={{ background: 'var(--color-navy)', padding: '12px 24px', display: 'flex', alignItems: 'center', gap: '12px' }}>
        <Link href={`/c/${slug}`} style={{ color: 'var(--color-bronze)', textDecoration: 'none', fontSize: '0.82rem' }}>
          ← Back to Profile
        </Link>
      </div>

      <div style={{ maxWidth: '520px', margin: '0 auto', padding: '32px 16px' }}>

        {/* The claim state, known at LOAD (work order 727): none shows the form; pending or approved
            say so - and a visitor whose own claim it is gets their way in, never a form that rejects them. */}
        {cs.state !== 'none' ? (
          <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '28px' }}>
            <h1 style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', fontSize: '1.3rem', fontWeight: 700, margin: '0 0 10px' }}>
              {cs.state === 'approved' ? (cs.mine ? 'This is your business' : 'This profile has been claimed') : (cs.mine ? 'Your claim is under review' : 'A claim on this profile is under review')}
            </h1>
            {cs.state === 'approved' && cs.mine && (
              <>
                <p style={{ fontSize: '0.88rem', color: 'var(--color-ink)', margin: '0 0 16px' }}>You claimed this{cs.on ? ` on ${fmtDay(cs.on)}` : ''}.</p>
                <p style={{ display: 'flex', gap: 16, flexWrap: 'wrap', margin: 0 }}>
                  <Link href={`/claim/${slug}/profile`} className="finder-btn" style={{ textDecoration: 'none' }}>Edit your profile</Link>
                  <Link href={`/claim/${slug}/photos`} style={{ color: 'var(--color-bronze)', alignSelf: 'center' }}>Photos of your work</Link>
                </p>
              </>
            )}
            {cs.state === 'approved' && !cs.mine && (
              <>
                {!signedIn && (
                  <p style={{ fontSize: '0.88rem', color: 'var(--color-ink)', margin: '0 0 12px' }}>
                    If the claim is yours, <Link href={`/login?next=/claim/${slug}/profile`} style={{ color: 'var(--color-bronze)' }}>sign in</Link> with the email you claimed with to edit your profile.
                  </p>
                )}
                <p style={{ fontSize: '0.84rem', color: 'var(--color-sage)', margin: 0 }}>
                  If you run this business and believe the claim is wrong, email{' '}
                  <a href={`mailto:register@departmentofproperty.com?subject=${encodeURIComponent('Claim query: ' + c.display_name)}`} style={{ color: 'var(--color-bronze)' }}>register@departmentofproperty.com</a> and a person will look into it.
                </p>
              </>
            )}
            {cs.state === 'pending' && (
              <p style={{ fontSize: '0.88rem', color: 'var(--color-ink)', margin: 0 }}>
                {cs.mine
                  ? 'A person reads every claim. When yours is approved we will send a link to your email to set your password, and you can then edit your profile and add photos.'
                  : <>A person is reviewing it. If you run this business and believe the claim is not yours, email <a href={`mailto:register@departmentofproperty.com?subject=${encodeURIComponent('Claim query: ' + c.display_name)}`} style={{ color: 'var(--color-bronze)' }}>register@departmentofproperty.com</a>.</>}
              </p>
            )}
            <p style={{ margin: '18px 0 0' }}><Link href={`/c/${slug}`} style={{ fontSize: '0.84rem', color: 'var(--color-bronze)' }}>Back to profile</Link></p>
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
                Every licensed business has an entry from the public register. Claim it to correct the record:
                a person reads every claim.
                We compare the licence number you give with the state register and note what we find.
              </p>
            </div>

            {/* How it works */}
            <div style={{ background: 'var(--color-white)', borderRadius: '14px', border: '1px solid var(--color-light-gray)', padding: '16px', marginBottom: '16px' }}>
              <p style={{ fontSize: '0.78rem', fontWeight: 700, color: 'var(--color-navy)', margin: '0 0 10px', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                How it works
              </p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                {[
                  ['1', 'Enter the licence number you hold or work under'],
                  ['2', 'Provide your contact details'],
                  ['3', 'We review it and get in touch'],
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
