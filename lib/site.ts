// Canonical public host. The apex is live on Vercel + Cloudflare, attached to
// do-c-site, serving 200 with a valid cert. Every canonical URL, sitemap entry,
// metadataBase, JSON-LD `url`, and vCard/QR fallback MUST read from this constant
// so they can never drift apart again.
//
// NOTE: departmentofconstruction.com is the DEAD prior name (no A/MX record,
// nothing indexed, 301s here later). It is never a canonical target — do not
// reintroduce it as a host. The "Department of Construction" brand copy in
// titles/chrome/footer is a separate rename pass and is intentionally untouched.
export const SITE_URL = 'https://departmentofproperty.com'
