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
