# Access Limits & Abuse Controls

**Section 13 of the platform compliance framework.** Merge into `PROVIDER_REASONABLE_PROCEDURES.md` after §12 (Governance), before the Appendix.

**Drafted 2026-07-23.** Companion to §§1–12, which protect *the subject of a report*. This section protects *the asset and the platform*. Different threat model, same enforcement principle: a policy without technical enforcement is paper.

> **Every threshold in this document is an unset parameter.** We do not yet have usage telemetry, so no number here is invented. Build the enforcement architecture now; set the dials when `assistant_query_log` has produced a real distribution. A guessed limit is worse than a configurable one, because it will be either uselessly loose or wrongly punitive and nobody will know which.

---

## 13.1 Threat model

Three distinct abuses, often conflated, with different signatures and different controls.

| # | Threat | Actor | What they consume | Primary control |
|---|---|---|---|---|
| **T1** | **Asset extraction** | Legitimate paying subscriber | Distinct parcels | Parcel-access budget (§13.3) |
| **T2** | **Cost abuse** | Heavy or automated user | Compute / tokens | Cost ceiling + query caps (§13.4) |
| **T3** | **Boundary escape** | Adversarial user, often via the AI assistant | Data outside their tier | Database-enforced scope (§13.5) |

**T1 is the existential one.** The compiled dataset is the company's only durable asset. A Pro subscriber with unlimited statewide access and a natural-language interface has been handed a straw into it. Patient querying inside the terms of a $300/month subscription could reconstruct a material share of what took months to build.

---

## 13.2 The core insight: meter parcels, not queries

**Rate-limiting queries does not stop extraction.** If one query returns 1,000 parcels, then 50 queries/day is 50,000 parcels/day. Query count is uncorrelated with asset consumption.

**The honest unit of consumption is the distinct parcel.** It is:
- what the asset actually consists of
- what cost roughly tracks
- what an extractor needs and a working agent does not
- defensible to a customer: *"unlimited reports on up to N distinct properties per month"*

That phrasing is genuinely unlimited for every real agent while being bounded against extraction. It is also honest — it describes what is actually being limited rather than hiding a cap behind a query counter.

---

## 13.3 Parcel-access budget (T1)

**Counter:** distinct parcels accessed per user per rolling period. Repeat access to the same parcel is free — an agent revisiting their own farm area is not consuming new asset.

**Parameters — all unset pending telemetry:**

| Parameter | Applies to | Value |
|---|---|---|
| `BASIC_DISTINCT_PARCELS_PER_MONTH` | Basic tier | *unset* |
| `PRO_DISTINCT_PARCELS_PER_MONTH` | Pro tier | *unset* |
| `SOFT_WARN_PCT` | both | *unset* |
| `BREADTH_COUNTY_THRESHOLD` | Pro (statewide) | *unset* |
| `REPEAT_VISIT_RATIO_FLOOR` | both | *unset* |

**Set them from measured behaviour, not intuition.** Once real Pro users have run for a month: the median agent's distinct-parcel count sets the expectation, p95 sets the soft warn, and the limit sits above p99 so no legitimate user ever meets it.

### Behavioural signatures

A working agent and an extractor differ in shape, not volume alone:

| Signal | Working agent | Extractor |
|---|---|---|
| Geographic breadth | Concentrated — a farm area, a few ZIPs | Broad — many counties, systematic |
| Repeat-visit ratio | High — returns to the same properties | Near zero — each parcel once |
| Sequence | Irregular, follows client activity | Ordered — by parcel ID, by geography, by grid |
| Timing | Business hours, bursty | Constant rate, including overnight |
| Result breadth per query | Narrow — specific properties | Wide — maximum rows per call |

**No single signal is sufficient.** A rural agent legitimately covers several counties; a new agent has no repeat visits yet. Flag on combination, and route to human review rather than auto-suspension (§7 graduated response applies).

### Result-set caps

Independent of the budget: cap rows returned per query, and cap total rows per session. This prevents a single wide query from consuming a month's budget in one call, and it bounds the damage before the budget counter even registers.

---

## 13.4 Cost ceilings (T2)

Depends on `assistant_query_log` (see telemetry task). **Median sets the price; p95 sets the limit.**

| Parameter | Purpose | Value |
|---|---|---|
| `MAX_TOKENS_PER_QUERY` | one runaway query cannot run away | *unset* |
| `USER_MONTHLY_COST_SOFT_WARN` | notify user and ops | *unset* |
| `USER_MONTHLY_COST_HARD_CAP` | degrade to structured queries only | *unset* |
| `USER_24H_COST_ALERT` | catch automation early | *unset* |
| `DB_QUERY_TIMEOUT_MS` | assistant-issued DB calls | *unset* |

**Design rule:** "unlimited" remains genuinely unlimited for the ~95% who never approach a cap. The tail that would break the economics gets bounded, and the customer is told where the line is at signup rather than discovering it mid-month.

**On hitting the hard cap**, degrade rather than cut off — structured/cached queries continue, open-ended generation pauses. A subscriber who paid $300 should never hit a blank wall without warning.

---

## 13.5 Boundary enforcement — architectural, not instructional (T3)

**The rule: tier restrictions live in the database, not the prompt.**

If Basic's city/county restriction is enforced by instructing the assistant *"only answer about Volusia County,"* that is one clever prompt away from statewide access. If it is enforced by a scoped database role that physically cannot see other counties, no prompt can break it.

**Requirements:**

1. **Scoped roles per tier.** A Basic subscriber's queries execute under a role whose visibility is restricted to their licensed county/city. Enforce with RLS policies keyed to the subscription record — not application logic, not prompt text.
2. **No user-influenced SQL.** The assistant calls parameterized, allow-listed functions. It never composes and executes arbitrary SQL against the full database. If natural language must become a query, it selects from a fixed set of templates with bound parameters.
3. **Restricted-profile data (§1, §5) is unreachable from the assistant entirely**, at the role level — not filtered in the response. The assistant should not be able to retrieve it and then decline to show it.
4. **Prompt-injection resistance.** Content retrieved from the database or the web may contain adversarial text. Treat all retrieved content as data, never as instructions. This applies to property records, official-records text, and any web search feeding the neighborhood-news section.
5. **Log the attempt, not just the block.** Queries that trip a scope boundary are a strong abuse signal and feed §6 monitoring.

**Standing item:** the `consumer_report_readonly` role still carries a placeholder password. Until that is rotated, the scoped-role architecture is theoretical. Fix before Pro launch.

---

## 13.6 Fair use policy — the customer-facing surface

Presented at signup, not buried in terms. States plainly:

- What is metered (distinct properties, not reports or queries)
- The tier's allowance and what happens on approach — warn, then degrade, never silent failure
- Prohibited: bulk extraction, redistribution, resale, scraping, automated harvesting, sharing credentials
- That usage is logged — **including the request IP address, the device/browser (user-agent), and a session identifier** — and why (cost control, product improvement, and abuse/security detection: credential sharing, concurrent sessions from different locations, and other anomalous access). This is what makes the "sharing credentials" prohibition enforceable rather than aspirational.
- That limits may be raised on request for legitimate high-volume use — this is the pressure valve that keeps the policy from punishing your best customers

**The §4 lesson applies exactly:** a fair-use clause with no technical enforcement is the same paper defense as a permissible-purpose checkbox with no monitoring. What makes it real is that the limits are measured and enforced. The policy's job is to tell people where the line is so enforcement is never a surprise.

---

## 13.7 Build order

Sequenced so nothing depends on numbers we don't have:

1. **Telemetry first** — `assistant_query_log` with `distinct_parcels_accessed`, breadth (distinct counties), and repeat-visit ratio alongside cost. Cannot be backfilled.
2. **Scoped roles and allow-listed functions** (§13.5) — architectural, needs no thresholds, and is the control that cannot be added later without a rewrite.
3. **Result-set caps and per-query token caps** — safe defaults now, tuned later.
4. **Counters running in observe-only mode** — measure real behaviour with nothing enforced.
5. **Set thresholds from the measured distribution.**
6. **Enable enforcement**, soft warn first, hard limits after a grace period.
7. **Publish the fair use policy** with real numbers in it.

**Steps 1–3 build the wall. Steps 4–7 add the doors once we know where people actually walk.**

---

## 13.8 Open questions for counsel and ops

1. Does the fair use policy need to be a contract term, or does terms-of-service incorporation suffice?
2. What notice is required before suspending a paying subscriber for extraction behaviour?
3. Does a parcel-count limit conflict with how "unlimited PIRs" is advertised on the Pro tier? *(Likely a marketing-copy fix: "unlimited reports" → "unlimited reports on up to N properties." Resolve before the tier is sold, not after.)*
4. Retention period for `assistant_query_log` — long enough to be evidentiary, short enough to limit exposure. Interacts with §12 question 4. **Now sharper: the log holds IP address and user-agent (§13.9), which are personal data.** Traceability vs. data-minimisation is a real tension — flagged, not decided here.

---

## 13.9 Session context logging (T2/T3 support) — built, observe-only

**Built 2026-07-24.** `assistant_query_log` now captures, on **every** assistant call (success *and* failure paths, never sampled): `ip_address` (inet, null when unresolvable), `user_agent` (text), `session_id` (client-generated, text). Cannot be backfilled — landed before alpha access opened.

**View `assistant_session_anomalies`** — per account, rolling 7-day window, **observe-only** (no thresholds, no enforcement — same discipline as the cost guardrails):
- **concurrent sessions** — distinct IPs whose session windows overlap (the credential-sharing signal)
- **impossible travel** — distinct IPs within 30 minutes, flagged as a pair for review (no geolocation)
- **distinct IP count** and **distinct device (user-agent) count** — the spread

With three alpha users the point is to learn the shape of normal before defining abnormal. These feed §13.10 (ban signals) and the daily ops report, but enforce nothing yet.

### Privacy-policy disclosure — REQUIRED before alpha, and it does not yet exist

There is **no customer-facing privacy policy in the repo** — `/privacy` is a planned route (see `PRE_BUILD_SPEC.md`) that has not been built. IP address and user-agent are personal data; logging them without disclosure is the gap. **Before alpha opens, the `/privacy` page must state** (drop-in language):

> *We log each request's IP address, browser/device information (user-agent), and a session identifier, along with the queries you run. We use this to control cost, improve the product, and detect abuse and account-sharing (for example, the same account used from many locations at once). We do not sell this data. [Retention period: TBD — see below.]*

And the fair-use terms (§13.6) now disclose the same — done.

---

## 13.10 Ban infrastructure (T1/T2 support) — flags for counsel, not decisions

Ban-key strength, **strongest first** — `card_fingerprint` → `billing_name_address` → `device_hash` → `email` → `ip`. Build weighting accordingly; **do not over-weight IP** — mobile users rotate it, a brokerage office shares one, a VPN defeats it. IP's real value is the *pair signals* in §13.9, not identification. Capture Stripe's **card fingerprint** at payment (not just last-four): cards are costly to churn and tie to a real identity via AVS. Checked **at signup, not only at query time** — otherwise a returning banned user is caught only after they're already inside.

**Two dependencies that are NOT ours to decide — flagged, not invented:**
1. **Retention period for IP and session logs.** Traceability (evidentiary value for bans/abuse) vs. data minimisation (personal-data exposure). Interacts with §12 of `PROVIDER_REASONABLE_PROCEDURES.md` (which is itself not yet in the repo). Counsel/ops decision.
2. **Termination clause in the Terms of Service.** A ban has no contractual footing without a stated right to suspend/terminate for the prohibited conduct in §13.6. The ToS does not yet exist as a document. Counsel decision.
