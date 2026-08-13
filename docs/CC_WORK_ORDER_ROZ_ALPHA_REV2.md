# CC Work Order — Roz Alpha, Revision 2

**Supersedes:** `docs/CC_WORK_ORDER_ROZ_ALPHA.md` (rev 1)
**Companion:** `docs/ROZ_ENVIRONMENT_SPEC.md`
**Payload inventory / test oracle:** `docs/PROPERTY_DATA_MAP_1778_EARHART.md`
**Project:** `eaifqorwmgayiqmbtzcg`
**Target:** single confidential alpha user, Volusia only, comped, fully instrumented

---

## Standing rules

Each has cost a real failure. They apply to every task.

1. **Set-diff against live source counts.** Internal consistency is not verification.
2. **`empty ≠ done`.** Test `count(*) > 0`, never table existence. Assert non-zero after every load. Keep an explicit FAILED list.
3. **Never print a summary that implies success.** Skipped means skipped.
4. **Probe the OID field from layer metadata.** Never hardcode `objectid`.
5. **Abort and touch nothing if `returnIdsOnly` returns empty.**
6. **Chunk COPY at 50k**, `statement_timeout=0`.
7. **Rename indexes when renaming a table.**
8. **Round numbers are suspect.** 20,000 was a paging cap.
9. **Uniform values are suspect.** No genuine per-parcel measurement is constant across a county. This rule found 61 placeholder fields.
10. **Report per task:** what ran, verified against what source, what was skipped, what failed.

---

## 0. Status

### Complete and independently verified

| Item | Result |
|---|---|
| Tanks sentinel | 74,262 total / 72,357 usable / 1,905 `location_known=false`, geom nulled |
| Permit pivot | 128 rows corrected −100yr; max year 2026, 0 future rows; overdue 1,108 → 1,116 |
| GWCA set-diff | **376/376, zero diff** — the 144,842-home claim rests on a complete layer |
| Remaining set-diffs | PCTS, drycleaning, `sjrwmd_wells` clean; PNP +2 upstream drift; **no layer holds phantom rows** |
| Private table revocation | `service_role`, `anon`, `authenticated`, PUBLIC all denied on both `_private` tables. Closed a real `service_role` SELECT leak on `volusia_arrest_reports_private` |
| `roz_payload_reader` | created, 10 explicit grants, 0 on private tables |
| Capture tables | 6 created, RLS on, service-role only; version register append-only; `ops_event` emitters cannot set severity; classifier re-runnable over history |
| Licence gate | `agent_license_eligible` = **350,492 / 493,556**; daily pg_cron recheck jobid 4 |
| Query log | `user_query`, `response_text`, `roz_version`, `payload_hash` added |
| `derived_field_status` | 63 fields registered, **2 computed / 61 not_computed**, 7 with sources loaded |

### Decisions closed

| Gate | Decision |
|---|---|
| **G1** | **Snapshot the payload** into `assistant_query_log`. Do not version the record. At one user the storage is trivial and it is the only option where a week-one opinion stays verifiable in week five. |
| **G2** | **Lazy-on-access with cache** for the alpha. Full precompute remains the production target and gets built against a real payload shape. Reinforced by the PIR layout being unreviewed — do not precompute 313,578 records against an unsettled shape. |
| **G3** | **Roz is greenfield.** No chat surface, route or prompt exists. The existing B2B assistant is architecturally opposite — tool-using agentic loop with live DB queries and Pro-tier cross-property tools. Reuse the chat shell and logging; the tool/DB architecture must be absent. |
| **G4** | **Withdrawn.** Payload inventory derives from `PROPERTY_DATA_MAP_1778_EARHART.md`. The PIR example is illustrative only; no field in it is approved. |

---

## 1. Architecture corrections — read before Batch 3

Four findings from Batches 1–2 changed the design. These override rev 1.

### 1.1 `property_environmental` and `property_hazard_risk` are scaffolding

**61 of 63 derived fields are placeholder.** 38 all-null, 21 uniform across all 313,578 rows, 2 null-with-source. Only `airport_distance_m` (11,667 distinct values) and `in_flight_path` are real, and only because of remediation.

The layer's own `source_attribution` states it: *"Parcel-level spatial joins for proximity fields … pending geocoding completion."* This is not interpretation. The table documents itself as unbuilt.

**Most dangerous class — four uniform proximity zeros** on every parcel in the county: `superfund_sites_3km`, `tri_facilities_1km`, `brownfield_sites_1km`, `underground_storage_tanks_500m`. These render as a fabricated contamination all-clear, which is worse than a null because it reads as a checked negative. All four sources are already loaded.

**Consequence:** the payload does **not** read from these tables. It reads from the verified cross-reference tables — `gwca_parcel_match` (195,358 rows), `well_gwca_flag` (2,803), `well_icr_flag` (566), and the `fdep_*` source layers — with `derived_field_status` stamping everything else.

### 1.2 The lens model — resolution is part of the value

Layers bind to a parcel at different levels, and descending the levels narrows *relevance* without increasing *precision*. A tract statistic is not a fact about a house inside the tract. A zone polygon boundary **is** a fact about the parcel, because the rule attaches to location.

| Lens | Layer examples | May support a claim about the parcel? |
|---|---|---|
| State | BEBR, OIR, DOR | context only |
| County | BLS LAUS/QCEW, tax authority | context only |
| Municipality / district | school attendance, fire, utility service | yes |
| Census tract / block group | ACS, CHAS, HMDA | statistical only, never individual |
| Zone polygon | GWCA, flood zone, wellfield protection | **yes — statutory force** |
| Parcel | CAMA, geometry, permits | yes |
| Interest | condo unit, severed mineral estate | below parcel |

**Every payload field therefore carries six things:**

```
value
field_status        present | null_at_source | layer_not_loaded
                    | county_not_covered | stale | conflicting_sources
                    | not_computed
as_of
source
resolution_level    state | county | municipality | tract | zone | parcel | interest
relation            contains | intersects | within_distance | adjacent   (spatial only)
```

`fdep_institutional_controls` already carries `resolution_level` — generalise that pattern, don't invent one.

**Containment beats distance.** A count at an arbitrary radius is the weak construction and it is the one currently fabricating zeros. Spatial containment against a polygon with statutory force is the strong one. Build the seven fields as containment-plus-relation, not as radius counts.

**Partial containment is a real state.** A parcel straddling a boundary is neither in nor out — expect this constantly with 1,000-foot setback zones and larger parcels. That is what `relation` is for.

### 1.3 `field_status` must be per cell, not per field

`pfas_detected` has 3 genuine matches out of 313,578 and reads as uniform to a table-wide test. A correctly sparse result and a placeholder are indistinguishable at field level. `derived_field_status` is correct for the audit; the payload needs per-cell status.

### 1.4 Tanks and contamination are one source

**72,352 of 72,357 contamination points are `ST_Equals` to a tank point** — verified, and reproduced independently at 3000/3000 on a fresh sample. STCM layer 1 (Registered Tanks) and layer 5 (Contamination Monitoring) are the same facilities as two attribute views. `fdep_clm` PETRO (6,610) equals its STCM `source_database` count exactly, so those rows are index pointers into the same set.

**One leaking tank must never surface as three findings.** Dedup rule is written into `env_layer_catalog`; the payload builder must honour it.

---

## 2. BATCH 3

### 3.1 Discovery — report before building anything

**`auth.users` = 0. `auth.identities` = 0. `auth.sessions` = 0.** There is no authentication in this system. Not misconfigured — absent. Every route reaches the database through the secret key, which is why RLS-with-no-policies never broke anything.

Report:

- Is Supabase Auth configured at all — providers enabled, email templates, redirect URLs, SMTP configured or default?
- Does DoC-Site have any sign-in route, session middleware, or auth handling, or is every route unauthenticated?
- Is `app/api/assistant/route.ts` deployed and reachable in production, and what if anything gates it? *(Carried from Batch 2 — still unanswered.)*
- Does `pir.ts` surface storage tanks and contamination monitoring as **separate** findings? If so the double-count is live in the existing product.

The auth answer determines whether 3.2 is wiring or greenfield. Do not start it before reporting.

### 3.2 Auth foundation

Auth is upstream of everything else on the alpha path. Profile needs an identity, password reset needs an account, entitlements need a subject, per-user telemetry needs a user, and Roz needs to know who is asking.

- **Supabase Auth, email + password.** Use the built-in flows; do not hand-roll token handling.
- **Invite-only. No public signup.** Single-use invite token, bound to a specific email address, expiring, stored as a hash. Log consumption — a token used twice is a signal.
- **Password reset via Supabase's own flow.**
- **Session middleware** on every non-public route.
- **Verify SPF, DKIM and DMARC on the sending domain before the first invite is sent.** A new domain's first transactional email is the worst possible deliverability test. Emit `email_queued`, `email_sent`, `email_delivered`, `email_bounced`, `email_deferred`, `link_clicked`, `email_verified` as separate `ops_event` rows from provider webhooks. **Delivered and clicked are different facts** — without the delivery event, a broken pipeline is indistinguishable from an uninterested user, and those have opposite responses.
- **Re-send must exist**, and each re-send is an event. One spam-foldered email otherwise ends the alpha.

### 3.3 `agent_profile`

Keyed to `auth.users.id`:

- `license_number` — validated against `agent_license_eligible` at registration **and** on the daily recheck
- `name`, `employing_broker`, contact
- entitlement reference
- `accepted_version` → `user_version_acceptance`

**Identity limitation to record explicitly:** the roster carries no email, phone or address. It proves a licence exists and is current; it cannot prove the person typing owns it. Name and licence number are both public. For the alpha this is covered because the invite is issued personally out of band — log it as `invite_issued_by` plus address plus date plus licence claimed, and record it as *a licence claimed by an invited person*, not as verified licensee identity. That distinction matters the day an account's actions are disputed.

**Name matching will be the friction.** `agent_license_roster.name` is a single text field in surname-first form (`LETIZIA, ALEXIS B`). Test the exact match against the real licence before she registers, and decide whether a near-miss blocks, warns, or logs. `county` and `employing_broker` give two corroborating fields worth using.

**Registration emits step-by-step to `ops_event`:** licence entered, lookup result, status evaluated, terms shown, terms accepted, entitlement granted, first session opened — failures included. If she abandons, you need the step. **Capture device and IP at first touch** — it is the cleanest baseline and it happens once.

**Q&A&O covers registration too.** One exchange, `subsystem = 'registration'`, same open text field. Her opinion on the signup flow is only available once.

**Do not let her be first through it.** Register a throwaway licence number from the roster against a test account, walk the whole flow including the email, then hand it over.

### 3.4 Entitlements — Phase 2.8

`consumer_accounts` is 0 rows and its columns are `email, display_name, stripe_customer_id, first_purchase_at, last_purchase_at, purchase_count`. **The account model is the purchase model** — there is no path to access without a payment record.

Build entitlements as a separate concept: grantable, time-boxed, revocable, logged. **Not** a "payments disabled" flag, which has to be unwound later with live users in the table.

### 3.5 The seven computable fields — to the resolution contract

Sources already loaded. Build to §1.2, **not** as radius counts:

| Field | Source | Build as |
|---|---|---|
| `underground_storage_tanks_500m` | `fdep_stcm_tanks` | containment + distance, `relation` set; **sentinel now excluded** |
| `superfund_sites_3km` | `hifld_superfund_sites` | containment + distance |
| `brownfield_sites_1km` | `fdep_brownfield_sites` / `_areas` | containment + `relation` |
| `tri_facilities_1km` | `hifld_frs_relevant` | containment + distance |
| `landfill_distance_m` | `epa_landfills` — **75 rows, federal subset only, not a Florida inventory** | distance, with coverage caveat in status |
| `pfas_detected` / `pfas_level_ppt` | `fdep_clm` | per-cell status; 3 present, remainder `not_computed` |

Four of these currently fabricate a contamination all-clear. Fixing them converts the worst defects in the database into the strongest content Roz will have. **Flip `derived_field_status` to `computed` only on verified output, per field, with the verification basis recorded.**

Honour the §1.4 dedup rule: tanks and contamination are one facility set.

### 3.6 Permit intake collector — start now, data is perishable

`volusia_current_permits` holds 2,930 rows and carries **`indate`** — the application intake timestamp. `property_permit_history` has issue, completion and CO dates but **no application date**, so permitting *delay* is currently unmeasurable.

The source publishes intake. Nothing archives it. Every day without a snapshot is duration data permanently lost, and it cannot be backfilled — same rule as the weekly snapshot archive.

Build a daily collector → `volusia_current_permits_history`, preserving `indate`, `statuscode`, `statusdesc`, `councildistrict`. Small job, starts paying immediately, independent of everything else in this batch.

---

## 3. Held — not in this batch

| Item | Why |
|---|---|
| **Listings** | Large surface: media, syndication, fair housing exposure on how listings surface and filter. Tests none of the data logic the alpha exists to test. She cannot log in yet. |
| **Cohort / daily B2B report** | Needs a subject and a delivery address, so it is behind auth and entitlements. See §4 for what already exists. |
| **Roz herself (Phase 4)** | Behind the payload. Behavioural spec is settled in `ROZ_ENVIRONMENT_SPEC.md` §0–§5. |
| **Full precompute** | G2 — lazy with cache for alpha. |
| **`wui_zone`** | No WUI source layer exists. Leave as `not_computed`; do not fabricate. |

---

## 4. Cohort / daily report — findings for when it is scoped

Better positioned than expected. **Do not build yet**, but the constraints are known:

**Change history that exists:** `volusia_official_records_private` — 606 distinct weeks, 2015-01-01 → 2026-07-16, latest recorded date 2026-07-20, 1.27M rows. Also `volusia_cama_snapshot_log`, `volusia_basemap_changes`, `volusia_cities_dissolved_weekly`, `property_transaction_history`, `license_eligibility_snapshot`.

**Detectable changes:** recorded deeds and transfers, liens and lis pendens, permits, ownership changes, licence status. A lis pendens is a distress signal months ahead of a listing, and no MLS feed carries it.

**Not detectable:** new listings, price changes, days-on-market. That is MLS. Say so early — "daily report" will read as hotsheet, and this instrument reports what was *recorded*, not what was *listed*.

**Extraction bites here, not at Roz.** A territory report is a legitimate bulk-delivery channel; define territory as all of Volusia and receive the database in daily instalments. Needs a territory area cap, a record cap per delivery, and every run logged to `b2b_query_log` (which already has `allowed` / `denial_reason`). Roz's payload-only boundary does not cover this surface.

**Unresolved policy question:** parcel-level lists of identifiable households delivered to a third party. Aggregate-only was already ruled for contractors; this is the same shape with a different recipient. Recorded deeds are public and defensible. Permit-derived "about to spend $20k" is closer to the line. Decide per signal type, not for the product as a whole.

---

## 5. Carried — do not let these displace Batch 3

- **SRID-0 reprojection** — Seminole, Lake, Osceola. Reload `school_attendance_zones` separately. **Verify centroids land in-county afterward** — wrong projection moves parcels silently rather than erroring.
- **Identify `parcels_staging`** — 21 GB, 10,327,257 rows, unknown provenance, 504,667 short of the cadastral yet physically larger. Quarter of an 81 GB database, top cost line. Identify before dropping anything.
- **Then drop** `orange_parcels_govt_source_abandoned_20260722` (725 MB).
- **`fema_flood_zones`** — 1,210 MB index on 232 MB table, unregistered, no source URL.
- **~45 unregistered tables** — cannot produce a valid `field_status`. Register or exclude from payload; do not let them render as silence.
- **Roof material join** — `VCPA_CAMA_RES_BLDG` roof cover. Asphalt 15–25, tile 40–50, metal 40–70 years. Without it the layer calls tile roofs overdue with thirty years left.
- **Trade classification** — 576,254 rows (58.6%) in `other / other`.
- **Absence signal** — parcels with no roofing permit against `ACT_YR_BLT`. Stronger agent lead than a documented roof, currently invisible.
- **Naming** — `epa_landfills` is 75 rows and not a Florida inventory. Also `miamidade_dump_sites` (21), `orange_solid_waste_transfer_landfill` (4).
- **Brownfield duplication** — 571 + 624 statewide plus ~90 per-county tables on the same sites.
- **`properties` is Volusia-only** — all 313,578 rows, co_no 74. The derived layer is one county, so every defect in §1.1 gets rebuilt 66 more times unless `not_computed`-by-default is baked into the layer definition first. `derived_field_status` is that guard.

---

## 6. Suggested order

1. **3.1 discovery** — report, change nothing
2. **3.6 permit collector** — perishable, independent, small
3. **3.2 auth** — gates everything else
4. **3.5 the seven fields** — converts the worst defects into Roz's best content
5. **3.3 profile + registration events**
6. **3.4 entitlements**

Then Phase 3 payload, then Phase 4 Roz.
