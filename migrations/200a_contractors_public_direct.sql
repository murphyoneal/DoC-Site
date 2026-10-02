-- 200a - contractors_public_direct: the slug-addressed opt-in path for registered test fixtures (ruling 922, interim).
--
-- 922: "contractors_public excludes registered fixtures by default; the fixture's own test pages read through an explicit
-- opt-in path." Coupled deploy, additive first:
--   200a (this)  create contractors_public_direct = today's contractors_public, row for row. Nothing reads it yet.
--   code         the four slug-addressed readers switch to it: /c/[slug] profile, /c/[slug]/scan, /claim/[slug],
--                /claim (route). Each fetches ONE business by slug or id - never a list.
--   200b (after the code deploys)  contractors_public excludes test_fixture keys, so every list (state, county, city,
--                map, Volusia, related businesses, gallery) inherits the control; evaluate_claim_licence moves to _direct.
-- Grants: service_role only. The four readers use the service key; contractors_public is anon-readable, and the view
-- that still contains fixtures must not be.
-- Temporary by ruling: when module-level tests cover the claim and gallery flows the fixture is retired and this view
-- is dropped with it.

do $$
begin
  execute 'create or replace view public.contractors_public_direct as ' || pg_get_viewdef('public.contractors_public'::regclass, true);
end $$;
revoke all on public.contractors_public_direct from public, anon, authenticated;
grant select on public.contractors_public_direct to service_role;
comment on view public.contractors_public_direct is
  'Slug-addressed opt-in path (200a, ruling 922): identical to contractors_public before 200b, but keeps registered test fixtures. Only single-business readers by slug/id may use it (profile, scan, claim page, claim route, evaluate_claim_licence). Never a list. Dropped when the fixture is retired.';

do $$
declare a bigint; b bigint;
begin
  select count(*) into a from public.contractors_public;
  select count(*) into b from public.contractors_public_direct;
  if a is distinct from b then raise exception '200a: row counts differ % vs %', a, b; end if;
  if has_table_privilege('anon', 'public.contractors_public_direct', 'select') then raise exception '200a: anon can read the direct view'; end if;
end $$;

select public._log_action('cc', 'add_contractors_public_direct', 'contractors_public_direct', array['contractors_public_direct'], null,
  jsonb_build_object('grants', 'service_role only', 'phase', '1 of 2 (additive)'),
  'Ruling 922 interim: an explicit opt-in view for the slug-addressed fixture pages, ahead of excluding fixtures from contractors_public itself.', null);
