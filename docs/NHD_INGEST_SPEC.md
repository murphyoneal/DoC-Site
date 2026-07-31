# NHD ingest & wiring spec — NHDArea + NHDFlowline

**Status:** contract for Murphy's pull (network) + the wiring plan (no-network, mine). Write the ingest to
this so the data does not sit unused or get wired on assumptions. This is the layer where a wrong wiring is
expensive: it feeds **both** flood *cause* and waterfront *amenity*.

## 1. Why this layer, in both directions

Waterways explain both halves of the report, and we currently hold only `hydrology_waterbodies` (lakes,
ponds, swamps) — no rivers, canals, estuaries, or coastline. Roz self-diagnosed the gap on 3149 Brickell:
"nearest mapped water feature 3.2 mi — in tension with this being a Biscayne Bay address."

- **Flood has no cause without it.** We can say *24% Zone AE, BFE 11 ft*. We cannot say *what floods it*.
  Zone AE beside a tidal river is a different risk from Zone AE beside a stormwater canal or at the foot of
  a slope — different mechanism, different mitigation, different insurance conversation. The zone is the
  classification; the water is the reason.
- **Amenity is unquantifiable without it.** Waterfront is Florida's premium, and today we cannot distinguish
  river frontage from a canal from a retention pond from a view across a road. The marine block proves a
  parcel has a dock; it cannot say what the dock is *on*.

Same gap, both directions — the parcel that takes value from water takes risk from it.

## 2. Components, geometry classes, and the question each answers

Three components, three geometry classes, three different questions. Do **not** collapse them into one
"nearest water" number — that flat number *is* the defect we are replacing.

| Component | Geometry class | The correct question | Feeds |
|---|---|---|---|
| **NHDArea** | shadow (polygon) | **Adjacency & frontage** — does the parcel touch it, and how many linear feet? Bays, inlets, estuaries, sea, wide rivers as polygons. | amenity (frontage) + flood (what the SFHA is adjacent to) |
| **NHDFlowline** | corridor (line) | **Perpendicular distance** — how far to the nearest line? Every river, stream, creek, canal. | flood mechanism + context |
| **NHDWaterbody** *(already held as `hydrology_waterbodies`)* | shadow (polygon) | **Containment / within-distance** — lakes, ponds, swamps. | amenity + context |

**Adjacency is not proximity, and they are different findings.**
- A parcel **touching** an NHDArea polygon has **frontage** — measurable in linear feet. That is the amenity.
- A parcel **200 ft from** a flowline has **proximity** — that is context, and possibly a flood mechanism.
- Render them as two facts. A single blended distance destroys the distinction that makes the layer worth pulling.

## 3. The pull contract (Murphy, network)

- **Source:** USGS National Hydrography Dataset (NHD), Florida. Prefer the state or HU-4 subregion
  geodatabase(s) covering all of FL over per-feature REST paging (these are large; a bulk GDB is cleaner).
- **Tables to load:** `NHDArea` → `nhd_area`; `NHDFlowline` → `nhd_flowline`. (`NHDWaterbody` is already held.)
- **SRID:** store as **4326**. If the source is in a projected CRS, reproject on load and record the original.
- **Preserve `FCODE` and `FTYPE` RAW on every row** (see §4). Also keep `GNIS_NAME`/name (the feature name —
  "Halifax River", "Miami Canal") — that is what lets a finding *name* the water.
- **Validate geometry AT INGEST (item 99), non-negotiable.** These are large national datasets and *will*
  contain invalid geometry — not a maybe. On load: `ST_MakeValid` into the stored geom, then assert
  `count(*) FILTER (WHERE NOT ST_IsValid(geom)) = 0`. Do NOT defer this to a per-call `ST_MakeValid` in the
  resolver — that is exactly the 26 s flood timeout we just fixed. Repair once, at the boundary.
- **Index:** a GiST index on `geom` for each table, at load time.
- **Register** both tables in `data_source_registry` with a refresh cadence (NHD updates are infrequent —
  quarterly to annual is fine), and add a `county_layer_registry` concept row so they enter the
  held-vs-served sweep (concept `hydrology` for flowline; `hydrology_area` or `coastal` for area — pick from
  the delivered data, don't force it).

## 4. FCODE — derive the vocabulary from the delivered data, do NOT pre-map it

`FCODE` is the field that turns *"water 200 ft away"* into *"a tidal river you can dock on"* or *"a drainage
ditch"*. It is the single most important field in this layer, and it must survive ingest intact.

- **Do not hardcode an FCODE→meaning table from expectation.** After the pull, run a discovery step (the same
  discipline as the CAMA schema probe and the sentinel evidence sweep): `SELECT fcode, ftype, count(*) FROM
  nhd_flowline GROUP BY 1,2 ORDER BY 3 DESC` and read what is actually there. Build the crosswalk from the
  data, recording what was found; where an FCODE has no clear meaning in the delivered data, flag it rather
  than guess (a guessed classification is the fabrication class).
- **State now the distinctions that MUST survive** — if the ingest flattens any of these, the amenity/risk
  distinction is unrecoverable:
  - **tidal vs non-tidal** (a tidal river is dockable saltwater frontage; a non-tidal creek is not),
  - **perennial vs intermittent** (a year-round stream vs a wet-season ditch),
  - **canal/ditch (artificial) vs natural stream/river** (NHD encodes this in FCODE — e.g. the
    canal/ditch codes are distinct from stream/river; confirm the exact codes against the delivered data).
- **Expose FCODE + its derived class in the fact record**, never a normalized national label that erases the
  county/feature's own designation — same rule as zoning codes (B-5 in Ocala ≠ B-5 in DeLand).

## 5. Wiring plan (mine, once the data lands)

Three resolvers, one per question, each a fact record (subject·predicate·value·source·as_of·note), each
with the coverage-gap-is-about-us discipline and **US units (feet) in output**, meters internal only.

1. **`get_parcel_water_frontage`** (NHDArea, adjacency/shadow). Does the parcel boundary touch an NHDArea
   polygon? If so, frontage length = `ST_Length(ST_Intersection(ST_Boundary(parcel), area)::geography)` in
   **feet**, plus the feature name and FCODE-class. Predicate `has_frontage`. This is the amenity fact — the
   thing the marine block's dock sits on.
2. **`get_parcel_nearest_flowline`** (NHDFlowline, proximity/corridor). Perpendicular
   `ST_Distance(parcel, flowline::geography)` in **feet** to the nearest flowline, with its name + FCODE-class
   (river / canal / ditch / intermittent). Predicate `nearest_flowline`. Context + candidate flood mechanism —
   labelled proximity, NOT frontage.
3. **Containment** stays with `hydrology_waterbodies` (already served); add FCODE-class exposure if the NHD
   waterbody attributes are richer than what we hold.

**The flood link is the point.** Once NHDArea + NHDFlowline are in, a Zone AE finding should be able to
*name what it is adjacent to*: **"24% Zone AE, BFE 11 ft, parcel fronts the Halifax River"** is a different
statement from the same zone beside a stormwater canal — different mechanism, different mitigation, different
insurance conversation. Wire the frontage/nearest-flowline result into `get_parcel_flood_block` as an
adjacency note, and into the marine block so a dock says what it is on (tidal river vs canal, via FCODE).

**Do not reintroduce the flat "nearest water" number.** `water.nearestWaterM` (the current single blended
distance) is the defect this replaces; the three questions above produce three distinct facts, and the old
key should be retired from the payload once the frontage/flowline facts render (payload-is-the-boundary rule).

## 6. Acceptance — how we know the wiring is right

- A Brickell (Biscayne Bay) parcel reports **frontage on a named tidal water**, not "nearest water 3.2 mi".
- A parcel on a canal reports **canal**, not "river", and its flood note reflects that mechanism.
- A dry inland parcel reports the **honest proximity** to the nearest flowline, labelled as context, with the
  coverage caveat where no NHD feature is within range — a gap about our data, never "no water risk".
- `SELECT count(*) FILTER (WHERE NOT ST_IsValid(geom)) FROM nhd_area/nhd_flowline` = **0** after ingest, and
  the served-flood/hydrology invalid-geometry harness predicate stays green.
