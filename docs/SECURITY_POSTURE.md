# Security Posture — DoP / DoC-Site

**As of 2026-07-25.** Evidence-based; verified against the live database and git history, not inferred. This document is the reference to check rather than a question to re-ask.

---

## Summary

The application reads data through **`postgres`-owned SECURITY DEFINER functions**, not through table grants. The Postgres role the app authenticates as (`service_role`, via the secret key) has **no direct SELECT on any bulk table** and cannot run the SECURITY INVOKER functions. The two private tables are revoked from every app-facing role. There is **no export, download, or email surface** — the only tool surface is Q&A&O (question → answer → opinion). The one genuinely open exposure is a **legacy `service_role` JWT in public git history**; its mitigation is confirming that key is disabled in Supabase.

---

## 1. How the app reads data — function-mediated

- Every app data function is **owned by `postgres`**.
- **PIR reads are `SECURITY DEFINER`** (`get_pir_report`, `get_pir_map_geojson`, `get_pir_parcel_closeup`) — the query body executes **as `postgres`**, regardless of caller. This is why the app works without granting the app role table access.
- The `SECURITY INVOKER` functions (`get_site_intelligence`, `find_parcels`, `search_properties`, `get_nearby_amenities`, `parcels_in_view`) execute **as the caller** and are **denied to `service_role`** (verified).
- **Reads are function-mediated, not table-direct.** A question cannot become an arbitrary query: the boundary is code-shaped, via parameterised functions.

## 2. No table grants to app roles

- `service_role` holds only `TRUNCATE / REFERENCES / TRIGGER` (the Supabase default) on `properties`, `parcels_staging`, `fl_cadastral_dor_statewide`, `property_permit_history`, `b2b_accounts`, `county_registry` — **no SELECT / INSERT / UPDATE / DELETE**. Verified empirically: as `service_role`, direct `SELECT` on each is **permission denied**.
- This was **never granted** (not a revoke — the bulk-loaded, `postgres`-owned tables never received the app-role SELECT grant). A leaked `service_role` key therefore **cannot dump tables directly**; it can only invoke the DEFINER functions (parameterised, per-parcel, public-record property data).

## 3. Private tables — revoked

- `volusia_arrest_reports_private` (47 rows) and `volusia_official_records_private` (1.27M rows) grant **only `postgres`**. `service_role`, `anon`, `authenticated`, and `PUBLIC` are fully revoked (verified: `service_role` SELECT → denied). Third-party personal data is structurally out of every app path.

## 4. No export surface

- There is **no export, download, or email surface** — not restricted, simply unbuilt. The assistant's tool surface is limited to single-property and (Pro) fixed-filter cross-property lookups plus opinion capture (Q&A&O). **Do not build a bulk export/download/email surface during the alpha.**

## 5. Browser / key exposure

- **No secret key reaches the browser.** `SUPABASE_SECRET_KEY` is referenced only in server files (`lib/supabase/server.ts`, sockets, API routes, server-component pages); **no `'use client'` component references it**. The only `NEXT_PUBLIC_` variables are non-secret: `NEXT_PUBLIC_SUPABASE_URL` (public), `NEXT_PUBLIC_MAPBOX_TOKEN` (publishable), `NEXT_PUBLIC_APP_URL`.
- Current source contains **no hardcoded keys**.

## 6. Open exposure — legacy JWT in public git history

- `github.com/murphyoneal/DoC-Site` is **public**. Git history (old commits) contains a **hardcoded legacy `service_role` JWT** (`eyJ…`) in former versions of app pages, sockets, and geocode scripts. It was removed from the working tree but remains permanently in history.
- **Required action:** confirm in the Supabase dashboard that the **legacy JWT secret is disabled / the exposed key is rotated**. Until confirmed, treat the historical key as potentially live. No other secret (connection string, Resend, Anthropic, new-format `sb_secret`) appears in history.

## Threat model — attacker with the public repo + the deployed site, nothing else

They lift the legacy `service_role` JWT from git history. **If still enabled:** they reach the PostgREST API as `service_role` — but with no direct SELECT and no INVOKER-function access, they are limited to the SECURITY DEFINER functions (per-parcel property reports, public-record data, already anon-callable). They **cannot** dump the database and **cannot** reach the private arrest/official-records tables. **If disabled/rotated:** the repo yields nothing live. From the deployed site: public property-report functions and the API-key-gated assistant; no key in the browser, no direct DB access. **Worst realistic case: per-parcel public-record reads, not a database dump — contingent entirely on whether the historical JWT is still enabled.**

## Engineering protections (the only two, both invisible to any tester)

1. **Secret key stays server-side** — never in browser-reachable JavaScript. It bypasses RLS, so client-side exposure would be total database exposure. Same failure class as the key that reached GitHub.
2. **Parameterised functions, never prompt-driven raw SQL** — a question cannot become an arbitrary query.

## Verify list (not changes — checks)

- [ ] Legacy `service_role` JWT disabled in Supabase (the one open exposure).
- [ ] Confirm which app features actually serve data in production (PIR works via DEFINER; INVOKER-based property-map / assistant paths are denied to `service_role`).
