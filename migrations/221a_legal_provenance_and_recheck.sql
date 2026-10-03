-- 221a - legal rows: provenance that says who read what and when, a recheck clock keyed to effective dates, and the
-- checks that can tell us a statute moved (work order 1005, parts 2, 3 and 6).
--
-- 1005: "PRIMARY_VERIFIED DOES NOT MEAN VERIFIED. IT MEANS A PROCESS RAN." All 50 rows carried it, including the four
-- false presuit rows 220a corrected. It is RE-SCOPED here, not retired, because get_verified_construction_law filters
-- on it and retiring it would change what is served: its comment now says what it witnessed (an August pass stored a
-- statute_quote and a URL), and per-field truth moves to construction_law_field_check - one row per field read, with
-- the authority read, the method, who and when.
-- A REGISTER's retrieval date keeps its claim true forever; a statute's does not - a law amended since the check is a
-- wrong instruction under a diligent-looking date. So every row gets last_checked / recheck_due / check_method /
-- session_window, and recheck_due is the first common effective date (1 Jan, 1 Jul, 1 Oct) AFTER the stalest served
-- field was read: a fixed 90-day timer straddling 1 July would publish repealed law for weeks. Per-state session
-- calendars are not researched yet and session_window says so. Every row's stalest field was read in August, so every
-- row is due 2026-10-01 - already past. The recheck detection is RED on purpose; the repose/limitations re-audit
-- clears it.
-- DC is absent from the table; the detections declare 51 jurisdictions, so DC counts against them until it is added.

comment on column public.construction_defect_law.primary_verified is
  'RE-SCOPED 2026-10-03 (221a, ruling 1005). Witnesses only that the August 2026 pass stored a statute_quote and a primary_source_url for the repose provision. It is NOT a per-field verification: that pass produced four false pre-suit rows (corrected in 220a). Per-field provenance is construction_law_field_check. Still the serving filter of get_verified_construction_law.';

alter table public.construction_defect_law
  add column last_checked date,
  add column recheck_due date,
  add column check_method text,
  add column session_window text;

create table public.construction_law_field_check (
  id bigint generated always as identity primary key,
  state_code text not null references public.construction_defect_law(state_code),
  field_group text not null check (field_group in ('repose','limitations','warranty','presuit','fraud_exception','rights_you_have','what_to_do_now','homeowner_summary','statute_quote')),
  authority_read text not null,          -- the statute section or opinion actually read
  method text not null check (method in ('primary_statute_text','primary_opinion_text','cited_in_later_opinion','secondary_only','august_pass_unaudited')),
  checked_by text not null,
  checked_on date not null,
  migration text,
  note text,
  unique (state_code, field_group, checked_on, authority_read)
);
comment on table public.construction_law_field_check is
  'Who read what and when, per state per field group (ruling 1005). A row is evidence only for its own field_group. august_pass_unaudited records that a field was written in August and has not been re-read against primary text.';
revoke all on public.construction_law_field_check from anon, authenticated;

-- The August pass, recorded as what it is: written, not re-audited. One row per served field group per state.
insert into public.construction_law_field_check (state_code, field_group, authority_read, method, checked_by, checked_on, migration, note)
select d.state_code, g.fg, coalesce(case g.fg when 'repose' then d.repose_cite when 'limitations' then d.limitations_cite end, '(not recorded)'),
       'august_pass_unaudited', 'august research pass', d.verified_on, null,
       'Written in the August 2026 pass; not re-read against primary text since. primary_verified was set on this pass.'
  from public.construction_defect_law d
 cross join (values ('repose'),('limitations'),('rights_you_have'),('what_to_do_now'),('homeowner_summary'),('statute_quote')) g(fg)
 where d.verified_on is not null;

-- What 220a and 220b actually read.
insert into public.construction_law_field_check (state_code, field_group, authority_read, method, checked_by, checked_on, migration, note)
select state_code, 'presuit', presuit_cite, 'primary_statute_text', 'cc research subagent', date '2026-10-03', '220a', 'Statute text, legislature site first, FindLaw where blocked.'
  from public.construction_defect_law where state_code in ('OH','AK','HI','IN','MT','NM','SD','WV','IA','MN','VA','NJ','MD','MA');
insert into public.construction_law_field_check (state_code, field_group, authority_read, method, checked_by, checked_on, migration, note)
select state_code, 'presuit', '(no statute found by search)', 'secondary_only', 'cc research subagent', date '2026-10-03', '220a',
       'A search finding nothing is not a finding: served as not_researched.'
  from public.construction_defect_law where state_code in ('IL','MI','NC','PA');
insert into public.construction_law_field_check (state_code, field_group, authority_read, method, checked_by, checked_on, migration, note)
select state_code, 'warranty', coalesce(warranty_cite, '(no published authority)'),
       case when state_code in ('AL','AR','IA','ID','IN','NH','OK','RI','VT') then 'cited_in_later_opinion' else 'primary_opinion_text' end,
       'cc research subagent', date '2026-10-03', '220b',
       case when state_code in ('AL','AR','IA','ID','IN','NH','OK','RI','VT') then 'The leading case was read only as cited in a later opinion that was read; see source_note.' else 'Statutes and opinions read directly.' end
  from public.construction_defect_law
 where state_code in ('AK','AL','AR','CT','DE','HI','IA','ID','IN','KS','KY','LA','ME','MO','MS','MT','ND','NE','NH','NM','OK','RI','SD','TN','UT','VT','WI','WV','WY');

-- Ruling 1005 part 6: where two readings exist, the page states both, with cites, and says which we rely on.
do $$
declare n int;
begin
  update public.construction_defect_law set presuit_note =
    'Two readings exist. Minnesota''s statutory home warranty requires written notice to the builder or home improvement contractor within six months of discovering a defect, or the warranty claim is lost (Minn. Stat. § 327A.03(a)). Once notice is given, the builder may inspect and offer a repair, and related suits wait for that process (§ 327A.02, subds. 4 and 7). One reading treats this as a condition of the warranty claim only; the other as a step before any related lawsuit. We rely on the first, so we do not list Minnesota as requiring pre-suit notice. Either way, give the written notice before you sue.'
   where state_code = 'MN' and presuit_cite = 'Minn. Stat. §§ 327A.02, 327A.03';
  get diagnostics n = row_count;
  if n <> 1 then raise exception '221a: MN row not as 220a left it'; end if;
end $$;

-- The clock. last_checked = the stalest served field group's check; recheck_due = first 1 Jan / 1 Jul / 1 Oct after it.
create or replace function public._legal_next_effective_date(d date) returns date language sql immutable as $f$
  select min(x) from (values (make_date(extract(year from d)::int, 7, 1)), (make_date(extract(year from d)::int, 10, 1)),
                             (make_date(extract(year from d)::int + 1, 1, 1))) v(x) where x > d
$f$;
revoke all on function public._legal_next_effective_date(date) from public, anon, authenticated;

update public.construction_defect_law d
   set last_checked = s.stalest, recheck_due = public._legal_next_effective_date(s.stalest),
       check_method = 'stalest served field: ' || s.how,
       session_window = 'Not researched per state. Recheck before each common effective date (1 Jan, 1 Jul, 1 Oct).'
  from (select distinct on (state_code) state_code, latest as stalest, method as how
          from (select state_code, field_group, max(checked_on) latest, (array_agg(method order by checked_on desc))[1] method
                  from public.construction_law_field_check group by 1, 2) f
         order by state_code, latest asc) s
 where s.state_code = d.state_code;

-- External checks land here (scripts/legal/check_legal_sources.py): link liveness and statute-quote drift.
create table public.legal_source_check (
  id bigint generated always as identity primary key,
  state_code text not null references public.construction_defect_law(state_code),
  checked_at timestamptz not null default now(),
  url text not null,
  http_status int,
  outcome text not null check (outcome in ('live','dead','blocked','error')),
  quote_state text not null check (quote_state in ('found','not_found','not_checkable')),
  note text
);
comment on table public.legal_source_check is
  'Fetches of primary_source_url (ruling 1005 3c/3d). blocked = the site refused an automated fetch (403/429/challenge): NOT dead and NOT live - unverifiable. quote_found compares the stored statute_quote, whitespace- and punctuation-normalised, against the fetched page text.';
revoke all on public.legal_source_check from anon, authenticated;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values
('legal-row-past-recheck-due',
  'A state law row on /rights is past its recheck date, or a jurisdiction has no row',
  current_date, 'ruling 1005: verified_on 2026-08-03..08-31, nothing re-read in 33 days, no cadence, zero legal-staleness detections', 'temporal', 'blocking',
$q$with j(code) as (select unnest(array['AL','AK','AZ','AR','CA','CO','CT','DE','DC','FL','GA','HI','ID','IL','IN','IA','KS','KY','LA','ME','MD','MA','MI','MN','MS','MO','MT','NE','NV','NH','NJ','NM','NY','NC','ND','OH','OK','OR','PA','RI','SC','SD','TN','TX','UT','VT','VA','WA','WV','WI','WY']))
select count(*) filter (where d.state_code is null or d.recheck_due is null or d.recheck_due <= current_date) = 0 as ok,
       count(*) filter (where d.state_code is null or d.recheck_due is null or d.recheck_due <= current_date) as row_count,
       count(*) as population
  from j left join public.construction_defect_law d on d.state_code = j.code$q$,
  'clean', '51 jurisdictions (50 states + DC)',
  'Red on purpose from day one: every row''s stalest field was read in August, before the 1 Oct effective date. A missing jurisdiction (DC today) counts against it. Clears row by row as repose, limitations and the narrative fields are re-read against primary text and recorded in construction_law_field_check.',
  'active', 'ours', 'Re-read the stalest field group against primary text, record it in construction_law_field_check, recompute recheck_due.', 'rights_state_pages', 'blocking'),
('legal-primary-source-dead-or-drifted',
  'A /rights primary source link is dead, or the statute text we quote is no longer on the page',
  current_date, 'ruling 1005 3c/3d: a dead government link reads as authoritative and goes nowhere; a changed quote means the law moved', 'temporal', 'blocking',
$q$with latest as (select distinct on (state_code) state_code, checked_at, outcome, quote_state from public.legal_source_check order by state_code, checked_at desc),
     rows as (select d.state_code, l.checked_at, l.outcome, l.quote_state from public.construction_defect_law d left join latest l using (state_code) where d.primary_verified)
select count(*) filter (where checked_at is null or checked_at < now() - interval '35 days' or outcome = 'dead' or quote_state = 'not_found') = 0 as ok,
       count(*) filter (where checked_at is null or checked_at < now() - interval '35 days' or outcome = 'dead' or quote_state = 'not_found') as row_count,
       count(*) filter (where outcome in ('blocked','error') or quote_state = 'not_checkable') as not_checkable,
       count(*) as population
  from rows$q$,
  'clean', 'served /rights rows (primary_verified)',
  'blocked/error and not_checkable are unverifiable, not clean and not failing: they are counted in not_checkable, never in ok. A quote can fail to match because a site reformats text; a not_found is a lead to read the statute, not proof it changed. No check within 35 days fails it - a check that stopped running must not read clean.',
  'active', 'ours', 'Read the statute at a live primary URL; update primary_source_url and statute_quote, or record the amendment.', 'rights_state_pages', 'blocking');

update public.data_defect_registry
   set acknowledgement = 'Red by design at creation (221a): all 50 rows were last read in August, before the 1 Oct 2026 effective date, and DC has no row. Cleared by the repose/limitations re-audit (1005 priority 2). Review 2026-10-17.',
       expires_at = timestamptz '2026-10-17 23:59:59-04'
 where defect_id = 'legal-row-past-recheck-due';

do $$
declare a jsonb; m jsonb; n int;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'legal-row-past-recheck-due')) into a;
  if (a->>'ok')::boolean is distinct from false or (a->>'population')::int <> 51 or (a->>'row_count')::int <> 51 then
    raise exception '221a: recheck detection should be red on all 51 (50 past due + DC): %', a; end if;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'legal-primary-source-dead-or-drifted')) into m;
  if (m->>'ok')::boolean is distinct from false then raise exception '221a: source detection must be red until the first check runs: %', m; end if;
  select count(*) into n from public.construction_defect_law where recheck_due is null;
  if n > 0 then raise exception '221a: % rows have no recheck_due', n; end if;
  if (select count(*) from public.construction_law_field_check where method = 'august_pass_unaudited') <> 300 then
    raise exception '221a: expected 300 august rows (50 x 6)'; end if;
  raise notice '221a: recheck %; sources %; provenance rows %', a, m, (select count(*) from public.construction_law_field_check);
end $$;

select public._log_action('cc', 'legal_provenance_and_recheck', 'construction_defect_law',
  array['construction_defect_law','construction_law_field_check','legal_source_check','data_defect_registry'], null,
  jsonb_build_object('primary_verified', 're-scoped by comment', 'recheck', 'first 1 Jan/1 Jul/1 Oct after the stalest field', 'detections', 2),
  'Ruling 1005 parts 2, 3, 6.', null);
