-- 194a - license_status_now is renamed license_status_at_match: its name said current, its contents are frozen (912 item 4).
--
-- permit_contractor_match.license_status_now is copied from contractor_name_index when a permit is FIRST matched and is
-- never refreshed (refresh_permit_contractor_match is incremental). Measured 2026-10-01: 66,454 joined rows disagree with
-- the licence's current status. resolve_permit_contractor_match carries the same value into the resolved table.
-- Consumers, all three classes (CLAUDE.md): repo - none outside migrations; pg_proc - the two writers patched here, plus
-- match_contractor_license, which reads contractor_name_index LIVE (rebuilt in 191a/192a) and is NOT stale, so its output
-- key is left alone; system prompt - app/api/roz/route.ts does not name it. No view reads it.
-- Ruling 912: not rebuilt (454k rows, no consumer) and not left looking current. Renamed, and the column says what it is.

alter table public.permit_contractor_match rename column license_status_now to license_status_at_match;
alter table public.permit_contractor_match_resolved rename column license_status_now to license_status_at_match;
comment on column public.permit_contractor_match.license_status_at_match is
  'The licence''s license_status copied from contractor_name_index when this permit was first matched (matched_at). NEVER refreshed - NOT the current status (194a, was license_status_now). Read contractors.license_status for current.';
comment on column public.permit_contractor_match_resolved.license_status_at_match is
  'Carried from permit_contractor_match.license_status_at_match: the status at first match, never refreshed, NOT current (194a).';

do $$
declare f text; d text; a1 text; a2 text;
begin
  foreach f in array array['public.resolve_permit_contractor_match()', 'public.refresh_permit_contractor_match()'] loop
    select coalesce(proacl::text, '') into a1 from pg_proc where oid = f::regprocedure;
    d := pg_get_functiondef(f::regprocedure);
    if position('license_status_now' in d) = 0 then raise exception '194a: % has no license_status_now', f; end if;
    execute replace(d, 'license_status_now', 'license_status_at_match');
    select coalesce(proacl::text, '') into a2 from pg_proc where oid = f::regprocedure;
    if a2 is distinct from a1 then raise exception '194a: % grants changed % -> %', f, a1, a2; end if;
  end loop;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname in ('resolve_permit_contractor_match','refresh_permit_contractor_match')
                and pg_get_functiondef(p.oid) ~ 'license_status_now') then
    raise exception '194a: a writer still names license_status_now'; end if;
end $$;

select public._log_action('cc', 'rename_stale_column', 'permit_contractor_match', array['license_status_now->license_status_at_match'], null,
  jsonb_build_object('stale_rows_measured', 66454, 'consumers', 'none outside the two writers'),
  'Ruling 912 item 4: a column named _now held status frozen at first match on 66,454 stale rows; renamed so its staleness cannot be missed, not rebuilt.', null);

-- 194b (applied after 194a): resolve_permit_contractor_match DROPS and recreates the resolved table, so a column comment
-- set from outside is lost on the next refresh (observed: null after the first post-194a refresh). The comment now lives
-- in the function, beside the table comment it already sets.
do $$
declare d text; a1 text; a2 text; anchor text := '  analyze permit_contractor_match_resolved;';
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.resolve_permit_contractor_match()'::regprocedure;
  d := pg_get_functiondef('public.resolve_permit_contractor_match()'::regprocedure);
  if (select count(*) from regexp_matches(d, 'analyze permit_contractor_match_resolved;', 'g')) <> 1 then raise exception '194b: anchor'; end if;
  d := replace(d, anchor,
    '  comment on column permit_contractor_match_resolved.license_status_at_match is' || E'\n' ||
    '    ''Carried from permit_contractor_match.license_status_at_match: the status at first match, never refreshed, NOT current (194a).'';' || E'\n' || anchor);
  execute d;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.resolve_permit_contractor_match()'::regprocedure;
  if a2 is distinct from a1 then raise exception '194b: grants changed'; end if;
end $$;
