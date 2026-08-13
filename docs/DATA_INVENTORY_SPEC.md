# Data Inventory & LADM Mapping — Specification

**Purpose:** establish, once, what every table in the database is, what it pairs to, and what kind of statement it can support. Nothing further gets wired until this exists.

**Status:** specification. To be produced by CC as a generated table plus a written document.

---

## Why this exists

The database holds 2,012 tables, 97 million rows, 82 GB. Measured:

- **1,968 tables (97.8%) are pairable** to a parcel or an area — 1,546 by geometry, 175 by parcel key, 239 by area key. Only 44 are unpairable, and those are system metadata.
- **91 tables are referenced by name in any function.** Consumption is far behind collection.
- **282 tables have a provenance record** in `data_source_registry`; 1,730 do not.
- **527 tables carry a comment**; 16 columns do.
- **LADM was adopted as the modelling standard and applied in three places** — `restriction_class` on `fdep_gwca`, `fdep_institutional_controls`, `env_layer_catalog`, plus `level_type` on `geo_reference`.

The gap was never that the data is junk. It's that no artifact records what a table is *for*, so the difference between an orphan, a family member, and a redundant copy has been invisible. That is the defect this fixes.

---

## Structure — three axes, not one

Each table is classified on three independent axes. Conflating them is what produced the earlier confusion.

### Axis 1 — Pairing route (mechanical, generated)

*How* the table joins to a property or place.

| value | meaning |
|---|---|
| `geometry` | has a geometry column; spatial join |
| `parcel_key` | carries a parcel identifier; direct join |
| `latlon` | discrete lat/long columns; point construction required |
| `area_key` | county / tract / block group / zip only |
| `geocodable` | address text only; requires geocoding |
| `unpairable` | system metadata; not property data |

Derivable entirely from `information_schema`. No judgment.

### Axis 2 — Family (mechanical, generated)

**114 families of 2+ members covering 1,391 tables. 621 singletons.**

Family is the name after the county prefix — `*_future_land_use`, `*_sinkhole_incidents`, `*_address_points`. `data_source_registry.category` already encodes this concept for 288 tables (`future_land_use` × 50 counties, `zoning` × 47, `parcels` × 42) and its vocabulary should be extended rather than replaced.

**Classification decisions are made at family level and inherited by members.** That reduces ~2,012 decisions to ~735, most of which are obvious.

### Axis 3 — LADM class (judgment, assigned per family)

*What kind of thing* it is, and therefore what Roz may assert about it.

| LADM class | Holds | Statement type |
|---|---|---|
| `LA_SpatialUnit` | parcel geometry, plats, PLSS, condo units, buildings | this is the extent |
| `LA_BAUnit` | the property as a rights bundle | this is the thing owned |
| `LA_Party` | owners, multi-owner relations | this is who holds it |
| `LA_Right` | ownership, easements, leases, permits as authorisations | a legal entitlement |
| `LA_Restriction` | GWCA, institutional controls, wellfield protection, regulatory flood zones | **a legally binding constraint on use** |
| `LA_Responsibility` | maintenance obligations, well plugging liability | an obligation on the holder |
| `LA_SourceDocument` | deeds, plats, recorded instruments, permits as evidence | the evidence |
| `external_thematic` | traffic, demographics, schools, amenities, air quality, contractors | **context, no legal force** |

`external_thematic` is an explicit value, never null. Most of the database is legitimately outside LADM, and saying so is the point.

**This axis is the third honesty constraint.** `field_status` says whether we know it. `resolution_level` says what it describes. LADM class says **what kind of claim it is**.

An `LA_Restriction` and a nearby school are both a polygon 400 metres away. One constrains what the owner may legally do and has a recorded source document behind it. The other is an amenity. Presented in the same register, an institutional control reads as a feature and a school district reads as an encumbrance. That is the error most likely to harm a buyer.

---

## The generated table

```sql
CREATE TABLE table_inventory (
  table_name        text PRIMARY KEY,
  family            text,            -- 114 families or 'singleton'
  member_count      integer,         -- members in this family
  pairing_route     text,            -- axis 1
  pairs_to          text,            -- parcel | county | tract | block_group | zip | none
  ladm_class        text,            -- axis 3, incl. external_thematic
  geography_level   text,            -- parcel | municipality | county | tract | zone | state
  admin1_county     text,
  row_count         bigint,
  has_geometry      boolean,
  srid              integer,         -- flags the SRID-0 layers
  source_registered boolean,         -- in data_source_registry
  source_url        text,
  has_comment       boolean,
  consumed_by       text,            -- function or derived field, else null
  purpose           text,            -- the question it answers
  status            text,            -- reachable | orphan | redundant | staging | superseded | system
  provenance_route  text,            -- registry | comment | migration | oid_sequence | unresolved
  last_verified     timestamptz
);
```

### Provenance is recoverable — this is an audit, not a reconstruction

Four independent routes, in order of strength:

1. `data_source_registry` — 282 tables, with source URL and pull technique
2. Table comments — 527 tables
3. `supabase_migrations` — every CLI-applied DDL, timestamped and ordered
4. **OID sequence** — all 2,012 tables; OIDs run 17,644 → 6,561,962, giving creation order

Plus CC's scripts in WSL, `docs/`, and 47 commits of git history.

Cross-referencing these resolves most tables: OID sequence buckets them into sessions, migrations date the buckets, comments and the registry name the sources within them. **Report the residue that resolves through none of them as an explicit list.** Do not guess, and do not leave it implied.

---

## Rules that stop the gap reopening

1. **No load completes without an inventory row.** Same discipline as `field_status` — nothing renders without a status, nothing loads without a purpose.
2. **The table is generated and re-runnable.** Hand-maintained inventories rot; that is how 1,730 tables ended up unregistered.
3. **Mechanical fields are derived; judgment fields are assigned per family.** Never per table.
4. **`external_thematic` is explicit**, never null.
5. **Anything classed `LA_Restriction` or `LA_Responsibility` requires a source document reference** and is stated with an agency as grammatical subject.
6. **Anything `external_thematic` is stated as context** and may never be phrased as a constraint.
7. **`unpairable` tables are marked `system`** and excluded from gap counts. They are not a deficiency.

---

## Deliverables

1. `table_inventory` — populated, re-runnable, 2,012 rows
2. `docs/DATA_INVENTORY.md` — the readable version: families ranked by rows, LADM class distribution, the orphan list, the unresolved-provenance list, and the redundancy candidates
3. A short reconciliation note where the inventory contradicts an existing artifact — particularly `derived_field_status`, whose 46 `not_computed` fields should be re-read against what is actually addressable

## First questions it must answer

- Which families have no resolver and how many rows each — the work queue, ordered by leverage
- Is `parcels_staging` (10.3M rows, 21 GB) redundant against `fl_cadastral_dor_statewide` (10.8M)? That is a quarter of the database and the single largest open question
- Which tables can never be refreshed because no source was recorded
- Which layers are `LA_Restriction` and therefore must carry a source document before Roz may state them
- How many of the 1,546 geometry tables share a family and can be wired by one resolver

## Explicitly not in scope

No wiring, no derivation, no new fields. This pass produces the map. Read-only against the data; the only writes are `table_inventory` and the document.
