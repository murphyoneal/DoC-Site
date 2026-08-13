-- =============================================================================
-- handoff 56: Santa Rosa zoning was a LIVE WRONG ANSWER, not merely unverified.
-- The code column was mapped to rezone_ (petition/case numbers, 1,076 distinct, e.g.
-- 2004-R-049 / PZ-2023-10-RSS) — a string that looks like a code, means nothing, and
-- stops a reader asking. The real zoning district is in column `district` (66 codes:
-- R3, AG-RR, AG1...). Remap the code column; mark verified.
-- Proof: parcel 14-1N-29-0075-00G00-0040 served zoning "2004-R-049" before, "R3" after.
-- Own commit so the record is unambiguous (a wrong value corrected, not just a remap).
-- =============================================================================
UPDATE layer_column_map
   SET column_name='district',
       note='remapped from rezone_ (petition numbers) to district (real zoning codes) — handoff 56',
       verified_at=now()
 WHERE table_name='santarosa_zoning' AND col_role='code';

UPDATE layer_resolution
   SET verified=true, verified_at=now(),
       selected_by='content-verified 2026-08-09 (handoff 53/56): interior-point 0.996 + code remapped to district'
 WHERE table_name='santarosa_zoning';
