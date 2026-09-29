-- 158d: the only form of temporary exception allowed - a MEASURED condition, not a promise (ruling 770).
--
-- Until the classifier pre-filter exists, an unchecked photo may reach the review page (marked unchecked)
-- ONLY WHILE EVERY APPROVED CLAIM BELONGS TO THE OPERATOR. Uploading needs an approved claim, so while
-- that holds the only person who can put an image in front of the reviewer is the reviewer. The moment a
-- claim is approved for anyone else, the path closes by itself - nobody has to remember to switch it off.
--
-- operator_account: the operator's own login emails. One row, verified against the claim table: the only
-- approved claim today is murphy.oneal@gmail.com. Adding an address here is an action with an author.
-- unchecked_review_open(): evaluated on every upload; its answer is recorded in scan_result.policy.

create table public.operator_account (
  email        text primary key check (email = lower(btrim(email))),
  basis        text not null,
  recorded_by  text not null,
  recorded_at  timestamptz not null default now()
);
alter table public.operator_account enable row level security;
revoke all on public.operator_account from anon, authenticated;
insert into public.operator_account (email, basis, recorded_by) values
('murphy.oneal@gmail.com', 'the operator''s own account: the platform owner''s login email, and the requester on the only approved claim (the ZZ test fixture)', 'cc (ruling 770)');

insert into public.column_writer (table_name, column_name, writer_class, reason, classified_by)
select 'operator_account', a.attname, 'ours', 'the operator''s own accounts (158d)', 'cc'
  from pg_attribute a where a.attrelid = 'public.operator_account'::regclass and a.attnum > 0 and not a.attisdropped;

create or replace function public.unchecked_review_open() returns jsonb
language sql stable security definer set search_path = public as $f$
  with others as (
    select count(*) filter (where k = 'contractor') as contractor, count(*) filter (where k = 'agent') as agent from (
      select 'contractor' k from claim_requests where status = 'approved' and coalesce(lower(btrim(requester_email)), '') not in (select email from operator_account)
      union all
      select 'agent' from agent_claim_request where status = 'approved' and coalesce(lower(btrim(requester_email)), '') not in (select email from operator_account)
    ) x)
  select jsonb_build_object(
    'open', (contractor + agent) = 0,
    'approved_claims_not_operator', contractor + agent,
    'rule', 'unchecked photos may reach review only while every approved claim belongs to an operator_account email (ruling 770)',
    'evaluated_at', now())
  from others
$f$;
revoke all on function public.unchecked_review_open() from public, anon, authenticated;
grant execute on function public.unchecked_review_open() to service_role;

do $m$ declare r jsonb; begin
  r := public.unchecked_review_open();
  if not (r->>'open')::boolean then raise exception '158d: expected open today (only the operator''s claim is approved): %', r; end if;
  -- negative control, with no side effects: without the operator row, the operator's own approved claim
  -- counts as someone else's, and the path must close. Rolled back by the sub-transaction.
  begin
    delete from public.operator_account where email = 'murphy.oneal@gmail.com';
    r := public.unchecked_review_open();
    if (r->>'open')::boolean then raise exception 'CONTROL_FAILED'; end if;
    raise exception 'CONTROL_OK';
  exception when others then
    if sqlerrm = 'CONTROL_FAILED' then raise exception '158d: a non-operator approved claim did NOT close the path'; end if;
    if sqlerrm <> 'CONTROL_OK' then raise exception '158d: control could not run: %', sqlerrm; end if;
  end;
  if not (public.unchecked_review_open()->>'open')::boolean then raise exception '158d: control leaked'; end if;
end $m$;
