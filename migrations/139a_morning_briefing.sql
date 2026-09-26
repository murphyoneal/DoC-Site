-- 139a — Murphy's morning briefing, as the first section of daily_ops_report (work order 683).
--
-- READ FIRST (as ordered). daily_ops_report already covers: system health (CAMA/DBPR snapshot
-- dates, DB size, zeroed tables, security), action items, assistant usage and cost, anomalies,
-- work-gallery location states, commerce (NOT WIRED for Stripe), data estate and manual refresh.
-- It covers NONE of: claims, scans/visits, signups, register health, detections. It runs from
-- pg_cron (daily-ops-report, 09:00 UTC = 05:00 ET) and writes daily_ops_report_archive. It is NOT
-- delivered anywhere: nothing sends it to Murphy.
--
-- EXTENDED, not replaced: a "0. Morning briefing" section at the top, built by
-- _morning_briefing_md(since) so it can be read and tested alone. The window is "since the
-- previous report" (the last archive row before today), else 24 h.
--
-- RULES (683 s.2): counts and dates only; a zero is stated; not-measured is never printed as 0;
-- no personal data beyond what a claim contains; never an IP.
-- The helper returns claimant names and emails, so EXECUTE is revoked from the REST roles.

create or replace function public._morning_briefing_md(p_since timestamptz)
returns text language plpgsql stable set search_path = public, pg_temp as $$
declare
  md text := '';
  n bigint; n2 bigint; n3 bigint; s text; ts timestamptz; d date; r record;
begin
  md := md || E'\n## 0. Morning briefing\n'
           || format(E'_Since %s (the previous report). Counts and dates only. A 0 is a result; "not measured" means we cannot see it._\n',
                     to_char(p_since at time zone 'America/New_York', 'Dy DD Mon HH24:MI "ET"'));

  -- CLAIMS ------------------------------------------------------------------------------------
  md := md || E'\n**Claims (from a business''s page)**\n';
  begin
    select count(*) into n from claim_requests where created_at >= p_since;
    select count(*) into n2 from claim_requests where status = 'pending';
    md := md || format(E'- %s new claim(s) since the last report; %s pending in total.\n', n, n2);
    for r in
      select cr.created_at, coalesce(c.display_name, c.business_name) nm, c.city, county_display(c.county_name) cty,
             cr.requester_name, cr.requester_email, cr.license_number, coalesce(cr.licence_match_state, 'not evaluated') st
        from claim_requests cr left join contractors c on c.id = cr.contractor_id
       where cr.created_at >= p_since order by cr.created_at
    loop
      md := md || format(E'  - %s - %s (%s, %s) - by %s <%s> - licence given %s - check: %s%s\n',
        to_char(r.created_at at time zone 'America/New_York', 'DD Mon HH24:MI'), r.nm, coalesce(r.city,'?'), coalesce(r.cty,'?'),
        r.requester_name, r.requester_email, r.license_number, r.st,
        case when r.st in ('licence_mismatched','licence_not_comparable','not evaluated') then ' - NEEDS A PERSON (not a rejection)' else '' end);
    end loop;
  exception when others then md := md || format(E'- ERROR (claims): %s\n', sqlerrm); end;
  md := md || E'- Claims made on the register page go to Formspree and are not visible here (see Signups).\n';

  -- VISITS ------------------------------------------------------------------------------------
  md := md || E'\n**Visits to business pages** _(our own test traffic excluded)_\n';
  begin
    select count(*) filter (where action = 'page_view'),
           count(*) filter (where action = 'scan_landing'),
           count(*) filter (where ref = 'qr' or action = 'scan_landing')
      into n, n2, n3
      from scan_events where created_at >= p_since and excluded_reason is null;
    md := md || format(E'- %s profile view(s), %s QR scan landing(s); %s arrived by QR (ref=qr).\n', n, n2, n3);
    select string_agg(format('%s (%s)', slug, k), ', ' order by k desc, slug) into s
      from (select slug, count(*) k from scan_events where created_at >= p_since and excluded_reason is null
             and action in ('page_view','scan_landing') group by slug order by count(*) desc limit 10) x;
    md := md || format(E'- Profiles: %s\n', coalesce(s, 'none'));
    select string_agg(format('%s (%s)', ct, k), ', ' order by k desc, ct) into s
      from (select coalesce(initcap(lower(city)),'?') ct, count(*) k from scan_events where created_at >= p_since and excluded_reason is null
             and action in ('page_view','scan_landing') group by 1 order by 2 desc limit 10) x;
    md := md || format(E'- By the business''s city (not the visitor''s): %s\n', coalesce(s, 'none'));
    md := md || E'- Where visitors are: NOT MEASURED (we do not locate visitors).\n';
  exception when others then md := md || format(E'- ERROR (visits): %s\n', sqlerrm); end;

  -- SIGNUPS AND EMAIL -------------------------------------------------------------------------
  md := md || E'\n**Signups and email**\n'
           || E'- Register-page claims and newsletter sign-ups: NOT MEASURED. They go to Formspree, which forwards them to the inbox; nothing records them here. (Formspree''s Submissions API would close this, but it is on its Professional/Business plans only.)\n'
           || E'- Direct email to hello@ and register@: NOT VISIBLE to this report. Cloudflare forwards it to Gmail. Check the inbox.\n';

  -- REGISTER HEALTH ---------------------------------------------------------------------------
  md := md || E'\n**Contractor register**\n';
  begin
    select capture_date into ts from dbpr_snapshot_log where is_register_source;
    md := md || format(E'- Built from the state file of %s (%s days old)%s.\n', ts::date, (current_date - ts::date),
                       case when ts < now() - interval '45 days' then ' - STALE: refresh it before the next renewal deadline' else '' end);
    select max(capture_date) into ts from dbpr_snapshot_log where capture_date is not null;
    md := md || format(E'- Newest state file held: %s (%s days ago). The weekly DBPR pull %s.\n', ts::date, (current_date - ts::date),
                       case when ts > now() - interval '8 days' then 'ran this week' else 'has NOT run in the last 8 days' end);
    select count(*) filter (where register_file_state = 'absent_from_latest_file'),
           count(*) filter (where register_file_state = 'in_latest_file' and license_status = 'active'
                              and expiry_date ~ '^\d{2}/\d{2}/\d{4}$' and to_date(expiry_date,'MM/DD/YYYY') < current_date)
      into n, n2 from contractors;
    md := md || format(E'- %s licence record(s) MISSING from the latest file (missing, not lapsed); %s in the file are active with a past expiry (as the file states).\n', n, n2);
  exception when others then md := md || format(E'- ERROR (register): %s\n', sqlerrm); end;

  -- DETECTIONS --------------------------------------------------------------------------------
  md := md || E'\n**Checks**\n';
  begin
    select max(run_at) into ts from defect_detection_runs;
    if ts is null or ts < now() - interval '36 hours' then
      select r2.status || ': ' || left(regexp_replace(coalesce(r2.return_message,''), '\s+', ' ', 'g'), 120) into s
        from cron.job j join cron.job_run_details r2 using (jobid)
       where j.jobname = 'defect-detections-daily' order by r2.start_time desc limit 1;
      md := md || format(E'- DETECTIONS NOT CURRENT: the detection runner last completed %s. Its latest scheduled run: %s. Red/green below is from that old run and is not today''s state.\n',
                         coalesce(ts::date::text, 'never'), coalesce(s, 'no record'));
    end if;
    if ts is not null then
      with runs as (select distinct run_id, run_at from defect_detection_runs order by run_at desc limit 2),
           cur as (select d.defect_id, d.ok from defect_detection_runs d where d.run_id = (select run_id from runs order by run_at desc limit 1)),
           prev as (select d.defect_id, d.ok from defect_detection_runs d where d.run_id = (select run_id from runs order by run_at asc limit 1)
                     and (select count(*) from runs) = 2)
      select count(*) filter (where cur.ok is false and (prev.ok is distinct from false) and coalesce(g.expected_state,'clean') <> 'defect'),
             count(*) filter (where cur.ok is false and not ((prev.ok is distinct from false) and coalesce(g.expected_state,'clean') <> 'defect')),
             count(*) filter (where cur.ok is null),
             string_agg(cur.defect_id, ', ' order by cur.defect_id) filter (where cur.ok is false and (prev.ok is distinct from false) and coalesce(g.expected_state,'clean') <> 'defect')
        into n, n2, n3, s
        from cur left join prev using (defect_id) left join data_defect_registry g on g.defect_id = cur.defect_id;
      md := md || format(E'- Run of %s: %s newly red%s; %s red and known; %s errored (errored is never clean).\n',
                         ts::date, n, case when n > 0 then ' (' || s || ')' else '' end, n2, n3);
    end if;
  exception when others then md := md || format(E'- ERROR (detections): %s\n', sqlerrm); end;
  begin
    select g.run_at, count(*) filter (where g.structural_status = 'over_production_timeout'),
           string_agg(g.co_no || '/' || g.parcel_id || ' ' || g.current_value, '; ') filter (where g.structural_status in ('over_production_timeout','near_production_timeout'))
      into ts, n, s
      from golden_parcel_run g
     where g.section = '<latency>' and g.run_id = (select run_id from golden_parcel_run where section = '<latency>' order by run_at desc limit 1)
     group by g.run_at;
    if ts is null then md := md || E'- Report timing: NOT MEASURED yet (no golden run with timings).\n';
    else md := md || format(E'- Report timing (golden parcels, %s): %s over the 8 s production limit%s.\n', ts::date, n,
                            case when s is not null then '; at or near it: ' || s else '' end);
    end if;
  exception when others then md := md || format(E'- ERROR (timing): %s\n', sqlerrm); end;

  return md;
end $$;

revoke all on function public._morning_briefing_md(timestamptz) from public, anon, authenticated;
grant execute on function public._morning_briefing_md(timestamptz) to service_role;

-- Put it at the top of the existing report, windowed from the previous report.
do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.daily_ops_report()'::regprocedure);
  new_def := replace(def,
    E'_Generated %s. Legend: OK / EMPTY (no activity) / NOT WIRED / ERROR / FLAG._\\n'', today, now());',
    E'_Generated %s. Legend: OK / EMPTY (no activity) / NOT WIRED / ERROR / FLAG._\\n'', today, now());\n  -- 139a: the morning briefing, first.\n  md := md || public._morning_briefing_md(coalesce((select max(generated_at) from daily_ops_report_archive where report_date < today), now() - interval ''24 hours''));');
  if new_def = def or position('_morning_briefing_md' in new_def) = 0 then
    raise exception '139a: anchor not found - nothing changed';
  end if;
  execute new_def;
end $f$;

do $a$
begin
  if has_function_privilege('anon', 'public._morning_briefing_md(timestamptz)', 'EXECUTE') then
    raise exception '139a: briefing helper (names, emails) is executable by anon';
  end if;
  if position('## 0. Morning briefing' in public._morning_briefing_md(now() - interval '24 hours')) = 0 then
    raise exception '139a: briefing did not render';
  end if;
end $a$;
