-- 191b - daily_ops_report counts unactioned live-false-statement findings (ruling 907).
--
-- 907: "an unactioned finding naming a live false statement older than 24 hours reads RED", with the count in
-- daily_ops_report. The detection is live-false-statement-finding-unactioned (191a). This puts the same predicate, with
-- the row ids, under "2. Action Items" so it is read every morning, not only when the detection suite runs.
-- Anchored patch from pg_get_functiondef; aborts if the anchor is missing or not unique. SECURITY DEFINER replace
-- revokes anon/authenticated on this function only (trigger scoped 2026-09-22); its grant set is captured and re-issued.

do $$
declare d text; anchor text := '  md := md || E''\n## 3. Usage\n'';';  -- plain literal: matches the backslash-n in the source before_acl text; after_acl text;
begin
  select coalesce(proacl::text, '') into before_acl from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  d := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  if (select count(*) from regexp_matches(d, '## 3\. Usage', 'g')) <> 1 or position(anchor in d) = 0 then
    raise exception '191b: anchor missing or not unique'; end if;
  d := replace(d, anchor,
$p$  -- 191b (ruling 907): a verified false statement on a served surface is gated or fixed the day it is verified
  begin select count(*), string_agg(id::text, ', ' order by id) into n, s from agent_handoff
     where refs ilike '%LIVE_FALSE_STATEMENT%' and actioned_at is null and created_at < now() - interval '24 hours';
    select count(*) into n2 from agent_handoff
     where refs ilike '%LIVE_FALSE_STATEMENT%' and actioned_at is null and created_at >= now() - interval '24 hours';
    md := md || format(E'- %s Live false statements unactioned >24h: %s%s; within 24h: %s\n',
      case when coalesce(n,0)=0 then 'OK' else 'RED' end, coalesce(n,0),
      case when coalesce(n,0)>0 then ' (bus rows '||s||')' else '' end, coalesce(n2,0));
  exception when others then md := md || format(E'- ERROR (live false statements): %s\n', sqlerrm); end;
$p$ || anchor);
  execute d;
  -- re-issue whatever the function held before (the replace's trigger revokes anon/authenticated)
  if before_acl like '%anon=X%' then grant execute on function public.daily_ops_report() to anon; end if;
  if before_acl like '%authenticated=X%' then grant execute on function public.daily_ops_report() to authenticated; end if;
  select coalesce(proacl::text, '') into after_acl from pg_proc where oid = 'public.daily_ops_report()'::regprocedure;
  if after_acl is distinct from before_acl then raise exception '191b: grants changed % -> %', before_acl, after_acl; end if;
end $$;

select public._log_action('cc', 'ops_report_live_false_statements', 'daily_ops_report', array['daily_ops_report'], null,
  jsonb_build_object('added', 'Action Items line: LIVE_FALSE_STATEMENT findings unactioned >24h (RED) with bus ids'),
  'Ruling 907: a verified false statement may not sit as a queue item; the morning report now shows any left unactioned past 24 hours.', null);
