# CC Work Order — Roz Alpha Build

**Companion to:** `docs/ROZ_ENVIRONMENT_SPEC.md`
**Target:** single confidential alpha user, Volusia only, comped access, fully instrumented
**Project:** `eaifqorwmgayiqmbtzcg`

---

## Standing rules for this work order

These have each cost a real failure. They apply to every task below.

1. **Set-diff against live source counts.** Internal consistency is not verification. A count that agrees with itself proves nothing.
2. **`empty ≠ done`.** Skip/resume predicates test `count(*) > 0`, never table existence. Assert non-zero after every load. Maintain an explicit FAILED list.
3. **Never print a summary that implies success.** If a step was skipped, the summary says skipped.
4. **Probe the OID field from layer metadata.** Never hardcode `objectid`.
5. **Abort and touch nothing if `returnIdsOnly` returns empty.** A down service reporting zero is not a source with zero rows.
6. **Chunk COPY at 50k rows**, `statement_timeout=0`.
7. **Rename indexes when renaming a table.** Postgres does not.
8. **Round numbers are suspect.** 20,000 was a paging cap. If a count lands on a round figure, prove it.
9. **Report back per task:** what ran, what was verified against what, what was skipped, what failed.

---

## DECISION GATES — blocked pending answers

Do not guess these. Everything outside the listed dependencies can proceed now.

| # | Question | Blocks |
|---|---|---|
| **G1** | Record versioning: version the parcel record, or snapshot the payload into `assistant_query_log`? | Phase 2.1 column choice, Phase 3.3 |
| **G2** | Full precompute of all 313,578 Volusia parcels, or lazy-on-access with cache? | Phase 3.3 only |
| **G3** | **Does Roz exist in code in DoC-Site?** Chat surface, API route, prompt file — any of it? | All of Phase 4 |
| **G4** | Is the PIR field map an existing document, and where? It should define payload scope rather than CC deciding it. | Phase 3.2 |

**G3 is the real blocker.** Report what exists in the repo before Phase 4 is scoped.

Also confirm: `b2b_accounts` has one row. Is it Alexis, Murphy, or a fixture? Determines create vs modify in Phase 2.8.

---

## PHASE 0 — Data defects that poison everything downstream

Independent of all gates. Do first. Each of these silently corrupts something built on top of it.

### 0.1 Tanks sentinel — **gates the 500m compute**

`fdep_stcm_tanks` has 1,905 rows at exactly `lon −87.930, lat 23.942` (min = max on both axes). That is a source sentinel meaning *location unknown*, not a bad geocode. It sits in the Gulf of Mexico.

It passes `geom IS NOT NULL`, so every completeness check reports 100%.

- Null the geometry on those rows, or add `location_known boolean` and set false
- Verify: `74,262` total, `72,357` with usable geometry, `1,905` flagged
- **Do not run `underground_storage_tanks_500m` before this.** Those rows match no parcel, so a property genuinely near one of these tanks returns clean — a silent false negative, which is the direction that causes harm in a report

### 0.2 Permit date pivot bug — **gates the entire replacement-window layer**

`property_permit_history.permit_date` spans **1969 → 2068**. Source is `volusia_cama_permits.PERMDT`, stored as `text`.

Those two endpoints are the signature of a two-digit year pivot: `69` → 1969, `68` → 2068.

- Identify the pivot rule in the parse
- **Count affected rows before changing anything** and report the number
- Reparse; verify max year ≤ current year
- Re-derive `years_since_install`, `in_replacement_window`, `replacement_urgency` afterward

Every figure in that layer is subtraction against this column. Rows thrown forward a century are the *oldest* houses — the exact cohort the layer exists to surface. It does not error. It classifies them as new.

### 0.3 GWCA set-diff — **gates the headline finding**

`fdep_gwca` is 376 polygons and it carries the 144,842-homes claim. Smallest table, largest number, never compared to source. A truncated page in a short polygon layer leaves no trace.

Set-diff against source. Report source count vs held count.

### 0.4 Remaining set-diffs

Never verified against source: `fdep_pnp` 16,032 · `fdep_pcts_discharges` 38,682 · `fdep_drycleaning_sites` 1,293 · `sjrwmd_wells` 20,376.

Also: 22 `sjrwmd_wells` rows have null county — resolve or document.

### 0.5 STCM contamination independence check

`74,262 − 1,905 = 72,357`, which is exactly `fdep_stcm_contamination`'s row count.

Probably coincidence. Confirm `fdep_stcm_contamination` is independently sourced and not the in-bbox subset of tanks under a second name. Sixty seconds, and if it is the same data the CLM precedence rule below is wrong.

### 0.6 CLM / STCM precedence rule

`fdep_clm` splits `source_database` as STCM 6,610 + ERIC 3,575, and its `PETRO` category count equals the STCM count exactly. Those petroleum rows are the same sites already held at higher resolution in `fdep_stcm_contamination`.

Write the precedence rule into `env_layer_catalog`: **STCM is the detail record, CLM is the index.** Without it a report counts one contamination event twice under two names.

### 0.7 gwca_parcel_match reconciliation

`gwca_parcel_match` holds 195,358 rows against a reported 144,842 homes. Presumably residential filtered from total. Document the filter explicitly in `env_layer_catalog` — the two numbers will otherwise be used interchangeably.

### 0.8 Constraint as data, not copy

Write into `env_layer_catalog` for `fdep_gwca`: the restriction applies to **new potable wells**; properties on municipal water are unaffected in practice.

If that caveat lives only in report copy it gets stripped the first time the figure is quoted.

---

## PHASE 1 — Compartmentalization

Independent of all gates. Roughly one to two hours. This is what makes the spec's carve-outs real rather than asserted.

### 1.1 Discovery — report before changing anything

**What role does the Next.js app authenticate as?**

RLS is enabled across most of `public` with **four policies total**:

```
contractors                  :: Contractor update own       UPDATE
properties                   :: service_role_full_access     ALL
property_transaction_history :: service_role_full_access     ALL
scan_events                  :: allow_select_scan_events     SELECT
```

RLS on with no policy is deny-all. If the app functions, it is almost certainly running as `service_role`, which bypasses RLS on every table. Confirm and report.

### 1.2 Payload builder role

```sql
CREATE ROLE roz_payload_reader NOLOGIN;
-- explicit grants only, table by table, per the PIR field map (G4)
```

**Not granted, at any tier:**
- `volusia_arrest_reports_private` (47 rows: `arrestee_name`, `arrestee_dob`, `arrestee_address`, `charges`, `narrative`)
- `volusia_official_records_private` (1,267,929 rows keyed on `party_name`)

These concern third parties who are not participants in the alpha. Excluding them by grant rather than by prompt is the difference between a boundary and a convention.

### 1.3 Reserve `service_role`

Migrations and CC only. Not the running application.

### 1.4 `consumer_report_readonly`

Still on a placeholder password. Finish it.

---

## PHASE 2 — Capture infrastructure

Independent of gates except where noted. **All of this must be live before the first alpha exchange.** There is no second first session.

### 2.1 Extend the query log

```sql
ALTER TABLE assistant_query_log
  ADD COLUMN user_query      text,
  ADD COLUMN response_text   text,
  ADD COLUMN roz_version     text,
  ADD COLUMN payload_hash    text;
  -- plus payload_snapshot jsonb if G1 = snapshot
```

`assistant_query_log` currently stores account, tier, model, tokens, cost, `query_type`, `parcel_id`, `county`, `latency_ms`, `success`, `error`, `rows_returned`, IP, session. It is a metering log — **no question text, no answer text.**

Without `response_text`, every opinion filed is unreadable later: you hold the verdict and not the thing being judged.

`roz_version` is stamped **per exchange, not per session** — config can change mid-session.

### 2.2 Opinion table

```sql
CREATE TABLE assistant_exchange_opinion (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_log_id      uuid REFERENCES assistant_query_log(id),
  account_id        uuid,
  parcel_id         text,
  answer_correct    text,   -- correct | incorrect | partly | cant_tell
  answer_useful     text,   -- useful | not_useful | partly
  gap_verdict       text,   -- n_a | should_exist | correctly_withheld | wrong_source
  note              text,
  expected_instead  text,
  correction_claim  text,
  field_reference   text,
  mls_comparison    text,   -- better | worse | not_in_mls | n_a
  responded_at      timestamptz DEFAULT now(),
  response_lag_ms   integer
);
```

**Form requirements — not optional:**
- **Open text box first, always visible, nothing required before it.** Enums below it, all optional. Gate the box behind dropdowns and it stays empty.
- Prompt wording: *"What would you have needed here?"* Not *"Was this helpful?"*
- **Voice input enabled.** Field users do not thumb-type.
- No category selection at input. Cluster retrospectively.

An enum can only return values already on the list. The open field is the only channel through which an unanticipated defect can arrive.

### 2.3 Version register — append-only

```sql
CREATE TABLE roz_version_register (
  version                text PRIMARY KEY,
  effective_from         timestamptz NOT NULL,
  effective_to           timestamptz,          -- null = current
  system_prompt_hash     text NOT NULL,
  guardrail_hash         text NOT NULL,
  payload_allowlist_hash text NOT NULL,
  model                  text NOT NULL,
  model_params           jsonb,
  composite_hash         text NOT NULL,
  changelog_public       text,
  changelog_internal     text,
  authored_by            text,
  created_at             timestamptz DEFAULT now()
);
```

Enforce append-only: revoke UPDATE/DELETE, or a trigger permitting only `effective_to` to close. A register that can be edited retroactively is worse than none.

**Version the whole answering context** — prompt, guardrails, allowlist, model, params. If the model is swapped and the version string holds, the register stops being evidence.

### 2.4 Remediation log

```sql
CREATE TABLE roz_remediation_log (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  detected_at        timestamptz NOT NULL,
  source             text,   -- b2b_query_log | session_anomaly | agent_flag | internal_review
  source_ref         text,
  behavior_observed  text NOT NULL,
  risk_class         text,   -- privacy | fcra | fair_housing | assertion_beyond_record
                             -- | extraction | cost
  change_made        text,
  version_introduced text REFERENCES roz_version_register(version),
  status             text NOT NULL,  -- open | mitigated | accepted_risk | wont_fix
  resolved_at        timestamptz
);
```

Detection sources already exist: `b2b_query_log.allowed` / `denial_reason`, and `assistant_session_anomalies`. What is missing is the link from incident to fix.

**No orphaned entries.** Every row reaches a terminal status, including `accepted_risk` with a reason. A logged incident with no recorded resolution documents that you knew and did nothing.

### 2.5 Flat event log

```sql
CREATE TABLE ops_event (
  id            bigserial PRIMARY KEY,
  occurred_at   timestamptz NOT NULL DEFAULT now(),
  subsystem     text NOT NULL,  -- ingestion | roz | opinion | audit | cost | security
  event_type    text NOT NULL,
  entity_ref    text,
  county        text,
  payload       jsonb,
  severity      text,
  classified_by text,           -- ruleset version
  classified_at timestamptz
);
```

**Emitters never set severity.** Classification is a versioned function applied on top, and it must be **re-runnable over history** — otherwise you can never ask what today's rules would have flagged last week. The classifier is the alpha's real output.

### 2.6 Briefing action tracking

```sql
CREATE TABLE briefing_item_action (
  ops_event_id     bigint REFERENCES ops_event(id),
  surfaced_at      timestamptz NOT NULL,
  acted_on         boolean,
  acted_at         timestamptz,
  dismissed_reason text
);
```

The classifier learns the actionable line from observed behavior rather than from a guess about it.

### 2.7 Version acceptance

```sql
CREATE TABLE user_version_acceptance (
  account_id  uuid NOT NULL,
  version     text NOT NULL REFERENCES roz_version_register(version),
  accepted_at timestamptz NOT NULL DEFAULT now(),
  ip_address  inet,
  PRIMARY KEY (account_id, version)
);
```

The defensive value is demonstrating that a specific person operated under specific stated limits on a specific date.

### 2.8 Entitlements

`consumer_accounts` is 0 rows and its columns are `email, display_name, stripe_customer_id, first_purchase_at, last_purchase_at, purchase_count`. **The account model is the purchase model** — there is no path to access without a payment record.

Build entitlements as a concept independent of purchases: grantable, time-boxed, revocable, logged. **Not** a "payments disabled" flag — that has to be unwound later with live users in the table.

### 2.9 License gate

```sql
-- eligible: 350,492 of 493,556
WHERE primary_status = 'Current' AND secondary_status = 'Active'
```

Requiring both columns to agree correctly rejects the 5,085 `Invol Inactive / Active` rows where they disagree, plus the 44 Suspended and Probation licensees carrying an Active secondary. No special cases needed.

**Re-check on a schedule, not once at signup.** A licence can lapse mid-subscription. `dbpr_snapshot_log` already tracks refreshes.

---

## PHASE 3 — The parcel record

### 3.1 `field_status` derivation — **spec correction**

`ROZ_ENVIRONMENT_SPEC.md` §2 states this derives from `env_layer_catalog` and `county_coverage_status`. **It cannot.** `env_layer_catalog` is 9 rows with no county dimension; `county_coverage_status` tracks per-county ingestion progress by category, not per-layer coverage.

Correct rule, by layer provenance:

| Layer type | No matching row means |
|---|---|
| **Statewide** (FDEP, FEMA, DOR cadastral) | `null_at_source` — coverage is universal by construction, so absence is genuine |
| **County-sourced** | table absent → `county_not_covered`; table present, no row → `null_at_source` |

Check whether `env_layer_catalog.level` already encodes the distinction before adding a table.

Note: the catalog covers only the 9 environmental layers. The rest of the payload needs an equivalent derived from `data_source_registry` — and the **~45 unregistered tables cannot produce a correct `field_status` until registered.** Register them or exclude them from the payload; do not let them render as silence.

### 3.2 Payload allowlist — **blocked on G4**

Every field carries `value`, `field_status`, `as_of`, `source`. **No omitted keys** — absence must be explicit and typed, or an agent cannot flag a missing field and Roz cannot distinguish a build gap from a coverage boundary.

`properties` is a single flat table including `owner_name`, `owner_mail_addr` and related. The payload must be a constructed object against an allowlist, with owner identity as a separately gated section — not a select over the row.

### 3.3 Precompute — **blocked on G1, G2**

§12 measured 75–1,210 ms per parcel across 4–5 layers, median 383 ms. A 30+ layer report lands multi-second. Assembly at request time is not viable in production regardless of which option is chosen for the alpha.

### 3.4 `is_blackout`

Not computing on `county_coverage_status`. Required before first session — it is what lets the system decline gracefully outside coverage instead of returning a hollow report.

---

## PHASE 4 — Roz — **blocked on G3**

Scope after CC reports what exists in the repo. Everything behavioural is in `ROZ_ENVIRONMENT_SPEC.md` §0–§5: character brief, the payload-only boundary, grammar rules, the six declines, conflict reporting.

Two items to carry over regardless of what exists:

- **She reads the precomputed record and nothing else.** No database connection, no SQL generation, no table names in context, no cross-parcel access. That boundary is what makes T1 extraction structurally impossible rather than threshold-managed.
- **Declines must hold under demo conditions**, where nobody reads fine print and the caveats get skipped.

---

## PHASE 5 — Carried, not on the alpha path

Do not let these displace Phases 0–2.

- **SRID-0 reprojection** — Seminole, Lake, Osceola. Reload `school_attendance_zones` separately, it is genuinely dead. **Verify centroids land in-county afterward** — a wrong source projection moves parcels silently rather than erroring.
- **Identify `parcels_staging`** — 21 GB, 10,327,257 rows, unknown provenance, 504,667 short of the cadastral yet physically larger. A quarter of an 81 GB database and the top cost line. Identify before dropping anything.
- **Drop `orange_parcels_govt_source_abandoned_20260722`** (725 MB) once `parcels_staging` is resolved.
- **`fema_flood_zones`** — 1,210 MB of index on 232 MB of table, still unregistered with no source URL.
- **Roof material join** — `VCPA_CAMA_RES_BLDG` roof cover into the lifespan model. Asphalt 15–25 years, tile 40–50, metal 40–70. Without it the layer reports tile roofs as overdue with thirty years remaining, which is the most visible way to lose a subscriber.
- **Trade classification** — 576,254 rows (58.6%) in `other / other`.
- **Absence signal** — parcels with no roofing permit on record against `ACT_YR_BLT`. Stronger agent lead than a documented roof, and structurally invisible to the current model.
- **Naming** — `epa_landfills` holds 75 rows and is not a Florida landfill inventory. Rename or annotate before someone reads coverage into it. Same for `miamidade_dump_sites` (21) and `orange_solid_waste_transfer_landfill` (4).
- **Brownfield duplication** — `fdep_brownfield_sites` 571 and `fdep_brownfield_areas` 624 statewide, plus ~90 per-county tables covering the same sites. Live double-count risk.

---

## Suggested order

1. **Phase 1.1** — one discovery query, report back, changes nothing
2. **Phase 0.1, 0.2** — the two silent corrupters
3. **Phase 2.1** — `response_text`, because it is unrecoverable and cheap
4. **Phase 0.3–0.8** — verification sweep, batchable as one script
5. **Phase 1.2–1.4** — compartment
6. **Phase 2.2–2.9** — remaining capture
7. **Phase 3** once G1/G2/G4 are answered
8. **Phase 4** once G3 is reported

Phases 0, 1 and 2 are the whole alpha prerequisite and none of them depend on an unanswered question except 2.1's snapshot column and 2.8's create-vs-modify.
