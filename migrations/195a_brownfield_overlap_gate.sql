-- 195a - a parcel mostly inside a brownfield area is no longer served as "nearest area 5 ft away" (bus 466, ruling 907).
--
-- LIVE FALSE STATEMENT, verified 2026-10-01 (surfaced by the 916 reconciliation sample; reported by cc as 466 on 08-23
-- and never ruled). get_parcel_brownfield_facts tests ONE interior point (ST_PointOnSurface) against the area polygons.
-- When that point falls outside, the parcel is treated as outside and given the distance from the point to the area:
--   74/801011000123  95.6% of the parcel inside the Orange City Brownfield Area -> inside_area null, nearest 5 ft
-- and the page then says "Brownfield - nearby ... near, but not on, this parcel". Volusia, measured: 3,158 parcels
-- intersect an area while their point does not - 220 with >=50% of the parcel inside, 332 at 10-50%, 1,595 at 1-10%,
-- 1,011 under 1%.
--
-- GATE (DB only, additive, ships today):
--   point inside                     -> unchanged (relation 'contains')
--   point outside, parcel overlaps:
--     >= 50% of the parcel inside    -> inside_area, relation 'majority_overlap', share_of_parcel_pct. The page's
--                                       "covers this parcel / Within the X area" is true of a majority.
--     <  50%                         -> partly_within_area {name, share_of_parcel_pct, ...}; inside_area null and
--                                       nearest_area NULL (the point-distance was the false part). The page renders
--                                       nothing for it until the follow-up front-end change; Roz reads the payload.
--   no overlap                       -> unchanged (nearest area by distance)
-- The 50% line is where "within" becomes true of most of the parcel; the share is always served, so nothing rests on
-- it once the page renders the share. A none_nearby verdict can no longer be emitted for an overlapping parcel.

do $$
declare d text; a1 text; a2 text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_parcel_brownfield_facts'::regproc;
  d := pg_get_functiondef('public.get_parcel_brownfield_facts'::regproc);
  if position(E'DECLARE v_pt geometry;' in d) = 0
     or position(E'  v_pt := st_pointonsurface(public._parcel_geom_agg(p_co_no, p_parcel_id));' in d) = 0
     or position(E'''relation'',''contains'');\n  ELSE\n' in d) = 0
     or position(E'    IF FOUND THEN v_near := jsonb_build_object(''name'',a.name,''distance_ft'',a.dist_ft,''county'',a.county); END IF;\n  END IF;' in d) = 0
     or position(E'IF v_inside IS NULL AND v_near IS NULL AND v_sites IS NULL THEN' in d) = 0
     or position(E'''inside_area'',v_inside,''nearest_area'',v_near,' in d) = 0 then
    raise exception '195a: an anchor is missing';
  end if;

  d := replace(d, E'DECLARE v_pt geometry;', E'DECLARE v_pt geometry; v_geom geometry; v_partial jsonb;  -- 195a');
  d := replace(d, E'  v_pt := st_pointonsurface(public._parcel_geom_agg(p_co_no, p_parcel_id));',
                  E'  v_geom := public._parcel_geom_agg(p_co_no, p_parcel_id);\n  v_pt := st_pointonsurface(v_geom);');
  d := replace(d, E'''relation'',''contains'');\n  ELSE\n',
$r$'relation','contains');
  ELSE
    -- 195a (bus 466): the interior point can miss an area that covers most of the parcel. Test the parcel itself.
    SELECT b.area_name AS name, nullif(btrim(b.resolution_number),'') AS resnum,
           CASE WHEN b.resolution_date IS NOT NULL THEN to_char(to_timestamp(b.resolution_date/1000),'FMMonth DD, YYYY') END AS resdate,
           round(b.acreage::numeric,1) AS acres, b.derived_county_name AS county,
           (100 * ST_Area(ST_Intersection(b.geom, v_geom)::geography) / nullif(ST_Area(v_geom::geography), 0)) AS share
      INTO a FROM fdep_brownfield_areas b WHERE ST_Intersects(b.geom, v_geom)
      ORDER BY ST_Area(ST_Intersection(b.geom, v_geom)) DESC LIMIT 1;
    IF FOUND AND a.share > 0 THEN
      IF a.share >= 50 THEN
        v_inside := jsonb_build_object('name',a.name,'resolution_number',a.resnum,'resolution_date',a.resdate,
          'acreage_ac',a.acres,'county',a.county,'source','fdep_brownfield_areas','relation','majority_overlap',
          'share_of_parcel_pct', round(a.share::numeric, 1));
      ELSE
        v_partial := jsonb_build_object('name',a.name,'resolution_number',a.resnum,'resolution_date',a.resdate,
          'acreage_ac',a.acres,'county',a.county,'source','fdep_brownfield_areas','relation','partial_overlap',
          'share_of_parcel_pct', round(a.share::numeric, 1),
          'note','Part of this parcel lies within a designated brownfield area; the share is computed from the parcel and area boundaries we hold.');
      END IF;
    ELSE
$r$);
  d := replace(d, E'    IF FOUND THEN v_near := jsonb_build_object(''name'',a.name,''distance_ft'',a.dist_ft,''county'',a.county); END IF;\n  END IF;',
                  E'    IF FOUND THEN v_near := jsonb_build_object(''name'',a.name,''distance_ft'',a.dist_ft,''county'',a.county); END IF;\n    END IF;\n  END IF;');
  d := replace(d, E'IF v_inside IS NULL AND v_near IS NULL AND v_sites IS NULL THEN',
                  E'IF v_inside IS NULL AND v_partial IS NULL AND v_near IS NULL AND v_sites IS NULL THEN');
  d := replace(d, E'''inside_area'',v_inside,''nearest_area'',v_near,',
                  E'''inside_area'',v_inside,''partly_within_area'',v_partial,''nearest_area'',v_near,');
  execute d;

  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_parcel_brownfield_facts'::regproc;
  if a2 is distinct from a1 then raise exception '195a: grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'brownfield_overlap_gate', 'get_parcel_brownfield_facts', array['get_parcel_brownfield_facts'],
  jsonb_build_object('example', '74/801011000123 95.6% inside Orange City Brownfield Area served as nearest 5 ft', 'volusia_missed', 3158),
  jsonb_build_object('ge50', 'inside_area relation majority_overlap', 'lt50', 'partly_within_area, nearest_area null'),
  'Bus 466 / ruling 907: the brownfield test used one interior point, so parcels mostly inside a designated area were served as outside and "near, but not on". Gated the day it was verified.', null);
