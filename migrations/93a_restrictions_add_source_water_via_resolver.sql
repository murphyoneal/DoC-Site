-- =============================================================================
-- handoff 42: surface source_water_protection — a Ch. 62-524 REGULATORY RESTRICTION
-- (contains), not a proximity fact — through resolve_layer, appended to the existing
-- get_parcel_restrictions array (additive, same shape). resolve_layer supplies the
-- state / resolved_at_level / who_can_answer so it inherits uniform instrumentation.
-- Volusia baseline parcel does not intersect any source-water area, so landRestrictions
-- stays byte-identical for it; parcels inside a wellhead-protection area now surface it.
-- Everything above the new block is identical to the deployed function.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_parcel_restrictions(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '25s'
AS $function$
declare g geometry; res jsonb := '[]'::jsonb; in_gwca boolean; ic record;
        n_wells int := 0; n_wells_gwca int := 0; n_wells_icr int := 0; well_caveat text;
        v_geo text; v_sw jsonb; v_swtbl text; v_swgeom text; sw record;
begin
  select geom into g from parcels_staging where co_no=p_co_no and parcel_id=p_parcel_id;

  if g is not null then
    select count(*),
           count(*) filter (where exists(select 1 from well_gwca_flag f where f.oid=w.oid)),
           count(*) filter (where exists(select 1 from well_icr_flag  f where f.oid=w.oid))
      into n_wells, n_wells_gwca, n_wells_icr
      from sjrwmd_wells w where st_contains(g, w.geom);
  end if;

  select exists(select 1 from gwca_parcel_match where co_no=p_co_no and parcel_id=p_parcel_id) into in_gwca;
  if in_gwca then
    well_caveat := case
      when n_wells_gwca > 0 then format('This parcel has %s mapped well(s), %s inside the Groundwater Contamination Area - the contamination is MATERIAL here (private-well exposure), not merely a limit on drilling new wells.', n_wells, n_wells_gwca)
      when n_wells > 0 then format('This parcel has %s mapped well(s). Ch. 62-524 restricts potable-well use in the GWCA, so the restriction bites for any private-well reliance here.', n_wells)
      else 'No mapped well on this parcel. Ch. 62-524 restricts NEW potable wells inside the GWCA; a property on municipal/public water is unaffected in practice.'
    end;
    res := res || jsonb_build_object(
      'pass','zone','pass_num',4,'field','gwca_restriction','category','restriction','ladm_class','LA_Restriction',
      'value','within a delineated Groundwater Contamination Area (Ch. 62-524)','field_status','present',
      'as_of','FDEP WRM_UIC','source','gwca_parcel_match','authority','FDEP','resolution_level','parcel','relation','contains',
      'wells_on_parcel', n_wells, 'wells_in_gwca', n_wells_gwca,
      'coverage_caveat', well_caveat);
  end if;

  if n_wells_icr > 0 then
    res := res || jsonb_build_object(
      'pass','parcel','pass_num',5,'field','well_in_institutional_control','category','restriction','ladm_class','LA_Restriction',
      'value', format('%s mapped well(s) on this parcel fall within an FDEP institutional-control area', n_wells_icr),
      'field_status','present','as_of','FDEP ICR','source','well_icr_flag','authority','FDEP','resolution_level','parcel','relation','contains',
      'coverage_caveat','A well inside an institutional-control area is a direct exposure pathway the recorded control is meant to manage - verify the control''s terms in the official records before any well use.');
  end if;

  if g is not null then
    for ic in select restriction_class, coord_source_caveat, resolution_level,
      st_contains(i.geom,g) as contains from fdep_institutional_controls i where st_intersects(i.geom,g) limit 5 loop
      res := res || jsonb_build_object(
        'pass','zone','pass_num',4,'field','institutional_control','category','restriction','ladm_class','LA_Restriction',
        'value', coalesce(ic.restriction_class,'recorded institutional control'),'field_status','present',
        'as_of','FDEP ICR','source','fdep_institutional_controls','authority','FDEP','resolution_level','parcel',
        'relation', case when ic.contains then 'contains' else 'intersects' end,
        'coverage_caveat','An institutional control is a recorded/administrative restriction limiting site use to prevent exposure to contamination. Evidenced by recorded instruments (joinable to the official records). '||coalesce(ic.coord_source_caveat,''));
    end loop;
  end if;

  -- handoff 42: source-water / wellhead protection (Ch. 62-524), resolved via the hierarchy walk.
  if g is not null then
    begin
      select geo_id into v_geo from geo_reference where dor_co_no=p_co_no::int and admin_level=2 limit 1;
      v_sw := public.resolve_layer(v_geo, 'source_water_protection');
      v_swtbl := v_sw->>'table_name'; v_swgeom := coalesce(v_sw->>'geom_column','geom');
      if v_sw->>'state' = 'present' and v_swtbl is not null then
        for sw in execute format(
          'select nullif(trim(x.attributes->>''AQUIFER''),'''') aq, nullif(trim(x.attributes->>''PWS_ID''),'''') pws, st_contains(ST_SetSRID(x.%I,4326),$1) contains from public.%I x where st_intersects(ST_SetSRID(x.%I,4326),$1) limit 3',
          v_swgeom, v_swtbl, v_swgeom) using g loop
          res := res || jsonb_build_object(
            'pass','zone','pass_num',4,'field','source_water_protection','category','restriction','ladm_class','LA_Restriction',
            'value', coalesce('within a delineated source-water / wellhead protection area'||case when sw.aq is not null then ' ('||sw.aq||')' else '' end,'within a source-water protection area'),
            'field_status','present','as_of','FDEP source water','source', v_swtbl,'authority', coalesce(v_sw->>'who_can_answer','FDEP'),
            'resolution_level','parcel','relation', case when sw.contains then 'contains' else 'intersects' end,
            'resolved_at_level', v_sw->>'resolved_at_level',
            'coverage_caveat','Ch. 62-524 restricts new potable wells inside delineated source-water / wellhead protection areas. Verify the specific restriction with FDEP.');
        end loop;
      end if;
    exception when others then null;  -- a schema surprise in one county's layer must not drop the whole restrictions array
    end;
  end if;

  return res;
end $function$;