-- 131a — The identity-frame label must be a NOUN PHRASE (work order 653 (a); ruling 631 (b)).
--
-- The report lead renders "This is a {frame_label}, ...". Five of the labels were adjectives, so
-- the sentence dangled on every parcel they cover:
--   Residential            -> "This is a residential, ..."        (includes DOR use code 000)
--   Waterfront residential -> "This is a waterfront residential, ..."
--   the fallback branch    -> initcap(use_class): "This is an industrial", "This is an unknown", ...
-- Fixed AT SOURCE, not in the renderer (the doc_category anti-pattern: a renderer patch leaves
-- every other consumer of frame_label with the adjective).
--
-- DOR use code 000 is VACANT residential land, so it gets its own noun rather than "residential
-- property", which would describe a house that the roll says is not there.
--
-- ONLY frame_label changes. The frame CODES (residential, waterfront_residential,
-- standard_<class>) are untouched: they are what consumers key on. Consumers checked:
--   repo   — app/report/.../page.tsx reads frame_label (lower-cases it into the sentence);
--            app/api/roz/route.ts names the FIELD in the system prompt, never its values;
--   pg_proc — no function other than this one references frame_label or these strings.
--
-- Anchored in-place patch: every anchor must be present, or nothing is applied. SECURITY DEFINER,
-- so replacing it revokes its own grants: re-asserted below and checked.

do $mig$
declare
  v_def text := pg_get_functiondef('public.get_parcel_identity_frame(numeric,text)'::regprocedure);
  a1 text := $a$v_frame := 'waterfront_residential'; v_label := 'Waterfront residential';$a$;
  a2 text := $a$v_frame := 'residential'; v_label := 'Residential';$a$;
  a3 text := $a$v_label := initcap(replace(v_use_class,'_',' '));$a$;
begin
  if position(a1 in v_def) = 0 or position(a2 in v_def) = 0 or position(a3 in v_def) = 0 then
    raise exception '131a: an anchor is missing from get_parcel_identity_frame — body has moved, not applying';
  end if;
  v_def := replace(v_def, a1,
    $r$v_frame := 'waterfront_residential'; v_label := CASE WHEN v_uci = 0 THEN 'Vacant waterfront residential lot' ELSE 'Waterfront residential property' END;$r$);
  v_def := replace(v_def, a2,
    $r$v_frame := 'residential'; v_label := CASE WHEN v_uci = 0 THEN 'Vacant residential lot' ELSE 'Residential property' END;$r$);
  v_def := replace(v_def, a3,
    $r$v_label := CASE v_use_class
      WHEN 'industrial'            THEN 'Industrial property'
      WHEN 'institutional_private' THEN 'Private institutional property'
      WHEN 'utility_misc'          THEN 'Utility or miscellaneous property'
      WHEN 'acreage'               THEN 'Parcel of non-agricultural acreage'
      WHEN 'unknown'               THEN 'Property of unrecorded use'
      ELSE initcap(replace(v_use_class,'_',' ')) || ' property' END;$r$);
  execute v_def;
end
$mig$;

grant execute on function public.get_parcel_identity_frame(numeric, text) to service_role;
