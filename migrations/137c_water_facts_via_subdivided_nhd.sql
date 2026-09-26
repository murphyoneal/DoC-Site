-- 137c — get_parcel_water_facts measures distance through nhd_area_sub (137b). Backlog 258.
--
-- Santa Rosa golden parcel: 5,413 ms -> 420 ms. Cause: planar and geodesic ST_Distance against two
-- polygons of 42,558 and 21,827 vertices whose bounding boxes cover the parcel.
--
-- SAME ANSWERS, proven before applying against the live function on 22 parcels (10 golden, 7 that
-- touch a >5,000-vertex polygon in 7 counties, 5 others): every key identical except one TIE.
--   * candidates are still every polygon whose BOUNDING BOX meets the search envelope, as before;
--   * planar distance = min over the polygon's pieces (a polygon's distance is its nearest piece's);
--   * geodesic distance = min over pieces within pd/0.85 degrees: cos(latitude) > 0.85 everywhere in
--     Florida, so the geodesically nearest piece cannot lie further out than that;
--   * adjacency = any piece intersects the parcel (index-backed);
--   * shoreline = the polygon clipped to a box just around the parcel first; clipping adds edges only
--     on the box border, which the parcel never reaches, so the length is unchanged.
-- THE TIE: 74/961900000010 touches "Glory Hole" (bay) and an unnamed stream area with EXACTLY equal
-- shoreline (3,345 ft); ORDER BY shoreline DESC LIMIT 1 picked either, depending on the plan. The tie
-- is now broken deterministically - a named water body first, then objectid - which keeps Glory Hole.
-- service_role-only function (no browser grant); re-asserted.

do $f$
declare def text; new_def text; n int;
begin
  def := pg_get_functiondef('public.get_parcel_water_facts(numeric,text)'::regprocedure);
  new_def := def;
  new_def := replace(new_def,
$o$      'distance_ft', round((ST_Distance(a.geom::geography,g::geography)*3.28084)::numeric),
      'adjacent', ST_Intersects(a.geom,g),
      'shoreline_ft', case when ST_Intersects(a.geom,g)
        then round((ST_Length(ST_Intersection(ST_Boundary(a.geom),g)::geography)*3.28084)::numeric) end) x
    from nhd_area a where a.geom && env order by ST_Distance(a.geom,g) limit 6) s;$o$,
$n$      'distance_ft', round(((select min(ST_Distance(s2.geom::geography,g::geography)) from nhd_area_sub s2
                               where s2.objectid = a.objectid and ST_DWithin(s2.geom, g, d.pd / 0.85 + 1e-9))*3.28084)::numeric),
      'adjacent', d.adj,
      'shoreline_ft', case when d.adj
        then round((ST_Length(ST_Intersection(ST_Boundary(ST_ClipByBox2D(a.geom, ST_Expand(g, 0.0001)::box2d)),g)::geography)*3.28084)::numeric) end) x
    from nhd_area a
    cross join lateral (select (select min(ST_Distance(s1.geom, g)) from nhd_area_sub s1 where s1.objectid = a.objectid) as pd,
                               exists (select 1 from nhd_area_sub s3 where s3.objectid = a.objectid and s3.geom && g and ST_Intersects(s3.geom, g)) as adj) d
    where a.geom && env order by d.pd limit 6) s;$n$);
  new_def := replace(new_def,
$o$           'shoreline_ft', round((ST_Length(ST_Intersection(ST_Boundary(a.geom),g)::geography)*3.28084)::numeric))
    into body_adj
  from nhd_area a where a.geom && g and ST_Intersects(a.geom,g)
  order by ST_Length(ST_Intersection(ST_Boundary(a.geom),g)::geography) desc limit 1;$o$,
$n$           'shoreline_ft', round((ST_Length(ST_Intersection(ST_Boundary(ST_ClipByBox2D(a.geom, ST_Expand(g, 0.0001)::box2d)),g)::geography)*3.28084)::numeric))
    into body_adj
  from nhd_area a where a.geom && g and ST_Intersects(a.geom,g)
  order by ST_Length(ST_Intersection(ST_Boundary(ST_ClipByBox2D(a.geom, ST_Expand(g, 0.0001)::box2d)),g)::geography) desc,
           (a.gnis_name is null), a.objectid limit 1;$n$);
  n := (length(new_def) - length(replace(new_def, 'nhd_area_sub', ''))) / length('nhd_area_sub');
  if n <> 3 or position('(a.gnis_name is null), a.objectid' in new_def) = 0 then
    raise exception '137c: anchors did not apply cleanly - nothing changed';
  end if;
  execute new_def;
end $f$;

grant execute on function public.get_parcel_water_facts(numeric, text) to service_role;
