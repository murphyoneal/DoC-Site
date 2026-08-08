-- =============================================================================
-- handoff 42: surface drycleaning + stcm_contamination (both POINT proximity findings,
-- section-4 relation) through resolve_layer, merged additively into the existing
-- get_parcel_contamination_facilities promoted[] + area_context. A helper isolates the
-- resolve + dynamic proximity read. New area_context keys are added ONLY when count>0,
-- and on-parcel entries only when present, so the Volusia baseline parcel (0 drycleaning
-- within 1 mi, 0 stcm within 500 m) stays byte-identical while other parcels gain them.
-- Radii: drycleaning 1 mi (PCE/TCE plumes travel), stcm 500 m (matches tanks/clm).
-- =============================================================================
CREATE OR REPLACE FUNCTION public._contam_points_resolved(p_geo text, p_concept text, p_geom geometry, p_radius int)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v jsonb; v_tbl text; v_gc text; v_promoted jsonb; v_ct int;
BEGIN
  v := public.resolve_layer(p_geo, p_concept);
  IF v->>'state' <> 'present' OR v->>'table_name' IS NULL THEN
    RETURN jsonb_build_object('state', v->>'state', 'promoted','[]'::jsonb, 'count_within', 0,
      'who_can_answer', v->>'who_can_answer', 'resolved_at_level', v->>'resolved_at_level');
  END IF;
  v_tbl := v->>'table_name'; v_gc := COALESCE(v->>'geom_column','geom');
  -- build the object via to_jsonb on aliased columns (no manual jsonb-key quoting in
  -- dynamic SQL); %L for the attribute keys. Object keys = column aliases.
  BEGIN
    EXECUTE format(
      'SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.distance_ft) FILTER (WHERE t.on_parcel), ''[]''::jsonb), count(*) '
      ||'FROM (SELECT %L::text AS source, '
      ||'nullif(trim(x.attributes->>%L),'''') AS name, '
      ||'ST_DWithin(ST_SetSRID(x.%I,4326)::geography,$1::geography,15) AS on_parcel, '
      ||'round(ST_Distance(ST_SetSRID(x.%I,4326)::geography,$1::geography)*3.28084)::int AS distance_ft, '
      ||'nullif(x.attributes->>%L,'''') AS documents_url '
      ||'FROM public.%I x WHERE ST_DWithin(ST_SetSRID(x.%I,4326)::geography,$1::geography,$2)) t',
      p_concept, 'NAME', v_gc, v_gc, 'DOCUMENTS', v_tbl, v_gc)
    INTO v_promoted, v_ct USING p_geom, p_radius;
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('state','error','promoted','[]'::jsonb,'count_within',0,
      'who_can_answer',v->>'who_can_answer','err',SQLERRM);
  END;
  RETURN jsonb_build_object('state','present','promoted',COALESCE(v_promoted,'[]'::jsonb),
    'count_within',COALESCE(v_ct,0),'who_can_answer',v->>'who_can_answer','resolved_at_level',v->>'resolved_at_level');
END $fn$;
GRANT EXECUTE ON FUNCTION public._contam_points_resolved(text,text,geometry,int) TO anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.get_parcel_contamination_facilities(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql STABLE
AS $function$
DECLARE v_geom geometry; v_out jsonb; v_geo text;
  v_base_promoted jsonb; v_tank_ct int; v_clm_ct int;
  v_dry jsonb; v_stcm jsonb; v_area jsonb;
BEGIN
  SELECT ST_Union(ST_MakeValid(geom)) INTO v_geom FROM public.parcels_staging
   WHERE co_no=p_co_no AND parcel_id=p_parcel_id AND geom IS NOT NULL;
  IF v_geom IS NULL THEN RETURN jsonb_build_object('field_status','parcel_not_resolved','promoted','[]'::jsonb); END IF;

  WITH tanks AS (
    SELECT 'stcm_tank' AS source, t.attributes->>'FACILITY_NAME' AS name, t.attributes->>'FACILITY_TYPE' AS ftype,
      t.attributes->>'FACILITY_STATUS' AS fstatus, nullif(trim(t.attributes->>'FACILITY_CLEANUP_STATUS'),'') AS cleanup,
      NULL::text AS remediation, nullif(t.attributes->>'DOCUMENTS','') AS docs, NULL::text AS watch,
      round(ST_Distance(t.geom::geography, v_geom::geography))::int AS dist
    FROM public.fdep_stcm_tanks t WHERE ST_DWithin(t.geom::geography, v_geom::geography, 500)
  ),
  clm AS (
    SELECT 'clm_cleanup' AS source, c.attributes->>'BUSINESS_NAME' AS name, c.attributes->>'CLCC_CLEANUP_CATEGORY_KEY' AS ftype,
      NULL::text AS fstatus, nullif(trim(c.attributes->>'CLEANUP_STATUS'),'') AS cleanup, c.remediation_status AS remediation,
      nullif(c.documents::text,'') AS docs, nullif(c.attributes->>'WATCH_THIS_SITE','') AS watch,
      round(ST_Distance(c.geom::geography, v_geom::geography))::int AS dist
    FROM public.fdep_clm c WHERE ST_DWithin(c.geom::geography, v_geom::geography, 500) AND c.proximity_id='EXACT'
  ),
  all_f AS (SELECT * FROM tanks UNION ALL SELECT * FROM clm),
  promoted AS (SELECT * FROM all_f WHERE dist<=15 OR remediation='ACTIVE')
  SELECT coalesce((SELECT jsonb_agg(jsonb_build_object(
        'source',source,'name',name,'facility_type',ftype,'facility_status',fstatus,
        'on_parcel',(dist<=15),'distance_ft', round(dist*3.28084)::int,
        'remediation_status',remediation,'cleanup_status',cleanup,'documents_url',docs,'watch_url',watch)
        ORDER BY (CASE WHEN remediation='ACTIVE' THEN 0 ELSE 1 END), dist) FROM promoted),'[]'::jsonb),
    (SELECT count(*) FROM tanks), (SELECT count(*) FROM clm)
    INTO v_base_promoted, v_tank_ct, v_clm_ct;

  -- handoff 42: drycleaning + stcm via resolve_layer (additive; new keys only when >0)
  SELECT geo_id INTO v_geo FROM public.geo_reference WHERE dor_co_no=p_co_no::int AND admin_level=2 LIMIT 1;
  v_dry  := public._contam_points_resolved(v_geo, 'drycleaning', v_geom, 1609);
  v_stcm := public._contam_points_resolved(v_geo, 'contamination_stcm', v_geom, 500);

  v_area := jsonb_build_object(
    'tank_facilities_within_500m', v_tank_ct,
    'cleanup_sites_within_500m',   v_clm_ct,
    'note','Counts are area context only; on-parcel and active-remediation facilities are named above, not counted.');
  IF COALESCE((v_dry->>'count_within')::int,0)  > 0 THEN v_area := v_area || jsonb_build_object('drycleaning_sites_within_1mi', (v_dry->>'count_within')::int); END IF;
  IF COALESCE((v_stcm->>'count_within')::int,0) > 0 THEN v_area := v_area || jsonb_build_object('stcm_points_within_500m',      (v_stcm->>'count_within')::int); END IF;

  v_out := jsonb_build_object(
    'field_status','present',
    'promoted', v_base_promoted || COALESCE(v_dry->'promoted','[]'::jsonb) || COALESCE(v_stcm->'promoted','[]'::jsonb),
    'area_context', v_area);
  RETURN v_out;
END $function$;