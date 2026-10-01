-- 180a - geography expression indexes so the environmental lookups stop full-scanning (ruling 875 item 3).
--
-- MEASURED 2026-10-01, before changing anything (875: find out why before optimising):
--   get_parcel_env_findings(74,'522305000010') 17.1 s uncached; (74,'633001001890') 2.9 s.
--   Instrumented copies (a temp function recording clock_timestamp() before every `res := res ||`) located it:
--     11.6 s in ONE call - get_parcel_env_findings_core - of which:
--        underground storage tanks 500 m   2.9 s   (fdep_stcm_tanks, 74k points)
--        superfund + brownfield 1 km       4.9 s   (fdep_brownfield_areas/_sites, ~600 polygons each)
--        brownfield list + FRS 1 km        3.6 s   (hifld_frs_relevant, 12.6k points)
--     then pollution notices 1.5 s, flood 1.1 s, flood->FUDS 1.4 s, power line 0.7 s.
--   Every one filters with st_dwithin(geom::geography, g::geography, R). The tables carry geometry GIST indexes, but
--   a filter on geom::geography cannot use an index on geom, so each call casts and distance-tests every row.
--   hifld_transmission_lines has NO spatial index at all and has never been analyzed (reltuples -1); its
--   `order by geom <-> g limit 1` is a full scan.
-- FIX: GIST indexes on the exact expression the functions filter on, (geom::geography), which ST_DWithin(geography)
-- uses directly. No function body, output or grant changes. Output md5 asserted identical on three parcels below
-- (baseline taken twice to prove the output is deterministic).
-- NOT done here, reported: duplicate geometry GIST indexes (fdep_stcm_tanks x3, fdep_pnp x4, brownfield x2 each).

create index if not exists fdep_stcm_tanks_geog_gix        on public.fdep_stcm_tanks        using gist ((geom::geography));
create index if not exists hifld_superfund_sites_geog_gix  on public.hifld_superfund_sites  using gist ((geom::geography));
create index if not exists fdep_brownfield_sites_geog_gix  on public.fdep_brownfield_sites  using gist ((geom::geography));
create index if not exists fdep_brownfield_areas_geog_gix  on public.fdep_brownfield_areas  using gist ((geom::geography));
create index if not exists hifld_frs_relevant_geog_gix     on public.hifld_frs_relevant     using gist ((geom::geography));
create index if not exists fdep_pnp_geog_gix               on public.fdep_pnp               using gist ((geom::geography));
create index if not exists fl_sinkhole_incidents_geog_gix  on public.fl_sinkhole_incidents  using gist ((geom::geography));
create index if not exists hifld_rcra_tsd_sites_geog_gix   on public.hifld_rcra_tsd_sites   using gist ((geom::geography));
create index if not exists hifld_dams_geog_gix             on public.hifld_dams             using gist ((geom::geography));
create index if not exists volusia_scenic_roads_geog_gix   on public.volusia_scenic_roads   using gist ((geom::geography));
create index if not exists fuds_property_points_geog_gix   on public.fuds_property_points   using gist ((geom::geography));
create index if not exists hifld_transmission_lines_gix    on public.hifld_transmission_lines using gist (geom);

analyze public.fdep_stcm_tanks; analyze public.hifld_superfund_sites; analyze public.fdep_brownfield_sites;
analyze public.fdep_brownfield_areas; analyze public.hifld_frs_relevant; analyze public.fdep_pnp;
analyze public.fl_sinkhole_incidents; analyze public.hifld_rcra_tsd_sites; analyze public.hifld_dams;
analyze public.volusia_scenic_roads; analyze public.fuds_property_points; analyze public.hifld_transmission_lines;

select public._log_action('cc', 'index_env_geography_filters', 'get_parcel_env_findings_core', array['12 gist indexes'],
  jsonb_build_object('522305000010_env_ms', 17105, '633001001890_env_ms', 2932), null,
  'Ruling 875 item 3: environmental lookups filtered on geom::geography with only geometry indexes, so every call full-scanned; core alone took 11.6 s on one parcel under an 8 s REST limit.', null);
