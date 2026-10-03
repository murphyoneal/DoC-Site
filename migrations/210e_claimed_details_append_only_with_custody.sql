-- 210e - claimed details are append-only, and every version carries its custody (rulings 973, 974, 975).
--
-- Murphy's law: "We do NOT change the government record unless it is done by the person who owns the business fully
-- traceable." The claimed layer (business_profile) held only updated_by / updated_at - LAST WRITER, not a trail.
-- submission_event recorded THAT a profile_save happened (actor, IP with ip_basis, user agent) but nothing linked it to
-- WHAT changed, so a disputed specialty could not be shown appearing, when, or under which save, and 20 saves from one
-- address could not be reverted (975: "custody of the event is not custody of the value").
-- After this:
--   business_profile_version   one row per changed field per write: old_value, new_value (jsonb), the custody that
--                              authorised it - EXACTLY ONE of submission_event_id (an owner's save, FK) or operator_actor
--                              (+ operator_basis, a moderator's action) - and the approved claim it rests on. Append-only:
--                              no grants to browser roles, and a trigger refuses UPDATE and DELETE on it.
--   trg on business_profile    writes the versions, and REFUSES any insert/update that carries no custody. A save that
--                              was not custody-logged cannot land - enforcement by schema, not a convention that a route
--                              remembers to call logSubmission (it used to log AFTER saving, best-effort).
--   business_profile_save / business_logo_set  take p_submission_event_id; it must name a submission_event of the right
--                              kind, actor and subject, recorded in the last 10 minutes, or the save is refused.
--   operator_unpublish_field   records its operator custody (actor, basis) before writing.
-- The one existing row (the ZZ test fixture's profile, 3 saves on 2026-09-29) is backfilled as a single version marked
-- reconstructed - never presented as a record.
-- Coupling: the app routes must open the custody record first and pass its id (same PR). Until that deploys, an owner
-- save is refused - harmless today: no business outside the test fixture has an approved claim (measured).

set statement_timeout = 0;

create table if not exists public.business_profile_version (
  id bigint generated always as identity primary key,
  business_id uuid not null,
  field text not null,
  old_value jsonb,
  new_value jsonb,
  submission_event_id bigint references public.submission_event(id),
  operator_actor text,
  operator_basis text,
  claim_request_id uuid,
  reconstructed boolean not null default false,  -- our own state, never a fact about the business
  at timestamptz not null default now(),
  constraint bpv_exactly_one_custody check ((submission_event_id is not null) <> (operator_actor is not null) or reconstructed)
);
create index if not exists business_profile_version_business on public.business_profile_version (business_id, at);
create index if not exists business_profile_version_event on public.business_profile_version (submission_event_id);
alter table public.business_profile_version enable row level security;
revoke all on public.business_profile_version from public, anon, authenticated;
comment on table public.business_profile_version is
  '210e (rulings 973-975): append-only history of every claimed-detail change - old and new value, and the custody that authorised it (an owner''s submission_event, or a moderator''s actor + basis). The remedy for abuse is a query over this table. Never updated or deleted.';

create or replace function public.business_profile_version_immutable() returns trigger language plpgsql as $$
begin raise exception 'business_profile_version is append-only (210e): % refused', tg_op; end $$;
drop trigger if exists business_profile_version_immutable on public.business_profile_version;
create trigger business_profile_version_immutable before update or delete on public.business_profile_version
  for each row execute function public.business_profile_version_immutable();

create or replace function public.business_profile_custody() returns trigger language plpgsql set search_path to 'public', 'pg_temp' as $$
declare ev bigint := nullif(current_setting('app.submission_event_id', true), '')::bigint;
        op text := nullif(current_setting('app.operator_actor', true), '');
        basis text := nullif(current_setting('app.operator_basis', true), '');
        claim uuid; k text; o jsonb; n jsonb;
begin
  if ev is null and op is null then
    raise exception 'business_profile write refused: no custody (210e) - an owner save must carry a submission_event, a moderator action its actor';
  end if;
  select cr.id into claim from claim_requests cr join businesses b on b.canonical_contractor_id = cr.contractor_id
   where b.id = NEW.business_id and cr.status = 'approved' order by cr.reviewed_at desc nulls last limit 1;
  o := case when tg_op = 'UPDATE' then to_jsonb(OLD) else '{}'::jsonb end;
  n := to_jsonb(NEW);
  for k in select jsonb_object_keys(n) loop
    continue when k in ('business_id', 'updated_at', 'updated_by', 'logo_updated_at');
    if (o -> k) is distinct from (n -> k) then
      insert into business_profile_version (business_id, field, old_value, new_value, submission_event_id, operator_actor, operator_basis, claim_request_id)
      values (NEW.business_id, k, o -> k, n -> k, ev, case when ev is null then op end, case when ev is null then basis end, claim);
    end if;
  end loop;
  return NEW;
end $$;
drop trigger if exists business_profile_custody on public.business_profile;
create trigger business_profile_custody before insert or update on public.business_profile
  for each row execute function public.business_profile_custody();

-- custody check shared by the two owner-facing writers
create or replace function public._require_submission_event(p_id bigint, p_kind text, p_email text, p_ref text) returns void
language plpgsql set search_path to 'public', 'pg_temp' as $$
begin
  if p_id is null or not exists (
       select 1 from submission_event e where e.id = p_id and e.kind = p_kind
          and lower(coalesce(e.actor_email,'')) = lower(coalesce(p_email,'')) and e.subject_ref = p_ref
          and e.at > now() - interval '10 minutes') then
    raise exception 'custody required (210e): no matching % submission_event for this save', p_kind;
  end if;
  perform set_config('app.submission_event_id', p_id::text, true);
end $$;
revoke all on function public._require_submission_event(bigint, text, text, text) from public, anon, authenticated;

-- business_profile_save / business_logo_set: one more parameter, checked first. The signature changes, so the old
-- function is dropped (an extra overload would make PostgREST's named-argument call ambiguous). Both are service-role only.
do $$
declare d text; a1 text; a2 text;
begin
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = 'public.business_profile_save(text,text,jsonb)'::regprocedure;
  d := pg_get_functiondef('public.business_profile_save(text,text,jsonb)'::regprocedure);
  if position('p_email text, p jsonb)' in d) = 0 then raise exception '210e: business_profile_save signature anchor missing'; end if;
  d := replace(d, 'p_email text, p jsonb)', 'p_email text, p jsonb, p_submission_event_id bigint DEFAULT NULL)');
  d := regexp_replace(d, '(\$function\$\s*\n?\s*declare)', E'\\1', 'i');
  if position(E'BEGIN\n' in upper(d)) = 0 and position(E'begin\n' in d) = 0 then raise exception '210e: business_profile_save begin anchor missing'; end if;
  d := regexp_replace(d, E'\\m(begin)\\M\\s*\\n', E'begin\n  perform public._require_submission_event(p_submission_event_id, ''profile_save'', p_email, p_slug);  -- 210e\n', 'i');
  execute 'drop function public.business_profile_save(text,text,jsonb)';
  execute d;
  if a1 like '%service_role=X%' then grant execute on function public.business_profile_save(text,text,jsonb,bigint) to service_role; end if;

  select coalesce(proacl::text,'') into a1 from pg_proc where oid = 'public.business_logo_set(text,text,text)'::regprocedure;
  d := pg_get_functiondef('public.business_logo_set(text,text,text)'::regprocedure);
  if position('p_logo_path text)' in d) = 0 then raise exception '210e: business_logo_set signature anchor missing'; end if;
  d := replace(d, 'p_logo_path text)', 'p_logo_path text, p_submission_event_id bigint DEFAULT NULL)');
  d := regexp_replace(d, E'\\m(begin)\\M\\s*\\n', E'begin\n  perform public._require_submission_event(p_submission_event_id, case when p_logo_path is null then ''logo_remove'' else ''logo_upload'' end, p_email, p_slug);  -- 210e\n', 'i');
  execute 'drop function public.business_logo_set(text,text,text)';
  execute d;
  if a1 like '%service_role=X%' then grant execute on function public.business_logo_set(text,text,text,bigint) to service_role; end if;

  -- operator_unpublish_field: the moderator's custody, set before its writes
  d := pg_get_functiondef('public.operator_unpublish_field(uuid,text,bigint,text,text,inet)'::regprocedure);
  if position('perform _operator_check(p_actor, p_basis);' in d) = 0 then raise exception '210e: operator anchor missing'; end if;
  d := replace(d, 'perform _operator_check(p_actor, p_basis);', 'perform _operator_check(p_actor, p_basis);
  perform set_config(''app.operator_actor'', p_actor, true);   -- 210e: moderator custody for business_profile_version
  perform set_config(''app.operator_basis'', p_basis, true);');
  execute d;
end $$;

-- backfill: the one existing profile (test fixture), marked reconstructed
insert into public.business_profile_version (business_id, field, old_value, new_value, reconstructed, at)
select p.business_id, 'reconstructed_initial_state', null, to_jsonb(p) - 'business_id', true, coalesce(p.updated_at, now())
  from public.business_profile p
 where not exists (select 1 from public.business_profile_version v where v.business_id = p.business_id);

-- detection: no claimed-detail value without custody; history never altered
insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('claimed-detail-without-custody',
  'A claimed business detail can be written without a custody record, or its version history can be altered',
  current_date, 'rulings 973-975 (business_profile was last-writer-wins; custody of the event was not custody of the value)',
  'access_control', 'blocking',
$q$select (exists (select 1 from pg_trigger where tgname = 'business_profile_custody' and tgenabled <> 'D')
        and exists (select 1 from pg_trigger where tgname = 'business_profile_version_immutable' and tgenabled <> 'D')
        and not has_table_privilege('authenticated', 'public.business_profile_version', 'UPDATE')
        and not has_table_privilege('anon', 'public.business_profile_version', 'SELECT')
        and not exists (select 1 from public.business_profile p
                         where not exists (select 1 from public.business_profile_version v where v.business_id = p.business_id))) as ok,
       (select count(*) from public.business_profile p where not exists (select 1 from public.business_profile_version v where v.business_id = p.business_id)) as row_count,
       (select count(*) from public.business_profile) + 2 as population$q$,
  'clean', 'claimed profiles (each must have at least one version) plus the 2 enforcing triggers',
  'Catalog half: both triggers present and enabled, version table closed to browser roles. Data half: every claimed profile has a version. The behavioural proof (a write with no custody is refused) is in 210e itself.',
  'active', 'ours', 'Owner writes pass a submission_event id; moderator writes set operator custody; never disable the triggers.',
  'none', 'blocking');

do $$
declare refused boolean := false; ev bigint; n int; fx text; fx_bid uuid;
begin
  -- a write with no custody is refused
  begin
    update public.business_profile set description = description where business_id = (select business_id from public.business_profile limit 1);
    update public.business_profile set website = coalesce(website,'') || '' where business_id = (select business_id from public.business_profile limit 1);
    insert into public.business_profile (business_id) values (gen_random_uuid());
  exception when others then
    refused := sqlerrm like '%no custody%';
  end;
  if not refused then raise exception '210e: a write with no custody was not refused'; end if;
  -- the history cannot be edited
  refused := false;
  begin
    update public.business_profile_version set new_value = '"x"' where id = (select min(id) from public.business_profile_version);
  exception when others then refused := sqlerrm like '%append-only%'; end;
  if not refused then raise exception '210e: version history was editable'; end if;
  -- an operator write is versioned with its actor (rolled back)
  begin
    perform set_config('app.operator_actor', 'cc-210e-test', true);
    select business_id into fx_bid from public.business_profile limit 1;
    update public.business_profile set publish_phone = not coalesce(publish_phone, false) where business_id = fx_bid;
    select count(*) into n from public.business_profile_version where operator_actor = 'cc-210e-test';
    if n < 1 then raise exception '210e: operator write not versioned'; end if;
    raise exception 'op_ok';
  exception when raise_exception then if sqlerrm <> 'op_ok' then raise; end if;
  end;
  if current_setting('app.operator_actor', true) = 'cc-210e-test' then perform set_config('app.operator_actor', '', true); end if;
  if not exists (select 1 from pg_proc where oid = 'public.business_profile_save(text,text,jsonb,bigint)'::regprocedure) then raise exception '210e: new save signature missing'; end if;
  if exists (select 1 from pg_proc where proname = 'business_profile_save' and pronargs = 3) then raise exception '210e: old save overload remains'; end if;
  if has_function_privilege('anon', 'public.business_profile_save(text,text,jsonb,bigint)', 'EXECUTE') then raise exception '210e: save is anon-callable'; end if;
  raise notice '210e: no-custody write refused; history immutable; operator write versioned; % reconstructed versions', (select count(*) from public.business_profile_version where reconstructed);
end $$;
