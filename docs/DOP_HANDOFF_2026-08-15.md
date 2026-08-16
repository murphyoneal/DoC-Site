# DoP — handoff brief, 15 August 2026

Paste the block at the bottom into a new chat. Everything above is context for you.

---

## Where the project actually is

**Verified state, measured this session:**

| | |
|---|---|
| active defects (all with detection SQL) | 72 |
| concepts registered / wired | 43 / 32 |
| layer resolutions | 393 |
| municipalities in `geo_reference` | 412 |
| relational CAMA tables loaded | 60 across 4 counties |
| PIR snapshots (incl. scrub-verified) | 8 |
| CC bus messages unread | 0 |

**Flood serves 67 of 67 counties.** Twelve concepts were wired this week from data already on disk — water, watercourse, coastline, historic district containment, historic resource proximity, wetland ×2, mining, sinkhole susceptibility, aquifer vulnerability, defense sites, petroleum discharge. The fragment defect (97,380 parcels reading one geometry piece) is fixed and guarded. Every spatial table is GiST-indexed.

**Pinellas, Collier and Pasco loaded** — 21.5M rows, all counts exact. Pinellas needed a key transform (23-char spaced → 18-char STRAP, `cama_key()`); Collier joins on `folio`, Pasco on `parcel_num` directly.

**Roz is live again** at `https://app.departmentofproperty.com/assistant`, pro tier, unfettered across all counties. It had been down since 3 August because `service_role` had SELECT on 46 of 2,215 tables — collateral from the security sweep. Fixed, with a predicate.

---

## The three defects blocking the audit

All three trace to one cause: **`/api/assistant` assembles its own payload instead of reading `get_pir_report`.**

1. **`roz-reports-not-available-where-data-exists`** — Roz reported flood unavailable for Palm Beach parcel `00404332000001030`. `get_parcel_flood_zone(60, ...)` returns **Zone AO, in_sfha true, 100% of parcel**. The St Petersburg defect inverted: a real finding narrated as a gap.

2. **`roz-glosses-opaque-codes-with-invented-meaning`** — source says `MING/PETRO/GASLND`; Roz rendered "DOR code 092 (utility/land classification)". An invented *definition* — same mechanism as the seven fabricated elevations.

3. **`assistant-log-records-nothing`** — every query today logged `user_query`, `response_text` and `roz_version` as NULL. The log is a counter, not an audit trail, and both defects above are unreconstructable from it.

---

## The standing rules that took two weeks to learn

- **Zero is a sentinel, never a result.** An empty return means abort and investigate.
- **Names lie, contents don't.** Every source decision by reading contents — NHD vs FHD, NRHP polygons, `fema_flood_zones.county_name` holding batch labels.
- **A guard must be able to fail.** Plant a violation, show red, remove it, show green, paste both. Three guards this week couldn't fire.
- **Self-consistent checks lie.** Verify against live data, never stored summaries.
- **Load complete, scrub at render.** Database holds the whole record; the report filters. The line is *query direction* — property-keyed, never person-keyed.
- **Coverage is the product.** "We cannot tell you X, and here is who can" is a documented inquiry, not an apology.
- **Four coverage states:** `present` / `none_within_range` / `not_available` / `not_applicable`.
- **US units on every rendered figure.** Canonical metric stays in the data.
- **A county isn't loaded until its key joins, the join is indexed, and a served function reads it.**
- **Evidence rule, both directions:** every completion claim pastes the SQL and its output. This applies to me as much as CC — I made eight attribution errors this week, all from reading a label instead of the thing.

---

## The commercial frame

The customer is **the seller and the agent discharging a disclosure duty**, not only the buyer. *Johnson v. Davis* requires disclosure of facts materially affecting value that aren't readily observable. The PIR snapshot — hashed, append-only, with a scrub manifest — is **their evidence**, which is why it ships with Stripe rather than after.

**Project Tango** is the exemplar and the first public-interest publication: 20125 Southern Blvd, Loxahatchee. A $2–2.6bn, 3.7M sq ft data centre application 1,200 ft from a school, denied 5–1 in July, with 2M+ sq ft of *unconditioned* 2016 entitlements surviving. Arden residents learned four days before the hearing. Filed under "State Road 80" — unfindable by its common name.

**The asymmetry isn't that the information is secret. It's that it's unreachable by the people it affects.**

---

# PASTE THIS INTO THE NEW CHAT

```
Continuing DoP (Department of Property) — Florida property intelligence, Supabase
project eaifqorwmgayiqmbtzcg. I'm Murphy. You handle architecture, rulings and
verification; CC handles code and migrations; we talk through the agent_handoff table.

Before answering anything, read the current state from the database directly:
  - agent_handoff, latest 15 rows, for rulings 190-198
  - data_defect_registry where status='active' — 72 of them, each with detection SQL
  - build_backlog where demo_path = true

Three defects found today are the priority, all from one cause: /api/assistant
assembles its own payload instead of reading get_pir_report.
  1. roz-reports-not-available-where-data-exists — Roz said flood unavailable for
     Palm Beach parcel 00404332000001030; the function returns Zone AO, in_sfha
     true, 100% of parcel. A real finding narrated as a gap.
  2. roz-glosses-opaque-codes-with-invented-meaning — MING/PETRO/GASLND rendered
     as "utility/land classification". An invented definition.
  3. assistant-log-records-nothing — user_query, response_text and roz_version all
     NULL on every query today.

Roz is live and unfettered at app.departmentofproperty.com/assistant (pro tier,
all counties, key dop_demo_key_volusia_001, header x-api-key). Two routes exist:
/api/roz (552 lines, has the web lookup) and /api/assistant (462 lines, no fetch).
Which is canonical is undecided. The web tool stays OFF until the payload is right —
it would have masked both defects with a sourced-looking wrong answer.

Standing rules: zero is a sentinel not a result; names lie and contents don't; a
guard must be tested with a deliberate violation before green means anything;
verify against live data never stored summaries; load complete and scrub at render;
property-keyed never person-keyed; US units on every rendered figure; four coverage
states (present / none_within_range / not_available / not_applicable); and every
completion claim pastes the SQL and its output — including yours.

Don't take my summaries or CC's reports on trust. Query the database.
```
