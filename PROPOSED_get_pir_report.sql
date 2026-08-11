-- =============================================================================
-- get_pir_report(p_co_no, p_parcel_id)  →  jsonb   (SECURITY DEFINER)
--
-- Single server-side assembler for the Property Intelligence Report (PIR).
-- Only data confirmed real for the parcel; absent data is null/[] and the front
-- end renders honest "not on file" states rather than fabricating.
-- Keyed on the DOR/state parcel id. Spatial overlays are the Volusia layers.
-- =============================================================================
CREATE OR REPLACE FUNCTION get_pir_report(p_co_no numeric, p_parcel_id text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout = '25s'
AS $$
DECLARE
  v_prop   properties%ROWTYPE;
  v_cen    RECORD;
  v_si     RECORD;
  v_env    RECORD;
  v_haz    RECORD;
  v_pt     geometry(Point, 4326);
  v_pgeom  geometry;
  v_out    jsonb;
  v_amenities jsonb;
  v_permits   jsonb;
  v_permit_count int;
  v_txns      jsonb;
  v_txn_count int;
  v_water     jsonb;
  v_ramps     jsonb;
  v_schools   jsonb;
BEGIN
  SELECT * INTO v_prop FROM properties
    WHERE dor_parcel_id = p_parcel_id
    ORDER BY updated_at DESC NULLS LAST LIMIT 1;

  SELECT c.*, ST_X(c.geom) AS lng, ST_Y(c.geom) AS lat
    INTO v_cen FROM volusia_parcel_centroids c WHERE c.fullpid = p_parcel_id LIMIT 1;

  SELECT * INTO v_si FROM get_site_intelligence(p_co_no, p_parcel_id) LIMIT 1;

  SELECT geom INTO v_pgeom FROM parcels_staging
    WHERE co_no = p_co_no AND parcel_id = p_parcel_id LIMIT 1;
  v_pt := COALESCE(v_cen.geom, ST_PointOnSurface(v_pgeom));

  SELECT * INTO v_env FROM property_environmental WHERE property_id = v_prop.id LIMIT 1;
  SELECT * INTO v_haz FROM property_hazard_risk    WHERE property_id = v_prop.id LIMIT 1;

  -- amenities (coverage-aware RPC); the generic 'school' row is dropped here
  -- because assigned elementary/middle/high schools are returned separately below.
  SELECT jsonb_agg(jsonb_build_object(
           'amenityType', a.amenity_type, 'displayName', a.display_name,
           'iconName', a.icon_name, 'category', a.category, 'name', a.name,
           'distanceM', round(a.distance_m::numeric,1), 'bearingDegrees', round(a.bearing_degrees::numeric,1))
           ORDER BY a.sort_order)
    INTO v_amenities
    FROM get_nearby_amenities(p_co_no, p_parcel_id) a
   WHERE a.amenity_type <> 'school';

  -- assigned school zones (elementary / middle / high) — one badge each. The
  -- assignment table gives the zoned school NAME; volusia_schools supplies the
  -- point for distance + bearing (matched on the significant name + level word).
  SELECT jsonb_agg(jsonb_build_object(
           'level', lvl, 'name', COALESCE(sc.name, nm),
           'distanceM', CASE WHEN sc.geom IS NOT NULL THEN round(ST_Distance(sc.geom::geography, v_pt::geography)) END,
           'bearingDegrees', CASE WHEN sc.geom IS NOT NULL THEN round(degrees(ST_Azimuth(v_pt, sc.geom))::numeric,1) END)
           ORDER BY ord)
    INTO v_schools
    FROM (
      SELECT 1 AS ord, 'Elementary' AS lvl, a.elementary_school AS nm, 'ELEM'   AS kw FROM volusia_parcel_school_assignment a WHERE a.altkey = v_cen.altkey::text
      UNION ALL
      SELECT 2, 'Middle', a.middle_school_name, 'MIDDLE' FROM volusia_parcel_school_assignment a WHERE a.altkey = v_cen.altkey::text
      UNION ALL
      SELECT 3, 'High',   a.high_school_name,   'HIGH'   FROM volusia_parcel_school_assignment a WHERE a.altkey = v_cen.altkey::text
    ) t
    LEFT JOIN LATERAL (
      SELECT s.name, s.geom FROM volusia_schools s
       WHERE s.name ILIKE '%' || regexp_replace(t.nm, '\s*(Elementary|Elem|Middle School|Middle|High School|High|School)\s*$', '', 'i') || '%'
         AND s.name ILIKE '%' || t.kw || '%'
       ORDER BY ST_Distance(s.geom::geography, v_pt::geography) LIMIT 1
    ) sc ON true
   WHERE t.nm IS NOT NULL AND trim(t.nm) <> '';

  SELECT jsonb_agg(jsonb_build_object(
           'permitNumber', permit_number, 'permitDate', permit_date,
           'completionDate', completion_date, 'occCertDate', occ_cert_date,
           'status', permit_status, 'permitType', permit_type,
           'workDescription', work_description, 'contractorName', contractor_name,
           'jobValue', job_value, 'tradeCategory', trade_category)
           ORDER BY permit_date), count(*)
    INTO v_permits, v_permit_count
    FROM property_permit_history WHERE property_id = v_prop.id;

  WITH t AS (
    SELECT recording_date AS rec_date, sale_date, sale_price, instrument_type,
           grantor_name, grantee_name, qualified_sale, doc_stamp_amount,
           recording_book, recording_page
      FROM property_transaction_history WHERE property_id = v_prop.id
    UNION ALL
    SELECT v_cen.lastsaledate::date, v_cen.lastsaledate::date, v_cen.last_sale_price,
           NULL, NULL, NULL, NULL, NULL, NULL, NULL
      WHERE v_cen.last_sale_price IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM property_transaction_history WHERE property_id = v_prop.id)
  )
  SELECT jsonb_agg(jsonb_build_object(
           'recordingDate', rec_date, 'saleDate', sale_date, 'salePrice', sale_price,
           'instrumentType', instrument_type, 'grantor', grantor_name, 'grantee', grantee_name,
           'qualifiedSale', qualified_sale, 'docStampAmount', doc_stamp_amount,
           'book', recording_book, 'page', recording_page)
           ORDER BY COALESCE(rec_date, sale_date)), count(*)
    INTO v_txns, v_txn_count FROM t;

  SELECT jsonb_agg(x ORDER BY (x->>'distanceM')::numeric) INTO v_water FROM (
    SELECT jsonb_build_object(
             'name', NULLIF(trim(w.gnis_name),''), 'ftype', w.ftype,
             'distanceM', round(ST_Distance(w.geom::geography, v_pt::geography)),
             'bearingDegrees', round(degrees(ST_Azimuth(v_pt, ST_ClosestPoint(w.geom, v_pt)))::numeric,1)) AS x
      FROM hydrology_waterbodies w
     WHERE ST_DWithin(w.geom::geography, v_pt::geography, 3000)
     ORDER BY ST_Distance(w.geom::geography, v_pt::geography) LIMIT 5
  ) q;

  SELECT jsonb_agg(x ORDER BY (x->>'distanceM')::numeric) INTO v_ramps FROM (
    SELECT jsonb_build_object(
             'name', r.rampname, 'waterbody', r.waterbody,
             'distanceM', round(ST_Distance(r.geom::geography, v_pt::geography)),
             'bearingDegrees', round(degrees(ST_Azimuth(v_pt, r.geom))::numeric,1)) AS x
      FROM volusia_boat_ramps r
     WHERE ST_DWithin(r.geom::geography, v_pt::geography, 8000)
     ORDER BY ST_Distance(r.geom::geography, v_pt::geography) LIMIT 4
  ) q;

  v_out := jsonb_build_object(
    'meta', jsonb_build_object(
      'coNo', p_co_no, 'parcelId', p_parcel_id, 'stateParcelId', v_prop.state_parcel_id,
      'countyName', COALESCE(v_prop.county_name, v_si.county_name),
      'lat', v_cen.lat, 'lng', v_cen.lng, 'generatedAt', now(),
      'dataQualityScore', v_prop.data_quality_score, 'source', v_prop.source_import_id),
    'property', jsonb_build_object(
      'address', COALESCE(v_prop.address_line_1, v_si.phy_addr1), 'city', COALESCE(v_prop.city, v_si.phy_city),
      'zip', v_prop.zip_code, 'jurisdiction', v_cen.jurisdiction, 'incorporation', v_cen.statusincorporated,
      'ownerName', COALESCE(v_prop.owner_name, v_si.owner_name), 'ownerOccupied', v_prop.homestead_exempt,
      'ownerMailAddr', v_prop.owner_mail_addr, 'ownerMailCity', v_prop.owner_mail_city,
      'subdivision', v_cen.subdivision, 'neighborhood', v_cen.nbhd_desc, 'legal', v_cen.legal1,
      'propertyType', v_prop.property_type, 'landUseCode', COALESCE(v_prop.land_use_code, v_si.land_use_code),
      'yearBuilt', v_prop.build_year, 'effectiveYearBuilt', v_prop.effective_year_built,
      'stories', v_prop.stories, 'bedrooms', v_prop.bedrooms, 'bathrooms', v_prop.bathrooms,
      'numBuildings', v_prop.num_buildings, 'residentialUnits', v_prop.num_residential_units,
      'livingSqft', v_prop.living_sqft, 'totalSqft', v_prop.total_sqft, 'gisAcres', v_si.gis_acres,
      'section', v_prop.section, 'township', v_prop.township, 'range', v_prop.range),
    'values', jsonb_build_object(
      'justValue', v_prop.just_value, 'assessedValue', v_prop.assessed_value, 'assessedYear', v_prop.assessed_year,
      'landValue', v_prop.land_value, 'specialFeatureValue', v_prop.special_feature_value,
      'improvementValue', COALESCE(v_prop.just_value,0) - COALESCE(v_prop.land_value,0) - COALESCE(v_prop.special_feature_value,0)),
    'tax', jsonb_build_object(
      'homesteadExempt', v_prop.homestead_exempt, 'homesteadExemption1', v_prop.homestead_exemption_1,
      'homesteadExemption2', v_prop.homestead_exemption_2, 'taxableValueCounty', v_prop.taxable_value_county,
      'taxableValueSchool', v_prop.taxable_value_school, 'taxAuthorityCode', v_prop.tax_authority_code),
    'amenities', COALESCE(v_amenities, '[]'::jsonb),
    'schools', COALESCE(v_schools, '[]'::jsonb),
    'permits', jsonb_build_object('count', v_permit_count, 'items', COALESCE(v_permits, '[]'::jsonb)),
    'transactions', jsonb_build_object('count', v_txn_count, 'items', COALESCE(v_txns, '[]'::jsonb)),
    'air', jsonb_strip_nulls(jsonb_build_object(
      'aqiAnnualAvg', v_env.aqi_annual_avg, 'pm25', v_env.pm25_annual_avg, 'pm10', v_env.pm10_annual_avg,
      'ozone', v_env.ozone_annual_avg, 'wildfireSmokeDays', v_env.wildfire_smoke_days,
      'noiseDbDay', v_env.noise_db_day, 'lightPollutionIndex', v_env.light_pollution_index)),
    'wind', jsonb_strip_nulls(jsonb_build_object(
      'prevailingDirection', v_haz.wind_direction_prevailing, 'avgSpeedMph', v_haz.wind_speed_avg_mph,
      'maxGustMph', v_haz.wind_gust_max_mph, 'designSpeedMph', v_haz.fl_wind_design_speed_mph, 'windSpeedZone', v_haz.fl_wind_speed_zone)),
    'land', jsonb_strip_nulls(jsonb_build_object(
      'elevationM', v_si.elevation_m, 'elevationFt', round((v_si.elevation_m * 3.28084)::numeric,1),
      'radonZone', v_env.radon_zone, 'sinkholeRisk', v_env.sinkhole_risk, 'sinkholeHistoryCount', v_env.sinkhole_history_count,
      'waterSourceType', v_env.water_source_type, 'waterUtility', v_env.water_utility,
      'leadServiceLineRisk', v_env.lead_service_line_risk, 'algaeBloomRisk', v_env.algae_bloom_risk,
      'gopherTortoiseInside', (SELECT ST_Contains(g.geom, v_pt) FROM volusia_gopher_tortoise_overlay g
                                WHERE ST_DWithin(g.geom::geography, v_pt::geography, 8047)
                                ORDER BY ST_Distance(g.geom::geography, v_pt::geography) LIMIT 1),
      'gopherTortoiseNearestM', (SELECT round(ST_Distance(g.geom::geography, v_pt::geography))
                                FROM volusia_gopher_tortoise_overlay g
                                WHERE ST_DWithin(g.geom::geography, v_pt::geography, 8047)
                                ORDER BY ST_Distance(g.geom::geography, v_pt::geography) LIMIT 1))),
    'water', jsonb_build_object('nearestWaterM', round(v_si.nearest_water_m::numeric),
      'features', COALESCE(v_water, '[]'::jsonb), 'boatRamps', COALESCE(v_ramps, '[]'::jsonb)),
    'flood', jsonb_build_object('zone', v_si.flood_zone, 'available', v_si.flood_zone_available,
      'inHazardArea', v_si.in_flood_hazard_area, 'countyZone', v_haz.fema_flood_zone,
      'stormSurgeZone', v_haz.storm_surge_zone, 'floodEvents10yr', v_haz.flood_events_10yr,
      'areaRepetitiveLoss', (SELECT jsonb_build_object('properties', count(*), 'totalLosses', sum(totallosses))
        FROM fema_nfip_multiple_loss_fl WHERE county ILIKE '%volusia%')),
    'climate', jsonb_strip_nulls(jsonb_build_object(
      'precipAnnualIn', v_haz.precip_annual_avg_in, 'precipMax24hrIn', v_haz.precip_max_24hr_in,
      'tempAnnualF', v_haz.temp_annual_avg_f, 'tempMaxRecordF', v_haz.temp_max_record_f,
      'tempMinRecordF', v_haz.temp_min_record_f, 'humidityPct', v_haz.humidity_annual_avg_pct,
      'solarKwhM2Day', v_haz.solar_irradiance_kwh_m2_day, 'solarPeakHours', v_haz.solar_peak_hours_daily,
      'solarPotentialKwhYr', v_haz.solar_potential_kwh_yr, 'lightningDensity', v_haz.lightning_density_km2_yr,
      'hurricaneDirectHits', v_haz.hurricane_direct_hits, 'lastHurricaneCategory', v_haz.last_hurricane_category,
      'tornadoEvents10yr', v_haz.tornado_events_10yr, 'hailEvents10yr', v_haz.hail_events_10yr,
      'wildfireRiskClass', v_haz.wildfire_risk_class, 'extremeHeatDaysAnnual', v_haz.extreme_heat_days_annual)),
    'census', jsonb_build_object('blockGroup', COALESCE(v_prop.census_block_group, v_si.census_block_group),
      'population', v_si.area_population, 'medianHouseholdIncome', v_si.area_median_income, 'housingUnits', v_si.area_housing_units),
    'zoning', jsonb_strip_nulls(jsonb_build_object(
      'zoneCode', (SELECT zoncode FROM volusia_zoning z WHERE ST_Contains(z.geom, v_pt) LIMIT 1),
      'pudName',  (SELECT pud_name FROM volusia_zoning z WHERE ST_Contains(z.geom, v_pt) LIMIT 1),
      'futureLandUseCode', (SELECT luname FROM volusia_future_land_use f WHERE ST_Contains(f.geom, v_pt) LIMIT 1),
      'futureLandUseName', (SELECT lucode FROM volusia_future_land_use f WHERE ST_Contains(f.geom, v_pt) LIMIT 1))),
    'economic', jsonb_build_object(
      'opportunityZone', (SELECT jsonb_build_object('inside', ST_Contains(o.geom, v_pt), 'distanceM', round(ST_Distance(o.geom::geography, v_pt::geography)), 'tract', o.tractce10)
        FROM volusia_opportunity_zones o WHERE ST_DWithin(o.geom::geography, v_pt::geography, 8047) ORDER BY ST_Distance(o.geom::geography, v_pt::geography) LIMIT 1),
      'hubZone', (SELECT jsonb_build_object('inside', ST_Contains(h.geom, v_pt), 'distanceM', round(ST_Distance(h.geom::geography, v_pt::geography)), 'tract', h.censustract)
        FROM volusia_hub_zones_2023 h WHERE ST_DWithin(h.geom::geography, v_pt::geography, 8047) ORDER BY ST_Distance(h.geom::geography, v_pt::geography) LIMIT 1),
      'cra', (SELECT jsonb_build_object('inside', ST_Contains(c.geom, v_pt), 'distanceM', round(ST_Distance(c.geom::geography, v_pt::geography)), 'name', c.cra_name)
        FROM volusia_community_redevelopment_areas c WHERE ST_DWithin(c.geom::geography, v_pt::geography, 8047) ORDER BY ST_Distance(c.geom::geography, v_pt::geography) LIMIT 1),
      'enterpriseZone', (SELECT jsonb_build_object('inside', ST_Contains(e.geom, v_pt), 'distanceM', round(ST_Distance(e.geom::geography, v_pt::geography)), 'zone', e.zoneid)
        FROM volusia_enterprise_zones e WHERE ST_DWithin(e.geom::geography, v_pt::geography, 8047) ORDER BY ST_Distance(e.geom::geography, v_pt::geography) LIMIT 1),
      'brownfield', (SELECT jsonb_build_object('inside', ST_Contains(b.geom, v_pt), 'distanceM', round(ST_Distance(b.geom::geography, v_pt::geography)), 'name', b.area_name)
        FROM volusia_brownfield_areas b WHERE ST_DWithin(b.geom::geography, v_pt::geography, 8047) ORDER BY ST_Distance(b.geom::geography, v_pt::geography) LIMIT 1)),
    'environmentSources', v_env.source_attribution,
    'climateSources', v_haz.source_attribution
  );
  RETURN v_out;
END;
$$;

GRANT EXECUTE ON FUNCTION get_pir_report(numeric, text) TO anon, authenticated, service_role;
