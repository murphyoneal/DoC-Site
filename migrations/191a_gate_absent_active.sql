-- 191a - no licence absent from the latest state file is served as "active", on any surface (rulings 856, 905, 907).
--
-- LIVE FALSE STATEMENT reported 2026-09-30 (bus 856), verified, and left unactioned: contractors.license_status - OUR
-- derivation (138a), not a published fact - read 'active' on 17,981 rows whose register_file_state is
-- absent_from_latest_file: 16,819 with secondary_status 'A' from an older file, 1,162 with no secondary status at all.
-- Served by contractor_register_search (public, anon), search_contractors (Roz), get_business_licences, contractors_public,
-- verify_contractor_license and every app page reading the column.
--
-- Fixing the derivation at its source fixes every surface at once. Consumers checked 2026-10-01: the app branches only on
-- 'active' and renders any other value through statusLabel() ('not_in_latest_file' -> "Not in latest file") or
-- StatusBadge ('Unknown'); the profile page already reads register_file_state and says "Not in the latest state file";
-- the static public register pages do not render license_status at all. No consumer asserts anything from a new value.
--   absent + secondary present  -> 'not_in_latest_file'   (names its cause)
--   absent + no secondary       -> 'not_stated'           (ruling 907: never active)
-- The CHECK makes recurrence impossible: a loader that writes 'active' onto an absent row now fails loudly.
-- Phase 2 (status as published + file date + board link, old field removed) follows per 907.

update public.contractors set license_status = 'not_in_latest_file'
 where register_file_state = 'absent_from_latest_file' and license_status = 'active' and secondary_status is not null;
update public.contractors set license_status = 'not_stated'
 where register_file_state = 'absent_from_latest_file' and license_status = 'active' and secondary_status is null;

alter table public.contractors add constraint contractors_absent_never_active
  check (not (register_file_state = 'absent_from_latest_file' and license_status = 'active'));
comment on constraint contractors_absent_never_active on public.contractors is
 '191a (ruling 907). A licence absent from the latest DBPR file is never served as active. 138a marked absent rows without re-deriving license_status, leaving 17,981 reading active from the June file. Any future register refresh that sets register_file_state = absent_from_latest_file must set license_status in the SAME statement (not_in_latest_file, or not_stated when secondary_status is null) or this constraint fails it - by design.';
-- (comment applied in a follow-up statement the same session; derived copies rebuilt after apply:
--  rebuild_contractor_name_index() -> 0 stale of 115,210; refresh_permit_contractor_match() run in WSL)

-- the enforcement 907 asked for: a verified live false statement may not sit unactioned past 24 hours
insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('live-false-statement-finding-unactioned',
  'A bus finding tagged LIVE_FALSE_STATEMENT (a verified false statement on a served surface) has actioned_at NULL more than 24 hours after it was written',
  'completeness', 'blocking',
  $q$select not exists (select 1 from public.agent_handoff
                        where refs ilike '%LIVE_FALSE_STATEMENT%' and actioned_at is null
                          and created_at < now() - interval '24 hours') as ok$q$,
  'Ruling 907: "a verified false statement on a public surface is not a queue item; it is gated or fixed the day it is verified." Convention (191a): any finding reporting a verified live false statement carries LIVE_FALSE_STATEMENT in refs; the row that gates or fixes it sets actioned_at. Cannot see a false statement nobody tagged.');

select public._log_action('cc', 'gate_absent_active', 'contractors', array['license_status','contractors_absent_never_active','live-false-statement-finding-unactioned'],
  jsonb_build_object('absent_served_active', 17981, 'absent_secondary_A', 16819, 'absent_no_secondary', 1162),
  jsonb_build_object('not_in_latest_file', 16819, 'not_stated', 1162, 'constraint', 'absent rows can never be active'),
  'Ruling 907 / bus 856: 17,981 licences absent from the latest DBPR file were served as active on the public register and Roz for a day after verification. Derivation corrected at source, recurrence blocked by CHECK, unactioned-false-statement detection added.', null);

do $$
declare n int;
begin
  select count(*) into n from public.contractors where register_file_state = 'absent_from_latest_file' and license_status = 'active';
  if n is distinct from 0 then raise exception '191a: % absent rows still active', n; end if;
  -- the public search no longer says active for an absent licence
  if exists (select 1 from jsonb_array_elements((public.contractor_register_search('roofing', 50))->'results') r
              join public.contractors c on c.slug = r->>'slug'
             where c.register_file_state = 'absent_from_latest_file' and r->>'license_status' = 'active') then
    raise exception '191a: the public search still serves an absent licence as active';
  end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute') then raise exception '191a: register grant lost'; end if;
end $$;
