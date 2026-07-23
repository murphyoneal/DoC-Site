# PIR Report — Definitive Specification (v3, FINAL for Claude Code handoff)

This supersedes v1 and v2. Written to eliminate ambiguity — every design decision below is explicit, not implied, so Claude Code can build against this directly without another round of chat-based mockup iteration.

## The core visual concept: individual badge-compasses, not one shared map

**This is the single most important correction from prior drafts.** Every earlier mockup showed one shared circular compass with multiple amenity pins plotted on it. That is wrong. The real design is:

- **Each amenity/category type gets its own small, individual compass icon** — a badge. Hospital gets one compass badge showing its bearing and distance. School gets a separate one. Grocery gets a separate one. Fire station, park, each nearby lake, each economic zone type — each one is its own badge.
- **A property with no hospital nearby simply doesn't show a hospital badge** — the presence or absence of badges is itself informative. Two PIRs side by side should visually differ in which badges appear, not just in the numbers inside them.
- **This is the same completeness-badge concept from the county-level scale, applied per-category on a single property report.** A buyer scanning a report sees a grid/row of badges and can judge data richness at a glance, the same way they'd compare two counties' completeness scores.
- Visually: think a grid of small, identical-sized compass icons (each with N/E/S/W tick marks, a single directional indicator, and a distance label), laid out like a badge collection — not one large shared map with many pins on it.

## Default population: everything we have, not a curated sample

**Default behavior is maximal, not minimal.** Every data category confirmed working in this database gets populated on every report by default. The user (Murphy, or later a report viewer) can choose to hide categories they don't want — that's a display toggle, not a data-generation decision. Do not pre-select "the important ones" and omit the rest. If the data exists and is confirmed real, it goes on the report.

## Full category list — confirmed real data only, honest about what's not yet sourced

### Amenities (individual badge-compass per item, no exceptions)
Hospitals, fire stations, police stations, schools (primary/middle/high as separate badges), grocery, dining, retail, parks, transit stops, libraries, fire hydrants.

### Water (individual badge-compass for each off-property feature; flood zone itself is a property classification, no badge)
Lakes, streams, rivers, boat ramps — one badge each, as many as are found within range. Flood zone designation shown separately as a property-level fact (see below), not a compass badge.

### Air
Current AQI, 5-day forecast, historical baseline for the area (AirNow), windrose (airport ASOS station data — same standard EPA uses for dispersion modeling), nearby fire/smoke detection (NOAA HMS) as a badge, nearby pollution sources as badges if identified.

### Land
Topography (USGS elevation, property-level fact), soil type and drainage classification (USDA Soil Data Access, property-level fact), protected species habitat overlay (confirmed real Volusia gopher tortoise layer — badge only if the parcel is near but not within an overlay; property-level fact if the overlay covers the parcel itself), septic status if on record.

### Economic / zoning context — CONFIRMED REAL, was wrongly omitted from prior mockups
HUB Zones, Opportunity Zones, Brownfield areas, Community Redevelopment Areas — each shown as a badge if the property is within or near one. This is real, already-pulled Volusia Economic Development data and must appear on the report.

### Zoning / land use
Current zoning classification and future land use designation — property-level facts, shown with the standard industry color convention (yellow/tan residential, red/orange commercial, purple/gray industrial, green parks, blue institutional, gray utilities) on the shared area map.

### Flood
Flood zone designation (property-level classification, with source reconciliation — county data preferred over statewide FEMA layer when both exist, disagreement stated explicitly if it occurs). Area-level FEMA repetitive-loss statistics, explicitly framed as area context, not a property-specific claim.

### Census / demographic
Population, median household income, total housing units for the property's census block group — confirmed real, 343 block groups already loaded for Volusia alone.

### Property history
Every permit on record, every ownership transfer on record — the actual count shown must match the actual list shown. Never state a summary count that doesn't match the itemized list below it. Status shown honestly: "finaled" only when actually confirmed, "completed, status not on file" or "issued, no confirmed outcome" otherwise — never invent a status.

### Property basics
Lot shape (real parcel boundary geometry), acreage, square footage, year built, living area, sun exposure (sunlight rose, property-level fact, calculated from coordinates).

### Property values
Current assessed value, land value (separate from improvement value), assessed value history if available (year-over-year), every recorded prior sale with real date and price — not a single "last sale," the full history on file.

### Property tax
Current annual tax amount, homestead exemption status, any other exemptions on file (senior, veteran, agricultural, etc. if present), taxing authority breakdown if the data supports it (county/school/city portions).

### Listing and agent
If claimed: agent name, brokerage, contact. **If not claimed: "No agent listed — Claim this listing" as an active call-to-action**, not a passive blank state.

### Neighborhood news
Live web search at report-generation time (architecturally different from every other section above — not a structured data pull, needs real-time search and relevance judgment). New retail, transit changes, development announcements within roughly 5 miles. Paraphrased, cited by outlet name, never reproducing article text at length.

## Honest gaps — not yet sourced, do not fabricate

- **Crime/incident statistics**: CORRECTED — real data confirmed, multiple distinct sources, not to be merged:
  1. **City-level incident activity** (e.g. Tampa's `CallsforService/FirePoliceCalls`) — live police calls-for-service and traffic advisory data, confirmed real and working. Rolling-window feed (past 4 hours / past week), same polling architecture as fire/smoke and AQI. Confirmed for Tampa only so far; needs the same discovery work repeated per jurisdiction.
  2. **Volusia Sheriff's own active calls feed** (`vcso.us/ActiveCalls`) — confirmed real, live, county-specific (unincorporated Volusia plus Deltona, DeBary, Pierson). Auto-refreshes every 60 seconds, real call numbers/descriptions/priority/location/zone. Exact machine-readable access method (JSON feed vs. HTML page) not yet confirmed — needs inspection of the page's actual network requests.
  3. **CrimeMapping.com (Volusia hub)** — third-party aggregator used by multiple Volusia cities. Error messages observed ("Max record count of 500 reached") strongly suggest a real ArcGIS REST service underneath, not yet located.
  4. **Statewide stolen property / wanted-missing persons** (FDLE FCIC PAS) — real, statewide, updated every 24 hours. Explicitly does not include general criminal history.
  - **Critical requirement, not optional**: any of the above must filter out sensitive categories (sex offenses, domestic disturbance, and similar) before appearing on any report. This matches official practice — CrimeMapping.com's own published terms explicitly exclude sex offenses and confidential matters to protect victim privacy. Raw category lists must never be pulled indiscriminately; category filtering is a hard requirement, not a nice-to-have.
- **Pollen/allergen index**: no source identified yet.
- **Septic system structured records**: existence as real structured data is unconfirmed; may only be inferable from permit history (a septic permit on file), not a dedicated dataset.

## Final page structure (confirmed, multi-page document layout)

**Every page carries the same running header**: property address/parcel reference (and agent name, if claimed, may share this header line) — so any single page is identifiable on its own, without needing page 1 for context.

**Page 1 — Property facts**
Property basics, values, tax, amenities. All combined onto one page if it fits.

**Page 2 — Property history**
Full permit and ownership history. Its own dedicated page — this section can be long and shouldn't be compressed to fit alongside anything else.

**Page 3 — Environmental facts**
Air, Land, and Water combined (Water absorbs Flood entirely — flood is not a separate page). This page carries the real 5-mile radius map with flood zones shown directly on it, plus the windrose.

**Page 4 — Neighborhood data and facts**
Economic zones, Zoning, and Census combined onto one page. Carries the zoning map — real boundaries, industry-standard color coding, with a legend/scale to the side — plus the windrose again and the same 5-mile radius framing.

**Page 5 — Supporting information**
In this exact order: data completeness summary (most important — the report's primary trust signal), crime/safety statistics (supporting, not primary), neighborhood news, citation footer/disclaimer.

**Structural principle**: every page follows the same pattern — property reference header, then the facts for that page's topic. This is what makes the report modular and scannable rather than one undifferentiated scroll.

## Citation and disclaimer
Jurisdiction-level sources only (County GIS, State DOR, Federal — NOAA/FEMA/EPA/USDA/Census), never naming the specific portal or system. Standard disclaimer: "This report reflects public records as drawn on [date]. This is not a certified or verified record of ownership or title."

## Explicit instruction for whoever builds this (Claude Code)
Do not simplify this list when implementing. If a category above is confirmed real in the database, it must appear in the generated report by default. A toggle to hide categories is a separate, later feature — it does not change what gets generated by default. When in doubt about whether something is real vs. illustrative, check the database directly rather than assume.
