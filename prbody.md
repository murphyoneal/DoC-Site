## SEO canonical/kill-switch + PIR non-Volusia correctness (item 112)

Two workstreams on this branch. **(A)** the public-indexing / canonical-host / Florida-landing fixes; the site stays **noindex** until the brand-rename pass lands and the kill-switch is deliberately flipped. **(B)** item 112 — `get_pir_report` was serving Volusia-only data as universal, making non-Volusia reports *wrong* (false negatives), not merely thin.

> **Deploy ordering — read before merge.** The item-112 database functions (`get_pir_report`, new `get_parcel_econzone_facts`) are **already live in production** (applied directly to Supabase). The **consuming front-end ships in this PR**. The round-1 economic change was a payload-shape change made ahead of the front-end; that was only safe because `pir_purchases` is empty (the economic section is purchase-gated, so the mis-render window is empty). The class-(b) round was made **additive** (new keys only) so the current prod front-end is unaffected regardless. **Going forward, payload-shape changes must not precede their consuming code** — make them additive or hold the migration until the front-end merges. Merging this PR closes the gap.

### 1. Index kill-switch

- New `app/robots.ts` **replaces** the static `public/robots.txt`, and a site-wide meta-robots `noindex` in `app/layout.tsx`. Both are gated on `SITE_INDEXABLE === "true"` (build-time; flipping it needs a redeploy) so `robots.txt` and the meta tag can never disagree.
- Default is **OFF** — everything stays noindex until we're ready.

### 2. Canonical host reconciliation

`departmentofproperty.com` is the live apex (200 + valid cert); `departmentofconstruction.com` is the dead prior name (no A/MX record).

- New `lib/site.ts` centralizes the host as `SITE_URL`, single source of truth.
- Every **functional** reference repointed at the constant: `sitemap.ts` (was serving 62 URLs — incl. all 50 `/rights/[state]` — on the dead host), `layout` `metadataBase` + Org/WebSite JSON-LD, `rights/page`, `StateRightsLanding`, the vCard/QR route fallbacks (printed artifacts), and the QR sentence in `disclaimer/page.tsx`.

### 3. Florida landing

- List only counties we actually hold parcel data for: drop Broward/Palm Beach/Hillsborough/Pinellas/Duval (no data); add Seminole (Sanford), Osceola (Kissimmee), Lake (Tavares). Cards now match the county landing pages that resolve.
- `CountyLanding` repointed at `SITE_URL`.

### 4. AppShell

- Non-navigating "Listing check" soon-placeholder in the nav (draft-listing vs public-record pre-flight). Plain span, no dead link.

### 5. Item 112 — non-Volusia PIR correctness

`get_pir_report` queried Volusia-only tables as if universal, so a non-Volusia parcel got `null`/`[]` that the report rendered as definite negatives ("None mapped within 5 mi", "No assigned schools", null map pin). Fixed at the source with an explicit **coverage model** so the report tells apart *present* / *none in a covered county (a real negative)* / *not_available (a coverage gap, routed to §7 "What we couldn't tell you" with who-answers)*.

- **Economic overlays** (Opportunity Zone / HUBZone / Enterprise Zone / CRA) → new `get_parcel_econzone_facts` resolving each against the statewide `funnel_*` resolvers, three-state coverage. Coverage is decided by **content** (a funnel feature's interior point falling inside the county), not table names — `ST_Intersects` on the county polygon false-positived (a Volusia HUBZone edge crossed the Marion line). `not_available` routes to §7 with its authority (OZ→CDFI Fund, HUBZone→SBA, etc.).
- **Map pin** — `meta.lat/lng` now from `resolve_parcel_geometry` (fragment-safe union) + `ST_PointOnSurface`, and **null when unresolvable** — no county-centroid fallback. Was the Volusia centroid table → null off-Volusia. Marion and St. Johns now return real pins.
- **Gopher-tortoise habitat & school assignment** — Volusia-only layers, now carry an explicit coverage state (`land.gopherTortoiseCoverage`, `schoolsCoverage`) so off-Volusia reads "not evaluated — ask {FWC / the county school district}" instead of asserting a negative. (We deliberately did **not** surface `get_nearby_amenities` schools as a "nearby" middle state — that layer returns a single, often mislabelled row; Marion's nearest "school" is a juvenile detention center. Registered as a data defect.)
- Deleted the dead inline `volusia_cama_permits` aggregation (computed, never emitted; `permitFacts` supersedes).

Every change verified end-to-end on real Marion / St. Johns / Volusia parcels, with a per-key md5 diff on the Volusia parcel proving only the intended sections changed. `legal`-from-NAL was investigated and dropped — the parcel spine carries no legal column, so there is no statewide source.

### Deliberately left for the separate brand-rename pass

- The `hello@departmentofconstruction.com` mailto in `claim/[slug]` (no MX on either domain).
- The "Department of Construction" brand name in chrome/footer/disclaimer prose.

Rule: a URL in prose is functional and gets fixed now; a brand name is cosmetic and waits.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
