import Link from 'next/link'

// Shown instead of the paywall when the parcel id does not resolve (181a). The page never offers a report
// for a parcel we cannot find, and it says WHICH of the two things is true - they are different sentences:
//   none_recorded  we hold this county's parcel roll and this id is not in it (a typo, or a parcel created
//                  after the roll we hold)
//   not_available  we hold no county with this number
export default function ReportAbsent({ state, coNo, parcelId, countyName }: {
  state: 'none_recorded' | 'not_available'; coNo: number; parcelId: string; countyName: string | null
}) {
  const county = countyName ? `${countyName} County` : `county ${coNo}`
  return (
    <div className="max-w-lg mx-auto px-4 sm:px-6 py-12">
      <p className="text-xs font-semibold uppercase tracking-wide mb-2" style={{ color: 'var(--color-bronze)' }}>
        No report for this address
      </p>
      <h1 className="text-2xl font-bold mb-3" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}>
        {state === 'none_recorded' ? `We can't find parcel ${parcelId} in ${county}.` : `We don't hold records for ${county}.`}
      </h1>
      <p className="text-sm mb-5" style={{ color: 'var(--color-ink)' }}>
        {state === 'none_recorded'
          ? `We hold the ${county} parcel roll, and this parcel number is not in it. It may be mistyped, or the parcel may have been created after the roll we hold. Nothing has been charged.`
          : `The county number in this link does not match any Florida county we hold. Nothing has been charged.`}
      </p>
      <Link href="/" className="px-5 py-3 rounded-lg text-sm font-semibold inline-block"
        style={{ background: 'var(--color-navy)', color: 'var(--color-white)' }}>
        Search by address
      </Link>
    </div>
  )
}
