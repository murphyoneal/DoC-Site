import { notFound } from 'next/navigation'
import { contractorSocket } from '@/lib/sockets/contractors'
import ClaimForm from '@/app/components/ClaimForm'

interface Props {
  params: Promise<{ slug: string }>
}

export default async function ClaimPage({ params }: Props) {
  const { slug } = await params
  const c = await contractorSocket.forProfile(slug)
  if (!c) notFound()

  if (c.claimed) {
    return (
      <div className="max-w-xl mx-auto px-4 py-16 text-center">
        <h1 className="text-2xl font-bold mb-4" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          This profile has already been claimed
        </h1>
        <p className="text-sm mb-6" style={{ color: 'var(--color-sage)' }}>
          If you believe this is an error, please contact us.
        </p>
        <a href={`/c/${slug}`} className="text-sm underline" style={{ color: 'var(--color-bronze)' }}>Back to profile</a>
      </div>
    )
  }

  return (
    <div className="max-w-xl mx-auto px-4 py-12">
      <div className="mb-8">
        <a href={`/c/${slug}`} className="text-xs underline mb-4 inline-block" style={{ color: 'var(--color-sage)' }}>Back to profile</a>
        <h1 className="text-2xl font-bold mb-2" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          Claim Your Profile
        </h1>
        <p className="text-sm" style={{ color: 'var(--color-sage)' }}>
          Claiming your profile is free. Once verified you can add contact details, photos, and download your hi-res QR card.
        </p>
      </div>

      <div className="rounded-xl p-6 mb-6" style={{ background: 'var(--color-white)', border: '1px solid var(--color-light-gray)' }}>
        <h2 className="text-base font-bold mb-1" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
          {c.display_name}
        </h2>
        <p className="text-sm mb-1" style={{ color: 'var(--color-bronze)' }}>
          {c.trade_label ?? 'Licensed Contractor'}
        </p>
        <p className="text-sm" style={{ color: 'var(--color-sage)' }}>
          {[c.city, c.state].filter(Boolean).join(', ')}
        </p>
      </div>

      <ClaimForm slug={slug} licenseNumber={c.license_number ?? ''} displayName={c.display_name} />
    </div>
  )
}