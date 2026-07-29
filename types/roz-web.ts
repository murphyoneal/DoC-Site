// The web-vs-public-record comparison contract.
//
// "On the web" claims are a THIRD class of assertion — what a website says — walled from
// public-record findings. The record is the anchor; a web claim is attributed to its site and
// is perishable. This is the shape the discrepancy panel renders and the target for structured
// output. Today Roz narrates it in prose under the grammar in app/api/roz/route.ts; this type
// is the frame that narration converges to when the panel and structured output are wired.
//
// Enabling the feature is two deliberate switches, both off by default:
//   1. ROZ_WEB_LOOKUP=1                      (the web_search tool)
//   2. rows in roz_web_lookup_allowlist      (which domains — listing portals are marketing)
// The grammar (the wall) exists regardless; nothing surfaces until both are on.

/** How a single web claim stands against the public record. */
export type WebVsRecordOutcome =
  | 'agrees'        // web value matches the record — corroboration
  | 'disagrees'     // web value conflicts — FLAG; the public record wins
  | 'unverifiable'  // no record counterpart (marketing copy) — a listing claim only, never a fact

/** One field, compared. The record is the anchor; the web value is attributed and perishable. */
export interface WebFieldClaim {
  field: string                          // machine key, e.g. 'livingSqft'
  label: string                          // human label, e.g. 'Living area'
  webValue: string | number | null        // what the site claims
  webSource: string                        // the SITE is the subject, e.g. 'Zillow'
  retrievedAt: string                      // ISO — web claims are perishable, always stamped
  recordValue?: string | number | null     // public-record counterpart, if any
  recordSource?: string | null             // e.g. 'Volusia County CAMA'
  outcome: WebVsRecordOutcome
  note?: string                            // e.g. 'reconcile with the seller before pricing'
}

/**
 * Listing presence is a null with a REASON — "no listing found" is never "not for sale".
 * The three reasons are kept distinct so a lookup miss can't read as an off-market fact.
 */
export type ListingPresence =
  | { status: 'found'; sites: string[]; retrievedAt: string }
  | {
      status: 'none'
      reason: 'off_market' | 'no_address_match' | 'unretrievable'
      sites: string[]
      retrievedAt: string
    }

/** The deliverable, both directions: buyer diligence and listing-agent pre-flight. */
export interface DiscrepancyReport {
  parcelId: string
  listing: ListingPresence
  fields: WebFieldClaim[]
  summary: { agrees: number; disagrees: number; unverifiable: number }
}
