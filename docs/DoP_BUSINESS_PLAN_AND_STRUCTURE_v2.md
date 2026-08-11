# DoP / DoA — Business Plan & Structure

**Consolidated 2026-08-03.** Supersedes the 8 July business plan, the 24 July revenue model, the 28 July pricing revision, and `CUSTOMER_ACCOUNT_FEEDBACK_SPEC.md` — four documents that were never reconciled.

Every figure below is measured against the live database or a named public source. Where a number is an assumption it is labelled as one.

---

## Part 1 — What exists

| | measured |
|---|---|
| Parcels, all 67 Florida counties | **10,739,881** |
| Populated tables | **2,050** |
| Rows | ~98.5M |
| Counties with relational CAMA depth | **1** (Volusia — 306,889 parcels, **2.86%**) |
| Florida licensed agents (DBPR) | 312,291 |
| Annual Florida listings (est.) | ~446,946 |

**The asymmetry that defines the business:** the platform is statewide and the *depth* is one county. Everything that makes this intelligence rather than a lookup — marine improvements with depreciation, permit cross-examination, deed chains, improvement timelines, multi-owner ownership — is Volusia only.

**The single highest-information unknown** is whether the top ten counties by parcel count run Tyler iasWorld. If four do, the existing loader takes rich coverage from 2.86% to roughly a quarter of the state.

---

## Part 2 — Positioning

**A due-diligence check before a property is listed or purchased.** Not a listing service, not a feasibility screen, not a description.

**Pre-listing (B2B).** *"Know it before you list it."* An agent who finds the seawall, the unpermitted dock or the groundwater restriction first controls it. One who learns it from the buyer's inspector has lost the deal.

**Pre-purchase (PIR).** Same data, different question: not "how do I manage this" but "should I proceed, and what do I ask for."

**The moat is cross-examination, not coverage.** Every physical change should leave a trace in more than one register, and they should agree on date, scope and actor.

Measured: of **15,801** Volusia marine improvements, **9,704 (61.4%)** have a building permit within a year of the recorded build year. **6,097 do not** — and 5,725 of those sit on parcels that *do* have permits. That is not a value; it is a question the buyer must ask, with the evidence attached, and it is not searchable.

**What competitors do instead.** Civil Intelligence (New York, national, 150M properties, $79–149/mo for 50–150 analyses ≈ $1.00–1.58 per site) sells **feasibility screening to developers** — zoning limits, setbacks, a score. Breadth over depth. They cannot hold Volusia CAMA marine improvements, FDEP remediation status with a monitoring subscription URL, or a Ch. 62-524 well prohibition with a criminal penalty. Different product, different buyer, different moment.

---

## Part 3 — Revenue model

### 3.1 Unit economics

At $5, Stripe takes **8.9%** — net $4.56. At $49/mo it takes **3.5%**.

**One agent at $49/month is worth 125 PIR sales.** An agent-year nets $567.

### 3.2 Consumer PIR scenarios

Base: ~446,946 annual listings × research events per listing × attach rate.

| scenario | events | attach | reports | net |
|---|---|---|---|---|
| 1 per sale | 343,805 | 10% | 34,381 | $156,603 |
| Conservative 2× | 893,892 | 5% | 44,695 | $203,584 |
| Conservative 2× | 893,892 | 10% | 89,389 | $407,168 |
| **Moderate 5×** | 2,234,730 | 5% | 111,737 | **$508,960** |
| **Moderate 5×** | 2,234,730 | 10% | 223,473 | **$1,017,920** |
| Aggressive 10× | 4,469,460 | 10% | 446,946 | $2,035,839 |

**The multiplier is the insight.** Multiple people research the same property — buyer, seller, neighbours, agents. It moves the consumer tier from $157K to $1.02M at moderate assumptions.

### 3.3 B2B agent tier — 312,291 licensees

| saturation | agents | @$29/mo | @$49/mo | @$99/mo |
|---|---|---|---|---|
| 1% | 3,123 | $1.05M | $1.77M | $3.58M |
| 3% | 9,369 | $3.15M | $5.32M | $10.74M |
| 5% | 15,615 | $5.24M | $8.86M | $17.90M |
| 10% | 31,229 | $10.49M | $17.72M | $35.79M |

### 3.4 The conclusion

**3,123 agents — 1% saturation — beats the entire moderate consumer scenario.** At 3% saturation B2B is 84% of total revenue.

**And the assumptions differ in credibility, which matters more than the arithmetic.** A 10% consumer attach means one in ten people researching a Florida property buys a report from an unknown brand — aggressive; 2–5% is defensible. But **1–3% agent saturation is genuinely modest**, and alone clears $1.7M–$5.3M net.

**B2B is the business. Consumer is the funnel.**

---

## Part 4 — Tiers

| tier | price | scope | capability |
|---|---|---|---|
| **Free agent** | $0 | — | Profile claim via DBPR licence verification, listing claim |
| **PIR** | $5 | any property | Automated report, no login required |
| **Shared PIR** | $4 | any property | Agent-shared, read-receipt intelligence (disclosed consent) |
| **Basic** | $99/mo | 1 county | 30 PIRs, single-property assistant, listing syndication, daily brief |
| **Pro** | $300/mo | statewide | Unlimited PIRs, cross-property statistical queries, Roz |
| **Enterprise** | TBD | brokerage | Aggregate usage visibility, query-content privacy by design |

**Basic and Pro are alternatives, not stacked.** Two axes: query complexity (single-property vs cross-property statistical) and reach (one county vs statewide).

**$4 shared PIR is deliberately priced** to push agents toward the $99 bundle of 30 — a bundle is 30 shares at $3.30 each.

**Statewide Pro is defensible today** because the environmental findings — the unique value — come from statewide FDEP and FEMA layers uniform across counties. CAMA depth is what varies.

---

## Part 5 — SEGMENT DICTIONARY: every doorway

Each row is a distinct entry point with its own trigger, motive and product. **The point of many doorways is that each one carries its own reason to arrive; the parcel is the common anchor.**

### 5.1 Consumer doorways

| # | Doorway | Who arrives | Trigger | What they get | Converts to |
|---|---|---|---|---|---|
| **C1** | **PIR purchase** | Buyer, seller, curious | About to buy, or wondering | $5 report | Registration, seller lead |
| **C2** | **Property registration** | Homeowner | Wants map visibility, shareable link | Free claim of their own parcel | PIR, seller lead |
| **C3** | **Forwarded report** | Anyone | Received a shared PIR | Reads someone else's report | Self-serve PIR on their own home |
| **C4** | **Public listing discovery** | Browser | Found a claimed listing | Sees the property page | PIR purchase |
| **C5** | **"Are you selling?"** | PIR purchaser | Asked at checkout | — | Agent introduction, lead |
| **C6** | **Search arrival** | Anyone with a problem | Searched a statute or term | Landing page on that restriction | PIR |

**C6 is under-exploited.** The statutory citations in `restriction_authority` *are* the search terms, and someone searching them has already hit the problem — they are not browsing. Live examples: `Section 404 permit Florida` · `Chapter 373 ERP` · `Chapter 62-524 well prohibition` · `F.S. 197.502 escheat` · `s.872.02 unmarked burial` · `s.403.077 pollution notice` · `Chapter 378 phosphate reclamation` · `s.163.3178 coastal high hazard` · `s.95.11 construction defect repose` · `Chapter 558 notice`.

### 5.2 Professional doorways

| # | Doorway | Who | Trigger | Product |
|---|---|---|---|---|
| **P1** | **Free profile claim** | Licensed agent | Wants their name on a report | Free tier, DBPR-verified |
| **P2** | **Listing claim** | Listing agent | Client forwarded a PIR of their listing | Claim, upload photos, publish |
| **P3** | **Pre-listing check** | Listing agent | About to take a listing | Basic/Pro — *"know it before you list it"* |
| **P4** | **Self-serve curiosity PIR** | Agent | Forwarded a report, buys one | $5 — low-cost self-qualifying entry |
| **P5** | **Portfolio import** | Agent with volume | Has listings to screen | CSV upload, enriched return |
| **P6** | **Buyer-requirement signal** | Buyer's agent | Anonymous per-listing demand | Basic/Pro |

**P5 is the licensing sidestep.** An MLS feed makes *us* the licensee — terms, audit surface, per-market agreement, retention restrictions, one MLS's footprint. **Import makes the agent the licensee**: they already hold the entitlement, and RESO standardises field names across all 489 MLSs, so one importer plus a per-MLS mapping table covers any market. Scope it to *their own* listings.

*Stellar MLS (Florida regional) is ~$550/year + $150 setup; an IDX/RESO feed adds ~$10–70/mo. The gate is broker sponsorship, not cost.*

### 5.3 DoA doorways — `addressfolder.com` (US) · `homeproblems.co.nz` (NZ)

| # | Doorway | Who | Trigger | Motive |
|---|---|---|---|---|
| **A1** | **Defect log** | New-home owner | Found a problem in the warranty window | Evidence for a §558 claim |
| **A2** | **Energy bill claim** | Any homeowner | Proving they own the address | Ownership verification |
| **A3** | **Energy tracking** | New-home owner | Second bill arrives, higher than expected | *"Why did this cost this much?"* |
| **A4** | **Contractor invitation** | Contractor | Homeowner invites them to a logged defect | **Assembles their manufacturer warranty claim** |
| **A5** | **Warranty clock** | Owner or buyer | s.95.11 / s.553.837 deadline approaching | A right nobody tracks |
| **A6** | **Builder lookup** | Buyer | Wants to know who built it | Free, from permit records |

**A4 is what breaks the two-sided market.** I had this wrong initially. A contractor with a documented installation date, product, batch, failure mode and photos has what they need to **file a manufacturer warranty claim** — today that is reconstructed from memory and invoices. The folder produces the package, so the contractor participates because it recovers money, not as a favour.

**The classification allocates responsibility:** *installation* → contractor · *part* → manufacturer, contractor is claimant · *function* → design or specification. The contractor classifies because they have the competence and bear the consequence. The contractor supplies their own manufacturer claim contact — they have the relationship.

**A3 is a defect detector, not a utility feature.** New homes are sold on energy efficiency. A house performing badly against comparable homes *with comparable occupancy* may have an envelope, insulation or HVAC defect. The occupancy questions — occupants, HVAC setpoint, shower habits, pool pump, EV — are what make the comparison meaningful. A crack you notice; a leaky envelope you just pay for, monthly, for thirty years.

**Legal basis, all verified:** Florida's implied warranty of habitability (*Gable v. Silver*) **extends to subsequent purchasers**. **s.553.837**, effective 1 July 2025, requires a one-year warranty that **transfers to a new owner** if the home sells in year one. **s.95.11** repose is **seven years**, shortened in 2023. **Chapter 558** requires a 60-day pre-suit notice describing defects — failure to follow it can get a case dismissed. So the register is **the evidence file for a statutory process**, not a complaint board.

### 5.4 B2G and institutional

| # | Doorway | Who | Trigger |
|---|---|---|---|
| **G1** | **FEMA CTP partnership** | County / regional agency | $41M national cycle; county flood layers carry fields FEMA's statewide layer does not |
| **G2** | **Standards evidence** | County or state | A documented map of where standardisation exists and where it does not |
| **G3** | **Tax-deed / surplus** | County | Lands Available register, escheat clocks |

### 5.5 Free findings that need no market

Available today from data held, no user contribution, no new pull:

- **Builder from the original construction permit** — verified: D R Horton 2,125 homes in Volusia across two name variants, Maronda 2,121, Mercedes 1,744
- **Lead-based paint disclosure duty** — **2,323,819** Florida residential parcels built pre-1978, a federal obligation attaching by build year alone
- **Statute of repose clock** — s.95.11, computed from build year
- **Asbestos era prompt** — pre-1981 construction, framed as a prompt to inspect, never a finding

---

## Part 6 — The flywheel

Every mechanic feeds the next stage rather than dead-ending:

1. Homeowner registers free → unlocks map visibility and a shareable link
2. At PIR purchase the platform asks *"Are you selling?"* → a $5 transaction becomes a lead
3. Homeowner shares the page with their agent → agent, if subscribed, claims it and lists publicly
4. A visitor discovering that listing buys their own PIR → loop restarts
5. Separately, an agent forwarded a report buys a $5 PIR out of curiosity → self-qualifying entry

**The customer onboards new agents organically**, without agent-acquisition spend. This requires the report to make agent-claim status visibly obvious — that visibility is what triggers the question.

---

## Part 7 — The intelligence layer

Because registration is rewarded, a homeowner who registered months ago and is later found browsing another listing is a plausible seller.

**Privacy boundaries, designed in rather than retrofitted:**

- Reported **only at the pattern level** — *"someone matching a seller profile is showing interest"* — never as an identified individual
- Every property accumulates a **permanent activity ledger**: PIR pulls, views, claim history — the vehicle-history-report principle
- **Days-on-market becomes a statistic the platform owns**, because both listing-start and confirmed-sale are independently verified against the county record
- The consumer PIR is **property-keyed, never person-keyed**. No person-search interface.
- The assembled personal profile — criminal/booking + liens + lis pendens + cross-property fused around a named individual — is **a separate access class, never on the consumer tier**
- Owner research at B2B requires verified licence, purpose attestation, and logging

---

## Part 8 — Defensibility

**The data is public; the aggregation is not shortcuttable.** Sixty-seven counties, no two structured alike. Ten `parcel_id` formats. One county publishing the identifier wrapped in an HTML anchor tag. One storing Range–Township–Section where the county publishes Section–Township–Range. 26.7% duplicate keys in another, which are genuine geometry fragments and must be aggregated, not deduplicated.

**The intelligence layer requires owning both sides** — the registration and the query. A third party licensing raw county data cannot replicate it.

**Value compounds with usage.** Every query, registered property and claimed listing makes the next professional's search more valuable.

**And the discipline is itself the product.** Three coverage states rather than two; a null that never renders as false; every claim tracing to a fact record with its source and date; no confidence scores; computed rather than asserted source independence. That is what lets the report say *"we cannot tell you the flood zone here, and here is who can"* — which no competitor does, and which is the difference between due diligence and description.

---

## Part 9 — Roadmap

**Immediate**
- CAMA vendor probe on the top ten counties — decides whether depth reaches 2.86% or ~25% of Florida
- NHD (NHDArea + NHDFlowline) — flood cause and waterfront amenity
- Wire Stripe, launch PIR
- Builder + repose clock into the PIR — free, sourced, no pull
- FEMA CTP conversation

**Near-term**
- B2B assistant, Basic and Pro, with query logging and privacy boundaries from day one
- Agent onboarding via the PIR self-serve entry
- Numeric-provenance validation out of shadow mode
- Roz narration restructured to the nine sections

**Mid-term**
- DoA — `addressfolder.com`, defect log and warranty clock on the same property ledger
- Portfolio import (P5)
- Statewide CAMA per the probe result

**Long-term**
- RFQ — contractor bidding; renovation demand becomes a distinct data product at volume
- Enterprise brokerage licensing
- B2G beyond Volusia
- NZ `homeproblems.co.nz` — *see the parked thesis: a defect register creates accountability by existing. Advocacy rather than revenue; 5M people, small industry, low willingness to pay. Only after Florida works.*

---

## Part 10 — What blocks what

| Blocker | Blocks |
|---|---|
| CAMA vendor probe unrun | Whether the moat product is 3% or 25% of Florida |
| NHD not pulled | Flood causation, waterfront amenity, shoreline |
| Stripe not wired | All revenue |
| Ten reports through production | Numeric-provenance enforcement |
| Broker sponsorship | MLS feed (but **not** portfolio import — P5 sidesteps it) |
| No high-volume agent tester | The B2B pre-listing pitch is unvalidated |

**The chicken-and-egg that stalled the earlier plan is broken.** The data is loaded — 10.7M parcels, 67 counties, 2,050 populated tables. What remains is depth in more counties, not coverage.
