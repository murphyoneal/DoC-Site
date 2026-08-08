-- =============================================================================
-- handoff 36 Phase 2 (subdivisions + marine only): wire the two cleanly-additive
-- concepts into get_pir_report via the content-verified resolver helpers.
-- TWO changes only, both gated on volusia_parcel_centroids presence so a Volusia
-- parcel keeps its inline reads byte-for-byte:
--   property.subdivision : v_cen present -> v_cen.subdivision (unchanged)
--                          else -> get_parcel_subdivision_resolved (county *_subdivisions)
--   water.boatRamps      : v_cen present -> inline volusia_boat_ramps (unchanged)
--                          else -> get_parcel_boat_ramps_resolved (county marine layer)
-- school_zones and plat_index are HELD (reported to handoff 36); environmental_overlay
-- deferred to the section-3 restructure. Everything else in this function is identical
-- to the deployed definition. Proof: 28-section Volusia md5 baseline unchanged.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_pir_report(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '25s'
AS $function$
DECLARE
  v_vfacts jsonb;
  v_prop properties%ROWTYPE; v_cen RECORD; v_si RECORD; v_env RECORD; v_haz RECORD;
  v_pt geometry(Point,4326); v_pgeom geometry; v_rgeom geometry; v_rpt geometry(Point,4326); v_ps_actyr numeric; v_ps_effyr numeric; v_ps_nobldg numeric; v_ps_totlvg numeric; v_out jsonb;
  v_amenities jsonb; v_txns jsonb; v_txn_count int;
  v_water jsonb; v_ramps jsonb; v_schools jsonb;
  v_altkey text; v_subnum text; v_legal text; v_owners jsonb; v_owner_count int; v_plat jsonb; v_cama_land numeric; v_cama_bldg numeric; v_cama_tot numeric; v_roll_year text; v_cama_nsasd numeric; v_cama_cotxbl numeric; v_cama_stxbl numeric; v_val jsonb;
BEGIN
  SELECT * INTO v_prop FROM properties WHERE dor_parcel_id = p_parcel_id AND county_fips = (SELECT fips FROM county_registry WHERE dor_county_no = p_co_no::text) ORDER BY updated_at DESC NULLS LAST LIMIT 1;
  v_val := get_parcel_values(p_co_no, p_parcel_id);
  v_vfacts := public.get_parcel_values_facts(p_co_no, p_parcel_id);
  SELECT c.*, ST_X(c.geom) AS lng, ST_Y(c.geom) AS lat INTO v_cen FROM volusia_parcel_centroids c WHERE c.fullpid = p_parcel_id LIMIT 1;
  SELECT * INTO v_si FROM get_site_intelligence(p_co_no, p_parcel_id) LIMIT 1;
  SELECT geom, act_yr_blt::numeric, eff_yr_blt::numeric, no_buldng::numeric, tot_lvg_ar::numeric INTO v_pgeom, v_ps_actyr, v_ps_effyr, v_ps_nobldg, v_ps_totlvg FROM parcels_staging WHERE co_no = p_co_no AND parcel_id = p_parcel_id LIMIT 1;
  v_pt := COALESCE(v_cen.geom, ST_PointOnSurface(v_pgeom));
  SELECT geom INTO v_rgeom FROM resolve_parcel_geometry(p_co_no, p_parcel_id) LIMIT 1;
  v_rpt := ST_PointOnSurface(v_rgeom);

  SELECT altkey::bigint::text, subnum::text INTO v_altkey, v_subnum
    FROM volusia_parcels_govt_source WHERE pid = p_parcel_id LIMIT 1;

  SELECT nullif(trim("APRLAND"),'')::numeric, nullif(trim("APRBLDG"),'')::numeric,
         nullif(nullif(trim("APRTOT"),''),'0')::numeric, "TAXYR",
         nullif(trim("NSASD"),'')::numeric, nullif(trim("COTXBL"),'')::numeric, nullif(trim("STXBL"),'')::numeric
    INTO v_cama_land, v_cama_bldg, v_cama_tot, v_roll_year, v_cama_nsasd, v_cama_cotxbl, v_cama_stxbl
    FROM volusia_cama_parcel WHERE "PARID"=v_altkey ORDER BY "TAXYR" DESC LIMIT 1;

  SELECT "LEGDESC" INTO v_legal FROM volusia_cama_legal WHERE "PARID"=v_altkey ORDER BY "TAXYR" DESC LIMIT 1;

  SELECT jsonb_build_object('subnum',subnum,'subdivisionName',subname,'mapBook',map_book,
           'mapPage',page,'mapPageThru',page_thru,'orBook',or_book,'orPage',or_page,
           'plattedDate',platted_date,'lots',lots,'scanLink',coalesce(plat_link,internallink),
           'note', 'Current subdivision only; the historical plat chain lives in the legal-description text.'
                   || CASE WHEN (SELECT count(*) FROM volusia_subdivision_plats WHERE subnum::text=v_subnum) > 1
                           THEN ' Duplicate plat rows exist for this subnum (known defect).' ELSE '' END)
    INTO v_plat FROM volusia_subdivision_plats WHERE subnum::text=v_subnum
   ORDER BY (platted_date IS NULL), platted_date LIMIT 1;

  SELECT jsonb_agg(jsonb_build_object('amenityType',a.amenity_type,'displayName',a.display_name,
           'iconName',a.icon_name,'category',a.category,'name',a.name,
           'distanceM',round(a.distance_m::numeric,1),'bearingDegrees',round(a.bearing_degrees::numeric,1)) ORDER BY a.sort_order)
    INTO v_amenities FROM get_nearby_amenities(p_co_no, p_parcel_id) a WHERE a.amenity_type <> 'school';

  SELECT jsonb_agg(jsonb_build_object('level',lvl,'name',COALESCE(sc.name,nm),
           'distanceM',CASE WHEN sc.geom IS NOT NULL THEN round(ST_Distance(sc.geom::geography,v_pt::geography)) END,
           'bearingDegrees',CASE WHEN sc.geom IS NOT NULL THEN round(degrees(ST_Azimuth(v_pt,sc.geom))::numeric,1) END) ORDER BY ord)
    INTO v_schools FROM (
      SELECT 1 ord,'Elementary' lvl,a.elementary_school nm,'ELEM' kw FROM volusia_parcel_school_assignment a WHERE a.altkey=v_cen.altkey::text
      UNION ALL SELECT 2,'Middle',a.middle_school_name,'MIDDLE' FROM volusia_parcel_school_assignment a WHERE a.altkey=v_cen.altkey::text
      UNION ALL SELECT 3,'High',a.high_school_name,'HIGH' FROM volusia_parcel_school_assignment a WHERE a.altkey=v_cen.altkey::text
    ) t LEFT JOIN LATERAL (
      SELECT s.name,s.geom FROM volusia_schools s
       WHERE s.name ILIKE '%'||regexp_replace(t.nm,'\s*(Elementary|Elem|Middle School|Middle|High School|High|School)\s*$','','i')||'%' AND s.name ILIKE '%'||t.kw||'%'
       ORDER BY ST_Distance(s.geom::geography,v_pt::geography) LIMIT 1) sc ON true
   WHERE t.nm IS NOT NULL AND trim(t.nm) <> '';

  SELECT jsonb_agg(x ORDER BY (x->>'distanceM')::numeric) INTO v_water FROM (
    SELECT jsonb_build_object('name',NULLIF(trim(w.gnis_name),''),'ftype',w.ftype,
             'distanceM',round(ST_Distance(w.geom::geography,v_pt::geography)),
             'bearingDegrees',round(degrees(ST_Azimuth(v_pt,ST_ClosestPoint(w.geom,v_pt)))::numeric,1)) x
      FROM hydrology_waterbodies w WHERE ST_DWithin(w.geom::geography,v_pt::geography,3000)
     ORDER BY ST_Distance(w.geom::geography,v_pt::geography) LIMIT 5) q;
  SELECT jsonb_agg(x ORDER BY (x->>'distanceM')::numeric) INTO v_ramps FROM (
    SELECT jsonb_build_object('name',r.rampname,'waterbody',r.waterbody,
             'distanceM',round(ST_Distance(r.geom::geography,v_pt::geography)),
             'bearingDegrees',round(degrees(ST_Azimuth(v_pt,r.geom))::numeric,1)) x
      FROM volusia_boat_ramps r WHERE ST_DWithin(r.geom::geography,v_pt::geography,8000)
     ORDER BY ST_Distance(r.geom::geography,v_pt::geography) LIMIT 4) q;

  v_out := jsonb_build_object(
    'meta', jsonb_build_object('coNo',p_co_no,'parcelId',p_parcel_id,'altKey',v_altkey,'stateParcelId',v_prop.state_parcel_id,
      'countyName',COALESCE(v_prop.county_name,v_si.county_name),'lat',ST_Y(v_rpt),'lng',ST_X(v_rpt),'generatedAt',now(),
      'dataQualityScore',v_prop.data_quality_score,'source',v_prop.source_import_id),
    'property', jsonb_build_object('address',COALESCE(v_prop.address_line_1,v_si.phy_addr1),'city',COALESCE(v_prop.city,v_si.phy_city),
      'zip',v_prop.zip_code,'jurisdiction',v_cen.jurisdiction,'incorporation',v_cen.statusincorporated,
      'ownerName',COALESCE(v_owners->0->>'name',v_prop.owner_name,v_si.owner_name),'ownerOccupied',v_prop.homestead_exempt,
      'ownerMailAddr',v_prop.owner_mail_addr,'ownerMailCity',v_prop.owner_mail_city,
      'subdivision',CASE WHEN v_cen.fullpid IS NOT NULL THEN v_cen.subdivision ELSE public.get_parcel_subdivision_resolved(p_co_no,p_parcel_id) END,'neighborhood',v_cen.nbhd_desc,'legal',COALESCE(v_legal,v_cen.legal1),
      'propertyType',v_prop.property_type,'landUseCode',COALESCE(v_prop.land_use_code,v_si.land_use_code),
      'yearBuilt',COALESCE(v_prop.build_year::int, nullif(v_ps_actyr,0)::int),'effectiveYearBuilt',COALESCE(v_prop.effective_year_built::int, nullif(v_ps_effyr,0)::int),
      'stories',v_prop.stories,'bedrooms',v_prop.bedrooms,'bathrooms',(select (coalesce(nullif(trim("FIXBATH"),''),'0')::numeric + coalesce(nullif(trim("FIXBATH4"),''),'0')::numeric + coalesce(nullif(trim("FIXBATH5"),''),'0')::numeric + coalesce(nullif(trim("FIXBATH6"),''),'0')::numeric + coalesce(nullif(trim("FIXBATH7"),''),'0')::numeric + 0.5*coalesce(nullif(trim("FIXHALF"),''),'0')::numeric) from volusia_cama_res_bldg where "PARID"=v_altkey order by "TAXYR" desc limit 1),
      'numBuildings',COALESCE(v_prop.num_buildings::int, nullif(v_ps_nobldg,0)::int),'residentialUnits',v_prop.num_residential_units,
      'livingSqft',coalesce(
        (select nullif(trim("SFLA"),'')::numeric from volusia_cama_res_bldg where "PARID"=v_altkey order by "TAXYR" desc limit 1),
        (select nullif(trim("BUSLA"),'')::numeric from volusia_cama_comm_bldg where "PARID"=v_altkey order by "TAXYR" desc limit 1),
        v_prop.living_sqft,nullif(v_ps_totlvg,0)),
      'totalSqft',coalesce(
        (select nullif(trim("TOTAL_AREA"),'')::numeric from volusia_cama_res_bldg where "PARID"=v_altkey order by "TAXYR" desc limit 1),
        (select nullif(trim("TOTAL_AREA"),'')::numeric from volusia_cama_comm_bldg where "PARID"=v_altkey order by "TAXYR" desc limit 1),
        v_prop.total_sqft),
      'livingAreaSource',case
        when exists(select 1 from volusia_cama_res_bldg where "PARID"=v_altkey) then 'county CAMA residential record (SFLA)'
        when exists(select 1 from volusia_cama_comm_bldg where "PARID"=v_altkey) then 'county CAMA commercial building record (BUSLA)'
        else null end,
      'gisAcres',v_si.gis_acres,
      'section',v_prop.section,'township',v_prop.township,'range',v_prop.range),
    'ownerFacts', public.get_parcel_owner_facts(p_co_no, p_parcel_id),
    'plat', v_plat,
    'salesAgent', get_parcel_sales_agent(p_co_no, p_parcel_id),
    'values', jsonb_build_object(
      'valuesFacts', v_vfacts->'facts',
      'assessedYear', coalesce(v_roll_year::int, v_prop.assessed_year, (v_val->>'roll_year')::int), 'rollYear', coalesce(v_roll_year, v_val->>'roll_year')),
    'tax', jsonb_build_object('homesteadExempt',coalesce(v_prop.homestead_exempt, (v_val->>'homestead')::boolean),'homesteadExemption1',v_prop.homestead_exemption_1,
      'homesteadExemption2',v_prop.homestead_exemption_2,
      'taxableValueCounty',coalesce(v_cama_cotxbl, v_prop.taxable_value_county, (v_val->>'taxable_value_nonschool')::numeric),
      'taxableValueSchool',coalesce(v_cama_stxbl, v_prop.taxable_value_school, (v_val->>'taxable_value_school')::numeric),
      'taxAuthorityCode',v_prop.tax_authority_code),
    'amenities', COALESCE(v_amenities,'[]'::jsonb),
    'schools', COALESCE(v_schools,'[]'::jsonb),
    'schoolsCoverage', jsonb_build_object(
      'field_status', CASE WHEN COALESCE(jsonb_array_length(v_schools),0) > 0 THEN 'assigned'
                           WHEN v_cen.altkey IS NOT NULL THEN 'none_on_file'
                           ELSE 'not_available' END,
      'who_can_answer', 'the county school district'),
    'permitFacts', public.get_parcel_permit_facts(p_co_no, p_parcel_id),
    'transactionFacts', public.get_parcel_transaction_facts(p_co_no, p_parcel_id),
    'land', jsonb_strip_nulls(jsonb_build_object(
      'gopherTortoiseCoverage', CASE WHEN EXISTS (
          SELECT 1 FROM volusia_gopher_tortoise_overlay g
           JOIN fl_county_boundaries b ON b.county = (SELECT fips FROM county_registry WHERE dor_county_no = p_co_no::text)
          WHERE ST_Contains(b.geom, ST_PointOnSurface(g.geom))) THEN 'covered' ELSE 'not_available' END,
      'gopherTortoiseInside',(SELECT ST_Contains(g.geom,v_pt) FROM volusia_gopher_tortoise_overlay g WHERE ST_DWithin(g.geom::geography,v_pt::geography,8047) ORDER BY ST_Distance(g.geom::geography,v_pt::geography) LIMIT 1),
      'gopherTortoiseNearestM',(SELECT round(ST_Distance(g.geom::geography,v_pt::geography)) FROM volusia_gopher_tortoise_overlay g WHERE ST_DWithin(g.geom::geography,v_pt::geography,8047) ORDER BY ST_Distance(g.geom::geography,v_pt::geography) LIMIT 1))),
    'water', jsonb_build_object('nearestWaterM',round(v_si.nearest_water_m::numeric),'features',COALESCE(v_water,'[]'::jsonb),'boatRamps',CASE WHEN v_cen.fullpid IS NOT NULL THEN COALESCE(v_ramps,'[]'::jsonb) ELSE COALESCE(public.get_parcel_boat_ramps_resolved(p_co_no,p_parcel_id),'[]'::jsonb) END),
      'taxDeedStatus', get_parcel_tax_deed_status(p_co_no, p_parcel_id),
    'censusFacts', public.get_parcel_census_facts(p_co_no, p_parcel_id),
    'zoningFacts', public.get_parcel_zoning_facts(p_co_no, p_parcel_id),
    'economic', public.get_parcel_econzone_facts(p_co_no, p_parcel_id) || jsonb_build_object('brownfield', public.get_parcel_brownfield_facts(p_co_no, p_parcel_id))
  );
  RETURN v_out || jsonb_build_object('disclosures', public.get_parcel_disclosures(p_co_no, p_parcel_id), 'marineBlock', public.get_parcel_marine_block_by_parcel(p_co_no, p_parcel_id), 'floodBlock', public.get_parcel_flood_block(p_co_no, p_parcel_id) || jsonb_build_object('areaRepetitiveLoss',
       (SELECT CASE WHEN count(*)=0
          THEN jsonb_build_object('field_status','not_available','coverage_caveat','No FEMA repetitive-loss records are held for this county.')
          ELSE jsonb_build_object('field_status','present','properties',count(*),'totalLosses',sum(totallosses),'note','County-level FEMA NFIP repetitive-loss totals for this county — area context, not a claim about this parcel.') END
        FROM fema_nfip_multiple_loss_fl nfip
        WHERE upper(regexp_replace(nfip.county,'\s+COUNTY$','','i')) = upper((SELECT cr.county_name FROM county_registry cr WHERE cr.dor_county_no = p_co_no::text)))), 'sinkholeFacts', public.get_parcel_sinkhole_facts(p_co_no, p_parcel_id), 'landRestrictions', public.get_parcel_restrictions(p_co_no, p_parcel_id), 'identityFrame', public.get_parcel_identity_frame(p_co_no, p_parcel_id), 'wetland', public.get_parcel_wetland(p_co_no, p_parcel_id), 'reposeWindow', public.get_parcel_repose_window(p_co_no, p_parcel_id), 'groundElevation', public.get_ground_elevation_fact(p_co_no, p_parcel_id, (v_out->'land'->>'elevationFt')::numeric), 'contaminationFacilities', public.get_parcel_contamination_facilities(p_co_no, p_parcel_id));
END;
$function$;