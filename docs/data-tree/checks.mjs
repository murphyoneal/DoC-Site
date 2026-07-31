// docs/data-tree/checks.mjs
// The verifiable claims of the Data Tree Anchor. Consumed by verify.mjs.
//
// THE AUTHORING RULE (this is the whole point — read before adding a node):
//   A verify must be able to FAIL for the reason the claim would be wrong.
//   Ask: "can this return red if the claim is false?" If not, it is not a verify.
//
//   ✗ scalar-match     count(*) - count(DISTINCT x)  → expect 4474
//        Reproducible AND wrong: re-running a bad query re-derives the bad answer.
//        The harness REJECTS any predicate that doesn't return a single boolean `ok`.
//   ✓ falsifiable      NOT EXISTS (… GROUP BY x HAVING count(*) > 1)
//        Can only be true if the claim is true.
//
// Three kinds of verify, one per failure class:
//   predicate  — data/interpretation. SQL returns exactly one boolean column `ok`.
//   plan       — a fix/defect signature. EXPLAIN text must / must-not contain a line.
//                (Never assert milliseconds — they swing >10x on scan position. Assert shape.)
//   closure    — rendering. Computed on the RENDERED tree, not the DB: children sum to parent.

export const predicates = [
  {
    id: 'dor_parcel_id-no-duplicates',
    claim: 'dor_parcel_id has no duplicate non-null values — a coverage hole (NULLs), not a fan-out',
    // Regression test for this whole session. Cannot pass if a duplicate exists.
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM properties
            WHERE dor_parcel_id IS NOT NULL
            GROUP BY dor_parcel_id HAVING count(*) > 1
          ) AS ok`,
  },
  {
    id: 'five-layers-no-geom-gist',
    claim: 'exactly these five funnel tables lack a geometry GiST index',
    sql: `WITH funnel(tbl) AS (VALUES
            ('hydrology_waterbodies'),('fema_flood_zones'),('fdep_pnp'),('fdep_stcm_tanks'),
            ('fdep_brownfield_sites'),('fdep_clm'),('fuds_property_boundaries'),
            ('fuds_munitions_response_sites'),('fuds_property_points'),('hifld_dams'),
            ('volusia_scenic_roads'),('volusia_boat_ramps'),('traffic_aadt'),('fl_sinkhole_incidents'),
            ('epa_landfills'),('hifld_frs_relevant'),('hifld_rcra_tsd_sites'),
            ('hifld_superfund_sites'),('hifld_transmission_lines')),
          nogist AS (
            SELECT f.tbl FROM funnel f
            WHERE NOT EXISTS (SELECT 1 FROM pg_indexes i WHERE i.tablename = f.tbl
              AND i.indexdef ILIKE '%gist%' AND i.indexdef NOT ILIKE '%geography%'))
          SELECT (SELECT array_agg(tbl ORDER BY tbl) FROM nogist)
               = ARRAY['epa_landfills','hifld_frs_relevant','hifld_rcra_tsd_sites',
                       'hifld_superfund_sites','hifld_transmission_lines'] AS ok`,
  },
  {
    id: 'routes-account-for-every-classified-table',
    claim: 'every classified table carries a join route (nr_jointype covers nr_master)',
    sql: `SELECT (SELECT count(*) FROM nr_jointype) = (SELECT count(*) FROM nr_master) AS ok`,
  },
  {
    id: 'one-genuine-orphan',
    claim: 'exactly one genuine orphan (J14) — sjc_plat_index',
    sql: `SELECT (SELECT array_agg(table_name) FROM nr_jointype WHERE join_type = 'J14_genuine_orphan')
               = ARRAY['sjc_plat_index'] AS ok`,
  },
  {
    id: 'cndcmplx-022301-groups-78-units',
    claim: 'condo complex 022301 groups 78 unit parcels',
    sql: `SELECT count(*) = 78 AS ok FROM volusia_cama_condo_bldg WHERE "CNDCMPLX" = '022301'`,
  },
  {
    id: 'fabricated-tables-stay-dropped',
    claim: 'the two fabricated report-source tables stay dropped — property_environmental and ' +
      'property_hazard_risk do not exist (dropped 2026-07-29 §7; both single-valued/all-null ' +
      'statewide). Goes RED if a seed or restore re-creates either.',
    // Was the fabrication-tracking predicate; the tables are now dropped (remediated), so this
    // guards the remediation instead. The GENERAL guard for the next fabricated table — a
    // provenance gate (primary) + cardinality backstop — is blocked: source_url is recorded for
    // only ~3/15 report-source tables, so a provenance gate would fire on real data today. Backfill
    // provenance first, then build it. See anchor §8.7.
    sql: `SELECT to_regclass('public.property_environmental') IS NULL
             AND to_regclass('public.property_hazard_risk')   IS NULL AS ok`,
  },
  {
    id: 'report-sources-provenance-ratchet',
    claim: 'RATCHET: report-source tables (read by get_pir_report / get_site_intelligence) lacking a ' +
      'recorded source_url in table_inventory must not exceed the baseline (27 of 32 as of 2026-07-29). ' +
      'Green today; RED the instant an unsourced table is wired into the report path. 27/32 unsourced ' +
      'is a real defect — you cannot say where a paid report\'s data came from — not noise. Lower the ' +
      'baseline by 1 each time a source is recorded (the ratchet only tightens).',
    // Provenance is the PRIMARY integrity gate: it fails closed even on plausibly-varied fabrication,
    // which cardinality cannot. A RATCHET, not a permanent red — so the build isn't muted; it fails
    // only on regressions. The derivation reads the functions' prosrc, so a newly-wired unsourced
    // table is caught automatically without updating any manifest. Cardinality is the intended
    // backstop but only when scoped to RENDERED columns — a table-level scan is 102 legit constants
    // (state='FL', TAXYR, null expand_* cols): the cry-wolf case. See anchor §8.7.
    // ⇩ BASELINE — only ever decrease it, and only alongside a real source_url backfill.
    sql: `WITH report_fns(fn) AS (VALUES ('get_pir_report'),('get_site_intelligence')),
          refs AS (SELECT DISTINCT lower(m[1]) AS tbl
            FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            JOIN report_fns rf ON rf.fn=p.proname AND n.nspname='public'
            CROSS JOIN LATERAL regexp_matches(p.prosrc,'(?:from|join)\\s+([a-z_][a-z0-9_]+)','gi') m)
          SELECT (SELECT count(*) FROM refs r JOIN table_inventory ti ON ti.table_name=r.tbl
                    WHERE ti.source_url IS NULL OR ti.source_url='none') <= 27 AS ok`,
  },
  {
    id: 'marine-coverage-gap-is-null-not-false',
    claim: 'a county without marine coverage returns waterfront_indicator = JSON null (a coverage ' +
      'gap), NEVER false — absence of coverage must never render as absence of a dock. Volusia (74) ' +
      'returns non-null (false/true, a real finding).',
    // Guards the load-bearing distinction the marine block rests on (get_parcel_marine_improvements,
    // rendered in the PIR page). false = "county recorded no marine improvement"; null = "we don't
    // hold this county's file". Conflating them would tell a waterfront buyer their dock isn't there.
    sql: `SELECT jsonb_typeof(get_parcel_marine_improvements(23,'0141230000010')->'waterfront_indicator') = 'null'
             AND get_parcel_marine_improvements(23,'0141230000010')->>'field_status' = 'not_available'
             AND jsonb_typeof(get_parcel_marine_improvements(74,'744901030061')->'waterfront_indicator') <> 'null'
             AS ok`,
  },
  {
    id: 'payload-carries-no-superseded-fabrication-keys',
    claim: 'the get_pir_report payload contains NONE of the superseded flat keys a consumer could dress ' +
      'as a fabricated fact: land.elevationM/elevationFt (the USGS-datum fabrication that recurred 6×), ' +
      'and the pre-fact-index flood / marineImprovements shapes. THE PAYLOAD IS THE SECURITY BOUNDARY, ' +
      'not the render — a page guard protects only React; a payload consumer (Roz) reads these directly.',
    // The 6th recurrence proved a render-side withheld-fact guard is not enough: the bare land.elevationFt
    // stayed in the payload beside the withheld groundElevation fact, and Roz emitted the ±0.96 ft datum
    // lie off the payload. Elevation is represented ONLY by groundElevation (value_withheld); flood by
    // floodBlock; marine by marineBlock. Re-adding any of these flat keys must go red here.
    sql: `SELECT NOT ((p->'land') ? 'elevationM' OR (p->'land') ? 'elevationFt'
                       OR p ? 'flood' OR p ? 'marineImprovements') AS ok
          FROM (SELECT get_pir_report(74,'744403020120') AS p) s`,
  },
  {
    id: 'no-county-literal-in-report-path',
    claim: 'OPEN (tracks register #14) — no report-path function may hardcode a county: a co_no ' +
      'compared to a numeric literal, or a quoted county-name string. Two of three live incidents were ' +
      'a Volusia literal presented as universal (fema county_name match, "Volusia only" prose, ' +
      'areaRepetitiveLoss %volusia%). RED now: 5 resolvers (wind/surge/water/airport/marine) hardcode ' +
      'their coverage co_no — convert to a coverage lookup. Coverage-resolution fns are the exception.',
    // Scoped to VALUE literals (co_no = <digit>, or a quoted county name matched against county_registry)
    // — NOT the legitimate volusia_* TABLE identifiers, which are unquoted and don't match. \m/\M are
    // word boundaries so county_no / dor_county_no don't false-match co_no.
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='public'
              AND p.proname = ANY(ARRAY['get_pir_report','get_site_intelligence','get_parcel_flood_zone',
                'get_parcel_wind_design','get_parcel_storm_surge','get_parcel_water_service','get_parcel_airport_proximity',
                'get_parcel_marine_improvements','get_parcel_tax_deed_status','get_parcel_env_findings',
                'get_parcel_env_findings_core','get_parcel_containment_findings','get_parcel_planned_works','resolve_parcel_geometry'])
              AND ( p.prosrc ~ '\\m(p_)?co_no\\M\\s*=\\s*\\d'
                    OR EXISTS (SELECT 1 FROM county_registry cr WHERE p.prosrc ~* ('''[%]?' || cr.county_name || '[%]?''')) )
          ) AS ok`,
  },
  {
    id: 'pnp-pre-statute-count',
    claim: 'FDEP PNP has exactly 6 genuine pre-s.403.077 records (eff. 2017-07-01) — matches the RPC caveat',
    // Tests the caveat's actual CLAIM ("only 6 predate it"), not a loose proportion. A ≥99%
    // threshold tolerated 160 pre-statute records while the caveat said 6 — a threshold standing
    // in for a count (Gate 1, one level down). Excludes the one NULL release date: unanswered is
    // not pre-2017, the same distinction the RPC draws for MIGRATED_OFFSITE. Update 6 deliberately.
    sql: `SELECT count(*) FILTER (
            WHERE (attributes->>'RELEASE_START_DATE_TIME') IS NOT NULL
              AND to_timestamp((attributes->>'RELEASE_START_DATE_TIME')::bigint / 1000) < '2017-07-01'
          ) = 6 AS ok FROM fdep_pnp`,
  },
  {
    id: 'fragment-union-owner-address-invariant',
    claim: 'the ST_Union fragment fix is safe statewide: no multi-row (co_no, parcel_id) group carries ' +
      'more than one distinct owner OR more than one distinct situs address. A parcel that appears as N ' +
      'geometry rows is N fragments of ONE property (union them) — never N different properties sharing an ' +
      'id (which unioning would silently merge). This is the load-bearing precondition of ' +
      'resolve_parcel_geometry / get_site_intelligence aggregating fragments (§7).',
    // WHY owner/address and NOT acreage-vs-lnd_sqfoot: the acreage check was measured at only 12.7%
    // agreement (assessed land area != geometry area — condo interests, ROW, submerged parcels diverge
    // legitimately), so it is a cross-examine LEAD, not a guard. Owner/address is exhaustive-clean:
    // 3,443 groups across Miami-Dade/Orange/Pinellas/Volusia/Marion/St.Johns (incl. St.Johns' 26.7%
    // dup rate) = ZERO violations. This predicate generalises that to all 67 counties and goes RED the
    // instant a county's fragments are actually distinct properties (where the union would be wrong).
    // Full statewide GROUP BY over 10.7M rows: runs in the Tier-2 pg runner under SET statement_timeout=0
    // (it TIMED OUT through the MCP connector's ~2-min cap — that is a connector limit, not this query's).
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM parcels_staging
            WHERE parcel_id IS NOT NULL
            GROUP BY co_no, parcel_id
            HAVING count(*) > 1
               AND (count(DISTINCT own_name) > 1 OR count(DISTINCT phy_addr1) > 1)
          ) AS ok`,
  },
  {
    id: 'fact-index-corroboration-requires-independence',
    claim: 'the fact-index corroboration guard classifies the three hand-verified lineage cases ' +
      'correctly: two sources may corroborate ONLY if they share no derives_from upstream. RealtyTrac ' +
      'sqft and the DOR roll are the SAME witness (re-published) → NOT independent. parcels_staging.jv ' +
      'and the NAL tables share the DOR roll → NOT independent. DOR act_yr_blt (1939) and the NPS ' +
      'nomination form (1939) are two agencies with no shared upstream → independent = REAL corroboration.',
    // The guard on the guard, BOTH directions. Goes RED if (a) a derives_from edge is dropped so two
    // re-publications read as independent witnesses, OR (b) the function reverts to FAIL-OPEN — an
    // unknown/typo source key reading as independent, which manufactures a second witness from nothing.
    // (b) is why this predicate now exercises unknown keys: the original version tested only the seeded
    // slugs and was structurally blind to the permissive default the maintainer caught by calling it
    // with 'dor_nal'. NO confidence score: independence is a boolean about lineage, asserted here directly.
    sql: `SELECT roz_sources_lineage_disjoint('realtytrac','dor_roll')          = false  -- re-published, one witness
             AND roz_sources_lineage_disjoint('parcels_staging','nal')          = false  -- shared DOR lineage
             AND roz_sources_lineage_disjoint('parcels_staging','nps_nomination')= true   -- two agencies = real corroboration
             AND roz_sources_lineage_disjoint('dor_roll','nps_nomination')       = true
             AND roz_sources_lineage_disjoint('realtytrac','no_such_source')     = false  -- FAIL CLOSED: unknown ⇒ not independent
             AND roz_sources_lineage_disjoint('ghost_a','ghost_b')               = false  -- both unknown ⇒ not independent
             AND roz_sources_lineage_disjoint('realtytrac','realtytrac')         = false  -- a source is not its own witness
             AS ok`,
  },
  {
    id: 'enumeration-closure-every-geometry-layer-registered',
    claim: 'REGISTRATION-AS-RULE (forward closure), RED BY DESIGN today: every base table or matview ' +
      'carrying a geometry column — the `geometry_columns` spine, which PostGIS maintains from the ' +
      'catalog and so CANNOT decay — must appear in `table_inventory`. Mapping was run four times as a ' +
      'project (ladm_map_run1..v3); each snapshot decayed from its run date because nothing fires when a ' +
      'new layer arrives. RED = 7 layers that arrived after the last run by routes that touch no registry ' +
      '(matview fl_sinkhole_incidents, migration parcel_geometry_supplement, one-off FUDS×3, pulls ' +
      'calhoun_zoning/broward_bmsd_zoning). Goes GREEN only when every geometry layer is enumerated, then ' +
      'stays a permanent drift guard. Generalises §10 invariant 6 (empty≠done) from pulls to registration.',
    // The 370 "in no map" figure was inflated by ~364 VIEWS (legitimately outside a table inventory);
    // relkind IN ('r','m') scopes to arrived DATA — base tables + matviews — the real debt: 7. This is a
    // CLOSURE invariant, not another map: it reconciles the auto-maintained spine against the hand-
    // maintained inventory instead of producing a fifth snapshot. Clear the 7 (with real classes) to green it.
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM geometry_columns gc
            JOIN pg_class c ON c.relname = gc.f_table_name
            JOIN pg_namespace nsp ON nsp.oid = c.relnamespace AND nsp.nspname = gc.f_table_schema
            WHERE gc.f_table_schema = 'public' AND c.relkind IN ('r','m')
              AND NOT EXISTS (SELECT 1 FROM table_inventory ti WHERE ti.table_name = gc.f_table_name)
          ) AS ok`,
  },
  {
    id: 'enumeration-closure-no-dangling-registered-layer',
    claim: 'REGISTRATION-AS-RULE (reverse closure), RED BY DESIGN today: every registered layer must ' +
      'still exist. A `table_inventory` row pointing at a dropped/renamed relation is the registry ' +
      'lying — the same mechanism as the 10 "never-pulled" sources (loaded outside the registry-writing ' +
      'path) and the quarantine-rename hazard (§10 invariant 3). RED = 2: property_environmental, ' +
      'property_hazard_risk — fabricated tables DROPPED 2026-07-29 (§7) whose inventory rows were never ' +
      'removed. Create and de-register are as decoupled as create and register; this half catches the other direction.',
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM table_inventory ti
            WHERE ti.table_name IS NOT NULL
              AND to_regclass('public.' || quote_ident(ti.table_name)) IS NULL
          ) AS ok`,
  },
  {
    id: 'geometry-srid-metadata-not-lying',
    claim: 'DEF-005 in RULE form: no base table or matview geometry column may report srid=0 in ' +
      'geometry_columns while its rows carry a real SRID. The lie shelves a usable 4326 layer as ' +
      '"unjoinable" — it is why FUDS boundaries LOOKED absent (they were not; the report path reads row ' +
      'geometry and worked) — and misleads any code that trusts geometry_columns.srid. Swept 2026-07-30: ' +
      '38 base tables were lying (the class DEF-005 undercounted as "Seminole ~20": fdep_*, seminole_*, ' +
      'hifld_*, school_zones, fuds_*); 37 repaired via uniformity-guarded UpdateGeometrySRID. RED remains ' +
      'on fl_cadastral_dor_statewide ALONE (10.8M rows, a SUPERSET of parcels_staging holding twn/rng/sec + ' +
      'OR deed refs unique to it — NOT a drop; typmod fix needs a direct connection, exceeds the pooler limit), ' +
      'and fires anew for any layer loaded 4326-in-rows / 0-in-typmod. Views excluded (a view ' +
      'geometry inherits srid from its base expression). Backed by detect_srid_metadata_lie().',
    // The metadata lie did NOT corrupt any report — the row geometries carry 4326, so ST_Contains sees
    // 4326-vs-4326. It is a joinability/trust defect: DEF-005's registry-based detector (county_layer_registry.srid)
    // structurally cannot see it (FUDS is not even in that registry). This predicate probes the ROWS, the only
    // place the truth lives — the same row-vs-metadata lesson as sjc_, relkind, and fuds_munitions being MultiPolygon.
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM detect_srid_metadata_lie() d
            JOIN pg_class c ON c.relname = d.tbl
            JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = 'public'
            WHERE c.relkind IN ('r','m')
          ) AS ok`,
  },
  {
    id: 'active-repair-defects-are-harness-tracked',
    claim: 'THE REGISTRY IS CONSULTED BY THE HARNESS — the guard that would have stopped DEF-005 sitting ' +
      'active six days while it was rediscovered in FUDS as if new. Every active data_defect_registry defect ' +
      'with disposition=repair and a globally-runnable detection_sql (no per-table {template}) must name the ' +
      'harness_predicate that enforces it; a repair defect with no harness link is an UNTRACKED LIVE DEFECT. ' +
      'RED today: DEF-017 (distinctness-assertion design rule), DEF-020 (slug-matched layer registry), ' +
      'DEF-021 (single-county-backed report field). disclose/transform_on_ingest defects are tracked by the ' +
      'disclosure→report wiring and the ingest pipeline respectively, not here; per-table {template} ' +
      'detections run at ingest. Closes the loop the mid-session lesson named: consult, do not rediscover.',
    // Populated, not derived: harness_predicate is set by hand when a predicate is written for a defect.
    // This predicate makes the *absence* of that link fail the build, so a new repair-class defect cannot be
    // catalogued and then forgotten. Scoped to disposition=repair because that is the class the harness
    // mechanically PREVENTS; disclose is surfaced to the user, transform_on_ingest is fixed upstream.
    sql: `SELECT NOT EXISTS (
            SELECT 1 FROM data_defect_registry
            WHERE status='active' AND disposition='repair'
              AND detection_sql IS NOT NULL AND detection_sql NOT LIKE '%{%'
              AND harness_predicate IS NULL
          ) AS ok`,
  },
  {
    id: 'every-firm-flood-layer-is-wired',
    claim: 'Item 80 — every county FIRM flood layer we HOLD (fld_zone + sfha_tf + geom + rows) is either ' +
      'selected in flood_layer_selection or a merge-component of a selected view. The sjc_ miss (9,322 NFHL ' +
      'polygons, slug-matching skipped it) was found by ACCIDENT; the diagnostic then showed 6 counties ' +
      'returning "not established" while holding a full FIRM layer (Broward/Clay/Lee/Leon/Marion/St.Johns/' +
      'St.Lucie). 5 wired by CONTENT-EXTENT (Leon/Lee/Marion as merge views — a determination is split across ' +
      'zone/floodway tables). This predicate makes the next accidental gap fail the build. Excludes ' +
      'fema_flood_zones (superseded statewide) and *_city_* (a city SFHA is covered by its county). Broward ' +
      'is a curation judgement, held in the detector\'s deferred list until decided. Backed by detect_unwired_firm_layers().',
    // The whole point of item 80: rebuild by reading each layer's CONTENTS (geometry extent vs county
    // boundary, CO_NO where present), never the table name — slug-matching is what missed sjc_.
    sql: `SELECT NOT EXISTS (SELECT 1 FROM detect_unwired_firm_layers()) AS ok`,
  },
  {
    id: 'flood-layer-serves-its-own-county',
    claim: 'Item 80 follow-up — every SELECTED flood layer has geometry inside its EXPECTED county ' +
      '(matched FIPS-to-FIPS, never names — county_registry.fips = fl_county_boundaries.county). The 43 ' +
      'counties wired before this session were slug-matched (the sjc_ method that mis-wired by name); this ' +
      'converts "unverified by content" into a permanent assertion. GREEN: 0 mis-wired — all overlap their ' +
      'county. The check is boundary-INTERSECTION, arrived at after two wrong tries: single-sample point-in-' +
      'county false-positived on regional extracts (alachua_flood_zones spans Alachua + east), and interior-' +
      'point-coverage false-positived on SFHA-only layers whose dry county centroid is a zone-X area they omit. ' +
      'Backed by detect_flood_layer_wrong_county().',
    sql: `SELECT NOT EXISTS (SELECT 1 FROM detect_flood_layer_wrong_county()) AS ok`,
  },
];

export const plans = [
  {
    id: 'hydrology-geography-index-engaged',
    claim: 'FIXED: the geography functional index is used, not a sequential scan',
    // This — not "31.6 ms" — is the evidence the fix landed. A sample is not a proof.
    // Plan-shape is right HERE because the claim genuinely IS "this uses the index."
    sql: `EXPLAIN SELECT w.gnis_name
          FROM hydrology_waterbodies w
          WHERE ST_DWithin(w.geom::geography,
            ST_SetSRID(ST_MakePoint(-80.91271527783783, 29.008484422765257), 4326)::geography, 3000)`,
    mustContain: ['Index Scan using idx_hydrology_waterbodies_geog'],
    mustNotContain: ['Seq Scan on hydrology_waterbodies'],
  },
];

// Scan-count deltas. Replaces the earlier `Filter: (parcel_id` plan-check, which was wrong
// twice over: parameterised on which parcel/county (statistics-dependent), and designed to go
// RED when the index lands — breaking the build on an improvement. The scan-count delta has
// neither flaw: it's a deterministic integer, it's the claim the node actually makes, and it's
// STABLE across adding the index (count doesn't change, only cost). It goes red exactly when it
// should — a 9th lookup is added, or a consolidation drops one and the node isn't updated.
// Measured 2026-07-28: get_pir_report = 4, get_parcel_env_findings = 4, full answer = 8.
//
// Instrument: pg_stat_XACT_user_tables (transaction-local), NOT pg_stat_user_tables (global).
// The global counter is database-wide — any concurrent query on parcels_staging inflates the
// delta and the gate flakes red under load, which is the millisecond mistake in another costume.
// The runner wraps the actions in one transaction and reads the xact-scoped count, so concurrent
// traffic can't contaminate it. Verified 8, transaction-local, 2026-07-28.
export const deltas = [
  {
    id: 'parcels-staging-lookups-per-answer',
    claim: 'a full Roz answer scans parcels_staging exactly 8 times (index-independent)',
    actionSql: [
      `SELECT get_pir_report(74, '744901030061')`,
      `SELECT get_parcel_env_findings(74, '744901030061')`,
    ],
    countSql: `SELECT seq_scan + idx_scan AS n FROM pg_stat_xact_user_tables WHERE relname = 'parcels_staging'`,
    expected: 8,
  },
];

// Closure invariants run on the RENDERED diagram, not the DB — the sum failures were a
// rendering omission the database was never wrong about. Two-sided so it does one job each:
//   children == rendered parent  (catches an omitted/clipped row — even with the DB down)
//   rendered parent == live count (catches the render drifting from the data)
//   every child carries a row figure (a dropped row-figure is the same failure class)
//   every branch head present (a clipped export drops one)
export const closure = {
  file: 'diagram.html',
  liveTotalSql: `SELECT count(*)::int AS n FROM nr_master`,
  sumBranches: ['Attachment', 'Classes'],
  requiredBranchHeads: ['Identity', 'Attachment', 'Relation keys', 'Classes', 'Defects & fixes'],
};

// Census closure — guards the generated §1a block of DATA_TREE_ANCHOR.md against the exact
// class of error a status report once shipped: a summary figure ("wired") silently absorbing
// J0/J13, and a "792 empty" read off the reltuples=-1 never-analyzed sentinel (anchor §9).
// The runner reads the machine-owned state.json (a clean JSON parse — no fragile markdown
// scraping) and checks it against counts recomputed HERE, independently of build.mjs:
//   1. wired + system + non_parcel + orphan == classified   (the four buckets partition nr_master)
//   2. state.wired      == live parcel-reaching count        (definition can't drift back to "all but J14")
//   3. state.classified == live nr_master count              (state isn't stale)
// liveWiredSql is deliberately the reaching-a-parcel definition; if build.mjs ever redefines
// "wired" the two disagree and the gate goes red. Non-brittle: no count is hardcoded — the
// live side moves with the data, so adding tables keeps it green as long as the render tracks.
export const censusClosure = {
  stateFile: 'state.json',
  liveClassifiedSql: `SELECT count(*)::int AS n FROM nr_master`,
  liveWiredSql: `SELECT count(*)::int AS n FROM nr_jointype
                 WHERE join_type NOT IN ('J0_system','J13_non_parcel_domain','J14_genuine_orphan')`,
};
