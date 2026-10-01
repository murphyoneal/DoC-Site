-- 196a - the 7-day AMBER line counts what can be relied on: rows created since the actioned_at convention started (916).
--
-- 916: "actioned_at has not been maintained ... the AMBER line will read 419 forever ... If [the convention] cannot be
-- relied on, the AMBER line should count something that can - and say which." The reconciliation sample (seed
-- recon-2026-10-01, bus report) confirms the pre-convention rows mix done-but-unmarked, superseded, partial and live work
-- in proportions only a per-row check can separate. So:
--   AMBER  = finding/question rows created ON OR AFTER 2026-10-01 (the convention: actioned_at set when the work lands,
--            by whoever lands it) and unactioned past 7 days. It starts at 0 and can only rise by a lapse.
--   LEGACY = the same predicate before 2026-10-01, printed beside it as "under reconciliation", never AMBER. It falls as
--            reconciled rows are marked with evidence.
-- Anchored patch of the 193a line. daily_ops_report grants re-asserted.

do $$
declare d text; a1 text; a2 text; old_block text; new_block text;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  d := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  old_block := substring(d from '  -- 193a \(ruling 912\): backstop that needs no tag.*?ERROR \(unactioned backstop\): %s\\n'', sqlerrm\); end;');
  if old_block is null then raise exception '196a: 193a block not found'; end if;
  new_block := $p$  -- 193a/196a (rulings 912, 916): no-tag backstop, counted from the convention start so the alarm can go quiet
  begin select count(*), string_agg(id::text, ', ' order by created_at) into n, s from (select id, created_at from agent_handoff
             where kind in ('finding','question') and actioned_at is null and created_at < now() - interval '7 days'
               and created_at >= timestamptz '2026-10-01 00:00:00-04') t;
    select count(*) into n2 from agent_handoff
             where kind in ('finding','question') and actioned_at is null and created_at < timestamptz '2026-10-01 00:00:00-04';
    md := md || format(E'- %s Bus findings/questions unactioned >7 days (since the 2026-10-01 convention): %s%s; legacy under reconciliation: %s\n',
      case when coalesce(n,0)=0 then 'OK' else 'AMBER' end, coalesce(n,0),
      case when coalesce(n,0)>0 then ' (rows '||s||')' else '' end, coalesce(n2,0));
  exception when others then md := md || format(E'- ERROR (unactioned backstop): %s\n', sqlerrm); end;$p$;
  d := replace(d, old_block, new_block);
  if position('196a (rulings 912, 916)' in d) = 0 then raise exception '196a: replace did not apply'; end if;
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.daily_ops_report() to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.daily_ops_report() to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  if a2 is distinct from a1 then raise exception '196a: grants changed % -> %', a1, a2; end if;
end $$;

select public._log_action('cc', 'amber_from_convention_start', 'daily_ops_report', array['daily_ops_report'], null,
  jsonb_build_object('amber', 'finding/question created >= 2026-10-01, unactioned >7d', 'legacy', 'printed, not alarmed'),
  'Ruling 916: an always-on alarm is no alarm. AMBER now counts only rows under the actioned_at convention that starts 2026-10-01; the unmaintained legacy backlog is shown beside it while it is reconciled.', null);

-- 196b (applied after 196a): every kind except 'note' - 916 counted rulings, work orders and corrections in the 419,
-- and a ruling addressed to cc left unactioned is as open a loop as an unanswered question (CLAUDE.md).
do $$
declare d text; a1 text; a2 text; n int;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  d := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  select count(*) into n from regexp_matches(d, 'where kind in \(''finding'',''question''\) and actioned_at is null and created_at < ', 'g');
  if n is distinct from 2 then raise exception '196b: expected 2 kind predicates in the backstop, found %', n; end if;
  d := replace(d, 'where kind in (''finding'',''question'') and actioned_at is null and created_at < ',
                  'where kind <> ''note'' and actioned_at is null and created_at < ');
  d := replace(d, 'Bus findings/questions unactioned >7 days (since the 2026-10-01 convention)',
                  'Bus rows (all kinds but notes) unactioned >7 days (since the 2026-10-01 convention)');
  execute d;
  if a1 like '%anon=X%' then grant execute on function public.daily_ops_report() to anon; end if;
  if a1 like '%authenticated=X%' then grant execute on function public.daily_ops_report() to authenticated; end if;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  if a2 is distinct from a1 then raise exception '196b: grants changed'; end if;
end $$;
