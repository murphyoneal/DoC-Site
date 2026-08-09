# Nine-section report — section-to-payload mapping + verification plan

Prepared for ruling 72 (spec v5 §0.1). **This is the mapping report requested BEFORE writing the page.**
Scope: a RENDERING change only — `get_pir_report` is not touched. The current page
(`app/report/[coNo]/[parcelId]/page.tsx`) already has a nine-group scaffold; this audits it against
§0.1 and surfaces the ambiguous cases for a ruling rather than deciding them silently.

Payload = the 28 top-level keys `get_pir_report` returns (from `golden_parcel_baseline`):
`meta, property, identityFrame, ownerFacts, plat, salesAgent, values, tax, floodBlock, landRestrictions,
reposeWindow, contaminationFacilities, marineBlock, wetland, groundElevation, land, sinkholeFacts,
amenities, water, schools, schoolsCoverage, permitFacts, transactionFacts, zoningFacts, economic,
taxDeedStatus, censusFacts, disclosures`.

## 1. The mapping (payload key → section)

| § | Section | Payload keys that feed it |
|---|---|---|
| 1 | What this is | `property`, `meta`, `ownerFacts` (owner-of-record name only), `plat` (boundary map), `identityFrame` (frame signals) |
| 2 | What legally binds (no distances) | `floodBlock` (SFHA determination), `landRestrictions` (GWCA / institutional controls / on-parcel wells), `reposeWindow` (construction-defect window), `property.yearBuilt` (lead-paint duty), `identityFrame.signals` (historic designation), + hardcoded universal burial notice (s.872.02) |
| 3 | On / under parcel (contains only) | `contaminationFacilities` (on-parcel subset), `marineBlock`, `wetland`, `groundElevation`, `land` (gopher-tortoise **inside/covered only**) |
| 4 | Nearby (everything with a distance) | `contaminationFacilities` (nearby subset), `sinkholeFacts`, `amenities`, `water`, `schools` + `schoolsCoverage` |
| 5 | The record (facts w/ as_of) | `values`, `tax`, `transactionFacts`, `permitFacts`, `zoningFacts`, `economic` (cra/enterprise/hub/opportunity zones), `censusFacts`, `taxDeedStatus` (status) |
| 6 | Open questions | `identityFrame.triggers`, `marineBlock` cross-examination (permit vs assessor) |
| 7 | What we couldn't tell you | every `not_available` / `not_established` coverage state across all sections + its `who_can_answer` (read from the payload / `restriction_authority`, not hardcoded) |
| 8 | Further due diligence | crime & safety, neighborhood news/web (tier-separated; separate data path) |
| 9 | Sources | `data_source_registry` jurisdiction-level citations (never the portal) |

## 2. The interesting cases — need a ruling (not decided silently)

**C1 — HARD-RULE break: a distance above §4.** `land.gopherTortoiseNearestM` currently renders
"Nearest habitat {miles}" inside §3 ("Land"). Recommendation: §3 keeps only the containment
(`gopherTortoiseInside`/`covered`); the **nearest-distance moves to §4**. Same parcel key splits across two sections.

**C2 — `economic.brownfield` is misfiled and split-relation.** It renders in §5 "Economic zones" today, but
brownfield is not an incentive zone — and it carries BOTH relations: `inside_area` = **contains** (Designated
brownfield ON parcel → §3, or §2 as FDEP-regulated) and `nearby_sites`/`nearest_area` = **distances in ft**
(→ §4). Recommendation: unbundle brownfield from the tax-incentive `economic` block; containment → §3, proximity → §4.

**C3 — `environmental_overlay` is NOT in the payload.** The ruling places it in §3, but grep confirms it is
absent from `get_pir_report` (not among the 28 keys, not nested in `landRestrictions`). It is resolver-served
(8 counties) but never wired into the report payload (backlog #141). **Rendering it in §3 requires editing
`get_pir_report` — which this ruling forbids.** Ruling needed: lift the no-touch constraint for this one wire,
or defer environmental_overlay to a later payload change and render §3 without it for now.

**C4 — `salesAgent` is homeless.** It is in the payload (`get_pir_report` line 156) but rendered nowhere.
Ruling needed: assign a section (§5 record is the natural home) or leave it unrendered by decision — but not silently.

**C5 — `taxDeedStatus`: §5 vs §6.** Recommendation: **split.** The STATUS (on-list / not, opening-bid-or-estimate,
`as_of`) is a record fact with a date → **§5**. The ESCHEAT AMBIGUITY (cert 9219-20 still listed past its computed
date; "confirm with the Clerk") is a due-diligence question → **§6**, as a pointer, not a duplicate.

**C6 — `disclosures` (source limitations) placement.** Currently rendered at the TOP of §1. A source limit is
"what the county's record does not publish" — that reads as **§7 (what we couldn't tell you)** or §6, not the
identity frame. Recommendation: move to §7 (or §6); ruling on which.

**C7 — `economic` incentive zones in §5.** cra/enterprise/hub/opportunity are opt-in incentive designations, not
binding constraints; §5 (record) is defensible. Flagged only in case §2 is preferred. Minor.

**C8 — zoning sub-null (backlog #154).** `zoningFacts` sub-value returns bare null where no polygon matches;
that distinction (queried-no-polygon vs no-layer-held) belongs in the §7 coverage treatment, not silently in §5.

**C9 — the LEAD.** §0.1 requires a ranked lead (contamination containment → SFHA → GWCA → institutional control →
lead-paint duty → historic district; first-present wins; contamination+GWCA combine, ≤2 clauses; where none is
present, say so and point at §7 — silence must never read as clearance). The page today has the disclosures box +
historic signal but **no ranked lead hero**. This is new rendering work; the ranking selector is a pure function
over `floodBlock`, `landRestrictions`, `contaminationFacilities`, `property.yearBuilt`, `identityFrame`.

**Legitimate multi-home keys (not defects):** `ownerFacts` (name in §1, full set + history in §5);
`identityFrame` (lead + §1 frame + §2 designation + §6 triggers); `contaminationFacilities` (already correctly
split on-parcel §3 / nearby §4). These are frame/relation objects consumed in more than one place by design.

## 3. Verification plan (stated honestly)

The **golden-parcel suite watches payload sections, not rendered HTML** — it will NOT catch a rendering reorder or
a regression in section placement. So it is not sufficient here.

- **Verifiable without a browser (pure functions, no DB):** extend `lib/report-coverage.test.mjs` to assert the
  section-assignment adapters — `taxDeedView`, `disclosuresView`, the brownfield/contamination on-vs-near split,
  and the new lead-ranking selector. Deterministic.
- **A strong HARD-RULE check I can build:** assemble the §1–§3 view models as pure data and assert **no
  distance-bearing field appears above §4** — this directly enforces §0.1's hard rule and needs no browser.
- **What I CANNOT verify without a browser render on an UNLOCKED parcel:** the actual rendered section ORDER on a
  real page. The report is paywalled (per-parcel Stripe unlock). Honest answer: I cannot fully verify the rendered
  page without a comped/unlocked test parcel or a dev-mode gate bypass. **I will not substitute the payload/golden
  check as if it proved the rendering.** Need from Murphy: an unlocked test parcel per coverage archetype (or a
  dev bypass) so I can browser-render and confirm order + the no-distance-above-§4 rule visually.

## 4. What I did NOT do

Per the ruling: the page is not written. No change to `get_pir_report`. Awaiting rulings on C1–C9 (especially
C3 environmental_overlay, which cannot be satisfied under the no-touch constraint) and confirmation of the
verification approach before implementing.
