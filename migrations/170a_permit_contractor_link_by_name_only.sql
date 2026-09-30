-- 170a - the permit -> licence link, rebuilt on what the evidence supports (ruling 825, items 1-6; 809 5b).
--
-- Measured 2026-09-30: 902,368 Volusia permits name a contractor; 191,536 match a name in our register; only
-- 153,592 match something holding a licence (17%). 37,944 "matched" a QB business registration with NO licence
-- number and were served matched:true with a NULL licence and a NULL note (167a's concatenation). 13,229
-- "ambiguous" flags counted duplicate ROWS of one licence. And 15.6% of the unambiguous single-licence set named
-- a licence first issued AFTER the permit - impossible. Against a random-pairing baseline the match is real
-- signal (79-85% local vs 16%), with at most ~1 in 5 same-name risk: a link BY NAME, never by licence.
--
--   1. contractors.record_kind: 'licence' | 'business_registration', NOT NULL, NO DEFAULT - a loader must state
--      it. contractors_public and contractor_name_index carry it.
--   2. A licence first issued after the permit is never linked (a licence that did not exist cannot be used).
--   3. The choice among several licences keeps ONLY the issue-date floor; the expiry inference (167a) is gone,
--      and so are the trade-class and recency tie-breaks. Exactly one licence existing at the permit date -> a
--      name link; more than one -> ambiguous; none -> licence_issued_after_permit; only QB -> registration only.
--   4. Ambiguity counts DISTINCT licences.
--   5. matched:true is served only with a licence number behind it.
--   6. The served sentence states two facts separately and says they are linked by name only.
-- Keys finding/corroboration/active_at_permit_date/checked_as_of stay NULL (compat); contractor_as_recorded,
-- link and first_issued are additive; the deployed page renders register_note / note unchanged.

set local statement_timeout = 0;

-- 1. record_kind on the register -------------------------------------------------------------------------------
alter table public.contractors add column record_kind text;
update public.contractors set record_kind = case when coalesce(license_number,'') = '' then 'business_registration' else 'licence' end;
alter table public.contractors alter column record_kind set not null,
  add constraint contractors_record_kind_check check (record_kind in ('licence','business_registration')),
  add constraint contractors_registration_has_no_licence check ((record_kind = 'licence') = (coalesce(license_number,'') <> ''));
comment on column public.contractors.record_kind is
  'licence = a DBPR licence row (has a licence number); business_registration = a QB qualified-business entity row with NO licence number. Two kinds of record in one table (ruling 825): every reader must say which it has. NOT NULL with no default on purpose - a loader must state it.';

do $$ declare d text; begin
  d := pg_get_viewdef('public.contractors_public'::regclass);
  if position('register_file_date, register_file_state' in regexp_replace(d,'\s+',' ','g')) = 0 then
    raise exception '170a: contractors_public anchor not found';
  end if;
  d := regexp_replace(d, 'register_file_state\s+FROM contractors', 'register_file_state, contractors.record_kind FROM contractors');
  if position('record_kind' in d) = 0 then raise exception '170a: record_kind not added to the view'; end if;
  execute 'create or replace view public.contractors_public as ' || d;
end $$;

alter table public.contractor_name_index add column record_kind text;
create or replace function public.rebuild_contractor_name_index() returns integer
language plpgsql security definer set search_path to 'public' as $$
declare n integer;
begin
  truncate contractor_name_index;
  insert into contractor_name_index (norm_name, license_number, business_name, license_status, original_date, expiry_date, record_kind)
  select normalize_name(business_name), license_number, business_name, license_status, original_date, expiry_date, record_kind
    from contractors where business_name is not null;
  get diagnostics n = row_count;
  create index if not exists contractor_name_index_norm_idx on contractor_name_index(norm_name);
  analyze contractor_name_index;
  return n;
end $$;
revoke all on function public.rebuild_contractor_name_index() from public, anon, authenticated;
grant execute on function public.rebuild_contractor_name_index() to service_role;
select public.rebuild_contractor_name_index();

-- 2-4. Resolution, split out so it can run without a new raw ingest ---------------------------------------------
create or replace function public.resolve_permit_contractor_match() returns jsonb
language plpgsql security definer set search_path to 'public' as $$
begin
  drop table if exists permit_contractor_match_resolved;
  create table permit_contractor_match_resolved as
  with cand as (
    select m.parid, m.taxyr, m.permit_num, m.contractor_raw,
           nullif(m.license_number,'') lic, m.business_name, m.license_status_now, m.original_date, m.expiry_date,
           cama_date(p."PERMDT") permit_date, safe_date(m.original_date) orig
      from permit_contractor_match m
      left join volusia_cama_permits p on p."PARID" = m.parid and p."NUM" = m.permit_num and p."TAXYR" = m.taxyr
     where m.permit_num is not null and m.parid is not null and m.taxyr is not null
  ), g as (
    select parid, taxyr, permit_num,
           count(distinct lic) n_lic,
           -- the only date test kept: a licence cannot predate its own issue date. Unknown issue date or unknown
           -- permit date -> cannot exclude, so it counts as possibly existing.
           count(distinct lic) filter (where orig is null or permit_date is null or orig <= permit_date) n_existing
      from cand group by 1,2,3
  ), pick as (
    select distinct on (c.parid, c.taxyr, c.permit_num) c.*, g.n_lic, g.n_existing,
           case when g.n_lic = 0 then 'business_registration_only'
                when g.n_existing = 1 then 'licence_linked_by_name'
                when g.n_existing > 1 then 'ambiguous'
                else 'licence_issued_after_permit' end match_state
      from cand c join g using (parid, taxyr, permit_num)
     order by c.parid, c.taxyr, c.permit_num,
              case when g.n_lic = 0 then 0
                   when g.n_existing = 1 then case when c.lic is not null and (c.orig is null or c.permit_date is null or c.orig <= c.permit_date) then 0 else 1 end
                   when g.n_existing = 0 then case when c.lic is not null then 0 else 1 end
                   else 0 end,
              c.orig nulls last, c.lic
  )
  select parid, taxyr, permit_num, contractor_raw,
         case when match_state in ('licence_linked_by_name','licence_issued_after_permit') then lic end as license_number,
         business_name, license_status_now, original_date, expiry_date, permit_date,
         match_state as match_basis,
         (match_state = 'ambiguous') as match_ambiguous,
         match_state,
         case when match_state = 'licence_issued_after_permit' then orig end as first_issued,
         case when match_state = 'business_registration_only' then 'business_registration' else 'licence' end as record_kind,
         n_lic as candidate_licences, n_existing as candidate_licences_existing
    from pick;
  alter table permit_contractor_match_resolved add primary key (parid, taxyr, permit_num),
    add constraint pcmr_state_check check (match_state in ('licence_linked_by_name','ambiguous','licence_issued_after_permit','business_registration_only')),
    add constraint pcmr_linked_has_licence check (match_state not in ('licence_linked_by_name','licence_issued_after_permit') or license_number is not null),
    add constraint pcmr_only_linked_state_links check (match_state in ('licence_linked_by_name','licence_issued_after_permit') or license_number is null);
  grant select on permit_contractor_match_resolved to service_role, authenticated, consumer_report_readonly;
  comment on table permit_contractor_match_resolved is
    'Permit -> licence link by NAME (170a, ruling 825). match_state: licence_linked_by_name (exactly one licence of that business name existed at the permit date - a link by name only, never "performed under"), ambiguous (several), licence_issued_after_permit (never linked), business_registration_only (QB, no licence). Measured 2026-09-30: 17% of named permits reach a licence; ~5x chance locality; issue-date floor enforced.';
  analyze permit_contractor_match_resolved;
  return (select jsonb_object_agg(match_state, n) from (select match_state, count(*) n from permit_contractor_match_resolved group by 1) s);
end $$;
revoke all on function public.resolve_permit_contractor_match() from public, anon, authenticated;
grant execute on function public.resolve_permit_contractor_match() to service_role;

create or replace function public.refresh_permit_contractor_match() returns jsonb
language plpgsql security definer set search_path to 'public' as $$
declare new_raw integer; resolved jsonb;
begin
  insert into permit_contractor_match (parid,taxyr,permit_num,contractor_raw,license_number,business_name,license_status_now,original_date,expiry_date,matched_at)
  select p."PARID",p."TAXYR",p."NUM",p."CONTRACTOR",i.license_number,i.business_name,i.license_status,i.original_date,i.expiry_date,now()
    from volusia_cama_permits p
    join contractor_name_index i on i.norm_name = normalize_name(p."CONTRACTOR")
   where nullif(trim(p."CONTRACTOR"),'') is not null and p."NUM" is not null and p."PARID" is not null and p."TAXYR" is not null
     and not exists (select 1 from permit_contractor_match m where m.parid=p."PARID" and m.taxyr=p."TAXYR" and m.permit_num=p."NUM");
  get diagnostics new_raw = row_count;
  resolved := resolve_permit_contractor_match();
  return jsonb_build_object('new_raw_matches', new_raw, 'resolved_by_state', resolved);
end $$;
revoke all on function public.refresh_permit_contractor_match() from public, anon, authenticated;
grant execute on function public.refresh_permit_contractor_match() to service_role;

select public.resolve_permit_contractor_match();

-- 5-6. The served object, in the SAME transaction as the rebuild (so no moment serves the old wording over
-- the new states). Anchored patch of get_parcel_permit_facts.
do $$
declare d text; s int; e int; blk text;
begin
  d := pg_get_functiondef('public.get_parcel_permit_facts'::regproc);
  if position('m.license_number, m.business_name, m.match_ambiguous,' in d) = 0 then raise exception '170a: CTE anchor not found'; end if;
  d := replace(d, 'm.license_number, m.business_name, m.match_ambiguous,',
                  'm.license_number, m.business_name, m.match_ambiguous, m.match_state, m.first_issued,');
  s := position('''contractor_licence'', (SELECT CASE' in d);
  if s = 0 then raise exception '170a: contractor_licence anchor not found'; end if;
  e := s + position('END FROM c)' in substr(d, s)) + length('END FROM c)') - 1;
  if position('contractor_licence_in_register_file' in substr(d, s, e - s)) = 0 then raise exception '170a: block is not the 167a block'; end if;
  blk := $b$'contractor_licence', (SELECT CASE
              WHEN c.match_state IS NULL THEN NULL
              WHEN c.match_state = 'licence_linked_by_name' THEN (SELECT jsonb_build_object(
                'predicate','contractor_name_linked_to_register', 'link','name_only', 'matched', true,
                'contractor_as_recorded', c.contractor,
                'license_number', c.license_number, 'business_name', c.business_name,
                'match_basis', 'business name only (the permit carries no licence number)',
                'register_file_date', rf.register_file_date, 'register_file_state', rf.register_file_state,
                'register_note',
                  'The county recorded "'||coalesce(c.contractor,'(no name)')||'" as the contractor on this permit. A business of that name in our register, '
                  ||coalesce(c.business_name,'(name not held)')||', holds DBPR licence '||c.license_number||', '
                  ||CASE WHEN rf.register_file_state = 'in_latest_file' AND rf.register_file_date IS NOT NULL
                           THEN 'listed as current in the Florida construction licence file dated '||to_char(rf.register_file_date,'FMDD Mon YYYY')
                         WHEN rf.register_file_state = 'absent_from_latest_file' AND rf.register_file_date IS NOT NULL
                           THEN 'listed in the Florida construction licence file dated '||to_char(rf.register_file_date,'FMDD Mon YYYY')||' but not in the latest file'
                         ELSE 'in the Florida construction licence file we hold' END
                  ||'. The two are linked by name only: we have not established that this permit was carried out under that licence.',
                'active_at_permit_date', NULL, 'checked_as_of', NULL, 'finding', NULL, 'corroboration', NULL,
                'source','permit_contractor_match_resolved + DBPR contractors','source_tier','analysis_inference')
              FROM (SELECT (SELECT k.register_file_date FROM public.contractors k WHERE k.license_number = c.license_number ORDER BY k.register_file_date DESC NULLS LAST LIMIT 1) AS register_file_date,
                           (SELECT k.register_file_state FROM public.contractors k WHERE k.license_number = c.license_number ORDER BY k.register_file_date DESC NULLS LAST LIMIT 1) AS register_file_state) rf)
              WHEN c.match_state = 'ambiguous' THEN jsonb_build_object(
                'predicate','contractor_name_linked_to_register', 'link','none', 'matched', false, 'contractor_as_recorded', c.contractor,
                'note', 'The county recorded "'||coalesce(c.contractor,'(no name)')||'" as the contractor. More than one licence in our register is held by a business of that name, so we do not link this permit to any one of them.')
              WHEN c.match_state = 'licence_issued_after_permit' THEN jsonb_build_object(
                'predicate','contractor_name_linked_to_register', 'link','none', 'matched', false, 'contractor_as_recorded', c.contractor,
                'license_number', c.license_number, 'first_issued', c.first_issued,
                'note', 'A business of that name in our register holds DBPR licence '||c.license_number
                        ||', but that licence was first issued on '||coalesce(to_char(c.first_issued,'FMDD Mon YYYY'),'a later date')
                        ||', after this permit was filed, so it cannot be the licence this work was done under. We do not link them.')
              WHEN c.match_state = 'business_registration_only' THEN jsonb_build_object(
                'predicate','contractor_name_linked_to_register', 'link','none', 'matched', false, 'contractor_as_recorded', c.contractor,
                'note', 'A business of that name appears in our register only as a business registration with no licence number, so there is no licence to link this permit to.')
              ELSE NULL
            END FROM c)$b$;
  d := substr(d, 1, s - 1) || blk || substr(d, e + 1);
  if position('contractor_licence_in_register_file' in d) > 0 or position('matches DBPR licence' in d) > 0 then
    raise exception '170a: the 167a wording survived';
  end if;
  execute d;
end $$;

-- 799: the change and its log row in one transaction.
insert into public.moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via)
select now(), 'cc', 'build_agent', 'rebuild_served_link', 'get_parcel_permit_facts + permit_contractor_match_resolved',
  array['contractor_licence','permit_contractor_match_resolved','contractors.record_kind'],
  jsonb_build_object('resolved', 191536, 'qb_no_licence_served_matched_true', 37944, 'with_licence', 153592,
                     'unambiguous_single_licence', 76071, 'of_which_licence_issued_after_permit', 11792,
                     'false_ambiguity_one_licence', 13229, 'wording', 'The contractor name on the permit matches DBPR licence X ...',
                     'measured', '2026-09-30, 809 5b'),
  (select jsonb_build_object('by_state', jsonb_object_agg(match_state, n)) from (select match_state, count(*) n from permit_contractor_match_resolved group by 1) s),
  'Ruling 825 items 1-6 on the 809 5b measurement: QB registrations are not licence matches; a licence issued after a permit is never linked; the choice among licences keeps only the issue-date floor; ambiguity counts distinct licences; matched:true only with a licence; the served sentence states the county record and the register record separately, linked by name only.',
  'migration 170a';

do $$
declare f jsonb; x jsonb; st text; n int;
begin
  for st in select unnest(array['licence_linked_by_name','ambiguous','licence_issued_after_permit','business_registration_only']) loop
    select e->'contractor_licence' into x
      from (select parid, permit_num from permit_contractor_match_resolved where match_state = st limit 1) r
      join volusia_parcels_govt_source vp on vp.altkey::bigint::text = r.parid
      cross join lateral jsonb_array_elements(get_parcel_permit_facts(74, vp.pid)->'permits') e
     where e->>'permit_number' = r.permit_num limit 1;
    if x is null then raise exception '170a: could not exercise state %', st; end if;
    if st = 'licence_linked_by_name' then
      if (x->>'matched')::boolean is not true or x->>'license_number' is null or coalesce(x->>'register_note','') not like '%linked by name only%' then
        raise exception '170a: linked state wrong: %', x; end if;
    else
      if (x->>'matched')::boolean is not false or coalesce(x->>'note','') = '' then raise exception '170a: % state wrong: %', st, x; end if;
    end if;
  end loop;
  f := get_parcel_permit_facts(74, '633001001890');
  if (f->>'count')::int < 1 then raise exception '170a: founding parcel lost permits'; end if;
  select count(*) into n from permit_contractor_match_resolved where match_state = 'licence_linked_by_name' and license_number is null;
  if n > 0 then raise exception '170a: linked without licence: %', n; end if;
  if not has_function_privilege('anon', 'public.get_parcel_permit_facts(numeric,text)', 'execute') then raise exception '170a: execute grant lost'; end if;
  if (select count(*) from contractors where record_kind = 'business_registration') <> 6669 then raise exception '170a: record_kind count drifted'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '170a: register grants lost'; end if;
end $$;
