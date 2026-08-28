-- 125b — roz_account_access: fail CLOSED. NOT APPLIED. Awaiting Murphy's explicit go.
--
-- WHAT IS WRONG TODAY, measured by EXECUTING the gate on four uuids (2026-08-28):
--   roz_account_access('75c70158…')  REVOKED 11:25Z -> pro / roz_enabled true / statewide true
--   roz_account_access('59b1a71c…')  REVOKED 11:25Z -> pro / roz_enabled true / statewide true
--   roz_account_access('3691da6f…')  murphy, active -> pro / roz_enabled true / statewide true
--   roz_account_access('00000000-0000-0000-0000-000000000000')  A UUID THAT HAS NEVER EXISTED
--                                                   -> pro / roz_enabled true / statewide true
-- The control is the proof: a non-existent user is granted statewide Roz.
--
-- The deployed CTE filters status='active' AND revoked_at IS NULL AND expires_at CORRECTLY. That correct
-- filter is the mechanism: revocation EMPTIES the CTE, the only test is exists(... tier='basic'), an empty
-- CTE fails it, and control falls through to the pro branch. REVOCATION IS A PROMOTION, NOT A DOWNGRADE.
--
-- THE CHANGE IS ONE BRANCH. The test inverts from "is there an active BASIC row" (restrict) to "is there
-- an active PRO row" (grant). Everything else — no row, revoked, expired, null tier — lands on basic.
--
-- THIS REVERSES A DELIBERATE, RECORDED DECISION, not a defect. The prior body carried:
--   "ALPHA MODE: fail OPEN. Unfettered access is the instruction; the tier gate must never lock a tester
--    out. ... No row, null tier, expired, revoked -> full access."
-- The instruction changed when Murphy ordered both alpha entitlements revoked on 2026-08-28. Fail-open and
-- revocation cannot both hold. This migration is that decision written into the gate.
--
-- BLAST RADIUS, MEASURED. The ONLY consumer is app/api/roz/route.ts:344. No other route, page or database
-- function calls roz_account_access (grepped the repo; scanned every pg_proc body). PIR reports, checkout
-- and the report page do NOT gate on it, so closing this does not touch report access for anyone.
--
-- DRY RUN of this exact predicate, run against live data before writing this file:
--   murphy 3691da6f    active_tier 'pro'        -> pro / roz_enabled TRUE      (UNCHANGED — he keeps Roz)
--   revoked 75c70158   (no active row)          -> basic / roz_enabled FALSE
--   revoked 59b1a71c   (no active row)          -> basic / roz_enabled FALSE
--   control (never existed)                     -> basic / roz_enabled FALSE
-- NOTE: Murphy does NOT lose access and does not need a new entitlement — 7b01224e is an active pro row and
-- satisfies the new test directly. A briefing note today said his row would become basic; it is wrong, and
-- the dry run above is the correction.

CREATE OR REPLACE FUNCTION public.roz_account_access(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  -- FAIL CLOSED. Roz is a test vehicle (ruling 505 part 4) with web search on and its shape unsettled;
  -- access is granted by an explicit active PRO entitlement and by nothing else. No row, null tier,
  -- expired, REVOKED -> basic, no Roz. A revocation must land as a revocation.
  with e as (
    select tier from entitlement
    where user_id = p_user_id
      and status = 'active'
      and revoked_at is null
      and (expires_at is null or expires_at > now())
    order by case lower(tier) when 'pro' then 2 when 'basic' then 1 else 0 end desc
    limit 1
  )
  select case
    when exists (select 1 from e where lower(tier) = 'pro')
      then jsonb_build_object('tier','pro','roz_enabled',true,'statewide',true,
             'allowed_co_no',null,'pir_monthly_limit',null)
    else jsonb_build_object('tier','basic','roz_enabled',false,'statewide',false,
             'allowed_co_no',74,'pir_monthly_limit',30,
             'note','no active pro entitlement')
  end
$function$;

COMMENT ON FUNCTION public.roz_account_access(uuid) IS
  'Roz access gate. FAILS CLOSED: an active pro entitlement grants Roz; no row / revoked / expired / '
  'basic all return basic with roz_enabled false. Replaced the alpha fail-open body on 2026-08-28, after '
  'execution showed a never-existent uuid being granted statewide pro. Sole consumer: '
  'app/api/roz/route.ts. Does NOT gate PIR reports or checkout.';

-- ---------------------------------------------------------------------------------------------
-- NEGATIVE CONTROL — RUN BEFORE AND AFTER. This is the whole point; the artifact is not the proof.
--
--   SELECT roz_account_access('00000000-0000-0000-0000-000000000000')->>'roz_enabled' AS ctl;
--     BEFORE (measured 2026-08-28): 'true'   <- the defect
--     AFTER  (required):            'false'  <- anything else means the change did not take
--
-- THEN RE-VERIFY THE REVOCATIONS AGAINST THE GATE, NOT THE TABLE. Checking the entitlement row is what
-- reported these two as revoked while they still held statewide pro:
--   SELECT roz_account_access('75c70158-111c-48cb-805d-98e202890325')->>'roz_enabled';  -- must be 'false'
--   SELECT roz_account_access('59b1a71c-5f25-4c4c-aa85-ad35266af54d')->>'roz_enabled';  -- must be 'false'
--   SELECT roz_account_access('3691da6f-5ab4-4b80-be2d-c725a83ecc99')->>'roz_enabled';  -- must be 'true'
--
-- The last line matters as much as the others: a gate that locks everyone out is not fixed, it is broken
-- the other way, and only the positive case distinguishes them.
-- ---------------------------------------------------------------------------------------------
