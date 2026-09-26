-- 138b — Standing guard: the register must not go stale across a renewal deadline again.
-- After 138a (register refreshed from the 7 Sep 2026 file). Applied to production 2026-09-26.

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('register-state-file-older-than-45-days',
 'The contractor register must be built from a DBPR state file retrieved in the last 45 days, and no in-file active licence may show a past expiry beyond what the file itself says',
 date '2026-09-26', 'walkthrough row 675 / 138a: 71,998 licence records showed a past expiry because the register was the 27 Jun file', 'temporal', 'blocking',
 $d$select (
    coalesce((select capture_date > now() - interval '45 days' from public.dbpr_snapshot_log where is_register_source), false)
    and (select count(*) from public.contractors
          where register_file_state = 'in_latest_file' and license_status = 'active'
            and expiry_date ~ '^\d{2}/\d{2}/\d{4}$' and to_date(expiry_date,'MM/DD/YYYY') < current_date) <= 10
  ) as ok$d$,
 'the register source row of dbpr_snapshot_log, and every in-file active licence',
 'Goes red 45 days after the register file was retrieved, before a renewal deadline can pass unseen again (DBPR construction licences renew on 31 Aug of even years). The second half allows 10: the 7 Sep 2026 file itself lists 4 active licences with a past expiry, and those are reproduced as the state published them. No register source row is red, not clean. The DBPR snapshot job has been failing since 31 Jul 2026, so nothing refreshes this automatically today.',
 'active', 'ours', 'clean',
 'Load the latest DBPR construction file as a new snapshot and refresh the register from it (138a pattern: freeze, update state-file fields, mark absences).')
on conflict (defect_id) do nothing;
