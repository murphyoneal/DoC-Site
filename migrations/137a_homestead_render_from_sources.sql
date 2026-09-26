-- 137a — get_pir_report renders homestead from the SOURCES, not properties.homestead_exempt.
-- Ruling 2026-09-26 (row 676 item 2, backlog 259): fix the renderer, not the column.
--
-- properties (313,578 rows, Volusia only) carries a homestead_exempt flag that disagrees with both
-- value-bearing sources on 16,365 rows, measured 2026-09-26:
--   flag false, state roll (NAL EXMPT_01/02) true:  4,789 — 4,778 carry a homestead amount in the SAME row
--   flag true,  state roll false:                   11,576 — 0 carry any amount
-- The row's own exemption amounts agree with the state roll in both groups; the flag is the odd one
-- out. The page showed "Owner-occupied" only when true, and the tax block read the flag BEFORE the
-- roll (coalesce(flag, NAL)), so the roll was never consulted for Volusia.
--
-- The rule (conservative — never assert what the sources do not):
--   TRUE  when the row carries a homestead exemption amount, or the state roll records one;
--   FALSE only when the roll, the amounts and the flag all say no;
--   NULL  (not recorded) when they conflict or nothing is recorded.
-- ownerOccupied stays NULL outside properties' coverage, as before: using the roll statewide is a
-- scope change nobody ruled on. The tax block already fell back to the roll outside Volusia; it now
-- uses the same value inside it.
-- service_role-only function (no browser grant), re-asserted anyway.

do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.get_pir_report(numeric,text)'::regprocedure);
  new_def := def;
  new_def := replace(new_def, '  v_vfacts jsonb;', '  v_vfacts jsonb; v_homestead boolean;');
  new_def := replace(new_def, '  v_val := get_parcel_values(p_co_no, p_parcel_id);',
    '  v_val := get_parcel_values(p_co_no, p_parcel_id);
  -- 137a: homestead from the sources (state roll, the row''s exemption amounts), never the flag alone.
  v_homestead := CASE
    WHEN coalesce(v_prop.homestead_exemption_1,0) > 0 OR coalesce(v_prop.homestead_exemption_2,0) > 0 THEN true
    WHEN (v_val->>''homestead'')::boolean THEN true
    WHEN v_prop IS NULL THEN (v_val->>''homestead'')::boolean
    WHEN (v_val->>''homestead'')::boolean = false AND v_prop.homestead_exempt = false THEN false
    ELSE NULL END;');
  new_def := replace(new_def, '''ownerOccupied'',v_prop.homestead_exempt,',
    '''ownerOccupied'',CASE WHEN v_prop IS NULL THEN NULL ELSE v_homestead END,');
  new_def := replace(new_def, 'coalesce(v_prop.homestead_exempt, (v_val->>''homestead'')::boolean)', 'v_homestead');
  if (length(new_def) - length(replace(new_def, 'v_homestead', ''))) / length('v_homestead') <> 4
     or position('v_prop.homestead_exempt,' in new_def) > 0
     or position('coalesce(v_prop.homestead_exempt, (v_val' in new_def) > 0 then
    raise exception '137a: an anchor did not apply cleanly - nothing changed';
  end if;
  execute new_def;
end $f$;

grant execute on function public.get_pir_report(numeric, text) to service_role;
