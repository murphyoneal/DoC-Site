-- =============================================================================
-- handoff 38: resolve_layer becomes the hierarchy walk (the last structural piece of
-- Stage 1). Supersedes the 81c version (which read county_layer_registry and did not
-- walk). Now reads layer_resolution and walks geo_reference upward: the parcel's geo,
-- then its ancestors (county -> state -> country) via parent_geo_id.
--
-- ONE ORDERED WALK (ruling 21): candidates are gathered across the whole geo chain and
-- ranked by a SINGLE ORDER BY on the precedence primitive (3 city > 2 county > 1 state
-- > 0 country), with verified/row_count only as deterministic tiebreakers. The first
-- USABLE row (table_name NOT NULL and row_count>0) wins. No second ordering rule; the
-- walk direction IS precedence.
--
-- Returns resolved_at_level + resolved_geo_id, and fell_back = (resolved above the
-- concept's expected_level). A county concept (flood, expected 2) resolving at state
-- (level 1) sets fell_back=true -> the caller renders a coverage statement. A state
-- concept (contamination, expected 1) resolving at state sets fell_back=false -> normal.
-- Three states preserved: present / none_recorded (a row exists in the chain but empty
-- or de-selected) / not_available (nothing at any level).
-- =============================================================================
CREATE OR REPLACE FUNCTION public.resolve_layer(p_geo_id text, p_concept text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $fn$
DECLARE
  v_exp int; v_who text; v_name text; v_lvl int; v_cmap jsonb; v_any boolean; r record;
BEGIN
  SELECT expected_level, who_can_answer INTO v_exp, v_who FROM public.concept_registry WHERE concept=p_concept;

  SELECT name, admin_level INTO v_name, v_lvl FROM public.geo_reference WHERE geo_id=p_geo_id LIMIT 1;
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'state','not_available',
      'table_name',NULL,'column_map',NULL,'note','Unknown geo_id.','who_can_answer',v_who);
  END IF;

  -- one ordered walk over the geo chain
  WITH RECURSIVE chain AS (
    SELECT geo_id, parent_geo_id, admin_level FROM public.geo_reference WHERE geo_id=p_geo_id
    UNION ALL
    SELECT g.geo_id, g.parent_geo_id, g.admin_level
      FROM public.geo_reference g JOIN chain c ON g.geo_id=c.parent_geo_id
  )
  SELECT lr.table_name, lr.geom_column, lr.key_column, lr.bridge_key, lr.key_transform, lr.srid,
         lr.row_count, lr.resolution_mode, ch.geo_id AS r_geo, ch.admin_level AS r_lvl
    INTO r
    FROM public.layer_resolution lr
    JOIN chain ch ON ch.geo_id = lr.geo_id
   WHERE lr.concept = p_concept
     AND lr.table_name IS NOT NULL AND COALESCE(lr.row_count,0) > 0
   ORDER BY lr.precedence DESC, lr.verified DESC NULLS LAST, lr.row_count DESC NULLS LAST
   LIMIT 1;

  IF NOT FOUND THEN
    -- does ANY row exist in the chain for this concept (de-selected/empty)? -> none_recorded
    WITH RECURSIVE chain AS (
      SELECT geo_id, parent_geo_id FROM public.geo_reference WHERE geo_id=p_geo_id
      UNION ALL
      SELECT g.geo_id, g.parent_geo_id FROM public.geo_reference g JOIN chain c ON g.geo_id=c.parent_geo_id
    )
    SELECT EXISTS (SELECT 1 FROM public.layer_resolution lr JOIN chain ch ON ch.geo_id=lr.geo_id
                    WHERE lr.concept=p_concept) INTO v_any;
    IF v_any THEN
      RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'geo_name',v_name,'admin_level',v_lvl,
        'expected_level',v_exp,'state','none_recorded','table_name',NULL,'column_map',NULL,
        'who_can_answer',v_who,'note','A layer is registered for this concept in the geo chain but holds no rows or was de-selected.');
    END IF;
    RETURN jsonb_build_object('concept',p_concept,'geo_id',p_geo_id,'geo_name',v_name,'admin_level',v_lvl,
      'expected_level',v_exp,'state','not_available','table_name',NULL,'column_map',NULL,
      'who_can_answer',v_who,'note','No layer is held for this concept at any level of the geo chain.');
  END IF;

  SELECT jsonb_object_agg(col_role, column_name) INTO v_cmap
    FROM public.layer_column_map WHERE table_name = r.table_name;

  RETURN jsonb_build_object(
    'concept',p_concept,'geo_id',p_geo_id,'geo_name',v_name,'admin_level',v_lvl,
    'state','present','table_name',r.table_name,'geom_column',r.geom_column,
    'key_column',r.key_column,'bridge_key',r.bridge_key,'key_transform',r.key_transform,'srid',r.srid,
    'row_count',r.row_count,'resolution_mode',COALESCE(r.resolution_mode,'pick'),
    'column_map',COALESCE(v_cmap,'{}'::jsonb),
    'resolved_at_level',r.r_lvl,'resolved_geo_id',r.r_geo,'expected_level',v_exp,
    'fell_back',(v_exp IS NOT NULL AND r.r_lvl < v_exp),
    'who_can_answer',v_who);
END $fn$;
GRANT EXECUTE ON FUNCTION public.resolve_layer(text,text) TO anon, authenticated, service_role;
