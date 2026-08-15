-- =============================================================================
-- WO159 / ruling 160, steps b + d — the municipal rung of geo_reference + the parcel->municipality
-- containment primitive. Applied to production after fl_city_limits loaded (412/412).
--
-- b. geo_reference admin_level 3 (412 municipalities). geo_id US-12-<placefp> (dash-namespaced so it
--    cannot collide with US-12<countyfips> or the Nova Scotia CA-12xx codes). parent_geo_id resolved by
--    SPATIAL CONTAINMENT (largest ST_Area(ST_Intersection(city,county))), never the county string.
--    Weeki Wachee (disincorporated 2020-06-09) kept with active=false.
-- d. get_parcel_municipality — parcel -> municipality with the measured pct-of-area caveat (ruling 160:
--    "a percentage is honest and self-evidencing; a boolean hides the ambiguity"). Fragment-safe.
-- =============================================================================

-- b. one row per municipality; parent = largest-area county; multi-county overlaps (>0.5%) recorded in notes.
INSERT INTO geo_reference (geo_id, name, parent_geo_id, dor_co_no, active, notes, country_iso, national_code, admin_level, level_type, code_scheme, admin1_abbr)
SELECT
  'US-12-'||c.placefp, c.name, par.geo_id, par.dor_co_no, c.is_active,
  CASE
    WHEN upper(c.name) LIKE '%WEEKI WACHEE%' THEN 'DISINCORPORATED 2020-06-09; retained for historical parcel-in-city facts. active=false, excluded from current answers.'
    WHEN cc.ncnt > 1 THEN 'Multi-county city (ruling 160: one row, parent = largest-area county). Meaningful (>0.5%) county overlaps: '||cc.clist||'.'
    ELSE NULL
  END,
  'US', '12'||c.placefp, 3, 'municipality', 'Census ANSI place FIPS', 'FL'
FROM fl_city_limits c
CROSS JOIN LATERAL (
  SELECT g.geo_id, g.dor_co_no FROM fl_county_boundaries b JOIN geo_reference g ON g.national_code=b.geoid AND g.admin_level=2
  WHERE ST_Intersects(c.geom,b.geom) ORDER BY ST_Area(ST_Intersection(c.geom,b.geom)) DESC LIMIT 1
) par
CROSS JOIN LATERAL (
  SELECT count(*) ncnt, string_agg(g2.name||' ('||round((100.0*ST_Area(ST_Intersection(c.geom,b2.geom))/ST_Area(c.geom))::numeric,1)||'%)', ', ' ORDER BY ST_Area(ST_Intersection(c.geom,b2.geom)) DESC) clist
  FROM fl_county_boundaries b2 JOIN geo_reference g2 ON g2.national_code=b2.geoid AND g2.admin_level=2
  WHERE ST_Intersects(c.geom,b2.geom) AND ST_Area(ST_Intersection(c.geom,b2.geom))/nullif(ST_Area(c.geom),0) > 0.005
) cc
ON CONFLICT (geo_id) DO NOTHING;

-- d. parcel -> municipality with the pct-of-area caveat. pct alone (NOT boundary distance): a coastal/water
--    edge is not jurisdictional ambiguity, so a fully-inside bayfront parcel must not be caveated.
CREATE OR REPLACE FUNCTION public.get_parcel_municipality(p_co_no numeric, p_parcel_id text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $fn$
DECLARE v_geom geometry; v_pct numeric; r record; n record;
BEGIN
  v_geom := public._parcel_geom_agg(p_co_no, p_parcel_id);
  IF v_geom IS NULL THEN RETURN jsonb_build_object('field_status','parcel_not_resolved'); END IF;
  SELECT c.placefp, c.name, ST_Area(ST_Intersection(v_geom, c.geom)) AS iarea, ST_Area(v_geom) AS parea
  INTO r FROM fl_city_limits c
  WHERE c.is_active AND c.geom && v_geom AND ST_Intersects(c.geom, v_geom)
  ORDER BY ST_Area(ST_Intersection(v_geom, c.geom)) DESC LIMIT 1;
  IF NOT FOUND THEN
    SELECT c.name, c.placefp INTO n FROM fl_city_limits c
    WHERE c.is_active AND ST_DWithin(v_geom::geography, c.geom::geography, 100)
    ORDER BY ST_Distance(v_geom::geography, c.geom::geography) LIMIT 1;
    IF FOUND THEN
      RETURN jsonb_build_object('field_status','near_municipality','municipality',n.name,'geo_id','US-12-'||n.placefp,'placefp',n.placefp,
        'caveat','Parcel is just outside the mapped limit of '||n.name||' (within ~330 ft). The 1:24000 city-limits layer is a tax-code proxy, not a legal boundary — confirm jurisdiction with '||n.name||' and the county.');
    END IF;
    RETURN jsonb_build_object('field_status','not_in_municipality','note','No mapped municipal boundary contains or is near this parcel. An absent city limit is NOT evidence the parcel is unincorporated.');
  END IF;
  v_pct := round((100.0 * r.iarea / nullif(r.parea,0))::numeric, 1);
  IF v_pct >= 99 THEN
    RETURN jsonb_build_object('field_status','present','municipality',r.name,'geo_id','US-12-'||r.placefp,'placefp',r.placefp,
      'pct_of_parcel_in_city',v_pct,'source','fl_city_limits (FGDL/FDOT)','source_tier','government_derived');
  ELSE
    RETURN jsonb_build_object('field_status','present','municipality',r.name,'geo_id','US-12-'||r.placefp,'placefp',r.placefp,
      'pct_of_parcel_in_city',v_pct,'source','fl_city_limits (FGDL/FDOT)','source_tier','government_derived',
      'caveat','This parcel STRADDLES the municipal boundary — only '||v_pct||'% falls inside '||r.name||'. The 1:24000 city-limits layer is a tax-code proxy, not a legal boundary — confirm jurisdiction with '||r.name||' and the county.');
  END IF;
END $fn$;
