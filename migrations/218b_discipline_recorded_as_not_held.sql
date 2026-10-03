-- 218b - discipline is recorded as a register we do NOT hold (ruling 1000).
-- The construction file carries exactly three status values across 130,474 licences - A 94,335, blank 24,473, I 11,666.
-- There is no revoked and no suspended status in it at all, so this register cannot show discipline, and nothing built
-- on it may imply a clean record ("no disciplinary history" would be a false statement built on an absence). Discipline
-- needs DBPR enforcement data, which we do not hold. register_coverage records it as its own missing thing so no surface
-- or plan can read the licence register as covering it. Internal only (rulings 990-992: coverage is never published).
alter table public.register_coverage drop constraint if exists register_coverage_profession_check;
alter table public.register_coverage add constraint register_coverage_profession_check
  check (profession = any (array['construction','electrical','real_estate','construction_discipline']));
insert into public.register_coverage (state_geo_id, profession, coverage_state, notes, register_scope, access_type)
values ('US-12', 'construction_discipline', 'not_held',
  'Measured 2026-10-03 (ruling 1000): the construction licence file carries only A, I and blank status - no revoked, no suspended. We hold no enforcement/discipline data, so no page may say or imply a licensee has no disciplinary history. A separate register (enforcement actions) would be needed.',
  'not_established', 'not_established')
on conflict (state_geo_id, profession) do update set coverage_state = excluded.coverage_state, notes = excluded.notes;
do $$ begin
  if not exists (select 1 from public.register_coverage where state_geo_id = 'US-12' and profession = 'construction_discipline' and coverage_state = 'not_held') then
    raise exception '218b: row not recorded'; end if;
end $$;
