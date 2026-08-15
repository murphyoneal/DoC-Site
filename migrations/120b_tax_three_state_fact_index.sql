-- =============================================================================
-- Ruling 231/233 Stage B, block 1 of 8 — TAX three-state fact index. Applied to production.
--
-- The exposure (ruling 231): a value that cannot be distinguished from its absence. The tax block
-- rendered taxableValueCounty:0 and homesteadExempt:false as bare values. Zero is not no-tax: 22,846
-- Volusia parcels (7.3%) carry taxable_value_county=0 against a positive assessed value that the
-- exemptions we hold (homestead only) do not cover - indistinguishable from a roll sentinel.
--
-- Design (approved ruling 233): each figure is a three-state fact. The wiring is ADDITIVE (coupled-deploy
-- rule): the existing scalar fields stay scalars for the current FE - but a bare $0 sentinel now resolves
-- to NULL, not 0 - and a companion `facts` object carries per-field field_status / source / as_of that the
-- Stage C rebuild consumes. Nothing in the payload changes shape; only the sentinel-0 becomes null.
-- =============================================================================

-- one taxable-value figure -> a three-state fact. The $0 is the crux:
--   present  : positive value, OR a $0 explained by exemptions >= assessed value (fully exempt)
--   not_recorded : null (no taxable value on any roll we hold)
--   value_withheld : $0 against a positive assessed value with no covering exemption we hold (sentinel-safe)
CREATE OR REPLACE FUNCTION public._taxable_fact(p_txbl numeric, p_jv numeric, p_exempt numeric, p_roll text, p_source text, p_tier text)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN p_txbl IS NULL THEN jsonb_build_object('field_status','not_recorded','value',null,'unit','usd')
    WHEN p_txbl > 0 THEN jsonb_build_object('field_status','present','value',p_txbl,'unit','usd','source',p_source,'source_tier',p_tier,'as_of',p_roll)
    WHEN coalesce(p_jv,0) = 0 THEN jsonb_build_object('field_status','present','value',0,'unit','usd','source',p_source,'source_tier',p_tier,'as_of',p_roll,'note','Both assessed and taxable value are $0 on the roll for this parcel.')
    WHEN p_jv > 0 AND coalesce(p_exempt,0) >= p_jv THEN jsonb_build_object('field_status','present','value',0,'unit','usd','source',p_source,'source_tier',p_tier,'as_of',p_roll,'note','$0 taxable — exemptions on record cover the full assessed value (fully exempt).')
    ELSE jsonb_build_object('field_status','value_withheld','value',null,'unit','usd','assessed_value',p_jv,'coverage_note',
      'The roll records $0 taxable against a $'||to_char(p_jv,'FM999,999,999,999')||' assessed value, but the exemptions we hold (homestead only) do not account for it. A non-homestead exemption (institutional, agricultural, disabled-veteran, senior) or a roll sentinel cannot be distinguished here, so a $0 is NOT rendered as a confirmed tax figure. The county tax collector can confirm.')
  END
$$;

-- the tax block: backward-compatible scalars + a companion `facts` fact index.
CREATE OR REPLACE FUNCTION public._tax_block(
  p_txbl_co numeric, p_txbl_sch numeric, p_jv numeric,
  p_hs_exempt boolean, p_hex1 numeric, p_hex2 numeric,
  p_tax_auth text, p_roll text, p_source text, p_tier text
) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  WITH f AS (SELECT
    public._taxable_fact(p_txbl_co, p_jv, coalesce(p_hex1,0)+coalesce(p_hex2,0), p_roll, p_source, p_tier) AS co,
    public._taxable_fact(p_txbl_sch, p_jv, coalesce(p_hex1,0)+coalesce(p_hex2,0), p_roll, p_source, p_tier) AS sch)
  SELECT jsonb_build_object(
    'taxableValueCounty', (f.co->>'value')::numeric,
    'taxableValueSchool', (f.sch->>'value')::numeric,
    'homesteadExempt', p_hs_exempt,
    'homesteadExemption1', p_hex1,
    'homesteadExemption2', p_hex2,
    'taxAuthorityCode', p_tax_auth,
    'facts', jsonb_build_object(
       'taxableValueCounty', f.co,
       'taxableValueSchool', f.sch,
       'homesteadExempt', CASE WHEN p_hs_exempt IS NULL
           THEN jsonb_build_object('field_status','not_available','value',null,'coverage_note','Homestead flag not held for this county; absence is not a finding of non-homestead.')
           ELSE jsonb_build_object('field_status','present','value',p_hs_exempt,'source',p_source,'source_tier',p_tier,'as_of',p_roll) END,
       'homesteadExemption1', CASE WHEN p_hex1 IS NULL THEN jsonb_build_object('field_status','not_recorded','value',null) ELSE jsonb_build_object('field_status','present','value',p_hex1,'unit','usd','as_of',p_roll) END,
       'homesteadExemption2', CASE WHEN p_hex2 IS NULL THEN jsonb_build_object('field_status','not_recorded','value',null) ELSE jsonb_build_object('field_status','present','value',p_hex2,'unit','usd','as_of',p_roll) END,
       'taxAuthorityCode', CASE WHEN p_tax_auth IS NULL THEN jsonb_build_object('field_status','not_recorded','value',null)
           ELSE jsonb_build_object('field_status','present','value',p_tax_auth,'note','A taxing-district code; the millage rate and district name are not held here — the county tax collector can provide them.') END),
    'field_status', CASE WHEN f.co->>'field_status'='not_recorded' AND f.sch->>'field_status'='not_recorded' AND p_hs_exempt IS NULL AND p_tax_auth IS NULL THEN 'not_established' ELSE 'present' END)
  FROM f
$$;

-- get_pir_report was patched in place (regexp swap of the inline 'tax' jsonb_build_object for a
-- public._tax_block(...) call, args resolved from the same v_cama_*/v_prop/v_val the block already read;
-- source/tier chosen by a CASE on which roll won). See pg_get_functiondef for the deployed body.
-- Defect tax-taxable-zero-unexplained (growth monitor) + statewide_metric tax_taxable_zero_unexplained_volusia
-- registered separately. Golden rebaselined (run 10): tax structural + 2 fragmented parcels' amenities/sinkhole.
