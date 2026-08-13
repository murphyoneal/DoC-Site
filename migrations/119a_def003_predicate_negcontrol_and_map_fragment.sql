-- =============================================================================
-- Rulings 152-154 — DEF-003 (fragmented parcels) predicate hardening + two more real reads.
--
-- Ruling 154's load-bearing point: a guard means nothing until you show it can FAIL. A green
-- predicate with a real fragment read still present is worse than no predicate — it certifies
-- the bug as absent. Three prior guards this session "could not fire": the anon revoke that was
-- a no-op, the validity guard repairing already-valid geometry, and this detection blind to the
-- standard form (aliased 'select p.geom into') of its own defect.
--
-- What this migration does:
--  1) parcels_in_view — the map viewport RPC emitted st_centroid(p.geom) PER fragment ROW, so a
--     fragmented parcel got one pin per fragment (Collier 00226001401: 14 pins), the single-fragment
--     pin up to 1,696m off the true centre. Aggregate the in-view fragments per parcel: 14 -> 1 pin.
--  2) get_area_findings (corner branch) — 'distinct on(parcel_id) parcel_id, geom' + fragment
--     centroids for the midpoint. Keep the INDEXED raw-geom KNN for nearest-parcel selection (the
--     18.6s cost there is a pre-existing missing expression index on street_norm(phy_addr1), NOT
--     DEF-003), then take the midpoint from the UNIONED chosen parcels' centroids.
--  3) The detection predicate: (a) STRIP -- comments before matching (explanatory comments that
--     quote the anti-pattern were re-flagging already-fixed functions — the detection reads prosrc,
--     comments included); (b) match only the real single-fragment-capture SHAPES ([alias.]geom,
--     optionally compound geom-first, INTO a variable; or ST_Centroid/ST_PointOnSurface of a RAW
--     geom) so ST_Union(...), another table's .geom, and containment lookups no longer false-match.
--
-- Verified by plant-and-remove of the registered detection_sql: GREEN (no probe) -> RED (aliased
-- 'select p.geom into g from parcels_staging p' feeding ST_DWithin) -> GREEN. Golden 290/290 match.
-- The full evolution lives in data_defect_registry.false_positive_notes for this defect.
-- =============================================================================

-- (1) parcels_in_view: one pin per PARCEL at its (in-view) centroid, not one per fragment.
CREATE OR REPLACE FUNCTION public.parcels_in_view(p_west double precision, p_south double precision, p_east double precision, p_north double precision, p_limit integer DEFAULT 25)
 RETURNS TABLE(parcel_id text, co_no numeric, lng double precision, lat double precision)
 LANGUAGE sql STABLE PARALLEL SAFE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp' SET statement_timeout TO '25s'
AS $function$
  -- DEF-003: a fragmented parcel has N rows in parcels_staging; st_centroid(p.geom) per row emitted
  -- N pins at fragment centroids. Aggregate the in-view fragments per parcel so each parcel is ONE
  -- pin at its centroid. Group key is (parcel_id, co_no) -- parcel_id is unique only within a county.
  select p.parcel_id, p.co_no,
    st_x(st_centroid(st_union(p.geom)))::double precision as lng,
    st_y(st_centroid(st_union(p.geom)))::double precision as lat
  from parcels_staging p
  where p.geom && st_makeenvelope(p_west, p_south, p_east, p_north, 4326)
  group by p.parcel_id, p.co_no
  limit greatest(1, least(p_limit, 200));
$function$;

-- (2) get_area_findings corner branch: indexed-KNN selection + union-of-chosen-parcels midpoint.
--     (Full function re-created in the applied migration; see git history / pg_get_functiondef.
--      The changed section is the corner-branch geometry read only.)

-- (3) Detection predicate: comment-stripped + shape-scoped. Applied via:
UPDATE data_defect_registry
SET detection_sql = $DSQL$SELECT NOT EXISTS (
  SELECT 1 FROM pg_proc p
  WHERE p.pronamespace='public'::regnamespace
    AND p.proname NOT IN ('_parcel_geom_agg','resolve_parcel_geometry')
    AND regexp_replace(p.prosrc, '--[^\n]*', ' ', 'g') ~*
      '(select[[:space:]]*([a-z_]+\.)?geom([[:space:]]*,[^;]*)?[[:space:]]+into[[:space:]]|st_pointonsurface[[:space:]]*\([[:space:]]*([a-z_]+\.)?geom[[:space:]]*\)|st_centroid[[:space:]]*\([[:space:]]*([a-z_]+\.)?geom[[:space:]]*\))[^;]*from[[:space:]]+(public\.)?parcels_staging'
) AS ok$DSQL$
WHERE defect_id='parcels-staging-geometry-read-not-aggregated';
