-- 197a - Citrus and Sumter flood are served as not_available: the layers we hold are truncated (rulings 907, 919).
--
-- LIVE FALSE STATEMENT, verified 2026-10-01. citrus_flood_zones holds exactly 6,000 rows and sumter_flood_zones exactly
-- 4,000 - both the SELECTED flood layer for their county (layer_resolution 4 and 34, verified=true). Measured coverage,
-- with Volusia as the complete control (NFHL hazard polygons tile the whole county, X zones included):
--   Volusia  11,061 rows   4,664 km2 of polygons vs 3,710 km2 county   126%  (complete; extends offshore)
--   Citrus    6,000 rows     775 km2              vs 2,488 km2           31%  (51% of land alone)
--   Sumter    4,000 rows     629 km2              vs 1,502 km2           42%; objectid 8,424-12,423 = exactly 4,000
--                                                                             consecutive ids, a window of a larger set
-- Served: 239 of 400 sampled Sumter parcels returned field_status none_intersecting, which get_parcel_flood_block turns
-- into in_sfha = FALSE, field_status present - "not in a Special Flood Hazard Area" for a parcel whose polygon we never
-- loaded. And a parcel touching a loaded X polygon may be missing its AE polygon, so even 'present' answers in these two
-- counties cannot be trusted. The whole county is gated, not just the misses.
--
-- MECHANISM (data, not code, so the round-count sweep can use it): layer_resolution.incomplete_reason. NULL = no known
-- incompleteness. When set on the selected layer, get_parcel_flood_zone returns not_available with that reason, and
-- get_parcel_flood_block states it instead of "no county FEMA NFHL layer is held" (which would be a false cause).
-- Re-pull goes through the engine with the collapse guard (919 item 4); clearing incomplete_reason is the un-gate.

alter table public.layer_resolution add column if not exists incomplete_reason text;
comment on column public.layer_resolution.incomplete_reason is
  'NULL = no known incompleteness. Set = the held layer is measured incomplete; served functions that honour it return not_available with this text as the stated cause (197a). Clear it only after a re-pull is measured complete.';

update public.layer_resolution set incomplete_reason =
  'The flood layer we hold for Citrus County is incomplete: it stopped at exactly 6,000 polygons, covering about 31% of the county''s area where a complete FEMA layer covers all of it. Flood zone is not evaluated here until it is re-pulled.'
 where id = 4 and table_name = 'citrus_flood_zones' and concept = 'flood';
update public.layer_resolution set incomplete_reason =
  'The flood layer we hold for Sumter County is incomplete: it stopped at exactly 4,000 polygons, covering about 42% of the county''s area where a complete FEMA layer covers all of it. Flood zone is not evaluated here until it is re-pulled.'
 where id = 34 and table_name = 'sumter_flood_zones' and concept = 'flood';

do $$
declare d text; a1 text; a2 text; n int;
begin
  select count(*) into n from public.layer_resolution where id in (4, 34) and incomplete_reason is not null;
  if n is distinct from 2 then raise exception '197a: expected 2 layers gated, got %', n; end if;

  -- get_parcel_flood_zone honours incomplete_reason on the selected layer
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_parcel_flood_zone'::regproc;
  d := pg_get_functiondef('public.get_parcel_flood_zone'::regproc);
  if (select count(*) from regexp_matches(d, E'  v_geomcol := COALESCE\\(v_res->>''geom_column'',''geom''\\);\n', 'g')) <> 1 then raise exception '197a: zone anchor'; end if;
  d := replace(d, E'  v_geomcol := COALESCE(v_res->>''geom_column'',''geom'');\n',
$r$  v_geomcol := COALESCE(v_res->>'geom_column','geom');

  -- 197a: a held layer measured incomplete is never queried - a missing polygon would read as "no flood zone".
  IF v_tbl IS NOT NULL THEN
    SELECT lr.incomplete_reason INTO v_cur FROM public.layer_resolution lr
     WHERE lr.concept = 'flood' AND lr.geo_id = v_geo AND lr.table_name = v_tbl AND lr.incomplete_reason IS NOT NULL LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('field','flood_zone','field_status','not_available','in_sfha',NULL,'zones',NULL,
        'county_layer_status', v_cur.incomplete_reason,
        'resolver_state','layer_incomplete',
        'coverage_caveat','COVERAGE GAP, NOT A FINDING. This is NOT a statement that the parcel is outside a Special Flood Hazard Area. Check the FEMA Flood Map Service Center (msc.fema.gov) before drawing any conclusion about flood insurance.',
        'source','FEMA National Flood Hazard Layer','authority','FEMA');
    END IF;
  END IF;
$r$);
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_parcel_flood_zone'::regproc;
  if a2 is distinct from a1 then raise exception '197a: zone grants changed % -> %', a1, a2; end if;

  -- get_parcel_flood_block states the actual cause of a not_available
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_parcel_flood_block'::regproc;
  d := pg_get_functiondef('public.get_parcel_flood_block'::regproc);
  if position('''determination_note'',''Not established — no county FEMA NFHL layer is held for this county here. This is a statement' in d) = 0 then
    raise exception '197a: block anchor'; end if;
  d := replace(d, '''determination_note'',''Not established — no county FEMA NFHL layer is held for this county here. This is a statement',
    '''determination_note'',''Not established — '' || COALESCE(v_f->>''county_layer_status'', ''no county FEMA NFHL layer is held for this county here.'') || '' This is a statement');
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_parcel_flood_block'::regproc;
  if a2 is distinct from a1 then raise exception '197a: block grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'gate_truncated_flood_layers', 'layer_resolution', array['4:citrus_flood_zones','34:sumter_flood_zones'],
  jsonb_build_object('citrus_rows', 6000, 'citrus_coverage_pct', 31, 'sumter_rows', 4000, 'sumter_coverage_pct', 42, 'control', 'volusia 126%'),
  jsonb_build_object('served', 'not_available with the measured cause'),
  'Rulings 907/919: the selected flood layers for Citrus and Sumter are truncated at a paging cap, so missing polygons were served as "not in a Special Flood Hazard Area". Both counties gated to not_available the day it was measured.', null);
