-- 206f - base flood elevation says "not available" where we hold no BFE column. Diagnosis of the errored
-- bfe-missing-column-served-as-not-recorded (ruling 937 section 7).
--
-- DIAGNOSIS. The detection was errored with "ok is not boolean (null)". Its population was fine: 4 layers (miamidade,
-- pasco_fema, columbia, hendry) resolve a zone column and no BFE column. It asserted
--   get_parcel_flood_block(...)->'base_flood_elevation'->>'field_status' = 'not_available'
-- but get_parcel_flood_block returns base_flood_elevation = JSON null for any parcel without a BFE value. null ->> is null,
-- and bool_and over nulls is null. Measured on 23/0101000000020 (Miami-Dade, zone AE) and 36/1 28 43 01 010 0000-001.1
-- (Hendry, zone AE): both serve base_flood_elevation null.
-- The ruling-223 fix (not_available plus a coverage note naming the layer) is in NO function body: pg_proc measured,
-- and only flood_col and get_parcel_flood_zone mention 'bfe'. So the guard was a check against a fix that does not exist.
-- The reassuring assertion it guards against ('not_recorded') is also gone, so nothing false is served. The parcel
-- is simply silent about BFE, which is weaker than the three-state rule allows.
--
-- FIX. When the layer is used and flood_col(layer,'bfe') is NULL, base_flood_elevation becomes a not_available object
-- with a coverage note.
--   - Everything else is unchanged: a present value stays present; a layer that HAS the column and no value stays null.
--   - Additive: lib/fact-render.mjs renders BFE only when field_status = 'present', so the object is ignored until the
--     page reads the note (same PR).
--   - No database function calls get_parcel_flood_block (pg_proc measured), so get_pir_report and the golden suite
--     do not change.
-- The detection now treats a null field_status as a failure (coalesce false), so a regression reads red, not errored.

do $$
declare d text; a1 text; a2 text;
  anchor text := $a$      ELSE null END,$a$;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_parcel_flood_block(numeric,text)'::regprocedure;
  d := pg_get_functiondef('public.get_parcel_flood_block(numeric,text)'::regprocedure);
  if (length(d) - length(replace(d, anchor, ''))) / length(anchor) <> 1 then raise exception '206f: anchor missing or not unique'; end if;
  d := replace(d, anchor, $p$      -- 206f (ruling 937/223): the layer we hold carries no BFE column - say so; never a bare null, never 'not_recorded'
      WHEN v_status = 'present' AND v_f->>'layer_used' IS NOT NULL AND public.flood_col(v_f->>'layer_used', 'bfe') IS NULL
      THEN jsonb_build_object('subject', v_subject, 'predicate', 'base_flood_elevation_ft', 'value', null,
             'field_status', 'not_available', 'source', v_f->>'layer_used', 'source_tier', 'federal_regulatory',
             'coverage_note', 'We hold FEMA''s flood zones for this county but not its base flood elevations: the layer as we loaded it ('
               || (v_f->>'layer_used') || ') carries no BFE field. This is a gap in our data, not a finding that FEMA published none. '
               || 'The BFE is on the Flood Insurance Rate Map at msc.fema.gov, or on an elevation certificate.')
      ELSE null END,$p$);
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_parcel_flood_block(numeric,text)'::regprocedure;
  if a2 is distinct from a1 then
    -- restore exactly what was there (the secdef guard revokes anon/authenticated on replace)
    if a1 like '%anon=X%' then grant execute on function public.get_parcel_flood_block(numeric,text) to anon; end if;
    if a1 like '%authenticated=X%' then grant execute on function public.get_parcel_flood_block(numeric,text) to authenticated; end if;
    select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_parcel_flood_block(numeric,text)'::regprocedure;
    if a2 is distinct from a1 then raise exception '206f: grants changed % -> %', a1, a2; end if;
  end if;
end $$;

update public.data_defect_registry set detection_sql =
$q$select bool_and(chk) and count(*) > 0 as ok, count(*) filter (where not chk) as row_count, count(*) as examined from (
   select coalesce((public.get_parcel_flood_block(g.dor_co_no::numeric, s.parcel_id)
             ->'base_flood_elevation'->>'field_status') = 'not_available', false) as chk
     from (select distinct lr.table_name, lr.geo_id from public.layer_resolution lr
            where lr.concept in ('flood','flood_zones') and lr.table_name is not null
              and coalesce(lr.row_count,0) > 0
              and public.flood_col(lr.table_name,'zone') is not null
              and public.flood_col(lr.table_name,'bfe') is null) fl
     join public.geo_reference g on g.geo_id = fl.geo_id
     join lateral (select parcel_id from public.parcels_staging p
                    where p.co_no = g.dor_co_no limit 1) s on true
 ) t$q$,
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 206f (ruling 937): was ERRORED - the function served base_flood_elevation null and the 223 not_available branch existed in no function body. Branch built; a null field_status now reads RED (coalesce false) instead of erroring. examined = layers without a BFE column.'
 where defect_id = 'bfe-missing-column-served-as-not-recorded';

do $$
declare j jsonb; b jsonb; p jsonb;
begin
  b := public.get_parcel_flood_block(23::numeric, '0101000000020');
  if b->'base_flood_elevation'->>'field_status' is distinct from 'not_available' then raise exception '206f: Miami-Dade AE parcel: %', b->'base_flood_elevation'; end if;
  if b->'determination'->>'field_status' is distinct from 'present' then raise exception '206f: determination changed: %', b->'determination'; end if;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'bfe-missing-column-served-as-not-recorded')) into j;
  if (j->>'ok')::boolean is distinct from true or (j->>'examined')::int is distinct from 4 then raise exception '206f: detection %', j; end if;
  raise notice '206f: %; Miami-Dade bfe %', j, b->'base_flood_elevation'->>'field_status';
end $$;

select public._log_action('cc', 'flood_bfe_not_available_where_column_absent', 'get_parcel_flood_block',
  array['get_parcel_flood_block','bfe-missing-column-served-as-not-recorded'],
  jsonb_build_object('base_flood_elevation', 'null on the 4 BFE-less layers'), jsonb_build_object('base_flood_elevation', 'not_available + coverage_note'),
  'Ruling 937 section 7: the errored detection guarded a ruling-223 fix that was in no function body. Built; a null now reads red.', null);
