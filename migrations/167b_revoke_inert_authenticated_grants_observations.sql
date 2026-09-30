-- 167b - ruling 805 question: authenticated held INSERT/SELECT on web_observations and tax_deed_observations.
-- Inherited, not deliberate: both have RLS on with ZERO policies (so the grant could never pass a row), and the
-- only writer is /api/roz through service_role. Revoked so the grant list says what is true. Applied 2026-09-30.
revoke insert, select on public.web_observations, public.tax_deed_observations from authenticated, anon;
do $$ begin
  if has_table_privilege('authenticated','public.web_observations','INSERT') or has_table_privilege('authenticated','public.tax_deed_observations','INSERT')
     or has_table_privilege('authenticated','public.web_observations','SELECT') or has_table_privilege('authenticated','public.tax_deed_observations','SELECT') then
    raise exception '167b: authenticated still holds a grant';
  end if;
  if not has_table_privilege('service_role','public.web_observations','INSERT') or not has_table_privilege('service_role','public.tax_deed_observations','INSERT') then
    raise exception '167b: service_role lost INSERT (Roz writes web_observations)';
  end if;
end $$;
