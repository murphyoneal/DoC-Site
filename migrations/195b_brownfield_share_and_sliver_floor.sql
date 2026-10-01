-- 195b - brownfield serves the share, never a 50% boolean; a sub-3-ft overlap is a boundary disagreement (ruling 919).
-- HOLD: apply only after PR #127 (front end) is merged and deployed. The deployed page renders inside_area only, so
-- moving partial parcels out of inside_area ahead of it would turn them silent (coupled deploy, additive-first rule).
--
-- 919: "DO NOT MAKE 50% A BOOLEAN ... The served fact is THE SHARE AND THE AREA'S NAME ... AND THE SLIVER FLOOR NEEDS
-- MEASURING, NOT CHOOSING ... state the floor in FEET or ACRES of overlap rather than a percentage."
--
-- SLIVER FLOOR, MEASURED 2026-10-01 on every Volusia parcel intersecting an FDEP brownfield area (18,779 pairs), by the
-- overlap's STRIP WIDTH = overlap area / (overlap perimeter / 2), in feet - the measure a digitising offset produces
-- (a thin strip along the shared edge), and the same on a large parcel as a small one:
--   0-0.5 ft 545 · 0.5-1 586 · 1-2 658 · 2-3 586 · 3-5 149 · 5-8 270 · 8-12 491 · 12-20 1,144 · 20-50 5,078 · ...
-- Density falls from ~586 per foot below 3 ft to ~75 per foot at 3-5 ft - an ~8x break. Floor = 3 ft. Median share
-- of parcel inside the <0.5 ft bucket is 0.02%.
--
-- SERVED (the parcel polygon is always tested; the interior-point shortcut is gone):
--   no overlap                          -> nearest_area by distance (unchanged)
--   overlap strip  < 3 ft               -> boundary_disagreement {name, overlap_sqft, floor_ft 3, note}: neither inside nor
--                                          outside; nearest_area NULL
--   uncovered strip < 3 ft (or none)    -> inside_area, relation 'wholly_within' (no qualifier), share_of_parcel_pct
--   otherwise                           -> partly_within_area, relation 'partial_overlap', share_of_parcel_pct - at 49%
--                                          and 95.6% alike
-- inside_area is derived from geometry, never from a share threshold.

do $$
declare d text; a1 text; a2 text; old_block text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.get_parcel_brownfield_facts'::regproc;
  d := pg_get_functiondef('public.get_parcel_brownfield_facts'::regproc);
  if position('v_partial jsonb;  -- 195a' in d) = 0 then raise exception '195b: 195a is not applied'; end if;
  old_block := substring(d from '  -- AREA containment \(polygon shadow\).*?\n  END IF;\n\n  -- SITES within 1 mile');
  if old_block is null then raise exception '195b: area block not found'; end if;
  d := replace(d, old_block, $b$  -- AREA (195b, ruling 919): the parcel polygon, its share, and a measured 3 ft strip-width sliver floor.
  SELECT b.area_name AS name, nullif(btrim(b.resolution_number),'') AS resnum,
         CASE WHEN b.resolution_date IS NOT NULL THEN to_char(to_timestamp(b.resolution_date/1000),'FMMonth DD, YYYY') END AS resdate,
         round(b.acreage::numeric,1) AS acres, b.derived_county_name AS county,
         ST_Area(ST_Intersection(b.geom, v_geom)::geography) AS ov_m2,
         ST_Perimeter(ST_Intersection(b.geom, v_geom)::geography) AS ov_per_m,
         ST_Area(ST_Difference(v_geom, b.geom)::geography) AS un_m2,
         ST_Perimeter(ST_Difference(v_geom, b.geom)::geography) AS un_per_m,
         ST_Area(v_geom::geography) AS parcel_m2
    INTO a FROM fdep_brownfield_areas b WHERE ST_Intersects(b.geom, v_geom)
    ORDER BY ST_Area(ST_Intersection(b.geom, v_geom)) DESC LIMIT 1;
  IF FOUND AND a.ov_m2 > 0 THEN
    IF a.ov_m2 / nullif(a.ov_per_m / 2, 0) * 3.28084 < 3 THEN
      v_bd := jsonb_build_object('name',a.name,'county',a.county,'source','fdep_brownfield_areas',
        'overlap_sqft', round((a.ov_m2 * 10.7639)::numeric), 'floor_ft', 3,
        'note', format('This parcel''s boundary and the %s boundary disagree by less than 3 ft along their edge - too little to say the area reaches the parcel or stops short of it. Ask the county.', a.name));
    ELSIF a.un_m2 = 0 OR a.un_m2 / nullif(a.un_per_m / 2, 0) * 3.28084 < 3 THEN
      v_inside := jsonb_build_object('name',a.name,'resolution_number',a.resnum,'resolution_date',a.resdate,
        'acreage_ac',a.acres,'county',a.county,'source','fdep_brownfield_areas','relation','wholly_within',
        'share_of_parcel_pct', round((100 * a.ov_m2 / nullif(a.parcel_m2, 0))::numeric, 1));
    ELSE
      v_partial := jsonb_build_object('name',a.name,'resolution_number',a.resnum,'resolution_date',a.resdate,
        'acreage_ac',a.acres,'county',a.county,'source','fdep_brownfield_areas','relation','partial_overlap',
        'share_of_parcel_pct', round((100 * a.ov_m2 / nullif(a.parcel_m2, 0))::numeric, 1));
    END IF;
  ELSE
    -- nearest area within 5 mi (area context, polygon distance in feet) - only when nothing overlaps
    SELECT b.area_name AS name, round((ST_Distance(b.geom::geography, v_geom::geography)*3.28084)::numeric) AS dist_ft, b.derived_county_name AS county
      INTO a FROM fdep_brownfield_areas b
      WHERE ST_DWithin(b.geom::geography, v_geom::geography, 8047)
      ORDER BY ST_Distance(b.geom::geography, v_geom::geography) LIMIT 1;
    IF FOUND THEN v_near := jsonb_build_object('name',a.name,'distance_ft',a.dist_ft,'county',a.county); END IF;
  END IF;

  -- SITES within 1 mile$b$);
  d := replace(d, 'v_partial jsonb;  -- 195a', 'v_partial jsonb; v_bd jsonb;  -- 195a/195b');
  d := replace(d, 'IF v_inside IS NULL AND v_partial IS NULL AND v_near IS NULL AND v_sites IS NULL THEN',
                  'IF v_inside IS NULL AND v_partial IS NULL AND v_bd IS NULL AND v_near IS NULL AND v_sites IS NULL THEN');
  d := replace(d, '''partly_within_area'',v_partial,', '''partly_within_area'',v_partial,''boundary_disagreement'',v_bd,');
  if position('''boundary_disagreement'',v_bd' in d) = 0 or position('v_bd IS NULL AND v_near' in d) = 0 then raise exception '195b: a replace did not apply'; end if;
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.get_parcel_brownfield_facts'::regproc;
  if a2 is distinct from a1 then raise exception '195b: grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'brownfield_share_and_sliver_floor', 'get_parcel_brownfield_facts', array['get_parcel_brownfield_facts'],
  jsonb_build_object('rule', '>=50% inside_area majority_overlap, <50% partly_within (195a)'),
  jsonb_build_object('rule', 'wholly_within / partial_overlap with share / boundary_disagreement below 3 ft strip width', 'floor_basis', 'density break 586/ft -> 75/ft at 3 ft, Volusia 18,779 pairs'),
  'Ruling 919: the share and the area name are the served fact, not a 50% boolean; the sliver floor is measured in feet of strip width from the data.', null);
