-- 164a - standing check for the 7 field-shifted register rows (row 801 item 2). Detection only; no row touched.
-- Applied 2026-09-30. Red by design until the 7 are re-derived from dbpr_construction_snapshot 3 (ruling pending).
insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('register-row-field-shifted',
  'A served contractor licence row is shifted one field left (licence number = county code, name split, city in state)',
  'key_integrity', 'blocking',
  $d$select (count(*) = 0) as ok from contractors where zip_code = 'FL' or state ~ ' '$d$,
  'Found 2026-09-30 (rows 801/802): 7 rows from the 27 Jun 2026 register build carry license_number "74" (Volusia county code), full_name split into business_name=SURNAME / trading_name=FIRST, city in state, "FL" in zip_code. The loader that built June is not in the repo or WSL and the June file was never archived row-by-row, so the parse cause is NOT established. The current path (dbpr_construction_snapshot 3, csv module) parses all 7 correctly and has 0 shifted rows of 258,061. Because license_number was "74", 138a never matched them to the Sep file, so they serve as absent_from_latest_file although all 7 are active in it. Signature measured exact: zip_code=''FL'' or a space in state = 7 rows, 0 false positives. Red until the 7 are re-derived from snapshot 3 through the refresh path (ruling pending). Keep the evidence for the 792 standardisation page.');
do $$ declare ok boolean; begin
  execute (select detection_sql from data_defect_registry where defect_id='register-row-field-shifted') into ok;
  if ok is not false then raise exception '164a: detection should be red today (7 rows)'; end if;
end $$;
