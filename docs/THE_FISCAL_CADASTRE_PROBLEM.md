# The Fiscal Cadastre Problem

**Why this database keeps producing the same eight kinds of defect, and what the shape of the fix is.**

Recorded 2026-08-16. Every figure is measured against the live database; every external claim is sourced.

---

## Part 0 — The observation, and the fact that it has a name

Murphy's framing, verbatim: *government property data was mostly built as a revenue system, not a property system — an inventory of a "product", and that product is the parcel.*

That is not an analogy. It is the established distinction in land administration, and the US authority states it plainly.

The National Research Council's 1983 study *Procedures and Standards for a Multipurpose Cadastre* describes North American cadastral institutions as sharing a focus on fiscal and juridical purposes, and notes that these traditional files are built for special-purpose outputs — <cite index="17-1">the routine use of these files as a source of land information is rarely satisfactory for purposes other than those originally intended</cite>. It sets out three types:

| type | question it answers | who maintains it |
|---|---|---|
| **fiscal cadastre** | *what is this worth, and who is billed?* | the assessor |
| **juridical cadastre** | *who holds what right, and where exactly does it run to?* | the recorder / registry |
| **multipurpose cadastre** | *everything relatable to the parcel* | nobody, by default |

<cite index="17-1">The juridical cadastre demanded a more rigorous delineation of interests, because secure transfer of title depends on it.</cite> The fiscal one never needed that rigour, because a bill only needs one addressee and an approximate footprint.

**Florida gives us the fiscal cadastre and calls it a property record.** The DOR roll, the county CAMA export, the parcel polygon — all three are assessor products. The juridical record lives somewhere else entirely, in the Clerk of Circuit Court, in instruments we have loaded for exactly one county.

**We are building a multipurpose cadastre out of fiscal inputs.** Everything below follows from that.

---

## Part 1 — Does the frame actually explain the defects? Measured.

111 active defects. Testing the hypothesis rather than assuming it.

| class | n | blocking | what the frame predicts |
|---|---|---|---|
| completeness | 28 | 11 | a tax roll carries only what is taxable; non-taxable is simply absent |
| null_as_value | 16 | 11 | a bill has no need to distinguish *no data* from *nothing owed* |
| entity_confusion | 14 | 5 | the unit of a tax roll is the **payer**, not the legal object |
| resolution_mislabelling | 13 | 6 | mostly ours — see below |
| access_control | 12 | 9 | ours, plus statute |
| key_integrity | 10 | 5 | the parcel ID is an **account number**, reassigned on split/merge |
| temporal | 9 | 3 | tax *year*, not calendar time; assessment date, not event date |
| geometry | 8 | 4 | the polygon is a tax map, drawn to bill, not surveyed to bound |
| fanout | 1 | 0 | |

**The honest counter-measurement, and it matters:**

| attribution | n | blocking |
|---|---|---|
| **ours** | **83** | **40** |
| source | 17 | 10 |
| mixed | 3 | 2 |
| undetermined | 3 | 1 |
| unset | 5 | 1 |

**Seventy-five percent of active defects are ours, not the source's.** So the frame is *not* an excuse and must not be used as one.

What it explains is the **shape** of ours. We keep making the same errors because we are repeatedly asking a fiscal record a juridical question and then treating a fiscal-shaped answer as though it were juridical. The impedance mismatch is the defect generator; our carelessness is only the immediate cause.

---

## Part 2 — Six defects re-read through the frame

Each of these was found empirically, before the frame was articulated. Re-reading them is the test of whether the frame is doing work or just sounding good.

**1. The Sarasota condo — `id` vs `account`.** One condo unit returned two valid DOR records: the unit owner at $208,800, and the homeowners association at $0 with 108,052 sq ft of land. Both real. ~58,000 parcels, 19% of the county.

*Fiscal reading:* correct in both cases. The assessor bills the unit owner for the unit and the association for the common element. Two payers, two records.
*Juridical reading:* the buyer owns a unit **and** an undivided share of the common element. That is one bundle of rights, and the tax roll has no place to say so.
**The defect is not in the data. It is that we asked "who owns this?" of a system that only records "who pays this?"**

**2. `hialeah_city_zoning` and `hialeah_city_future_land_use` — 37,362 rows each, 37,291 identical folios.** One parcel layer loaded twice, carrying `true_owner1..3` and mailing addresses.

*Fiscal reading:* of course zoning is joined to parcels. Zoning changes value; value drives the bill. The assessor needs zoning **per payer**, not per district.
**A municipal zoning map is a juridical/regulatory object — a district with a boundary. What the county published is the fiscal projection of it onto billing units.** Highlands is the same shape at 111,860 straps.

**3. `palmcoast_city_zoning` — `originalzone` is the only zoning-shaped column.** 2,687 parcels moved SFR-3B → SFR-2.

*Fiscal reading:* the assessor needs to know what changed, because the change is what re-values the parcel. A rezoning **event log** is a perfectly good fiscal artefact.
**A buyer needs the current state. The record keeps the transition because the transition is what generates revenue impact.**

**4. `true_sink` — 4,215 of 4,417 sinkhole incidents unverified (95.4%), only 103 confirmed.**
Not fiscal at all — a hazard-reporting register, where an unverified report is a legitimate record of *a report having been made*. The defect class is the same though: **a register built to record reports, read as though it recorded findings.**

**5. Collier `ownerline1..5`, `granteeline1..5`.** The owner is split across five lines.
*Fiscal reading:* those are **address label lines on a bill**. Five lines because an envelope has five lines. The party is not modelled as an entity at all — it is modelled as the text you print above the address.
**That is the purest expression of the whole thesis in the entire database.**

**6. The DOR roll carries one `OWN_NAME` per parcel.** Co-owners flattened. 41.5% of Volusia real-property parcels have multiple owners.
*Fiscal reading:* a bill needs one addressee. Correct by design.
**Joint ownership is the norm for married couples, so a single owner field silently misrepresents a large share of the state — and the misrepresentation is in the source's design, not its execution.**

---

## Part 3 — The model that already solves this, and which we have already claimed

**ISO 19152, the Land Administration Domain Model.** Its core is four classes: <cite index="27-1">parties (people and organisations); the rights, restrictions and responsibilities attached to a basic administrative unit; and spatial units, being parcels and the legal space of buildings and utility networks</cite>.

The structure that matters:

```
LA_Party  ──────  LA_RRR  ──────  LA_BAUnit  ──────  LA_SpatialUnit
(who)             (what right)     (the bundle)       (where)
```

<cite index="25-1">A basic administrative unit exists so that one homogeneous right can be registered against one or more spatial units</cite> — which is exactly the Sarasota condo: one BAUnit (the unit + its common-element share), two spatial units, one party.

**Three properties of the model map onto three of our worst defect classes:**

| LADM concept | our defect class it dissolves |
|---|---|
| `LA_Party` as a first-class entity with `role` | entity_confusion — owner vs HOA vs grantor vs contractor stop being "a name in a column" |
| `LA_BAUnit` between party and parcel | the lot/interest problem, condo stacking, fragment aggregation |
| `LA_RRR` split into Right / Restriction / Responsibility | our entire environmental spine is **restrictions**, currently modelled as unrelated "concepts" |
| `VersionedObject` on every class | the temporal class — `originalzone`, `prevflum`, `previouszoning`, `flupy_zone_from` become *versions*, not traps |
| `LA_Source` on every RRR | the fact index — provenance stops being a bolt-on |

**That last row is worth sitting with.** We independently built a fact record with `source · source_tier · as_of · corroborators · derivation`. LADM has the same thing as `LA_AdministrativeSource` and `LA_SpatialSource`, standardised since 2012. We reinvented it because the problem forces the shape.

**MARKETING_THREAD v2 §12 already flags "LADM-based" as an unverified claim, and rules that "LADM-conformant" must never be said.** That ruling stands and this document does not change it. Conformance is a levelled, testable claim against the Annex A Abstract Test Suite. Nothing here has been tested against it.

**But the reason to adopt the model is not the claim.** It is that our defect classes are the known failure modes of not having it.

---

## Part 4 — What this changes, and what it does not

### It does NOT change

- **The load.** Load complete, scrub at render. The fiscal record is the best available evidence of most facts and we keep all of it.
- **The four coverage states.** They are already the right instrument, and they are how a fiscal answer gets marked as *not* a juridical one.
- **The defect discipline.** 75% of defects are ours. The frame explains their shape; it does not excuse one of them.
- **Any current priority.** The nine open items in ruling 223 stand exactly as they are.

### It DOES change three things

**1. The question "is this data wrong?" is usually the wrong question.**

Replace it with: **"what was this record built to answer, and is that the question we are asking it?"**

That single reframe would have caught, in advance: the Sarasota `account` join, the Hialeah duplicate, the Palm Coast `originalzone`, the Collier owner lines, and the single-`OWN_NAME` flattening. Five of the most expensive findings on the project.

**2. Every served field should carry its cadastral register, not just its source.**

We already record `source_tier`. Add the register:

| register | what a finding from it can support |
|---|---|
| **fiscal** (DOR roll, CAMA, parcel polygon) | value, use code, area, improvement — *and an approximation of who* |
| **juridical** (Clerk instruments, plats, deeds) | who holds what right, and the boundary as recorded |
| **regulatory** (FEMA, FDEP, zoning, ERP) | what binds the land, independent of who owns it |
| **inventory/report** (sinkhole incidents, permits) | that a thing was *reported*, which is not that it is *so* |

**A finding that crosses registers is the moat.** Our best product — permit versus improvement cross-examination — is precisely a fiscal record (the assessor's improvement) checked against a regulatory one (the building permit). 6,097 Volusia marine improvements with no permit within a year of the recorded build year: that is a fiscal register and a regulatory register disagreeing, and neither register can see the disagreement alone.

**3. It sharpens what the PIR actually is.**

Not "a property report." **A multipurpose cadastre assembled from three registers that were never built to be joined, with the joins declared and the register of every claim disclosed.**

The 1983 NRC study argued the multipurpose cadastre had to rise beyond special-purpose files. Forty-three years later nobody has built one for Florida, and the reason is visible in our own numbers: 67 counties, ten parcel-ID formats, one county with relational depth in the juridical register.

---

## Part 5 — The repair plan

Ordered by whether the frame changes the work, not by size.

### A — Things the frame says to do differently, starting now

1. **Add `register` to the fact record** — `fiscal | juridical | regulatory | inventory`. One column, four values, and it makes the read-what-it-was-built-for question mechanical instead of cultural. It also makes the cross-examination product *queryable*: "show me findings where two registers disagree."

2. **Model the party, stop modelling the name.** `layer_column_map` now declares 18 party-bearing columns across five counties (`owner`, `owner_2`, `grantor`, `grantee`, `contractor`). That is the LADM `LA_Party.role` enumeration arriving through the back door. Finish it — Collier lines 3–5 are undeclared, and the `(table_name, col_role)` key needs widening to include `column_name` before they can be.

3. **Treat the "previous value" columns as versions, not traps.** Seven found so far: `originalzone`, `rezone`, `prevflum`, `previouszoning`, `previous_zoning`, `flupy_zone_from`, `priorusety`. Under LADM these are `VersionedObject` history and are *valuable* — a downzoning is a finding. Currently each one is a landmine because we have no place to put a superseded value.

4. **Name the register in every coverage note.** *"We hold the assessor's record, which tells you who is billed. Who holds title is a Clerk record and we do not hold it for this county."* That is a better sentence than any current `not_available` text, and it is true.

### B — Things that stay exactly as planned

The nine items in ruling 223 — inventory view, BFE coverage state, the four predicates, `layer_column_map`, the six pulls, Miami-Dade municipal zoning, `COMPL_DATE`, the two new concepts, and the 206 split measured against the permit guard. **None of these change.** The frame explains why they exist; it does not reorder them.

### C — The one strategic item the frame surfaces

**The juridical register is one county deep and that is the real gap.**

`volusia_official_records_private` holds 2,048,300 rows — liens, judgments, lis pendens, restrictions — and it is the only juridical register we have. Everything else is fiscal or regulatory.

The HOA case Murphy raised — a buyer who completed with trust, bank and agent, then found delinquent fines, current fines and land restrictions three months later — **is exactly and only a juridical-register failure.** No fiscal record would ever have shown it. The declaration of restrictions is a recorded instrument. It is in the Clerk's index, in the county where it happened, and it was in nobody's report because nobody joined the juridical register to the parcel.

`parcel_encumbrance_match` resolves ~9.1% of recorded filings (6,923 of 75,946 distinct instruments) — and *states that in the payload*, which is the right handling. **But 9.1% in one county of 67 is the honest measure of our juridical coverage.**

**That, not more counties of CAMA, is what makes the product what it claims to be.** CAMA depth adds fiscal detail we largely already have in shallower form. Juridical depth adds the class of finding that nothing else in the market holds — and it is the class that ruins buyers.

---

## Part 6 — What I am not claiming

- **Not that the frame excuses anything.** 83 of 111 active defects are ours.
- **Not that LADM conformance is claimed, or should be.** MARKETING_THREAD v2 §12 stands unchanged.
- **Not that this reorders the queue.** It reorders how we *read* the data, which is different.
- **Not that fiscal data is bad data.** It is excellent data, rigorously maintained, for the purpose it was built for. Ten million parcels valued annually by 67 independent offices is an extraordinary public asset. It simply is not a record of who owns what, and it never claimed to be — we did.

**The one-line version, and it is Murphy's:**

> *The parcel is not a property. It is a product in a revenue system, and the product is the bill.*

Everything the report does well comes from remembering that, and every defect in the eight classes above comes from forgetting it.
