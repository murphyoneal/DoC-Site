# Reference Parcels

The fixed test parcels used to verify Roz end-to-end. Each exercises a distinct part of the
record; keep them stable so a regression shows up as a changed answer on a known parcel.

| parcel_id (DOR) | address | what it exercises |
|---|---|---|
| `633001001890` | 1778 Earhart Ct, Port Orange | **Physical ground truth.** FUDS `not_evaluated` (Spruce Creek Res Anx point-only, no boundary), flood Zone X, elevation. Owner-verified facts the record can't self-correct: an owner-attested ~30-year-old buried LP tank with **no permit record** (the discrepancy case for item 40), and a bath count the record got wrong. The environmental/FUDS example — **not** an encumbrance example (it has no filing). |
| `521704001010` | 128 Logenberry Ct (Bayberry Lakes) | **Encumbrance positive.** Corroborated lis pendens `2026129180` (recorded 2026-07-17, party LOMASH MICHAEL). Also a `.tif` plat, 3 permits. The all-six-changes exemplar. |
| `521704003140` | 152 Springberry Ct (Bayberry Lakes) | **Encumbrance negative.** Same subdivision and legal-description format as Logenberry, differs only in whether a filing exists → returns `not_evaluated` (not a title search, not a clearance). The correct contrast for the encumbrance work. |
| `703310000350` | 214 Wellington | **Multiple encumbrances + GWCA.** Three encumbrances and a groundwater-contamination-area restriction (Ch. 62-524 caveat). |
| `702820000080` | 180 Fenway | **Commercial.** Non-residential parcel shape. |

Notes
- These are DOR/geographic `parcel_id` values (co_no 74). The internal AltKey differs; `properties`
  crosswalks the two.
- Earhart's owner-attested tank vs. the empty permit record is the worked case for the discrepancy
  finding state (item 40): the permit record can never self-correct there — the only path in is
  someone standing on the ground.
