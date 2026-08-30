# Work order 526 — measurements before the builds

Everything here was measured against the live database or a live endpoint on 2026-08-30. Nothing was
inferred from the absence of a row. Two of the work order's own premises did not survive measurement, and
both are corrected below rather than quietly worked around.

Bounds observed: sections 1 and 4 are builds and are **reported, not implemented**. Section 6 is
**counts only, no bulk pull**. Nothing deployed.

---

## 1. Marion founding case — CONFIRMED RED, before any build

Parcel **52 / 16501-000-00**, 14701 NE 88TH ST, SILVER SPRINGS. Owner DICKEY DAN W.
`ST_Intersects` against the parcel geometry in `parcels_staging`:

| layer | hits | required state |
|---|---|---|
| `marion_springs_protection` | 1 | present |
| `marion_elementary_school_zones` | 1 | present |
| `marion_middle_school_zones` | 1 | present |
| `marion_high_school_zones` | 1 | present |
| `marion_wetlands` | 1 | present |
| `marion_flood_prone_areas` | 1 | present |
| `marion_scrub_jay_areas` | **0** | real negative |
| `marion_environmentally_sensitive_zones` | **0** | real negative |

All eight reproduce the work order's figures exactly. **Two further layers intersect that the work order
did not list:** `marion_zoning` (2 hits) and `marion_future_land_use` (3 hits). More than one hit on a
single parcel is the multi-value case — the inventory must report every intersecting value with its share,
not silently pick a winner.

Note the table name is `marion_environmentally_sensitive_zones`, not `marion_environmentally_sensitive`.
The acceptance test must use the real name or it will error rather than fail, and an erroring test is not
a red test.

---

## 2. Section 4 is REFUTED — there is no second parcel spine

The work order states: *"Marion parcels are in `marion_parcels`, keyed `parcel`. They are NOT in
`parcels_staging` under co_no 52."*

Measured, and the opposite is true:

```
parcels_staging where co_no = 52          283,399 parcels
marion_parcels                            284,702 parcels
parcels_staging co_no 52, '16501-000-00'  FOUND
```

The founding parcel is in `parcels_staging` under co_no 52 **with the identical key format** —
`16501-000-00`, 12 characters, hyphenated — carrying the correct address (14701 NE 88TH ST) and the correct
owner (DICKEY DAN W). Sample keys from the same table are `00001-000-00`, `00001-001-00`: the same shape.

`parcels_staging` holds **all 67 counties**, co_no 11 through 77, 10.7M parcels.

So there is no second spine, no key mismatch, and no statewide enumeration needed. What remains true and
still open is **backlog 209** — `parcels_staging` and the county NAL disagree on just value and land area
for the same parcel (Collier 4.90%, Palm Beach 0.97%, both directions), and the spine carries no roll year.
That is a vintage question about one spine, not evidence of two.

The earlier 19-row `parcel_id LIKE '16501%'` result that suggested a mismatch was a prefix match across
sibling parcels (`16501-001-00` and so on), not a formatting difference.

---

## 3. Section 6b — USDOT National Address Database, MEASURED

### Resolving the endpoint

`hub.arcgis.com/maps/fedmaps::national-address-database-1` returns **title metadata only** — the dataset
detail is JS-rendered and does not resolve from page source. This is the third occurrence of that exact
failure (Pinellas download controls, Collier GMCD hub, now NAD).

**The route in is the search API, not the hub page** — exactly as work order 522 prescribed:

```
https://www.arcgis.com/sharing/rest/search?q=title:"National Address Database"&f=json
```

which resolves the service:

```
https://services.arcgis.com/xOi1kZaI0eWDREZv/ArcGIS/rest/services/
  Address_Points_from_National_Address_Database_view/FeatureServer/0
```

60 fields, `maxRecordCount` 2000, capabilities `Query,Extract`.

### The counts

| query | result |
|---|---|
| `where=1=1&returnCountOnly=true` | **97,928,946** records nationally |
| Florida bounding box, `returnCountOnly=true` | **135,357** |

Bounding box `-87.7,24.4 → -79.9,31.1`, which **overcounts** Florida by including slivers of Georgia and
Alabama. So Florida is **at most 135,357** address points.

### The verdict, and it is decisive

We already hold **~6.5M address points across 28 county layers** (`palmbeach_situs_addresses` alone is
790,000). Florida has ~10.7M parcels.

**NAD carries at most 135,357 Florida points — around 2% of what we already hold, and about 1.3% of the
parcel count.** It does not supersede county-by-county acquisition and it is not a convenience layer
either; it is a small fraction of existing coverage. The county acquisition gap stands undiminished, and
NAD should be registered as *located, not worth pulling for Florida* rather than as an acquisition target.

### An endpoint constraint worth recording

The hosted view **rejects every attribute filter and every groupBy**:

```
where=State='FL'                    -> 400 "Unable to perform query"
where=State IS NOT NULL             -> 400
groupByFieldsForStatistics=State    -> 400
where=1=1                           -> 200
geometry=<envelope>                 -> 200
```

Only `1=1` and **indexed spatial filters** are permitted. The by-county count the work order specified
(one request, `returnCountOnly`, grouped by county) **is not available on this endpoint**. The spatial
envelope is the substitute and it is why the measurement was possible at all. Had I stopped at the first
400 I would have reported the target as unmeasurable, which would have been false.

---

## 4. Section 6a — FDOR PointMatch, NOT measured

Requires downloading Polk's sub-file to count non-null coordinates. That is a file pull, and the work
order says measure before pulling. **Not attempted.** The deciding question stands as the work order
framed it: if rural counties submitted text-only rows, PointMatch confirms an address *exists* and gives
its jurisdiction but cannot place it — the `address_recognized_parcel_unresolved` state, not a resolution.

One item from the guide is worth acting on independently of any pull: **unincorporated areas carry
`FEATID = 000000000`**. That is a statewide, address-level, state-authored incorporated/unincorporated
flag — a second and independent test for the jurisdiction-hole work in backlog 208, sourced from the
state's own record rather than from city-limits geometry.

---

## 5. Carried forward unmeasured

- **EPA FRS (section 3)** — three stacked defects: a `primary_name` we hold and dropped, `interest_type`
  `FORMAL ENFORCEMENT ACTION` collapsed into "TRI-reporting", and 36 m reported as "about 100 ft".
  The fix is to carry `primary_name` and `interest_type` and never label an FRS row by the registry's
  most familiar member.
- **Defect 190** — "sole owner of record", third sighting across three counties. `owner_count` counts
  strings, not parties, and the payload already says so in `note` and `owner_shape`.
- **Defect 194** — `s.95.11(3)(b)` cited a third time, still unverified against primary source.
- **Confidence scores remain banned** on a stored fact. Only the decision state escapes a resolver:
  confirmed / probable / ambiguous / unmatched / address_recognized_parcel_unresolved.
- **`ST_Contains` must not gate an address match** — a geocode 24 m from the nearest parcel and inside
  none is a road-centreline result, which is what rural geocodes are. Containment as a gate manufactures
  false negatives.
- **Precedence when both address sources land:** county address points, then NAD, then PointMatch.
