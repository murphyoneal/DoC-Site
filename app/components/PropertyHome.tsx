import { CONTRACTOR_URL } from '@/lib/site'

// Department of Property's home (work order 712): the two registers, agents and contractors, and
// what each is. The property lookup that stood here led to the $5 report checkout, and PIR is not
// on sale (Murphy, 2026-09-28). It is PARKED, not deleted: AddressAutocomplete, /api/address-search,
// /report/* and the Stripe wiring all remain, unreachable from the site, and /api/checkout refuses
// unless PIR_SALES_OPEN=true.
export default function PropertyHome() {
  return (
    <div className="px-4 py-10" style={{ background: 'var(--color-light-gray)' }}>
      <div className="max-w-3xl mx-auto">
        <h1 className="text-2xl font-bold" style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)', margin: 0 }}>
          Florida&rsquo;s licensed agents and contractors, from the state registers.
        </h1>
        <p className="text-sm" style={{ color: 'var(--color-sage)', margin: '8px 0 20px' }}>
          Two public registers, each as the Florida register showed it on the date we retrieved it.
          Counts and dates, never a rating.
        </p>
        <div className="grid gap-3 sm:grid-cols-2">
          <a href="/agents.html" className="block p-5 rounded-lg" style={{ background: 'var(--color-white)', border: '1px solid #e2ddd6', textDecoration: 'none' }}>
            <span className="block font-semibold" style={{ color: 'var(--color-navy)', fontSize: '1.05rem' }}>Real estate agents &rarr;</span>
            <span className="block text-sm mt-1" style={{ color: 'var(--color-sage)' }}>
              Sales associates, broker associates and brokers from the Florida real estate licence register: licence
              status as recorded, and the brokerage each works under.
            </span>
          </a>
          <a href={`${CONTRACTOR_URL}/c`} className="block p-5 rounded-lg" style={{ background: 'var(--color-white)', border: '1px solid #e2ddd6', textDecoration: 'none' }}>
            <span className="block font-semibold" style={{ color: 'var(--color-navy)', fontSize: '1.05rem' }}>Contractors &rarr;</span>
            <span className="block text-sm mt-1" style={{ color: 'var(--color-sage)' }}>
              Florida contracting businesses from the state construction licence register, on Department of Construction:
              trade, city, county and licence status as recorded.
            </span>
          </a>
        </div>
      </div>
    </div>
  )
}
