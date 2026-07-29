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
