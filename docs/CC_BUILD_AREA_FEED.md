# CC Build — Area Context Feed + Planned-Works Layers

**Work order:** `docs/CC_WORK_ORDER_ROZ_ALPHA_REV2.md` — standing rules apply.
**Spec:** `docs/ROZ_ENVIRONMENT_SPEC.md` — §2.5 funnel, §2 field contract.

Three parts, in this order. Part 1 uses data already loaded and needs no new source.

---

## The problem this solves

Two problems, and one solution addresses both.

**Latency.** The first answer takes 60–120 seconds. Streaming can't fix the bulk of it, because the delay is *before* the model: resolve address → containment against 165 layers → build payload → *then* call the model. Streaming animates only the last stage. The user stares at nothing for a minute.

**A genuine disclosure gap.** Public works planned for the next two years are **not on a property record** unless they've reached a recorded easement or restriction. The sequence is planning → funding → design → right-of-way acquisition → recorded instrument. The property record catches it only at the last step. A buyer closing at step two sees nothing — and nobody is concealing it. The seller doesn't know, the agent doesn't know, and it isn't a disclosure failure. It's information nobody has assembled.

---

## Part 1 — Wire the planned-works layers that are already loaded

**These are parcel-level, containment-testable, dated, sourced, and unused.** They belong in the findings with a `field_status` like any other layer, because a county project record *is* a government record.

### Volusia — do these first

| table | rows |
|---|---|
| `volusia_current_development_projects` | 920 |
| `volusia_current_environmental_projects` | 1,056 |
| `volusia_storm_water_projects` | **0 — empty, source it** |

**1,976 records with geometry, nothing reading them.** One resolver, no new source, and it answers the planned-works question directly at parcel resolution.

### Other counties — same category, same pattern

`lee_development_orders` 17,889 · `pinellas_land_use_proposed` 8,647 · `stlucie_development_projects` 3,888 · `lee_planned_developments` 1,621 · `collier_planned_unit_developments` 510 · `orange_adopted_comp_plan` 126 · `hillsborough_dri` 63 · `orange_cip_roadways` (empty) · `marion_urban_growth_area` (empty) · `palmbeach_managed_growth_tier` (empty)

**`hillsborough_right_of_way` — 208,281 rows.** This is the acquisition step, the moment before a recorded easement. Distinct from a project record and worth its own field.

### Rules

- Build to the six-part contract: `value`, `field_status`, `as_of`, `source`, `resolution_level`, `relation`
- `resolution_level: parcel` where containment holds; **never** upgrade an area project to a parcel fact
- **`relation` carries the meaning here** — `contains` (the parcel is inside the project footprint) is materially different from `adjacent` or `within_distance`. A road widening *on* the parcel is a taking; one 300 m away is context.
- Apply the county-attribute rule: **test geometry against geometry**, never filter on a county column before containment
- Multi-authority: a county project and a municipal project over the same ground are two findings, not one reconciled answer
- Spot-check each against a real parcel with a non-trivial value before marking `computed`

---

## Part 2 — Area context feed

### What it is

A **parallel** fetch of government and local news items for the resolved area, rendered directly to the user while the funnel and model work.

**It is not a model tool.** Nothing fetched enters Roz's context. This is deliberate and it is the security design: if fetched web content reached the model, a county agenda page carrying adversarial text becomes an injection surface inside the one product whose entire claim is that it doesn't invent things. Fetching in parallel and rendering straight to the user means there is nothing to inject into. **The wall between record and context becomes architectural rather than a prompt rule.**

### Timing — this is the point

```
0–2s     find_parcels resolves → city, county, subdivision known
2–6s     feed renders. User starts reading.
60–120s  Roz's answer arrives underneath, from the records.
```

**Fire the search off `find_parcels`. Do not wait for the funnel.** `find_parcels` returns in a second or two and yields enough jurisdiction to build the query.

**Two hard conditions:**

1. **The feed must land in seconds.** One narrow search. No page fetching, no model involvement, no chaining. If it takes forty seconds it is a second wait, not a fix.
2. **An empty result renders nothing.** No spinner, no placeholder, no filler. Four irrelevant items are worse than none — it reads as padding and costs trust in the findings below it.

### The funnel builds the query

Roz does not guess the locale. Containment has already resolved it — county, municipality, subdivision, corridor. So the query is narrow **by construction**, not by filtering:

```
("Spruce Creek Fly-In" OR "Port Orange")
  AND (rezoning OR "comprehensive plan" OR "public works"
       OR "capital improvement" OR annexation OR "right of way"
       OR "development order" OR hearing OR notice)
```

### Allowlist — Volusia-curated, not statewide

Statewide `.gov` plus general news is too broad: 67 counties and ~400 municipalities means noise swamps signal, which is the exact failure this design exists to avoid.

Start hand-curated for Volusia — county, municipal, appraiser, FDOT District 5, SJRWMD, River to Sea TPO, local outlet(s). Grow it per county as counties come online. **Record the allowlist as data, not code**, so it's auditable and editable without a deploy.

### Presentation — the wall, stated to the reader

Its own section, visually separate, headed something like:

> **While Roz works — public notices and local news for this area.** Not part of the property record.

Every item carries a **link, a date, and the source domain**. Every item is `resolution_level: municipality` or `area` — **never `parcel`**. This is the same axis as county air quality versus parcel elevation and must be labelled the same way, or a city news item reads as a fact about her listing.

### Links persist

They stay on the page after the answer arrives. She reads the record from Roz, then works the links **with the record in hand** — which is the right order, because by then she knows what she's looking for.

That also means the feed survives the latency fix. Once the record is precomputed and answers arrive in under a second, this becomes a useful sidebar rather than wait-filler.

---

## Part 3 — Click telemetry

**This is the reason the feed persists, and the measurement nothing else in the system can produce.**

Typed feedback tells you what she noticed enough to comment on. Clicks tell you what she *reached for*, and those diverge. Nobody writes "I wanted to know about the road widening" in a text box — they just click it. And it costs her nothing to produce.

```sql
CREATE TABLE roz_feed_item (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  query_log_id     uuid REFERENCES assistant_query_log(id),
  parcel_id        text,
  title            text,
  url              text,
  source_domain    text,
  category         text,   -- planning | transport | development | news | utility | school
  resolution_level text,   -- subdivision | municipality | county
  rank             integer NOT NULL,
  surfaced_at      timestamptz NOT NULL DEFAULT now(),
  clicked_at       timestamptz
);
```

**`rank` matters as much as `clicked_at`.** A click on item five is a stronger signal than item one, because position drives clicks independently of relevance. Without rank the data is uninterpretable.

### What it will tell you

- **Whether the area layer is worth having.** Zero clicks across fifty properties is a clear, cheap answer.
- **Which categories matter** — rezoning versus capital projects versus local reporting. That ranking directly orders the structured work: heavy transport clicking moves FDOT's work program up; development-approval clicking moves the DRI and planned-development layers up.
- **Which resolution she cares about** — subdivision, city, or county. That aims the query.
- **The negative signal** — items surfaced repeatedly and never clicked are the ones to stop showing. The allowlist gets pruned by evidence rather than opinion.

**Honest caveat to record in the spec:** with one user this measures one person's habits, not a market. Alexis is a part-time agent at a five-person brokerage. Directional, not conclusive. A second user makes it a pattern.

---

## Part 4 — Statewide structured sources to acquire

The published, loadable version of exactly this problem. Both are the road-widening-in-two-years case at proper resolution:

- **FDOT Five Year Work Program** — statewide, published, the authoritative forward transport pipeline
- **River to Sea TPO Transportation Improvement Program** — the MPO covering Volusia; every Florida county has an MPO TIP

Prefer these over the feed wherever they overlap. A structured layer is faster, containment-testable, citable, dated, and lives **inside** the record. The feed then becomes what it should be — recent noise around a project the record already told you about.

---

## Build order

1. **Part 1 Volusia** — 1,976 records, already loaded, no new source, parcel resolution. Cheapest real gain available.
2. **Part 2 + 3 together** — the feed is pointless without the telemetry, and the telemetry is its justification
3. **Part 1 other counties**
4. **Part 4** — FDOT work program, TPO TIP

## Report

- Project layers wired · records reachable · spot-check parcel and value for each
- `relation` distribution — how many parcels `contains` a project versus `adjacent`
- Feed: time from `find_parcels` to first rendered item, measured
- Confirmation that **no fetched content reaches the model context**
- Confirmation that feed items carry `resolution_level` and can never render as `parcel`
- The allowlist as stored, and where it lives
