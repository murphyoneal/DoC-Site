# Tier definition & enforcement (items 58 / 60 / 61 / 62)

Two paid tiers. **Basic ($99/mo):** daily briefing, 30 property reports (PIRs)/month, one county, no Roz.
**Pro ($300/mo):** Roz, unlimited PIRs, statewide. One user per account.

## Source of truth — the `entitlement` table

`entitlement(user_id, entitlement_type, tier, status, granted_at, expires_at, revoked_at, allowed_co_no, …)`.
An account is **Pro** iff it holds a row with `lower(tier)='pro'`, `status='active'`, `revoked_at is null`,
`(expires_at is null or expires_at > now())`. Otherwise **Basic** (including unprovisioned — default deny to the
paid features, not to the app). `entitlement_event` is the append-only audit of grants/revokes.

`allowed_co_no` (added for item 61): the single county a Basic account may see. `null` = statewide (Pro).

Resolver: **`roz_account_access(user_id) → {tier, roz_enabled, statewide, allowed_co_no, pir_monthly_limit}`**.
Single call, used everywhere a tier decision is made.

## What is enforced NOW (item 58 — the Roz surface)

- **Roz is Pro-only.** `app/api/roz` resolves `roz_account_access` before any model call. Basic → a plain
  "Roz is a Pro feature" reply, **no model spend**, logged with `tier='basic'`. Pro → full Roz, statewide.
- **Tier is logged.** `roz_log_query` now takes `p_tier` and writes `assistant_query_log.tier` (was `null` on
  every exchange — the column existed but was never set). Cost/usage is now sliceable by tier.
- **The two alpha users are provisioned Pro** (`granted_by='alpha_provision'`), so enforcement does not lock them
  out. Anyone else defaults to Basic.

Pro = statewide is already how Roz behaves (all 67 counties); Basic never reaches Roz, so no county scope is needed
on the Roz path. Single-user-per-account is a property of the entitlement (one `user_id`); multi-seat is out of scope.

## What is NOT yet enforceable — the consumer PIR surface (items 60, 61-consumer)

The consumer report route `app/report/[coNo]/[parcelId]` is **public / purchase-gated, not account-gated**
(`robots:noindex`, no session). `consumer_accounts` has 0 rows and no purchases have flowed. So there is nothing to
meter against yet. `consumer_accounts.purchase_count` is **cumulative**, not a monthly allowance, and cannot back a
30/month cap.

**Prerequisite for 60 & 61-consumer:** bind report generation to a `consumer_accounts` identity (the checkout flow
already returns `consumer_accounts.id`; the *free/logged-in* report path must adopt it too).

### Item 60 — PIR monthly quota (design, ready to wire)
- Ledger every generation: one row per (account_id, co_no, parcel_id, generated_at) — reuse `behavioral_events`
  (`event_type='pir_generated'`) or a dedicated `pir_generation` table.
- `pir_month_usage(account_id) → int` = count where `date_trunc('month', generated_at) = date_trunc('month', now())`.
  The **reset is implicit** in the calendar-month filter — no cron needed.
- Gate: Basic blocks when `usage >= 30` with an upgrade prompt; Pro (`pir_monthly_limit is null`) is uncapped.
  Enforce in the report route (and pre-check in the UI so the 31st report never renders before the block).

### Item 61 — county scope on Basic (design, ready to wire)
- Report route: reject `co_no != access.allowed_co_no` for Basic with "your plan covers <county> only"; Pro
  (`statewide`) unrestricted. Same resolver.

## Item 62 — daily briefing (the $99 deliverable) — spec

Distinct from the **internal** `daily_ops_report` (that is our pipeline-health digest). This is a **customer-facing,
county-scoped** morning email — the standing reason a Basic account is worth $99 even in a month with no report pulls.

- **Contents (county = `allowed_co_no`, last 24–48h):**
  - New recorded **encumbrances** in the county (lis pendens / liens) — corroborated, framed per the same
    reporting rules Roz uses (recorded-against-a-party, not a title claim).
  - New **permits** filed (from the CAMA permit feed).
  - New / newly-active **planned works** (dev / environmental / stormwater government projects) in the county.
  - New **distressed-cohort** signals (from `get_encumbered_parcels`), capped and de-duplicated.
  - Optional: upcoming tax / deadline reminders.
- **Delivery:** a scheduled job (the existing Windows **Task Scheduler** trigger, not WSL cron — see memory
  `data-refresh-system`) renders per-account, per-county and emails it. One account = one county = one digest.
- **Scope & privacy:** county-scoped to the entitlement; sensitive categories excluded exactly as the PIR crime
  section is (no unfiltered feeds). Honest-gap language when a section has nothing new ("no new filings", not silence).
- **Build note:** the queries all exist (encumbrances, permits, planned works, distressed cohort); item 62 is the
  assembler + template + scheduled send. It does **not** depend on item 14 precompute.

## Fair housing

Nothing in these tiers or the daily briefing exposes protected-class or demographic fields, steering, or listing
recommendations. The agent-claim work (item 59) is property-fact only; current-listings-with-price (item 52b) carries
its own fair-housing constraints and is a separate build.
