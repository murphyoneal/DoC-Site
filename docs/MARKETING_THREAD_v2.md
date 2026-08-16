# DoP / AddressFolder — Marketing Thread v2

**Consolidated 2026-08-15.** Supersedes `MARKETING_THREAD_v1.md` (9 August).

v1 collected six sessions of scattered material. v2 adds four things that were either missed, decided after v1 was written, or found this week:

1. **The customer is the seller and the agent discharging a disclosure duty**, not only the buyer. *Johnson v. Davis* is the legal hook and it changes who the pitch is aimed at.
2. **The public-interest publication programme** — Project Tango and the Palm Beach data centre corridor as the first free PIRs. This is the demonstration, the SEO engine and the credibility argument in one artefact, and v1 did not contain it at all.
3. **Goliath Data**, found 15 August. Not a competitor. The antithesis — and more useful for that.
4. **The price ceiling is deal economics, not software budget.** v1 corrected the MLS claim but kept arguing inside the wrong frame.

Each item is marked **DECIDED** (ruled and settled), **IDEA** (raised, not ruled), or **UNVERIFIED** (must be checked before public use). The last category is still the one that matters — a marketing claim that fails scrutiny on launch day is worse than no claim.

---

## 1. The core positioning

**DECIDED — the product is a due-diligence check before a property is listed or purchased.** Not a listing service, not a feasibility screen, not a description.

- **Pre-listing, to agents:** *"Know it before you list it."* An agent who finds the seawall, the unpermitted dock or the groundwater restriction first controls it. One who learns it from the buyer's inspector has lost the deal.
- **Pre-purchase, to buyers:** same data, different question — not "how do I manage this" but "should I proceed, and what do I ask for."

**DECIDED — a resource, not a report shop.** Murphy, 20 July: *"We aren't selling just reports but becoming the property resource for home buyers."*

A report shop is a funnel: address → pay $5 → PDF. A resource has depth people arrive at *before* they are ready to buy anything — someone searching "what does flood zone AE mean" is months from a transaction. That requires real informational content living independently of the paywall:

- A knowledge base — flood zones, sinkhole susceptibility, DOR use codes, what "arrests not convictions" means
- County hub pages — *"Buying a home in Volusia County: what to know"*
- **Public-interest reports** — see §2, which is the strongest version of this and was not in v1
- The PIR as the paid, specific culmination, not the whole product

### 1.1 NEW AND DECIDED — the customer is also the seller and the agent, because they carry a legal duty

v1 framed everything around the buyer. That was half the market and the less urgent half.

***Johnson v. Davis*** (Fla. 1985) requires a seller to disclose facts materially affecting value that are **not readily observable** to the buyer. Florida's residential disclosure obligation runs on that case. A groundwater restriction, a contamination plume two parcels away, an unconditioned entitlement on adjacent land — none of those are readily observable, and all of them are in a PIR.

**The consequence is the whole commercial argument:** the PIR snapshot — hashed, append-only, with a scrub manifest and a code version — is **the seller's and the agent's evidence that they looked**. That is why it ships with Stripe rather than after it.

**The line:** *"You are already the person who spots what the buyer missed. This is what you currently cannot see — and this is your record that you looked."*

Buyer marketing sells a $5 report. Seller-and-agent marketing sells insurance against a claim, and that buyer has a budget.

---

## 2. NEW — The public-interest publication programme

**DECIDED.** When a property becomes the subject of a public land-use fight, DoP publishes a free, complete PIR as a public service. First candidate and exemplar: **Project Tango, 20125 Southern Blvd, Loxahatchee (Palm Beach, parcel `00404332000001030`).**

This is simultaneously the demo, the SEO engine, the press hook and the ethical argument. v1 had none of it.

### 2.1 Why this parcel is the perfect example page

Every fact below is public. Every one is in county PDFs, newspaper archives, or an Earthjustice letter sitting on the county's own PZB server. **None of it is reachable from the address.**

- **It is filed as "State Road 80", not Southern Blvd.** A county address search on the common name returns nothing. Whether that is intent is not establishable and we do not assert it — SR 80 is the legal designation. **The effect is identical either way, and the effect is what harms a buyer.**
- **A $2–2.6bn, 3.7M sq ft AI data centre application was denied 5–1 on 15 July 2026** after a 12-hour hearing with overflow rooms.
- **The denial stopped the expansion, not the development.** The 2016 approval carried **no conditions of approval** — confirmed on the record by zoning staff when Commissioner Joel Flores asked directly. The site retains 202 acres zoned for 206,000 sq ft of data centre and 1,814,000 sq ft of warehouse, unconditioned. PBA Holdings has applied for **administrative approvals taking data centre space to 752,000 sq ft — with no public hearing required.**
- **1,200 feet from Saddle View Elementary**, which opened August 2025 on former Palm Beach Aggregates land.
- **Water demand: the developer said 5,000 gallons per day. County staff projected 100,000.** A twentyfold discrepancy on the most contested resource in the Everglades Agricultural Area — on land our own system scores at aquifer vulnerability 179 against a statewide median of 169.
- **The end operator is legally shielded.** A 2017 Florida statute lets developers keep the operator's identity confidential. Nobody knows who it is for. That is written law, not a theory.
- **An Arden resident running for his own HOA board learned about it four days before the hearing.** He lives next to it. The record was public the entire time.
- **Our own municipal boundary layer is dated 2 February 2021.** Wellington's limit sits 0.34 miles — 1,800 feet — from that parcel, and Wellington has explored an interlocal agreement to annex the area. **We disclose that staleness in the report.** The defect is registered as `municipal-boundary-annexation-lag`.

### 2.2 The sentence this programme exists to prove

> **The asymmetry is not that the information is secret. It is that it is unreachable by the people it affects.**

That is the thesis of the entire company, and this parcel demonstrates it better than any pitch deck.

### 2.3 How the pages are built — DECIDED

- **Free, complete, no paywall, no login.** Public-interest reports are never gated. Gating one would destroy the argument they exist to make.
- **Same renderer, same fact index, same coverage states as a paid PIR.** No special-casing. If the report says `not_available` for a field on this parcel, it says so publicly. That is the point.
- **`publicInterest: true`** already exists in the payload `meta` block. It is currently `false` on this parcel. Wire it.
- **Neighbour pages are the real product.** The Tango parcel is the anchor; the pages that convert are *"what this means if you own in Arden"* and *"what this means if you own in The Acreage"*. A buyer at 4521 Arden Way, 2.3 miles away, currently gets nothing from any listing, title search or property record.
- **A corridor, not a parcel.** Data centre applications cluster. One page per contested site, plus a Florida-wide index page, is a content category with genuine ongoing search demand and effectively no competition.
- **Every claim carries its authority and who can answer**, exactly as in a paid report. This is where the discipline becomes visible to a general audience rather than to a buyer.

### 2.4 What this earns

- **Search traffic on terms nobody else holds** — the project name, the school name, the road designation, the community names.
- **Press.** A free, sourced, machine-generated due-diligence report on a nationally-covered land-use fight is a story about the tool as much as the site.
- **The demo that ends the RPR argument.** Never demo a property record. Demo *this*.
- **Proof that the report is not for sale to the highest bidder.** A platform that publishes against a $2.6bn applicant is credible when it says the report is honest.

**UNVERIFIED / handle with care.** Reported facts that are *not* our findings and must never be rendered as findings: the Ellison family purchase of Lion Country Safari 1.8 miles away for $30M; the reported same-day $10,000 developer donation to Mayor Sara Baxter's PAC; the county attorney's recusal advice. Those are journalism. They go in a "further reading" tier with attribution or they do not appear at all. **We have no evidence of tax breaks on this project and will not repeat that as fact.**

---

## 3. The strongest single line for an agent conversation

**More than half of buyers say their agent pointed out property features or flaws they had not noticed** (NAR 2025 Profile of Home Buyers and Sellers). 56% say finding the right property was the hardest part. 88% still transact through an agent.

That is the service buyers already credit agents for. The pitch is therefore **not** "here is property data" — RPR is free with NAR dues and already does that. It is:

> *"You are already the person who spots what the buyer missed. This is what you currently cannot see."*

The agent is not being disintermediated. They are being asked to know more — and, per §1.1, to have a record that they looked.

---

## 4. What we are NOT competing on — the RPR ruling

**DECIDED.** Realtors Property Resource is free with NAR dues — no monthly fee, no upgrade tier, ~147M property records, custom-branded reports. Every agent already has it.

**Where it stops, precisely:** RPR's flood layer is FEMA NFHL only, and RPR states its flood maps exclude data from local municipalities not approved by FEMA. That is the exact statewide layer that produced a false "not in a Special Flood Hazard Area" on a St Petersburg parcel that is 24% Zone AE. Beyond flood, RPR's layers are trends, indicators and demographics — no contamination, no institutional controls, no wetlands, no mining, no sinkhole susceptibility, no groundwater restriction, no permit-versus-improvement cross-examination.

**The rule this forces:** "property data for agents" at $99/month competes with zero and loses. "The environmental and permit record RPR structurally cannot hold" competes with nothing.

**Never demo a property record. Demo a finding RPR cannot produce, on a parcel the agent knows** — or demo Project Tango.

### 4.1 NEW — and the "statewide is thin" worry is now obsolete

The business plan warned that Pro's statewide claim was thin — flood 52 of 67, wind 3, storm surge 2. **Measured 15 August, that has changed.** Flood is **67 of 67, all verified**. And every environmental concept — contamination ×3, GWCA, institutional controls, wetland ×2, phosphate mining, aquifer vulnerability, sinkhole susceptibility, petroleum discharge, brownfield, drycleaning, pollution notices, source-water protection, surface geology, defence sites, historic ×2, water ×3 — resolves at **state level, one layer, uniform across all 67 counties.**

That is exactly the spine the RPR ruling said Pro must be sold on, and it is now genuinely statewide. **The differentiator is not reach and never was — it is depth on a spine that happens to be uniform.** What varies is CAMA depth, which is not what we are selling against RPR.

---

## 5. Channels and doorways

### 5.1 Search arrival — free and under-exploited

**DECIDED.** The statutory citations in `restriction_authority` *are* the search terms, and someone searching them has already hit the problem — they are not browsing.

`Section 404 permit Florida` · `Chapter 373 ERP` · `Chapter 62-524 well prohibition` · `F.S. 197.502 escheat` · `s.872.02 unmarked burial` · `s.403.077 pollution notice` · `Chapter 378 phosphate reclamation` · `s.163.3178 coastal high hazard` · `s.95.11 construction defect repose` · `Chapter 558 notice`

Each deserves a landing page on that restriction, ending in the PIR.

**Add to this list, from §2:** data centre / land-use terms. `Project Tango` · `Palm Beach data center` · `Saddle View Elementary data center` · `Arden Loxahatchee data center` · `Florida data center water use`. These are live news terms with genuine volume and no property-data competitor holding them.

### 5.2 Free findings that need no market and no new data

Available today, no user contribution, no new pull:

- **Builder, from the original construction permit** — verified: D R Horton 2,125 Volusia homes across two name variants, Maronda 2,121, Mercedes 1,744
- **Lead-based paint disclosure duty** — 2,323,819 Florida residential parcels built pre-1978, a federal obligation attaching by build year alone
- **Statute of repose clock** — s.95.11; 813,971 parcels built since 2019 sit inside the seven-year window
- **Asbestos era prompt** — 2,949,619 parcels pre-1981, framed as a prompt to inspect, never as a finding

### 5.3 Agent profile pages as SEO, not just leads

**DECIDED (5 July, revised).** DoP does not sell or represent property; it displays the contact agent, who must register and maintain their own profile first — structurally the Zillow/Realtor.com model. Profile pages generate their own search traffic for the agent, which is an incentive to register *beyond* lead volume.

**Hard rule:** claimed profiles get a public page. Unclaimed licences stay in the database. There are ~246,714 licensed agents in the roster and generating a page for every one is a directory nobody asked to be in — legal, since it is public record, and exactly the thing that produces complaints. **The claim is what grants publication.**

**Open, needs a lawyer when designed:** any mechanic that charges agents for placement or leads touches state referral-fee law. Routine and well-solved — it is how Zillow monetises — but reviewed before it is built.

### 5.4 Word of mouth

A genuinely impressive $5 report is inherently shareable — *"look what this cost me five dollars."* A buyer showing it to their agent is organic distribution nobody paid for, and it is the self-qualifying entry that puts an agent in front of the product.

### 5.5 NEW — IDEA, from 20 July and never specced

**RSS property news feeds on the site, plus advertising, labelled as such.** Raised, never designed. It belongs in the resource layer alongside the knowledge base, and the public-interest pages in §2 are the natural editorial anchor for it.

---

## 6. Privacy as a marketing asset, not a constraint

**DECIDED, and it must be visible to the consumer rather than merely true in the schema.**

NAR 2025: 41–47% of buyers start by searching online; only 18–20% start by contacting an agent. Median search duration is 10 weeks. **Roughly four in five buyers deliberately begin without an agent** — they shop, shortlist, and attend open homes specifically so nobody hounds them.

DoP's design is property-keyed, never person-keyed; reported only at the pattern level. **The agent receives a count, never a contact.** They cannot call anyone because there is nobody to call.

Say it on the purchase page. *"We tell agents about the property. Never about you."*

**The risk if this is ever ambiguous:** if buyers suspect a $5 PIR flags them to an agent, the consumer funnel dies and takes the B2B data with it. The only lead path is the "are you selling?" prompt at checkout, where the consumer opts in.

### 6.1 NEW — the contrast is now concrete, and it has a name we must not use

See §8.1. There is now a live, funded platform with 11,000+ customers whose own homepage advertises tracking *"Family change – pregnancy"*, *"Job change detected"* and *"Marriage license filed"* against a named homeowner at a named address, scored for seller intent and routed to an automated calling agent.

**DECIDED — do not name them in any public copy.** Punching at a named competitor is bad form, invites a response, and makes the claim about them rather than about us. **The category is describable without the name**, and any buyer who has been on the receiving end of that outreach will recognise it in one sentence.

**And it raises a compliance item on our own side.** That platform ships DNC scrubbing, number registration, consent capture and opt-out handling, and carries a dedicated DNC-flagging legal page — because outbound to homeowners sits squarely in TCPA and state do-not-call law. Our "Are you selling?" prompt creates a lead an agent may then call. **The checkout consent must be explicit affirmative language, not a pre-ticked box, and it must be the lawyer item in §5.3 rather than after it.**

---

## 7. The discipline is itself the marketing

Four coverage states rather than two — `present` / `none_within_range` / `not_available` / `not_applicable`. A null that never renders as false. Every claim tracing to a fact record with its source and date. No confidence scores. Computed rather than asserted source independence. US units on every rendered figure.

That is what lets the report say:

> *"We cannot tell you the flood zone here — and here is who can."*

No competitor does this. It is the difference between due diligence and description, and it is a claim that survives inspection because it is mechanically true.

**And it is publicly testable, once §2 ships.** Anyone can open the Tango report and check.

---

## 8. Price anchors found in the market

| product | price | what it tells us |
|---|---|---|
| `homedatareports.com` | **$14.97–22.97** one-off | Consumer property-risk report — flood, SFHA, disaster declarations, 30 years of storm history, Superfund, TRI, radon, hazardous waste. Same shape and framing as the PIR, already in market, at 3–4× the price. **Argues $5 may be underpriced, not aggressive.** Their line: *we check the land and what's outside, an inspector checks inside, hire both.* |
| Civil Intelligence | $79–149/mo, ~$1.00–1.58/site | Feasibility screening for developers. Breadth over depth. Different product, buyer and moment. |
| **DoP Basic / Pro** | **$99 / $300 per mo** | Priced against an agent's software budget. See §8.2. |
| Mercator.ai (Florida) | **$400–1,200/mo**; exclusive leads $80–300 | The contractor side, priced by a participant. If RFQ or the AddressFolder contractor loop ever monetises, that is the band — not $99. |
| MLS + association dues | **~$1,260–1,280/yr** recurring | NAR $156, Florida REALTORS $146 + $30 advocacy, local dues ~$285–300, Stellar MLS ~$645. Plus $200 application. |
| **Goliath Data** | **$999 / $2,999 / $7,499 per mo** | **NEW 15 Aug.** Every tier runs the full system; tiers change volume only. Sold to investors *and* listing agents. See §8.1. |

### 8.1 NEW — Goliath Data: not a competitor, the antithesis

Found 15 August. `goliathdata.com`, Chattanooga TN, claims 11,000+ operators, claims 50-state coverage.

**What it is:** lead generation for wholesalers and investors, sold as an AI sales stack. It watches for pre-foreclosure notices, tax delinquencies, probate filings and code violations, skip-traces the owner, ranks them by a "Seller Intent Score", and pushes them into automated text and voice sequences. Their inbound voice agent is named David.

**Why it is not a competitor:** person-keyed versus property-keyed. Forward-looking versus backward-looking. It exists to find someone distressed enough to sell cheap; the PIR exists to stop a buyer walking into a bad parcel. They will never hold FDEP contamination status, a Ch. 62-524 well prohibition, or permit-versus-improvement cross-examination, because none of that helps you find a motivated seller.

**Why it is more useful than a competitor:** it is the clearest available illustration of the thing we have decided not to be (§6.1), and it prices the market (§8.2).

**UNVERIFIED — do not repeat.** *"We bypass delayed aggregators and pull from county data and court records hourly"* with *"Nationwide 50-State Coverage."* We know precisely what 67 counties in one state costs. Hourly direct pulls from ~3,100 counties is implausible as stated. The likely truth is a narrow slice of record types — foreclosure and probate filings have far fewer publishers than parcel or CAMA data — plus commercial skip-trace vendors behind the word "NATIVE". Not knowable from the site. **Record as a claim, not a fact**, and never cite it as evidence that statewide-and-deep is easy.

### 8.2 NEW AND IMPORTANT — the ceiling is deal economics, not software budget

v1 corrected the business plan's claim that *"$99/month sits inside an existing budget category"* — $1,188/year roughly equals an agent's entire existing platform spend rather than sitting inside it. That correction was right and the frame was still wrong.

**Goliath's entry tier is $999/month and its customers include listing agents, not only wholesalers.** That is ten times Basic and more than three times Pro. Mercator sits at $400–1,200. Two independent participants price this market in four figures monthly.

**The reason is the denominator.** Basic and Pro are priced against what an agent spends on *tools*. Goliath and Mercator are priced against what a *deal* is worth. One wholesale assignment is $10–20k. An agent who loses a $400k listing at inspection over an unpermitted seawall has lost roughly $12k of commission.

**That is the number Pro should be argued against — not the MLS invoice.**

*"MLS fees buy distribution. They do not buy feedback"* remains the right line for Basic. For Pro the line is different and stronger: **one deal saved pays for four years.**

**IDEA, not ruled:** this argues for a higher Pro price, or for a tier above Pro aimed at brokerages and investors where the deal-economics framing is explicit. Not decided. But the current pricing is defended on the wrong axis, and the market says the ceiling is a long way up.

---

## 9. AddressFolder — the defect-register argument

### 9.1 The proof of demand

**Cy Porter / CyFy Home Inspections, Phoenix.** ~250K TikTok, ~300K each on YouTube, Facebook and Instagram, one video past 4 million views, **booked 14 months out**. Taylor Morrison filed a complaint with the Arizona State Board of Technical Registration; the board found no verifiable violations. Streisand effect followed.

Three things his existence proves: demand is enormous, **builders will fight documentation** (which tells you a public record of defects has real commercial force), and **the warranty window is where the value is** — he specialises in one- and two-year warranty inspections, because that is when the builder is still obliged and the homeowner still has a claim.

**The gap:** nobody keeps a structured, durable record of new-build defects tied to the property and the builder. Cy documents on TikTok. Inspectors write PDFs the homeowner files and forgets. The builder holds the claim history and nobody else sees it. **And when the house sells, all of it vanishes** — the next buyer has no idea the roof was rejected twice in year one.

### 9.2 The structural argument — Murphy's, and explicitly flagged as marketing

> *"An organisation that certifies products has no institutional appetite for a register showing which certified products fail. That's not a conspiracy, it's just what the incentive produces."*

**Leaky buildings is the canonical proof** — a systemic, decade-long, multi-billion failure across an entire building stock, and no failure register existed to catch it early.

**And Florida is the better laboratory than New Zealand.** Larger stock, extreme environmental loading, and a documented history of exactly this failure mode: Chinese drywall, EIFS, polybutylene, and post-Surfside structural scrutiny. Each took years to surface. Each would have been visible early in a register holding installs and failures with dates and batches.

*(Murphy, 9 August: "NZ is where you understood the problem. Florida is where the sample size is.")*

### 9.3 It is not an empty register — lead with that

**The strongest AddressFolder line is that the county has already written most of it.** Volusia alone holds 992,313 permits across 240,264 parcels, 147,113 named contractors and 363,677 recorded improvements. **Statewide, 8,485,822 parcels have a building record.** A homeowner opens their folder and finds the work history already assembled — they are annotating a record, not creating one.

**And as of 15 August that is no longer one county.** Pinellas holds **1,654,923 permits across 376,553 parcels** — 67% larger than Volusia. *(Currently loaded but not yet served; blocked on ruling 199. Do not market it until it serves.)*

### 9.4 Framing rule

**Rights-first, never deadline-first fear.** The `construction_defect_law` table covers all 50 states with primary-source verified statute text, repose periods and exceptions, and the framing is what rights a homeowner has — not what they are about to lose.

**Statistics, never scores.** Complaint count, response count, resolved and unresolved. A count is what is in the record; a score is our own statement.

---

## 10. NEW — the multiplier loop, in Murphy's own framing

**IDEA, raised 20 July, never specced, and it is the reason the free content layer is not a cost centre.**

> *"All of these data loops we create have to benefit the end game of DoA and the RFQ system. The post-occupancy regrets data aids the agent in the sales game and provides logic for the buyer. So it's sort of a multiplier dataset. In the future this will tag that a bathroom will need replacing in such and such property. It becomes the future lead-in for the RFQ system. Even the notes on the PIR report signal this sort of information. Doesn't mean it's guaranteed, just that it's possible."*

The chain: PIR observation → AddressFolder record → renovation demand signal → RFQ. Each stage is a product the user wants for its own sake, and each one produces the input to the next.

**The marketing consequence:** the knowledge base, the county hubs and the public-interest pages are not overhead. They are the top of a funnel that ends in contractor bidding — a market priced at $400–1,200/month by Mercator.

**The framing rule this needs, and it is the same one as everywhere else:** a signal is a possibility, never a finding. *"Original bathroom, 1974, no permit since"* is a fact. *"This bathroom needs replacing"* is our own statement and must never be rendered as a record.

---

## 11. Compliance boundaries that constrain marketing

- **Beta does not suspend FCRA.** A beta serving real reports to real users is a real product legally. Use-restriction terms, purpose attestation and agent licence verification are live from the first paid report.
- **Property-keyed, never person-keyed.** The assembled personal profile is a separate access class and never on the consumer tier. "The inputs are public" is not a defence — compiling individually-public records into a sold report creates a new regulated artifact.
- **Geometry is a tax map, not a survey.** Every rendered parcel outline carries the caveat. This is a liability fence as much as an accuracy rule, and it is also a trust signal.
- **Never name the portal.** Jurisdiction-level citation only.
- **NEW — outbound consent.** Per §6.1, the "are you selling?" lead path needs explicit affirmative consent language reviewed before it is built. TCPA and state DNC law attach to the call, and the agent makes the call.
- **NEW — public-interest reports do not suspend any of the above.** A free report on a contested parcel is still a compiled artifact and still property-keyed. Publishing it does not licence naming individuals, and the journalism-tier facts in §2.4 stay attributed and separate.

---

## 12. Claims that must be verified before public use

**UNVERIFIED — handle carefully.**

1. **"First LADM-based property intelligence platform in the USA."** What was established is that no US profile appears in OICRF's 139 documents — the main public library, not an exhaustive search. Someone could have built one without publishing. Verify before launch.
2. **"LADM-conformant" must never be said.** "LADM-based" and "LADM-aligned" are safe. Conformance is a specific, levelled, testable claim against the Annex A Abstract Test Suite. National profiles are scrupulous about this — South Africa says its models *could be refined to conform to level one*. Claiming untested conformance is a match rate with no negative control, and in marketing it is worse because anyone who knows the standard can check.
3. **Stellar MLS ~$645/yr** comes from an association application form, not from Stellar — they do not publish a headline price. Well-sourced, not authoritative.
4. **Build it because it is the right model, not because it is a line.** If LADM is a positioning play it will be implemented shallowly and it will show. The Sarasota condo and the co-owner defect are the reason to do it. The press release is a side effect.
5. **NEW — Goliath's 50-state hourly county-and-court claim.** See §8.1. Recorded, not believed.
6. **NEW — anything in §2.4.** The Ellison purchase, the PAC donation, the recusal advice. Journalism, attributed, never rendered as a finding.

---

## 13. Gaps in this thread

- **No content calendar exists.** The knowledge base and county hub pages are agreed in principle and unwritten. **The public-interest pages in §2 are now the obvious first entry** — the material is already gathered.
- **No launch sequence.** Site is `Disallow: /` behind a `SITE_INDEXABLE` kill-switch, so none of the SEO work is live yet, and that is deliberate.
- **The feedback product is empty on day one.** An agent dashboard shows zeros until consumer traffic exists. The acquisition pitch must lead with the environmental record; the feedback loop is the retention argument.
- **No brand voice defined.** The report's voice is settled by the spec — honest absence, no confidence scores, who-can-answer. The marketing voice is not.
- **`CUSTOMER_ACCOUNT_FEEDBACK_SPEC.md` is superseded** by the business plan but contains marketing mechanics — feedback loop with $1 credit incentive, property visit notes, buyer-requirement signals — that were never re-homed. Worth re-reading before writing copy.
- **NEW — §8.2 reopens pricing and nothing has been ruled.** The market says four figures monthly. The plan says $99 and $300. That gap is unresolved and it is the largest unexamined number in the business.
- **NEW — the public-interest programme has no publication policy.** Who decides a property qualifies? What happens when an applicant's lawyer writes in? What is the correction process? None of that is designed, and it needs to be before the first page goes live rather than after.
