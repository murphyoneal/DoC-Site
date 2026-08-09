-- =============================================================================
-- WO 67 Stage 1b (ruling 70) — SERVE Putnam + Indian River, and fold Volusia into the
-- statewide table via the compatibility-view pattern (not duplicated served rows).
-- Loaded-but-not-served is the worst state; this closes it.
--
-- Escheat model (ruling 70, explicit): PUBLISHED date first (Indian River), computed only
-- as a plainly-labelled approximation at the STATUTORY sale + 3 years — NO +31-day fudge
-- factor (n=2 is not a model). The passed-but-still-listed case names all three hypotheses
-- and asserts none.
--
-- Money stays two concepts: opening_bid_usd (a FLOOR) vs estimated_purchase_price (Putnam's
-- estimate of total) — separate keys so the front-end never renders one as the other.
-- Additive payload: every key the FE already reads is preserved; new keys are optional.
-- =============================================================================

-- 1. statewide table gains Volusia's flood-enrichment columns (search_lands_available reads them)
ALTER TABLE lands_available_for_taxes ADD COLUMN IF NOT EXISTS fema_flood_zone text;
ALTER TABLE lands_available_for_taxes ADD COLUMN IF NOT EXISTS zone_subtype text;
ALTER TABLE lands_available_for_taxes ADD COLUMN IF NOT EXISTS in_special_flood_hazard_area boolean;
ALTER TABLE lands_available_for_taxes ADD COLUMN IF NOT EXISTS base_flood_elevation_ft numeric;

-- 2. migrate Volusia's 11 rows (with flood enrichment) into the statewide store
INSERT INTO lands_available_for_taxes
  (co_no, certificate_number, parcel_id, date_original_sale, date_available_public, original_opening_bid,
   fema_flood_zone, zone_subtype, in_special_flood_hazard_area, base_flood_elevation_ft,
   county_contact_name, county_contact_phone, source_url, loaded_at)
SELECT 74, certificate_number, parcel_id, date_original_sale, date_available_public, original_opening_bid,
       fema_flood_zone, zone_subtype, in_special_flood_hazard_area, base_flood_elevation_ft,
       'Volusia County Clerk — Tax Deed Dept', '(386) 736-5919', NULL, loaded_at
FROM lands_available_for_taxes_volusia
ON CONFLICT (co_no, certificate_number) DO UPDATE SET
  parcel_id=EXCLUDED.parcel_id, date_original_sale=EXCLUDED.date_original_sale,
  date_available_public=EXCLUDED.date_available_public, original_opening_bid=EXCLUDED.original_opening_bid,
  fema_flood_zone=EXCLUDED.fema_flood_zone, zone_subtype=EXCLUDED.zone_subtype,
  in_special_flood_hazard_area=EXCLUDED.in_special_flood_hazard_area, base_flood_elevation_ft=EXCLUDED.base_flood_elevation_ft,
  county_contact_name=EXCLUDED.county_contact_name, county_contact_phone=EXCLUDED.county_contact_phone,
  loaded_at=EXCLUDED.loaded_at;

-- 3. compatibility view: the old name now reads the statewide store (co_no 74). search_lands_available
--    and any other reader keep working unchanged; the physical Volusia table is gone (single store).
DROP TABLE lands_available_for_taxes_volusia;
CREATE VIEW lands_available_for_taxes_volusia AS
  SELECT id, certificate_number, parcel_id, date_original_sale, date_available_public, original_opening_bid,
         loaded_at, fema_flood_zone, zone_subtype, in_special_flood_hazard_area, base_flood_elevation_ft
  FROM lands_available_for_taxes WHERE co_no = 74;

-- 4. coverage for the two newly-served counties (Volusia already present)
INSERT INTO dataset_coverage (dataset, co_no, county_name, as_of, row_count)
VALUES ('tax_deed_lands_available', 64, 'Putnam',       DATE '2026-08-09', 36),
       ('tax_deed_lands_available', 41, 'Indian River', DATE '2026-08-09', 2)
ON CONFLICT DO NOTHING;

-- 5. Volusia's manual pull now lands in the statewide table
UPDATE data_source_registry SET table_name='lands_available_for_taxes'
 WHERE id=305 AND table_name='lands_available_for_taxes_volusia';

-- 6. the served path: read the statewide store by co_no; published escheat first; two money concepts
CREATE OR REPLACE FUNCTION public.get_parcel_tax_deed_status(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '10s'
AS $function$
DECLARE v_row record; v_asof date; v_escheat date; v_contact text; v_phone text;
BEGIN
  IF NOT has_coverage('tax_deed_lands_available', p_co_no) THEN
    RETURN jsonb_build_object(
      'field','tax_deed_status','field_status','not_available','on_lands_available_list',NULL,
      'coverage_caveat','The county Lands Available for Taxes register is not held for this county. COVERAGE GAP, not a finding: absence here does not mean the parcel is free of tax-deed exposure.',
      'source','county Lands Available for Taxes register','authority','county clerk / tax collector');
  END IF;

  SELECT max(loaded_at)::date INTO v_asof FROM lands_available_for_taxes WHERE co_no = p_co_no;

  SELECT l.certificate_number, l.original_opening_bid, l.estimated_purchase_price,
         l.date_original_sale, l.date_available_public, l.published_escheat_date,
         l.county_contact_name, l.county_contact_phone
    INTO v_row FROM lands_available_for_taxes l
   WHERE l.co_no = p_co_no AND l.parcel_id = p_parcel_id LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'field','tax_deed_status','field_status','not_on_list','on_lands_available_list',false,'as_of',v_asof,
      'coverage_caveat','This parcel does not appear on the Lands Available for Taxes register as of the snapshot date. That register lists ONLY parcels that went unsold at tax-deed auction and are now county-held. It is NOT a statement that taxes are current, that no tax certificate is outstanding, or that no tax-deed application is pending.',
      'source','lands_available_for_taxes','authority','county clerk / tax collector','resolution_level','parcel');
  END IF;

  v_escheat := (v_row.date_original_sale + interval '3 years')::date;   -- STATUTORY sale+3yr, no fudge factor
  v_contact := COALESCE(v_row.county_contact_name, 'the county clerk / tax collector');
  v_phone   := v_row.county_contact_phone;

  RETURN jsonb_build_object(
    'field','tax_deed_status','field_status','present','on_lands_available_list',true,
    -- availability: three states
    'available_for_purchase', (v_row.date_available_public IS NOT NULL AND v_row.date_available_public <= current_date),
    'availability_status', CASE
        WHEN v_row.date_available_public IS NULL THEN 'unknown'
        WHEN v_row.date_available_public <= current_date THEN 'available_now'
        ELSE 'listed_not_yet_available' END,
    'availability_note', CASE
        WHEN v_row.date_available_public IS NULL THEN 'On the register; the date it becomes available to the public is not recorded. Confirm with '||v_contact||COALESCE(' ('||v_phone||')','')||'.'
        WHEN v_row.date_available_public <= current_date THEN 'On the register and available to the public as of '||v_row.date_available_public||'. Confirm current availability and the purchase total with '||v_contact||COALESCE(' ('||v_phone||')','')||' before relying on it.'
        ELSE 'On the register but NOT yet purchasable: it becomes available to the public on '||v_row.date_available_public||', a future date. Until then it cannot be bought even though it is listed.' END,
    'certificate_number', v_row.certificate_number,
    -- money: two DISTINCT concepts, whichever the county publishes
    'opening_bid_usd', v_row.original_opening_bid,
    'opening_bid_as_of', CASE WHEN v_row.original_opening_bid IS NOT NULL THEN v_row.date_original_sale END,
    'opening_bid_is_a_floor', CASE WHEN v_row.original_opening_bid IS NOT NULL THEN
        'The dollar figure is the ORIGINAL OPENING BID as of the date of original sale — a MINIMUM, never a price, cost, or amount owed. Accrued taxes, interest, recording fees and documentary stamp tax are ADDED on top. Only '||v_contact||COALESCE(' ('||v_phone||')','')||' can quote the current purchase total.' END,
    'estimated_purchase_price', v_row.estimated_purchase_price,
    'estimated_purchase_price_is_not_final', CASE WHEN v_row.estimated_purchase_price IS NOT NULL THEN
        'The dollar figure is the county''s ESTIMATED purchase price — an estimate of the total, still not the final amount and still subject to additional taxes and fees. It is NOT an opening bid. Only '||v_contact||COALESCE(' ('||v_phone||')','')||' can quote the current purchase total.' END,
    'price_is_not_current', true,
    -- escheat: published first, computed second, never asserted
    'published_escheat_date', v_row.published_escheat_date,
    'statutory_escheat_date_computed', v_escheat,
    'escheat_source', CASE WHEN v_row.published_escheat_date IS NOT NULL THEN 'county-published (authoritative)' ELSE 'computed (approximate)' END,
    'escheat_basis', CASE WHEN v_row.published_escheat_date IS NOT NULL
        THEN 'The county PUBLISHES this escheat date; treat it as authoritative. F.S. 197.502(8) runs the clock 3 years from the day the land was offered for public sale; on the few published samples we hold, the published date and that plain computation differ — an open question we do NOT resolve here.'
        ELSE 'COMPUTED, not Clerk-confirmed: F.S. 197.502(8) escheats land 3 years after the day it was offered for public sale (= date of original sale). The county does not publish an escheat date; this is a statutory computation, never a confirmed status.' END,
    'escheat_note', CASE
        WHEN v_row.published_escheat_date IS NOT NULL THEN 'Escheat date as published by the county: '||v_row.published_escheat_date||'. Confirm with '||v_contact||COALESCE(' ('||v_phone||')','')||'.'
        WHEN v_escheat <= current_date THEN 'The computed statutory escheat date ('||v_escheat||') has already passed, yet this parcel still appears on the current register (as of '||v_asof||'). We do NOT resolve why: the statute may anchor on a different date, escheat may not be enforced in real time, or the register may be stale. We assert neither that this parcel has escheated nor that it has not — only '||v_contact||COALESCE(' ('||v_phone||')','')||' can confirm.'
        WHEN v_escheat <= current_date + 365 THEN 'The computed statutory escheat date ('||v_escheat||') falls within the next year; on or after it the county may take title under F.S. 197.502(8). This is a computation — confirm the parcel''s actual status with '||v_contact||COALESCE(' ('||v_phone||')','')||'.'
        ELSE 'Computed statutory escheat date is '||v_escheat||' (informational, F.S. 197.502(8)).' END,
    'escheat_rule','Land on the list escheats to the county three years after the day it was offered for public sale (F.S. 197.502(8)).',
    'county_contact_name', v_row.county_contact_name,
    'county_contact_phone', v_row.county_contact_phone,
    'date_original_sale', v_row.date_original_sale,
    'date_available_to_public', v_row.date_available_public,
    'as_of', v_asof,
    'meaning','This parcel went unsold at a tax-deed auction and is held by the county on the Lands Available for Taxes list. Title conveys by tax deed, which is NOT a warranty deed and is sold AS IS with no warranty as to title, liens, easements, restrictions, zoning, access, utilities, or improvements. A quiet-title action is commonly required before the title can be insured or conveyed.',
    'staleness_warning','The register changes as parcels are purchased, redeemed or escheat. Confirm current status with the county clerk; the snapshot date is given above.',
    'not_legal_advice','Informational only. Not legal, title or investment advice.',
    'source','lands_available_for_taxes','authority','county clerk / tax collector','resolution_level','parcel','relation','contains');
END $function$;