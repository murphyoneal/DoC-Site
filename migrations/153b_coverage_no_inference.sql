-- 153b: coverage is never inferred - undo both places 153a inferred it (ruling 736).
--
-- 153a turned "our old form only offered a county list" into "the business says it works in
-- counties", twice: a backfill UPDATE (which wrote the fixture row without moving updated_at) and a
-- save shim for clients that omit coverage_scope. Both go.
--
-- 1. business_profile_save: no shim. A payload without coverage_scope stores scope NULL.
-- 2. counties_worked is stored EXACTLY as the payload sent it, independent of scope. Scope decides
--    what is PUBLISHED (business_profile_public gates on coverage_scope = 'counties'), never what is
--    KEPT. Without this, removing the shim would have deleted an old client's county list.
-- 3. The one row 153a backfilled gets coverage_scope back to NULL. Our write, our undo; nothing else
--    on the row is touched. publish_coverage is already false.
--
-- Patched from the live definition with anchored replace(); a missing anchor aborts.

do $m$
declare d text; n text;
begin
  d := pg_get_functiondef('public.business_profile_save(text,text,jsonb)'::regprocedure);

  -- anchor on the code line alone: the applied body carries no comments (the committed 153a file does)
  n := replace(d, $a$  if not (p ? 'coverage_scope') and jsonb_array_length(coalesce(p->'counties_worked', '[]')) > 0 then v_scope := 'counties'; end if;
$a$, '');
  if n = d then raise exception '153b: shim anchor not found'; end if;
  d := n;

  n := replace(d, $a$      case when v_scope = 'counties' then nullif(array(select jsonb_array_elements_text(coalesce(p->'counties_worked', '[]'))), '{}') end,$a$,
                  $a$      nullif(array(select jsonb_array_elements_text(coalesce(p->'counties_worked', '[]'))), '{}'),$a$);
  if n = d then raise exception '153b: counties_worked anchor not found'; end if;

  execute n;
end $m$;

update public.business_profile set coverage_scope = null
 where business_id = 'e8eae372-c292-41f4-9e80-bb79e2b414e2' and coverage_scope = 'counties';

do $m$
begin
  if position('p ? ''coverage_scope''' in pg_get_functiondef('public.business_profile_save(text,text,jsonb)'::regprocedure)) > 0 then
    raise exception '153b: shim still present'; end if;
  if exists (select 1 from business_profile where business_id = 'e8eae372-c292-41f4-9e80-bb79e2b414e2'
              and (coverage_scope is not null or counties_worked is null)) then
    raise exception '153b: fixture row not as intended'; end if;
end $m$;
