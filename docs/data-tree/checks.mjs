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
    // The guard on the guard. Goes RED if a derives_from edge is dropped (two re-publications would then
    // read as independent witnesses — the exact error the fact index exists to prevent) or if the
    // independence logic breaks. There is NO confidence score in this system: independence is a boolean
    // about lineage, and this predicate asserts that boolean, not a threshold. See roz_source_lineage.
    sql: `SELECT roz_sources_independent('realtytrac','dor_roll')          = false
             AND roz_sources_independent('parcels_staging','nal')          = false
             AND roz_sources_independent('parcels_staging','nps_nomination')= true
             AND roz_sources_independent('dor_roll','nps_nomination')       = true AS ok`,
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
