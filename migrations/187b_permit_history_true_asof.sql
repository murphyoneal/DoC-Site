-- 187b - property_permit_history's as-of is the source export it was built from, not its creation time (ruling 898 D4).
-- Every row carries source_import_id = 'VCPA_CAMA_2026_06_21' (983,991 of 983,991, measured 2026-10-01): it was built from
-- the 2026-06-21 Volusia CAMA export, which predates volusia_cama_snapshot_log. 186a recorded 2026-06-28 from created_at;
-- the source date is the stronger evidence and is a week earlier, so permits dated 2026-06-22..28 are also beyond the
-- derived table's reach. Correcting it widens the roof gate (186a) and the detection (187a) to the true boundary:
-- measured after: 8,486 missing permits, 7,379 parcels gated, 1,472 missing a roofing permit (was 7,524 / 6,587 / 1,303).
update public.derived_table_asof
   set source_as_of = date '2026-06-21',
       basis = 'source_import_id = VCPA_CAMA_2026_06_21 on all 983,991 rows (measured 2026-10-01): built from the 2026-06-21 Volusia CAMA export; rows created 2026-06-28 17:27-18:31 UTC. Builder not recovered: no script on record inserts into this table (only later correction scripts update it). 187b corrected the as-of from 2026-06-28.',
       recorded_at = now()
 where table_name = 'property_permit_history';

select public._log_action('cc', 'correct_derived_asof', 'derived_table_asof', array['property_permit_history'],
  jsonb_build_object('source_as_of', '2026-06-28', 'basis', 'created_at'),
  jsonb_build_object('source_as_of', '2026-06-21', 'basis', 'source_import_id VCPA_CAMA_2026_06_21'),
  'Ruling 898 D4: the derived permit history names its own source export (2026-06-21); 186a had used its creation time. Earlier boundary, stronger evidence.', null);

do $$
begin
  if (get_parcel_roof_lifespan(74, '701710160110'))->0->>'field_status' is distinct from 'not_available' then raise exception '187b: gate lost'; end if;
end $$;
