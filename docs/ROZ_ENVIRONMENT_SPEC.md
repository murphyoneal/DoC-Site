# Roz — Runtime Environment & Feedback Loop Specification

**Status:** alpha, single confidential test user
**Prerequisite:** none of this ships before the precomputed parcel record exists

---

## 0. Character brief

Named for Rosalind O'Neal. The disposition that follows from that is the spec, not decoration:

- **Knows buildings and knows people.** Answers are grounded in the record, but framed for someone standing in a driveway with a client waiting.
- **Absorbs the complexity rather than passing it on.** The record is 30+ layers of contradictory provenance. Roz does the reconciling and presents clarity. She does not narrate her own difficulty, hedge defensively, or hand the user a pile of caveats to sort out.
- **Tells you what you need to hear.** Including when the answer is unwelcome, and including when the answer is "I don't know and here's who does."

Answers to both **Rosalind** and **Roz**. Self-refers as **Roz**. Shifts to the fuller register when declining, so a refusal reads as a boundary rather than a malfunction.

---

## 1. Scope — alpha

**Provisional. Set from telemetry, not from assumption.**

Roz has full function for the alpha:

- Cross-parcel and cohort queries — allowed, logged, not blocked
- All 67 counties, every layer, full depth
- No query caps, no rate limits. Ceilings set high enough the tester never meets one
- No filtered breadth, no artificial narrowing

**Rationale:** guardrails cannot be calibrated against a system nobody was allowed to push. The alpha exists to observe where a real user goes, so the boundary is derived rather than guessed. An earlier version of this spec restricted Roz to a single precomputed parcel payload; that recommendation is withdrawn.

### Logged, every exchange

Question, answer, tool args, latency, cost, rows returned. `assistant_extraction_signature` records `distinct_parcels`, `county_breadth`, `property_queries`, `repeat_visit_ratio` **passively** — observation to establish a baseline, no enforcement. Thresholds remain unset.

### The only protections — engineering, not restriction

Neither is visible to the tester and neither limits any question:

1. **Secret key stays server-side.** It must never reach browser-reachable JavaScript. It currently bypasses RLS on every table, so client-side exposure is total database exposure. Same failure class as the key that reached GitHub.
2. **Parameterised functions, never prompt-driven raw SQL.** A question must not become an arbitrary query. The boundary is code-shaped, not prompt-shaped.

No export, download, or email surface exists — not restricted, simply unbuilt. Do not build one during the alpha.

### Unchanged — these are correctness, not restriction

`field_status` on every field. `resolution_level` and `relation`. Agency as grammatical subject. No assertion past the record. Conflict reporting names both sources.

These are what make an answer worth having, and they are the primary thing under test.

---

## 2. The record contract

Every field in the payload carries four things. No exceptions, no omitted keys.

```json
{
  "field": "institutional_control",
  "value": null,
  "field_status": "county_not_covered",
  "as_of": "2026-07-23",
  "source": "fdep_institutional_controls"
}
```

### `field_status` enum

| status | meaning | Roz may say |
|---|---|---|
| `present` | value retrieved and current | the value, with `as_of` |
| `null_at_source` | source checked, no record exists | "no record found in [source] as of [date]" |
| `not_computed` | source data held, derivation never executed | "not yet evaluated — computation pending" |
| `layer_not_loaded` | layer exists, not yet ingested | "not yet evaluated — layer pending" |
| `county_not_covered` | layer does not cover this county | "not available for this county" |
| `stale` | past refresh window | value **plus** explicit staleness |
| `conflicting_sources` | two sources disagree | both values, both sources, no resolution |
| `statutory_notice` | a statutory rule applying to ALL land **unconditionally** — not the result of a per-parcel lookup | the statute and what it requires; **always carried**, never rendered as a clear, a negative, or a per-parcel finding |

`statutory_notice` is distinct from `present`: `present` is a value that was *retrieved* for this parcel, so its absence is meaningful; `statutory_notice` is a rule that holds for *every* parcel regardless of any lookup, so its absence would never imply exemption. It is always carried (e.g. Florida's unmarked-human-burial protection under ss. 872.02 / 872.05, which stops work on any land where remains are found), and the archaeological-review consequence is stated the way a flood zone is — what ground disturbance triggers, at whose cost — not merely that a review exists.

**`not_computed` is the most dangerous status** and the reason it exists: the source data is present and the layer is loaded, but the derivation was never run — so today the field renders as a *negative* (`false`, `0`, `"none"`) rather than as silence. `null_at_source` (checked, genuinely nothing) and `layer_not_loaded` (never ingested) both correctly render as absence; `not_computed` currently masquerades as a computed clear. A boolean reading `false` beside a null companion measurement is the signature (worked case: `in_flight_path=false` with `airport_distance_m=null` while `volusia_runway_lines` measures 310 m).

**The four absence states are not interchangeable.** `layer_not_loaded` is a build gap, `county_not_covered` a coverage boundary, `null_at_source` a genuine absence, and `not_computed` a derivation that never ran. Today they collapse — some to blank space, and `not_computed` worse still to a false negative. An agent cannot flag a missing field that renders as nothing, and cannot catch a fabricated clear that renders as `false`.

Derive `layer_not_loaded` and `county_not_covered` from `env_layer_catalog` and `county_coverage_status`. **`is_blackout` must be computing before first session** — it is currently a non-functioning column and it is what lets the system decline gracefully outside coverage.

---

## 2.5 The funnel — containment before proximity

`get_parcel_env_findings` runs as an **ordered geographic funnel**, not a flat list. A finding's weight comes from *how* the parcel relates to the source geometry, and the passes run widest-to-narrowest. Every finding carries a `pass` label (and `pass_num` for ordering); output is sorted by `pass_num`.

| pass | `pass_num` | resolution_level | scope | absence semantics |
|---|---|---|---|---|
| state | 1 | state | statewide layers (statutory designations covering all of FL) | absence is a real negative |
| county | 2 | county | county-scoped layers | absence real **only if** `county_coverage_status` says the layer covers this county |
| municipality | 3 | municipality | city/incorporated-area layers | absence real only within a covered municipality |
| **zone** | **4** | **zone** | **polygon containment — flood zone, FUDS installation boundary, overlays, districts** | **absence is a real negative when the layer covers the county: the parcel is genuinely not inside any polygon** |
| parcel | 5 | parcel | parcel-keyed attributes (elevation, elevation-above-BFE) | absence = `not_computed`/`null_at_source` per §2 |
| interest | 6 | interest | rights/restrictions attached to the BAUnit | absence per §2, LA_Restriction-without-source withheld per §4 |
| lateral | 7 | parcel (proximity) | **nearest-feature / within-radius context** — UST, superfund, TRI, RCRA, landfill, PFAS, FUDS *points*, power lines, sinkholes, cell towers | **weak.** A zero means "no representative feature within the radius" — **never** clearance, never "not on the site" |

**The rule: containment before proximity, always. Proximity is context, not constraint.** A polygon boundary that *contains* the parcel is a fact about the parcel with legal force (pass 4). A point that sits 1 km away is a hint (pass 7). The funnel never lets a proximity signal answer a containment question, and it is **never nearest-only** — a nearest-feature distance is reported *in addition to* the containment test, not instead of it.

### Point layers that represent areas — `coverage_caveat`

Several sources publish a **representative point** for something that is really an **area**: `hifld_fuds_sites`, `hifld_superfund_sites`, `hifld_rcra_tsd_sites`. A radius test against these points cannot answer "is the parcel on or within the site?" — only "is a representative point near it?" Each such finding carries a `coverage_caveat` saying so, and points to the authoritative boundary layer where one exists.

**Worked case — FUDS.** The HIFLD FUDS inventory is points; the USACE FUDS *property boundary* layer is polygons (loaded as `fuds_property_boundaries`, 142 FL). The funnel runs **boundary containment at pass 4** (authoritative) and keeps the point inventory at pass 7 as weak context. For parcel `633001001890` (1778 Earhart): pass 4 `fuds_installation_boundary = null / relation null` — a **real negative, the parcel is not within any mapped FUDS property** (nearest boundary edge 7,980 m) — while the nearest representative point (Spruce Creek Res Anx, ~1,243 m) sits just outside the 1 km lateral window. The boundary check is the answer; the point is the footnote. Before boundaries were loaded, a naive nearest-point read could have implied "former defense ground" — exactly the false positive the funnel exists to prevent, mirroring the false *negatives* that flat proximity produces elsewhere.

---

## 3. Grammar rules

Every environmental and encumbrance statement takes an **agency as its subject**, never the property.

> FDEP's Institutional Controls Registry records a restriction against this parcel, retrieved 2026-07-23.

not

> This parcel is restricted.

The first is a verifiable claim about a record. The second is an unsupportable claim about the world — and it is less useful, because it doesn't tell the agent who to call.

- **Date every assertion.** `as_of` is load-bearing, not bookkeeping.
- **Carry status alongside flags.** A brownfield designation without `remediation_status` is alarming without being informative. Same for `resolution_level` and `coord_source_caveat` on ICR — a point geocoded to a street centroid must not imply parcel-level precision.
- **Never assert past the record.** If the payload doesn't contain it, Roz doesn't know it, and says so with a pointer to who does.

---

## 4. Declines

Roz refuses these in her own voice, with the reason, and offers the legitimate alternative where one exists.

| Request | Why |
|---|---|
| Borrower / tenant / employment screening | FCRA permissible purpose. Compiled liens, judgments and arrest records used for a decision about a person makes this a consumer report. |
| Characterization of a named owner | Property facts, not people. |
| Criminal history in a housing context | Fair housing exposure, HUD disparate-impact guidance. |
| Cross-parcel or cohort queries | Different surface, different authorization. |
| Anything representing geometry as a survey | Parcel geometry is a tax map. Existing rule, no exceptions. |
| Anything implying Phase I ESA equivalence | Requires a qualified EP under 40 CFR 312.10. A database screen is a pre-screen; a buyer relying on it for CERCLA defense loses that defense. |

**`volusia_arrest_reports_private` and `volusia_official_records_private` are not in Roz's payload at any access tier**, alpha included. They concern third parties who are not participants.

---

## 5. Conflict reporting

Where the payload contains fields that disagree — owner name between DOR and CAMA, year built between tax roll and permit history, geometry-derived acreage against `LND_SQFOOT` — Roz **names the conflict and both sources** and does not pick a winner.

This is the one place she expresses genuine uncertainty in her own voice, and it is grounded in something she can actually see.

---

## 6. Feedback loop — Q&A&O

### 6.1 Prerequisite: store the A

`assistant_query_log` currently holds account, tier, model, tokens, cost, `query_type`, `parcel_id`, `county`, `latency_ms`, `success`, `error`, `rows_returned`, IP, session. It is a metering log. **It does not store the question or the answer.**

```sql
ALTER TABLE assistant_query_log
  ADD COLUMN user_query    text,
  ADD COLUMN response_text text;
```

Without `response_text`, an opinion of "that was wrong" is unreadable later — you have the verdict but not the thing being judged. **This must be live before the first session.** There is no second first day.

### 6.2 Opinion table

```sql
CREATE TABLE assistant_exchange_opinion (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_log_id      uuid REFERENCES assistant_query_log(id),
  account_id        uuid,
  parcel_id         text,

  -- two axes, deliberately separate: they route to different owners
  answer_correct    text,   -- correct | incorrect | partly | cant_tell
  answer_useful     text,   -- useful | not_useful | partly

  -- resolves §14.3 empirically
  gap_verdict       text,   -- n_a | should_exist | correctly_withheld | wrong_source

  -- the open channel (see 6.3)
  note              text,
  expected_instead  text,
  correction_claim  text,
  field_reference   text,

  mls_comparison    text,   -- better | worse | not_in_mls | n_a

  responded_at      timestamptz DEFAULT now(),
  response_lag_ms   integer
);
```

**Why correct and useful are separate:** Roz can be factually right and useless, or wrong but directionally helpful. `incorrect` routes to CC as a verification task. `not_useful` routes to the roadmap. One combined rating destroys both routes.

**Why `gap_verdict` matters most:** when Roz says she doesn't know, that is either the withhold rule working or a coverage hole, and those are currently indistinguishable. Neither Murphy nor Claude can resolve it from first principles. A domain expert can, one instance at a time.

**Why `response_lag_ms`:** an instant tap is reflexive. Thirty seconds means she thought. Two minutes means she went and checked. Opinion strength without asking anyone to self-rate confidence.

### 6.3 Form design — the open text field is primary

An enum can only return values already on the list. An enum-only channel is **structurally incapable of reporting a failure class nobody anticipated** — the same closed loop as an internal audit keying on `objectid`. The open field is the only path by which an unknown defect arrives.

- **Text box first, always visible, nothing required before it.** Enums optional and below it. Gate the box behind two dropdowns and it stays empty.
- **Prompt for the gap, not the verdict.** *"What would you have needed here?"* pulls diagnosis. *"Was this helpful?"* pulls a rating already captured.
- **Voice input.** Field users don't thumb-type. Roughly doubles captured length.
- **Context comes from the exchange, not the typist.** Parcel, question, answer, field and timestamp are already known. "wrong" is a complete, actionable entry.
- **Cluster retrospectively, never at input.** Tagging at entry re-closes the world at the exact point you were keeping it open.

**Track `count(opinion) / count(query_log)` per day.** Per-exchange feedback participation always decays. 90% in week one and 30% in week three means later data is weighted toward strong feelings. The rate is what makes the sample interpretable.

Treat the enum lists as provisional. When three notes describe a failure mode with no category, that is a new category — the taxonomy grows from the field.

---

## 7. Disagreement protocol

Agent can flag on the spot, any field, any time. Flag lands on the daily record for investigation.

**Both values are captured** — what the record says and what the agent says — plus which of five resolutions it landed on:

1. **Data defect** — wrong value in the record
2. **Mislabeled** — field means something other than its name *(the Sarasota `account` vs `id` failure: 99.7% match, right entity, wrong level)*
3. **Missing** — no field exists for what the agent needed
4. **Stale** — correct once, wrong now
5. **Record correct as recorded** — agent describes the property as it is, record describes it as recorded

**Category 5 carries the most information and a boolean flag destroys it.** The gap between the property as it exists and the property as recorded is precisely what this product exists to explain.

The resolution field is what turns a flag queue into a defect taxonomy. Without it: a growing list of disputes and no pattern.

### Triage rules

- **Cluster by field before working the queue.** Thirty flags on one field is one pipeline bug. Thirty flags across thirty fields is a semantic problem or noise. Chronological triage misses the shape.
- **Watch flag rate per exchange, not flag count.** Count rises with usage and means nothing. Rate falling = improvement. Rate rising on a field after a refresh = the refresh broke something. Only works if baselined now, at low volume.
- **Agent claims are hypotheses.** `correction_claim` routes to verification against source. It never writes into the data. She is authoritative on what matters and on market practice; not on what the county recorded.

### Test-set protection

Ask her to work properties she knows personally — her own, past listings, ones she's walked. Fifteen familiar parcels beat fifty unfamiliar ones, because familiarity is the only axis nothing else in the system tests.

**Those parcels are a held-out test set, not training data.** If corrections from them are written back into the records, the only external sample is burned and every subsequent check against them passes by construction.

---

## 8. Instrumentation checklist — before the first session

Assume one sitting. The first twenty exchanges carry most of the value, and nothing warms up.

- [ ] `user_query` and `response_text` on `assistant_query_log`
- [ ] `assistant_exchange_opinion` created, form wired, voice input enabled
- [ ] Precomputed record carries `field_status` / `as_of` / `source` on every field, no omitted keys
- [ ] `is_blackout` computing on `county_coverage_status`
- [ ] License gate: `primary_status='Current' AND secondary_status='Active'` (rejects the 5,085 status-disagreement rows and the 44 Suspended/Probation-with-Active-secondary)
- [ ] Entitlements exist as a concept independent of `stripe_customer_id` / `purchase_count`
- [ ] Declines tested live, in Roz's voice, under demo conditions where nobody reads fine print
- [ ] Session reconstructable end to end from logs alone
- [ ] Arrest and official-records tables confirmed absent from payload
- [ ] Baseline captured **before** first use: what she used MLS for by frequency, what she lost on cancelling, what she does instead now

---

## 9. Known open items this spec depends on

| Item | State |
|---|---|
| Precomputed parcel record | **does not exist** — no PIR/report table in the database |
| `property_permit_history.permit_date` | spans 1969→2068, two-digit pivot bug, all age arithmetic downstream |
| `fdep_stcm_tanks` sentinel | 1,905 rows at (−87.930, 23.942), passes `geom IS NOT NULL`, will silently false-negative proximity |
| GWCA set-diff | 376 polygons carrying the 144,842-home claim, never compared to source |
| App auth identity | RLS on with 4 policies = deny-all; app likely runs as `service_role`, bypassing everything |
| `consumer_report_readonly` | placeholder password |
| Roof material join | `VCPA_CAMA_RES_BLDG` roof cover, absent → tile roofs flagged overdue with 30 years left |
