# FDEP Hydrography + OpenData Folder — Resolved Endpoints

**Recorded 2026-08-09.** Closes the research half of PIR_REPORT_SPEC_v5 Part K item 2 (NHD) and Part K "septic". Every URL below was fetched, not recalled. No row counts appear in this document because none were measured — measuring them is step 1.

---

## 1. The NHD gap is resolvable on the host you already use

`ca.dep.state.fl.us` is the same ArcGIS host `fdep_enumerate.py` already targets. NHD is a service in the same `OpenData` folder as `MMP_MANPHO`, `MMP_MANNON` and `FGS_PUBLIC`. No new acquisition path, no geodatabase download, no new harness.

**Service:** `https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/NHD/MapServer`

| layer | name | geometry | status |
|---|---|---|---|
| 0 | NHD 24K (group) | — | — |
| 1 | NHD 24K PointEventFC | point | not held |
| 2 | NHD 24K Point | point | not held |
| 3 | NHD 24K Line | polyline | not held |
| **4** | **NHD 24K Flowline** | **polyline** | **MISSING — the whole gap** |
| **5** | **NHD 24K Area** | **polygon** | **MISSING — bays, inlets, sea/ocean** |
| 6 | NHD 24K Waterbody | polygon | ✅ this is what `hydrology_waterbodies` holds |
| 7 | NHD 100K (group) | — | — |
| 8 | NHD 100K Flowline | polyline | coarser duplicate of 4 |
| 9 | NHD 100K Waterbody | polygon | coarser duplicate of 6 |
| 10 | NHD 100K Area | polygon | coarser duplicate of 5 |
| 11–14 | FeatureToMetadata · Metadata · SourceCitation · VARIANT_NAMES | tables | feature-level provenance |

**Service item id:** `cc7d8463366d4ea190a11c0bb05bd625` · **Copyright:** DEAR · **MaxRecordCount:** 1000

### Two traps, both already in the defect registry as classes

1. **Spatial Reference is 102967 (EPSG 6439)** — NAD83 Florida GDL Albers, in **metres**. Identical to the FDEP mining layers. Pull with `outSR=4326` or the geometry silently misplaces. This is the third FDEP service in a row with this property; it should be treated as the FDEP default, not an exception.
2. **`MaxRecordCount` is 1000, not 2000.** Every batch count landing on an exact multiple of 1000 is a page-truncation suspect — the same signature that produced the `fema_flood_zones` multiples-of-200 defect. Use `returnIdsOnly` set-diff, not the page loop's own tally.

Tables 11–13 are worth pulling alongside the features: `NHDFeatureToMetadata` → `NHDMetadata` → `NHDSourceCitation` gives per-feature provenance, which maps directly onto the fact-index `source` / `as_of` / `derivation` columns rather than a blanket service-level citation.

---

## 2. There is a second hydrography service and nobody has decided between them

`OpenData/FHD` — **Florida** Hydrography Dataset — sits in the same production folder, and mirrors NHD **layer for layer, index for index** (0–14, same names with FHD substituted).

**Service:** `https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/FHD/MapServer`
**Item id:** `76cf8f13543443a7aacb2527e3cc5fed` · **MaxRecordCount: 2000** · same EPSG 6439

FHD's layer-5 description claims it is *"generally developed at 1:5,000 scale"* — five times finer than the 24K NHD — and its FTYPE renderer carries exactly the values the report needs: `312 BayInlet`, `445 SeaOcean`, `460 StreamRiver`, `336 CanalDitch`. Its copyright text names USGS **and** FDEP DEAR, where NHD names DEAR alone.

**Do not act on that description.** The same paragraph also says *"Data for Alaska, Puerto Rico and the Virgin Islands was developed at high-resolution"* — inherited NHD boilerplate, pasted wholesale. And the layer is still **named** "FHD 24K Area" while the text claims 1:5,000. The name and the description contradict each other, which means neither is evidence.

**Ruling: names lie, contents don't.** Before either service is loaded, run the comparison on contents:

- `returnCountOnly` on NHD/4 vs FHD/4, and NHD/5 vs FHD/5
- vertex count and total length for the same named feature in both — the Halifax River, the St. Johns, one Cape Coral finger canal
- whether FHD carries FTYPE values NHD lacks, and vice versa
- `FDATE` distribution in each — which is actually maintained

If FHD is genuinely denser it supersedes NHD outright and NHD/4/5 should never be loaded. If the counts are near-identical, FHD is a rename and NHD stays. **Load neither until the counts are on the table.** Loading both and reconciling later rebuilds the flood-layer defect at 10× the row count.

---

## 3. Three geometry classes, three questions — unchanged and still the design risk

Restating because the pull is what makes it live:

- **Area (5)** is a shadow — adjacency and frontage length, not centroid distance
- **Flowline (4)** is a corridor — perpendicular distance, plus whether it is tidal, perennial, artificial path or ditch. `FTYPE` decides this and must be carried, not collapsed
- **Waterbody (6)** stays a shadow

Collapsing all three into "nearest water" rebuilds the existing defect in a bigger layer. The Biscayne Bay 3.2-mile reading was not a distance error; it was a category error.

**Sentinel warning:** `FTYPE 558 ArtificialPath` is the NHD's synthetic centreline drawn *through* a waterbody so the network connects. It is not a stream. Counting it as "a river on the parcel" is the same class of defect as *Estuarine and Marine Deepwater* inside the wetlands layer. Exclude it from any "watercourse present" predicate; keep it for network tracing only.

---

## 4. Septic — the open item has a live endpoint, and a coverage problem

**Service:** `https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/SEPTIC_SYSTEMS/MapServer`
**Layer 0:** `Septic Systems` · item `6c03827a0f97498c83697da825c6eae6` · EPSG 6439 · MaxRecordCount 2000

**It is not statewide, and the extent says so before any pull.** Compare the published full extents (EPSG 6439 metres):

| | XMin | XMax | YMin | YMax |
|---|---|---|---|---|
| NHD (true state extent) | −164,520 | 805,164 | 55,806 | 904,764 |
| SEPTIC_SYSTEMS | **56,016** | 793,852 | 59,670 | **781,489** |

The septic layer stops roughly 220 km short on the west and 120 km short on the north — i.e. it appears to hold **nothing for the western panhandle and nothing for the far north**. Treat that as a flag to verify by county, not as a finding: extent is the bounding box of features present, so this is evidence of absence in those areas, not proof of it.

**Consequence for the report:** septic must ship as a three-state field from day one, per-county. A parcel in Escambia must return `not_available`, never `none_recorded` — "no septic system recorded here" on a parcel in a county the layer does not cover is exactly the St Petersburg flood failure in a new category. Resolve coverage per county with an interior-point test against the layer before the concept is registered, and gate it on `co_no`.

---

## 5. What else is sitting in that folder

Enumerating `OpenData` returned ~95 services. These map onto things already named in the spec, the business plan, or `restriction_authority` — and are on the host and pattern already in use:

| service | what it answers | why it matters now |
|---|---|---|
| `ERP` | Chapter 373 Environmental Resource Permits | already a live C6 search term (`Chapter 373 ERP`) with no data behind it |
| `ST404` | Section 404 dredge-and-fill | same — `Section 404 permit Florida` is a published doorway |
| `OFW` | Outstanding Florida Waters | a real regulatory restriction on adjacent development |
| `WRCA` | Water Resource Caution Areas | pairs with the Ch. 62-524 well prohibition already in the report |
| `FGS_WELLS`, `OIL_WELLS`, `WRM_UIC_PUBLIC` | wells, incl. underground injection control | adjacent to the WMD well-permit gap — **not a substitute for it**, these are different registers |
| `GYPSUMSTACKS` | phosphogypsum stacks | pairs with the Ch. 378 phosphate reclamation doorway |
| `IMPAIRED_WATERS`, `WBIDS`, `NNC` | impaired waterbodies, WBID, numeric nutrient criteria | the "what floods it / what's in it" half of waterfront |
| `MITIGATION_BANKS`, `AQUATIC_PRESERVES` | development constraint | |
| `PANTHER_CONSULT_AREA` | federal consultation trigger, SW Florida | a genuine build constraint on Collier/Lee land |
| `SPRINGS`, `DRAINAGE_BASINS`, `SURFACE_WATER` | | |
| **`LAND_SURFACE_ELEV`** | **land surface elevation** | see below |

**`LAND_SURFACE_ELEV` deserves its own line.** The single worst incident in the spec — an elevation figure fabricated seven times with escalating false precision, ending in a fake lidar vertical-accuracy citation — happened over a field whose `source_url` was NULL. FDEP publishes an elevation service on the host you already pull from. That does not excuse the fabrication and it is not the fix; the fact-index deterministic renderer is the fix. But it does mean the underlying absence is closable, and a `not_available` there is now a choice rather than a constraint.

**Do not bulk-pull this list.** Every one needs the same treatment as the flood layers: register the concept, resolve the layer by reading its contents, establish per-county coverage, then serve. Five registered honestly beats fifteen registered on faith.

---

## 6. Order of work

1. **Count first.** `returnCountOnly` on NHD/4, NHD/5, FHD/4, FHD/5. One decision falls out of four numbers.
2. **Pick one service on contents**, record why in `data_source_registry` with the comparison as evidence.
3. **Pull Flowline + Area** with `outSR=4326`, page size under 1000, `returnIdsOnly` set-diff as the completeness check, geometry validated at ingest (never per call).
4. **Carry `FTYPE`**, and exclude `558 ArtificialPath` from any watercourse-present predicate.
5. **Three concepts, not one** — `water_area_adjacent`, `watercourse_proximity`, `waterbody_proximity` — into `concept_registry` / `layer_resolution` separately.
6. **Septic**: resolve per-county coverage before registering; ship as three-state, gated on `co_no`.
7. Everything in §5 stays on the backlog, unregistered, until 1–6 are done.

---

## 7. Still not researched

- **Pinellas direct download URLs** — the 14 current + ~11 legacy tables are confirmed nightly (Aug 08 02:15–05:00 AM stamps) with full on-page column layouts, but the download controls are JS and the endpoint did not resolve from the page source or from search. The DevTools network capture remains the only way to answer it, and it remains a ten-minute job with a browser open.
- **Polk** — `ftp.polkflpa.gov` needs an FTP client; not reachable by HTTP probe or by fetch.
- **WMD well permits** — SJRWMD REST endpoint (Hub item `1ae18f9ade2b4af293e8de9251f6336d`), NWFWMD and SRWMD still unlocated. The FDEP well services in §5 are a different register and do not close this.
- **Row counts for everything above.** Not measured. Not estimated.
