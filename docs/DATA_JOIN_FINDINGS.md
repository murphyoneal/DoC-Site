# Data-Join Findings

Where a join between two datasets was validated (or overturned). The controlling rule: **internal
consistency is not verification** — a plausible join is proven only by a negative control that a
*wrong* join fails.

## §1 — Protocol

For any join asserted as correct, run §1 Test 3: **the deliberately-wrong join.** Construct a join
that must be wrong (shift a key by one, shuffle the pairing, use the neighbouring id) and measure its
match rate. If the wrong join matches nearly as often as the right one, the right join's rate means
nothing — the match is measuring "a record exists," not "the correct record."

A high match rate is necessary, never sufficient. Match **plus corroboration** (a second independent
key agreeing) is the standard where a single key cannot discriminate.

## §2 — Negative-control overturns

Cases where a negative control overturned or rescued a plausible join. Each cost a real failure or
near-miss; each is an anchor so the join is not re-trusted naively.

| # | join | plausible rate | wrong-join (control) | verdict |
|---|---|---|---|---|
| 1 | Sarasota `account` vs `id` | high | (control) | overturned — the "obvious" key was the wrong one; corrected after the control failed |
| 2 | Volusia official records → parcel, **by legal (lot+subdivision) alone** | 36.2% | **shifted lot +1 → 31.4%** | **overturned** — only 4.9 pts discrimination; lot N and N+1 are both real parcels, so a wrong lot silently attaches an encumbrance to the neighbour |
| 2b | same join, **legal + owner-name corroboration** | 22.9% | **shifted lot +1 → 0.4%** | **rescued** — 22.5 pts, **57× lift**; the neighbour has a different owner, so corroboration collapses the wrong join. Only corroborated matches emit as findings |

### Anchor detail — encumbrance join (case 2)

- **Match-alone forbidden.** A lien/lis-pendens finding requires Route 3 (legal → `volusia_parcel_centroids.legal1`, parse-to-parse; the `lot` column is lot×10 and unusable) **AND** Route 1 (recorded R-party name ↔ resolved parcel owner, ≥2 shared name tokens).
- **Route 2 (book/page/instrument → `volusia_cama_sales`) is a dead end (0.0%)** — encumbrances are not sales; their instrument is their own recording, not the parcel's deed.
- Controls 1 (wrong-subdivision: `BAYBERRY` ≠ `BAYBERRY LAKES`), 2 (wrong-lot → zero), 3 (20 lien-free parcels → zero fabricated) all pass.
- Materialised set: **4,598 corroborated encumbrances** (3,390 parcels, 1,181 lis pendens + 3,417 liens), deduped on `instrument_number`. Coverage ≈ 6% of 75,946 distinct instruments — so **absence is `not_evaluated`, never a title search**. Scripts: `~/route3_controls.py`, `~/route3_corrob.py`, `~/build_encumbrance.py`.
- Twice now a negative control has overturned a plausible join in this project (Sarasota account-vs-id, then this). The control is not optional.
