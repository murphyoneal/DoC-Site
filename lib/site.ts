// Canonical public host. The apex is live on Vercel + Cloudflare, attached to
// do-c-site, serving 200 with a valid cert. Every canonical URL, sitemap entry,
// metadataBase, JSON-LD `url`, and vCard/QR fallback MUST read from this constant
// so they can never drift apart again.
//
// THE BRAND SPLIT (ruled 2026-09-05). These are SEPARATE PRODUCTS, not one product
// mid-rename:
//
//   DoP  Department of Property      the parent, and the LAND
//                                    departmentofproperty.com — this repo (DoC-Site).
//                                    PIR is sold here.
//   DoC  Department of Construction  CONSTRUCTION and the TRADES
//                                    departmentofconstruction.com — repo DoC-Public,
//                                    its own deploy. Serves the contractor register.
//   DoA  AddressFolder               the homeowner side; draws on BOTH.
//                                    addressfolder.com (US) · homeproblems.co.nz (NZ).
//
// CORRECTED 2026-09-22 — the note that stood here was true when written and is now
// FALSE. It read: "departmentofconstruction.com is the DEAD prior name (no A/MX
// record, nothing indexed, 301s here later)." That domain returns 200 today and
// serves the live contractor register out of DoC-Public/main. It is not a retired
// name. It is a live sibling product.
//
// Why the correction matters more than a stale comment usually does: the
// "Department of Construction" brand copy still sitting in THIS app's titles and
// chrome is a pending rename pass, and a rename pass that trusted the old note
// would read DoC as a dead brand to erase — stripping the brand off a product that
// is currently serving the public. The rename is scoped to THIS REPO and stops at
// the DoC-Public boundary.
//
// SITE_URL is unchanged and still means "the canonical host for THIS app". It was
// never correct to emit departmentofconstruction.com from here — that part of the
// old note still holds. The reason changed, not the rule: it is a different
// product's host, not a former name of this one.
export const SITE_URL = 'https://departmentofproperty.com'

// ── ONE APP, TWO HOSTS (ruling 2026-09-27, work order 691) ────────────────────────────────
// Contractors are Department of Construction; land, PIR and agents are Department of Property.
// This one deployment serves both domains and DoC-Public retires. The layout, robots and sitemap
// pick their brand from the request host; next.config.ts carries the permanent cross-domain
// redirects.
//
// DOMAIN_SPLIT is the switch, and it is a CODE constant on purpose: flipping it is a reviewed
// commit, not a dashboard toggle. It stays false until departmentofconstruction.com is attached
// to THIS project and verified serving it. While false, nothing changes on departmentofproperty.com
// (no redirects; contractor links, QR targets and vCards keep the DoP host), so this can ship
// before the domain moves. When true: DoP contractor paths 308 to DoC (path and query kept, so
// ?ref=qr survives), and every contractor URL this app emits uses DOC_URL.
//
// The redirects are PERMANENT INFRASTRUCTURE: every QR code printed so far encodes
// departmentofproperty.com. Never remove them.
export const DOP_URL = 'https://departmentofproperty.com'
export const DOC_URL = 'https://departmentofconstruction.com'
export const DOMAIN_SPLIT = false

/** Base URL for contractor surfaces (profiles, claim, QR, vCard, county and rights pages). */
export const CONTRACTOR_URL = DOMAIN_SPLIT ? DOC_URL : DOP_URL
export const CONTRACTOR_BRAND = DOMAIN_SPLIT ? 'Department of Construction' : 'Department of Property'

/** True for departmentofconstruction.com and its www. The host header may carry a port locally. */
export function isDocHost(host: string | null | undefined): boolean {
  return /(^|\.)departmentofconstruction\.com$/i.test(String(host ?? '').split(':')[0])
}
