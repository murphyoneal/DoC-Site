-- =============================================================================
-- work order 66 — three semantic traps in the served tax-deed path.
-- get_parcel_tax_deed_status previously (a) collapsed "on the register" into one
-- state, hiding that a listed parcel may not yet be purchasable, and (b) ASSERTED
-- an escheat verdict ("likely no longer purchasable") from a naive date computation.
--
-- Trap 1  AVAILABILITY IS THREE STATES, not two. A parcel can be on the register
--         but not yet available to the public (a future date_available_public).
--         Cert 1587-19 becomes available 2026-10-22 — listing it as purchasable
--         today would be false. Split the present branch: available_now vs
--         listed_not_yet_available. (not-on-register / no-coverage already existed.)
--
-- Trap 2  OPENING BID IS NOT A PRICE. Already caveated; tightened to name it the
--         ORIGINAL OPENING BID as of the date of original sale, Clerk as who-answers.
--
-- Trap 3  ESCHEAT IS A COMPUTED CLAIM, NOT A STATUS. F.S. 197.502(8): land escheats
--         3 years after the day it was offered for public sale. But cert 9219-20
--         (sold 2023-04-18, computed escheat 2026-04-18) is STILL on today's register
--         four months later — the register is ground truth that the statutory date is
--         not administratively enforced in real time. So we present the computed date
--         labelled as computed, and REFUSE to assert the parcel has or has not
--         escheated. Only the Clerk can confirm. This kills the old false assertion.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_parcel_tax_deed_status(p_co_no numeric, p_parcel_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '10s'
AS $function$
DECLARE v_row record; v_asof date; v_escheat date;
BEGIN
  IF NOT has_coverage('tax_deed_lands_available', p_co_no) THEN
    RETURN jsonb_build_object(
      'field','tax_deed_status','field_status','not_available','on_lands_available_list',NULL,
      'coverage_caveat','The county Lands Available for Taxes register is not held for this county. COVERAGE GAP, not a finding: absence here does not mean the parcel is free of tax-deed exposure.',
      'source','county Lands Available for Taxes register','authority','county clerk / tax collector');
  END IF;

  SELECT max(loaded_at)::date INTO v_asof FROM lands_available_for_taxes_volusia;

  SELECT l.certificate_number, l.original_opening_bid, l.date_original_sale, l.date_available_public
    INTO v_row FROM lands_available_for_taxes_volusia l WHERE l.parcel_id = p_parcel_id LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'field','tax_deed_status','field_status','not_on_list','on_lands_available_list',false,'as_of',v_asof,
      'coverage_caveat','This parcel does not appear on the Lands Available for Taxes register as of the snapshot date. That register lists ONLY parcels that went unsold at tax-deed auction and are now county-held. It is NOT a statement that taxes are current, that no tax certificate is outstanding, or that no tax-deed application is pending.',
      'source','lands_available_for_taxes_volusia','authority','county clerk / tax collector','resolution_level','parcel');
  END IF;

  v_escheat := (v_row.date_original_sale + interval '3 years')::date;

  RETURN jsonb_build_object(
    'field','tax_deed_status','field_status','present','on_lands_available_list',true,
    -- Trap 1: availability is its own three-state axis, distinct from "on the list"
    'available_for_purchase', (v_row.date_available_public IS NOT NULL AND v_row.date_available_public <= current_date),
    'availability_status', CASE
        WHEN v_row.date_available_public IS NULL THEN 'unknown'
        WHEN v_row.date_available_public <= current_date THEN 'available_now'
        ELSE 'listed_not_yet_available' END,
    'availability_note', CASE
        WHEN v_row.date_available_public IS NULL THEN 'On the register; the date it becomes available to the public is not recorded. Confirm with the Clerk.'
        WHEN v_row.date_available_public <= current_date THEN 'On the register and available to the public as of '||v_row.date_available_public||'. Confirm current availability and the purchase total with the Clerk before relying on it.'
        ELSE 'On the register but NOT yet purchasable: it becomes available to the public on '||v_row.date_available_public||', a future date. Until then it cannot be bought even though it is listed.' END,
    'certificate_number', v_row.certificate_number,
    -- Trap 2: opening bid is a floor as of the sale date, never a price
    'opening_bid_usd', v_row.original_opening_bid,
    'opening_bid_as_of', v_row.date_original_sale,
    'opening_bid_is_a_floor','The dollar figure is the ORIGINAL OPENING BID as of the date of original sale — a MINIMUM, never a price, cost, or amount owed. Under F.S. 197.502 accrued taxes, interest, recording fees and documentary stamp tax are ADDED on top. Only the Clerk can quote the current purchase total — Volusia Tax Deed Dept (386) 736-5919.',
    'date_original_sale', v_row.date_original_sale,
    'date_available_to_public', v_row.date_available_public,
    -- Trap 3: escheat is COMPUTED, not asserted. The register overrides the computation.
    'statutory_escheat_date_computed', v_escheat,
    'escheat_basis','COMPUTED, not Clerk-confirmed. F.S. 197.502(8): land on this list escheats to the county three years after the day it was offered for public sale. This date = date of original sale + 3 years. It is a statutory computation, not a confirmed status.',
    'escheat_note', CASE
        WHEN v_escheat <= current_date THEN 'The computed statutory escheat date ('||v_escheat||') has already passed, YET this parcel still appears on the current register (as of '||v_asof||'). Escheat is administrative and the register can lag the statute; we do NOT assert this parcel has escheated, nor that it has not. Only the Clerk can confirm — Volusia Tax Deed Dept (386) 736-5919.'
        WHEN v_escheat <= current_date + 365 THEN 'The computed statutory escheat date ('||v_escheat||') falls within the next year; on or after it the county may take title under F.S. 197.502(8). This is a computation — confirm the parcel''s actual status with the Clerk.'
        ELSE 'Computed statutory escheat date is '||v_escheat||' (informational, F.S. 197.502(8)).' END,
    'escheat_rule','Land on the list escheats to the county three years after the day it was offered for public sale (F.S. 197.502(8)).',
    'as_of', v_asof,
    'meaning','This parcel went unsold at a tax-deed auction and is held by the county on the Lands Available for Taxes list. Title conveys by tax deed, which is NOT a warranty deed and is sold AS IS with no warranty as to title, liens, easements, restrictions, zoning, access, utilities, or improvements. A quiet-title action is commonly required before the title can be insured or conveyed.',
    'staleness_warning','The register changes as parcels are purchased, redeemed or escheat. Confirm current status with the county clerk; the snapshot date is given above.',
    'not_legal_advice','Informational only. Not legal, title or investment advice.',
    'source','lands_available_for_taxes_volusia','authority','county clerk / tax collector','resolution_level','parcel','relation','contains');
END $function$;
