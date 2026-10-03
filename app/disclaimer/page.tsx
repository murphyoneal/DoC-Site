import type { Metadata } from 'next'
import Link from 'next/link'
import { CONTRACTOR_URL } from '@/lib/site'

export const metadata: Metadata = {
  title: 'Disclaimer',
  description:
    'This site is a technology platform that aggregates public government registry data. Read the full disclaimer before relying on any information on this site.',
}

export default function DisclaimerPage() {
  const updated = 'October 2026'

  return (
    <div className="max-w-3xl mx-auto px-4 sm:px-6 py-10">
      <nav className="text-xs mb-6" style={{ color: 'var(--color-sage)' }}>
        <Link href="/" className="hover:underline">Home</Link>
        {' / '}
        <span style={{ color: 'var(--color-ink)' }}>Disclaimer</span>
      </nav>

      <h1
        className="text-3xl font-bold mb-2"
        style={{ fontFamily: 'Georgia, serif', color: 'var(--color-navy)' }}
      >
        Disclaimer
      </h1>
      <p className="text-sm mb-8" style={{ color: 'var(--color-sage)' }}>
        Last updated: {updated}
      </p>

      <div
        className="prose max-w-none text-sm"
        style={{ color: 'var(--color-ink)', lineHeight: 1.8 }}
      >
        <section className="mb-8">
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            1. Technology Platform — Not a Licensing Authority
          </h2>
          <p className="mb-3">
            {/* No legal entity is named: none exists yet (ruling 2026-09-24). */}
            This site (&quot;we&quot;, &quot;this site&quot;) is a technology platform
            that aggregates publicly available contractor licence data from government
            registries. We are not a licensing authority, regulatory body, government agency,
            or official government website.
          </p>
          <p>
            We do not issue, renew, revoke, or modify contractor licences. We do not verify
            the accuracy of any information beyond what is provided by the source government registry.
          </p>
        </section>

        <section className="mb-8">
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            2. Data Accuracy and Currency
          </h2>
          <p className="mb-3">
            {/* Audit 971 A5: this said "one register" and "no other state's register" while the electrical file was
                served and Oregon's file was held. */}
            The contractor licence data on this site is reproduced from two Florida files published by the
            Department of Business &amp; Professional Regulation (DBPR): the construction licence file
            (Construction Industry Licensing Board) and the electrical contractor licence file (Electrical
            Contractors&rsquo; Licensing Board). We also hold Oregon&rsquo;s construction contractor file, used only
            to check the licence an Oregon business gives when it registers itself; it is not shown as a register.
            A business that registers itself is shown as its own declaration, and says which of its licences we
            could not check.
          </p>
          <p className="mb-3">
            Each contractor&rsquo;s page shows the date of the licence file its record was read from. There will always be a lag
            between a change made at the registry (licence renewal, revocation, suspension) and this site.
          </p>
          <p className="font-semibold" style={{ color: 'var(--color-navy)' }}>
            Always verify current licence status directly with the relevant government registry
            before engaging any contractor.
          </p>
        </section>

        <section className="mb-8">
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            3. No Endorsement
          </h2>
          <p>
            The appearance of a contractor on this site does not constitute an endorsement,
            recommendation, or guarantee of their work quality, reliability, or professional
            conduct. A valid licence does not guarantee satisfactory workmanship or adherence
            to building codes.
          </p>
        </section>

        <section className="mb-8">
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            4. No Liability
          </h2>
          <p className="mb-3">
            This site and its data providers accept no liability for:
          </p>
          <ul className="list-disc ml-6 space-y-1">
            <li>Inaccurate, outdated, or incomplete licence information</li>
            <li>Any decision made in reliance on information displayed on this site</li>
            <li>Any loss, injury, or damage resulting from engaging a contractor found through this site</li>
            <li>Any contractor&apos;s professional conduct, work quality, or compliance with applicable laws</li>
          </ul>
        </section>

        <section className="mb-8">
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            5. Data Use Restrictions
          </h2>
          <p className="mb-3">
            Automated scraping, bulk downloading, or systematic extraction of contractor data
            from this site is expressly prohibited. This data is provided solely for individual
            reference use. Violation of this restriction may result in legal action under applicable
            computer fraud and data protection laws.
          </p>
          <p>
            Search results and lists are shown a page at a time for individual reference. We do not offer a bulk
            export.
          </p>
        </section>

        <section className="mb-8">
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            6. QR Codes and Contractor Profiles
          </h2>
          <p>
            QR codes generated by this site link to contractor profile pages on
            {CONTRACTOR_URL.replace('https://', '')}. Screen-resolution QR codes are available for
            all listed profiles. Hi-resolution print-ready QR cards are available only
            to contractors who have claimed and verified their profile. DoC does not share
            QR scan analytics with contractors — this data is retained by DoC solely for
            platform analytics purposes.
          </p>
        </section>

        <section>
          <h2
            className="text-lg font-bold mb-3"
            style={{ fontFamily: 'Georgia, serif', color: 'var(--color-bronze)' }}
          >
            7. Verify Directly
          </h2>
          <p className="mb-4">
            We reproduce Florida&rsquo;s construction and electrical licence registers. For any other state, check
            directly with the issuing authority below. Before engaging any contractor, verify their
            licence status directly with the relevant government registry:
          </p>
          <ul className="space-y-2">
            <li>
              <a
                href="https://www.myfloridalicense.com/wl11.asp"
                target="_blank"
                rel="noopener noreferrer"
                className="underline"
                style={{ color: 'var(--color-bronze)' }}
              >
                Florida DBPR Licence Verification →
              </a>
            </li>
            <li>
              <a
                href="https://www.cslb.ca.gov/onlineservices/checklicenseII/checklicense.aspx"
                target="_blank"
                rel="noopener noreferrer"
                className="underline"
                style={{ color: 'var(--color-bronze)' }}
              >
                California CSLB Licence Check →
              </a>
            </li>
            <li>
              <a
                href="https://secure.lni.wa.gov/verify/"
                target="_blank"
                rel="noopener noreferrer"
                className="underline"
                style={{ color: 'var(--color-bronze)' }}
              >
                Washington L&amp;I Contractor Lookup →
              </a>
            </li>
            <li>
              <a
                href="https://search.ccb.state.or.us/search/"
                target="_blank"
                rel="noopener noreferrer"
                className="underline"
                style={{ color: 'var(--color-bronze)' }}
              >
                Oregon CCB Licence Lookup →
              </a>
            </li>
          </ul>
        </section>
      </div>
    </div>
  )
}
