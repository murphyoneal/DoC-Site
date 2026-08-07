-- =============================================================================
-- get_parcel_econzone_facts(p_co_no, p_parcel_id) -> jsonb   (SECURITY DEFINER)
--
-- Item 112: the economic overlays in get_pir_report queried Volusia-only tables
-- as if universal, so a non-Volusia parcel got `null` -> rendered "None mapped
-- within 5 mi" (a false negative). This helper resolves each overlay against the
-- statewide funnel_* resolvers and returns a THREE-state coverage model so the
-- report can tell three genuinely different things apart:
--   present            parcel is inside a mapped zone
--   none_intersecting  county IS covered, parcel simply isn't in a zone (a real negative)
--   not_available      we do not hold that overlay for this county (a coverage gap)
--   not_established     parcel geometry could not be resolved
--
-- Coverage is decided by CONTENT, not table names: a county is "covered" iff a
-- funnel feature's interior point (ST_PointOnSurface) falls inside the county
-- boundary. ST_Intersects against the county polygon is NOT used — a Volusia
-- HUBZone with an edge crossing the Marion line produced a false positive.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_parcel_econzone_facts(p_co_no numeric, p_parcel_id text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public','pg_temp'
SET statement_timeout TO '20s'
AS $function$
DECLARE
  v_pt   geometry;
  v_cty  geometry;
  v_oz jsonb; v_hub jsonb; v_ez jsonb; v_cra jsonb;
  a record;
  c_oz  constant text := 'the U.S. Treasury CDFI Fund (Opportunity Zones — cdfifund.gov)';
  c_hub constant text := 'the U.S. Small Business Administration (HUBZone map — maps.certify.sba.gov)';
  c_ez  constant text := 'Florida Commerce (the state Enterprise Zone program sunset December 31, 2015)';
  c_cra constant text := 'the county or municipal Community Redevelopment Agency';
BEGIN
  SELECT ST_PointOnSurface(geom) INTO v_pt FROM resolve_parcel_geometry(p_co_no, p_parcel_id) LIMIT 1;
  SELECT b.geom INTO v_cty FROM fl_county_boundaries b
    JOIN county_registry cr ON b.county = cr.fips
   WHERE cr.dor_county_no = p_co_no::text LIMIT 1;

  IF v_pt IS NULL THEN
    RETURN jsonb_build_object(
      'opportunityZone', jsonb_build_object('field_status','not_established','who_can_answer',c_oz, 'coverage_note','Parcel geometry could not be resolved; Opportunity Zone status was not evaluated — a gap in our data, not a statement about the parcel.'),
      'hubZone',         jsonb_build_object('field_status','not_established','who_can_answer',c_hub,'coverage_note','Parcel geometry could not be resolved; HUBZone status was not evaluated — a gap in our data, not a statement about the parcel.'),
      'enterpriseZone',  jsonb_build_object('field_status','not_established','who_can_answer',c_ez, 'coverage_note','Parcel geometry could not be resolved; Enterprise Zone status was not evaluated — a gap in our data, not a statement about the parcel.'),
      'cra',             jsonb_build_object('field_status','not_established','who_can_answer',c_cra,'coverage_note','Parcel geometry could not be resolved; CRA status was not evaluated — a gap in our data, not a statement about the parcel.'));
  END IF;

  -- ── Opportunity Zone ──
  IF NOT EXISTS (SELECT 1 FROM funnel_opportunity_zones f WHERE ST_Contains(v_cty, ST_PointOnSurface(f.geom))) THEN
    v_oz := jsonb_build_object('field_status','not_available','inside',NULL,'who_can_answer',c_oz,
      'coverage_note','We do not yet hold Opportunity Zone boundaries for this county. Absence here is a gap in our coverage, not a finding that the parcel is outside a zone.');
  ELSIF EXISTS (SELECT 1 FROM funnel_opportunity_zones f WHERE ST_Contains(f.geom, v_pt)) THEN
    SELECT f.props->>'namelsad' AS nm, f.props->>'tractce' AS tract INTO a
      FROM funnel_opportunity_zones f WHERE ST_Contains(f.geom, v_pt) LIMIT 1;
    v_oz := jsonb_build_object('field_status','present','inside',true,'name',a.nm,'tract',a.tract,'source_tier','government_derived',
      'note','This parcel lies within a federal Qualified Opportunity Zone (a Census-tract designation).');
  ELSE
    SELECT round(ST_Distance(f.geom::geography, v_pt::geography)) AS d, f.props->>'namelsad' AS nm INTO a
      FROM funnel_opportunity_zones f WHERE ST_Contains(v_cty, ST_PointOnSurface(f.geom))
      ORDER BY ST_Distance(f.geom::geography, v_pt::geography) LIMIT 1;
    v_oz := jsonb_build_object('field_status','none_intersecting','inside',false,'distanceM',a.d,'name',a.nm,'source_tier','government_derived',
      'note','This parcel is not inside any Opportunity Zone we hold for this county.');
  END IF;

  -- ── HUBZone ──
  IF NOT EXISTS (SELECT 1 FROM funnel_hub_zones f WHERE ST_Contains(v_cty, ST_PointOnSurface(f.geom))) THEN
    v_hub := jsonb_build_object('field_status','not_available','inside',NULL,'who_can_answer',c_hub,
      'coverage_note','We do not yet hold HUBZone boundaries for this county. Absence here is a gap in our coverage, not a finding that the parcel is outside a zone.');
  ELSIF EXISTS (SELECT 1 FROM funnel_hub_zones f WHERE ST_Contains(f.geom, v_pt)) THEN
    SELECT f.props->>'tractce10' AS tract INTO a
      FROM funnel_hub_zones f WHERE ST_Contains(f.geom, v_pt) LIMIT 1;
    v_hub := jsonb_build_object('field_status','present','inside',true,'tract',a.tract,'source_tier','government_derived',
      'note','This parcel lies within an SBA-designated HUBZone (a historically underutilized business zone).');
  ELSE
    SELECT round(ST_Distance(f.geom::geography, v_pt::geography)) AS d INTO a
      FROM funnel_hub_zones f WHERE ST_Contains(v_cty, ST_PointOnSurface(f.geom))
      ORDER BY ST_Distance(f.geom::geography, v_pt::geography) LIMIT 1;
    v_hub := jsonb_build_object('field_status','none_intersecting','inside',false,'distanceM',a.d,'source_tier','government_derived',
      'note','This parcel is not inside any HUBZone we hold for this county.');
  END IF;

  -- ── Enterprise Zone (Florida program sunset 2015; boundaries are historical) ──
  IF NOT EXISTS (SELECT 1 FROM funnel_enterprise_zones f WHERE ST_Contains(v_cty, ST_PointOnSurface(f.geom))) THEN
    v_ez := jsonb_build_object('field_status','not_available','inside',NULL,'who_can_answer',c_ez,
      'coverage_note','We do not hold Enterprise Zone boundaries for this county. The Florida Enterprise Zone program sunset December 31, 2015; absence here is a coverage gap, not a finding.');
  ELSIF EXISTS (SELECT 1 FROM funnel_enterprise_zones f WHERE ST_Contains(f.geom, v_pt)) THEN
    SELECT f.props->>'zoneid' AS zone, f.props->>'cityname' AS city INTO a
      FROM funnel_enterprise_zones f WHERE ST_Contains(f.geom, v_pt) LIMIT 1;
    v_ez := jsonb_build_object('field_status','present','inside',true,'zone',a.zone,'name',initcap(coalesce(a.city,'')),'source_tier','government_derived',
      'note','This parcel falls within a former Florida Enterprise Zone boundary. The program sunset December 31, 2015 — the geography is historical, not an active incentive.');
  ELSE
    SELECT round(ST_Distance(f.geom::geography, v_pt::geography)) AS d, f.props->>'zoneid' AS zone INTO a
      FROM funnel_enterprise_zones f WHERE ST_Contains(v_cty, ST_PointOnSurface(f.geom))
      ORDER BY ST_Distance(f.geom::geography, v_pt::geography) LIMIT 1;
    v_ez := jsonb_build_object('field_status','none_intersecting','inside',false,'distanceM',a.d,'zone',a.zone,'source_tier','government_derived',
      'note','This parcel is not inside any (former) Enterprise Zone we hold for this county.');
  END IF;

  -- ── Community Redevelopment Area (only Volusia's layer is wired; not_available elsewhere) ──
  IF NOT EXISTS (SELECT 1 FROM volusia_community_redevelopment_areas c WHERE ST_Contains(v_cty, ST_PointOnSurface(c.geom))) THEN
    v_cra := jsonb_build_object('field_status','not_available','inside',NULL,'who_can_answer',c_cra,
      'coverage_note','We do not hold Community Redevelopment Area boundaries for this county (no unified statewide CRA layer exists). Absence here is a coverage gap, not a finding.');
  ELSIF EXISTS (SELECT 1 FROM volusia_community_redevelopment_areas c WHERE ST_Contains(c.geom, v_pt)) THEN
    SELECT c.cra_name AS nm INTO a
      FROM volusia_community_redevelopment_areas c WHERE ST_Contains(c.geom, v_pt) LIMIT 1;
    v_cra := jsonb_build_object('field_status','present','inside',true,'name',initcap(coalesce(a.nm,'')),'source_tier','government_derived',
      'note','This parcel lies within a Community Redevelopment Area (a local tax-increment financing district).');
  ELSE
    SELECT round(ST_Distance(c.geom::geography, v_pt::geography)) AS d, c.cra_name AS nm INTO a
      FROM volusia_community_redevelopment_areas c WHERE ST_Contains(v_cty, ST_PointOnSurface(c.geom))
      ORDER BY ST_Distance(c.geom::geography, v_pt::geography) LIMIT 1;
    v_cra := jsonb_build_object('field_status','none_intersecting','inside',false,'distanceM',a.d,'name',initcap(coalesce(a.nm,'')),'source_tier','government_derived',
      'note','This parcel is not inside any Community Redevelopment Area we hold for this county.');
  END IF;

  RETURN jsonb_build_object('opportunityZone',v_oz,'hubZone',v_hub,'enterpriseZone',v_ez,'cra',v_cra);
END $function$;

GRANT EXECUTE ON FUNCTION public.get_parcel_econzone_facts(numeric, text) TO anon, authenticated, service_role;
