-- 210g - the abuse detection Murphy asked for: one source touching many businesses (ruling 975).
--
-- Murphy: "What if one IP address goes and changes 20 profiles? This way we can track what has been done and issue a
-- remedy and possibly block the IP user function." 210e made the first two possible (every change is versioned against
-- its custody, so the remedy is a query: revert the versions written under the offending submission_events). This is
-- the third: it fires on the board before a human notices.
--   RED when, in the last 24 hours, ONE ACCOUNT (actor_email) wrote to more than 3 distinct businesses, or ONE ADDRESS
--   (ip, with ip_basis vercel_edge - an address we can trust) wrote to more than 10, via profile saves, logos, work
--   photos or withdrawals.
-- Thresholds are calibration choices, stated so they can be challenged: an owner normally speaks for one business and a
-- multi-business owner for a few, hence 3 per account; an address can be carrier NAT shared by thousands (975: Murphy's
-- own test IP is T-Mobile CGNAT), hence a higher bar and never a block on its own - the account is the attributable unit.
-- Population: custody events of those kinds ever recorded (so an idle day reads clean on a real population, not on
-- nothing). Red-run below with 20 synthetic saves from one address to 20 throwaway subjects, rolled back - never against
-- a real business.

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('one-source-touches-many-businesses',
  'In the last 24 hours one account wrote claimed details for more than 3 distinct businesses, or one trusted address for more than 10',
  current_date, 'ruling 975 (Murphy: "what if one IP address goes and changes 20 profiles?")', 'access_control', 'material',
$q$with w as (select actor_email, ip, ip_basis, subject_ref from public.submission_event
               where kind in ('profile_save','logo_upload','logo_remove','work_upload','work_withdraw')
                 and at > now() - interval '24 hours' and subject_ref is not null and coalesce(outcome,'') not like 'refused%'),
    by_actor as (select actor_email, count(distinct subject_ref) n from w where actor_email is not null group by 1 having count(distinct subject_ref) > 3),
    by_ip as (select ip, count(distinct subject_ref) n from w where ip is not null and ip_basis = 'vercel_edge' group by 1 having count(distinct subject_ref) > 10)
select not exists (select 1 from by_actor) and not exists (select 1 from by_ip) as ok,
       (select count(*) from by_actor) + (select count(*) from by_ip) as row_count,
       (select max(n) from (select n from by_actor union all select n from by_ip) z) as most_businesses_by_one_source,
       (select count(*) from public.submission_event where kind in ('profile_save','logo_upload','logo_remove','work_upload','work_withdraw')) as population$q$,
  'clean', 'custody events of the claimed-detail kinds ever recorded (the check itself reads the last 24 hours)',
  'Thresholds (3 per account, 10 per trusted address, 24 h) are calibration choices, not measurements - revisit when real claim traffic exists. An address is never grounds for a block by itself (carrier NAT). The remedy: business_profile_version rows under the offending submission_event ids, reverted to old_value, the revert logged as our action.',
  'active', 'ours', 'Investigate the account first; block the account or claim, not the address; revert via business_profile_version.',
  'none', 'material');

do $$
declare q text; j jsonb; red jsonb; i int;
begin
  select detection_sql into q from public.data_defect_registry where defect_id = 'one-source-touches-many-businesses';
  execute format('select to_jsonb(x) from (%s) x', q) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) = 0 then raise exception '210g: not clean on a population: %', j; end if;
  begin
    for i in 1..20 loop
      insert into public.submission_event (kind, subject_ref, actor_email, ip, ip_basis, outcome)
      values ('profile_save', 'zz-redrun-210g-' || i, 'redrun-210g@example.invalid', '203.0.113.7', 'vercel_edge', 'saved');
    end loop;
    execute format('select to_jsonb(x) from (%s) x', q) into red;
    raise exception 'redrun_done';
  exception when raise_exception then if sqlerrm <> 'redrun_done' then raise; end if;
  end;
  if (red->>'ok')::boolean is distinct from false or (red->>'most_businesses_by_one_source')::int is distinct from 20 then
    raise exception '210g: red run did not fire on 20 businesses from one source: %', red; end if;
  if exists (select 1 from public.submission_event where subject_ref like 'zz-redrun-210g-%') then raise exception '210g: synthetic rows survived'; end if;
  raise notice '210g: clean %; red run %', j, red;
end $$;
