// Visual harness for DiscrepancyPanel. Not linked in the app — /prototype/discrepancy.
// Fixture is the 1511 S Riverside example (listing brochure vs the county record we verified).
import DiscrepancyPanel from '@/app/components/DiscrepancyPanel'
import type { DiscrepancyReport } from '@/types/roz-web'

const T = '2026-07-28T14:00:00Z'

const found: DiscrepancyReport = {
  parcelId: '744901030061',
  listing: { status: 'found', sites: ['Zillow', 'Realtor.com', 'Redfin'], retrievedAt: T },
  summary: { agrees: 1, disagrees: 2, unverifiable: 2 },
  fields: [
    { field: 'yearBuilt', label: 'Year built', webValue: 2017, webSource: 'Zillow', retrievedAt: T, recordValue: 2017, recordSource: 'Volusia County CAMA', outcome: 'agrees' },
    { field: 'livingSqft', label: 'Living area', webValue: '8,277 sq ft', webSource: 'Zillow', retrievedAt: T, recordValue: '8,001 sq ft', recordSource: 'Volusia County CAMA', outcome: 'disagrees', note: 'Reconcile with the seller / cite the source before pricing.' },
    { field: 'price', label: 'Price', webValue: '$6,895,000 (asking)', webSource: 'Zillow', retrievedAt: T, recordValue: '$4,323,870 (just value)', recordSource: 'Volusia County roll', outcome: 'disagrees', note: 'Asking is a marketing figure — not the assessed value or a sale.' },
    { field: 'wineCellar', label: 'Wine cellar', webValue: '550-bottle', webSource: 'Zillow', retrievedAt: T, outcome: 'unverifiable', note: 'Listing amenity; no public-record counterpart.' },
    { field: 'theater', label: 'Theater room', webValue: 'Yes', webSource: 'Redfin', retrievedAt: T, outcome: 'unverifiable' },
  ],
}

const none: DiscrepancyReport = {
  parcelId: '744901030061',
  listing: { status: 'none', reason: 'off_market', sites: ['Zillow', 'Realtor.com', 'Redfin'], retrievedAt: T },
  summary: { agrees: 0, disagrees: 0, unverifiable: 0 },
  fields: [],
}

export default function DiscrepancyPrototype() {
  return (
    <div style={{ maxWidth: 820, margin: '0 auto', padding: 24, display: 'flex', flexDirection: 'column', gap: 20 }}>
      <h1 style={{ fontSize: 18, fontWeight: 700, color: 'var(--color-navy)' }}>Discrepancy panel — prototype</h1>
      <div>
        <p style={{ fontSize: 12, color: 'var(--color-sage)', margin: '0 0 6px' }}>Listing found — web claims adjudicated against the record</p>
        <DiscrepancyPanel report={found} />
      </div>
      <div>
        <p style={{ fontSize: 12, color: 'var(--color-sage)', margin: '0 0 6px' }}>No listing — a reasoned null, never “not for sale”</p>
        <DiscrepancyPanel report={none} />
      </div>
    </div>
  )
}
