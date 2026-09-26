-- 136c — The 15 contractor capability flags: NULL (not stated), not FALSE (said no).
-- Ruling 2026-09-26: same as disciplinary_history (136a). The test is WHOSE FACT IT IS — these
-- describe the business (what it offers), nobody asked it, so there is no honest default.
--
-- Before: DEFAULT false, FALSE on all 114,104 rows, TRUE on none, and SERVED to anon through
-- contractors_public — "does not offer emergency callouts" asserted about every contractor.
-- Writers: none (repo, pg_proc and WSL scripts grepped); the default was the only source.
-- Readers: the profile badge and map marker render only when true, and the map filter is
-- emergency_available=eq.true, so NULL renders exactly as FALSE did. Type is already nullable.
-- A value is written when a business answers at claim time.

do $m$
declare col text; n bigint;
  cols text[] := array['ada_compliant_work','aging_in_place','chemical_sensitivity_aware','mobility_accessible_worksite',
    'hurricane_hardening','impact_window_certified','roof_certification','storm_restoration','emergency_available',
    'emergency_plumbing','emergency_roofing','emergency_electrical','emergency_storm_damage','emergency_water_damage',
    'emergency_board_up'];
begin
  foreach col in array cols loop
    execute format('alter table public.contractors alter column %I drop default', col);
    execute format('comment on column public.contractors.%I is %L', col,
      'NULL = NOT STATED by the business. Was DEFAULT false on every row until 136c (2026-09-26). Only the business''s own answer (claim time) may write true or false.');
  end loop;
  update public.contractors set
    ada_compliant_work = null, aging_in_place = null, chemical_sensitivity_aware = null, mobility_accessible_worksite = null,
    hurricane_hardening = null, impact_window_certified = null, roof_certification = null, storm_restoration = null,
    emergency_available = null, emergency_plumbing = null, emergency_roofing = null, emergency_electrical = null,
    emergency_storm_damage = null, emergency_water_damage = null, emergency_board_up = null
  where not claimed or claimed is null;
  -- claimed rows (0 today) keep whatever the business may have set; none exist, asserted below.
  if exists (select 1 from public.contractors where claimed) then
    raise exception '136c: claimed rows exist - their flags need a per-row decision, not a sweep';
  end if;
  foreach col in array cols loop
    execute format('select count(*) from public.contractors where %I is not null', col) into n;
    if n <> 0 then raise exception '136c: % still has % non-null values', col, n; end if;
    if (select column_default from information_schema.columns where table_schema='public'
          and table_name='contractors' and column_name=col) is not null then
      raise exception '136c: % still has a default', col;
    end if;
  end loop;
end $m$;
