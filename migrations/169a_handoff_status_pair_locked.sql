-- 169a - the bus's two representations of "done" are locked together (ruling 815).
--
-- agent_handoff carried status AND actioned_at/read_at with nothing keeping them agreeing: 245 rows disagreed on
-- 2026-09-30, and bulk timestamps (34 rows closed in one minute on 08-15) hid 63 cc rows that were not done.
-- The cc side has been evidence-tested and is now fully consistent (0 disagreeing pairs). claude's inbox still
-- holds 14 disagreeing pairs (133,138,152,156,159,161,163,274,357,358,369,370,371,386) and 7 unread-with-read_at
-- rows, which only claude can evidence - so both constraints are added NOT VALID (enforced on every write from
-- now on) and are to be VALIDATED once those rows are resolved. No row is forced to lie to satisfy a constraint.

-- handoff_mark was itself a source of drift: 'superseded' never set actioned_at, and going back to 'read' left a
-- stale actioned_at. It now writes a consistent pair by construction.
create or replace function public.handoff_mark(p_id bigint, p_status text)
returns void language sql security definer set search_path to 'public' as $$
  update agent_handoff
     set status      = p_status,
         read_at     = case when p_status = 'unread' then null else coalesce(read_at, now()) end,
         actioned_at = case when p_status in ('actioned','superseded') then coalesce(actioned_at, now()) else null end
   where id = p_id
$$;
revoke all on function public.handoff_mark(bigint, text) from public, anon, authenticated;
grant execute on function public.handoff_mark(bigint, text) to service_role;

alter table public.agent_handoff
  add constraint agent_handoff_done_pair
    check ((status in ('actioned','superseded')) = (actioned_at is not null)) not valid,
  add constraint agent_handoff_unread_pair
    check (status <> 'unread' or read_at is null) not valid;

comment on constraint agent_handoff_done_pair on public.agent_handoff is
  'Ruling 815: status actioned/superseded <=> actioned_at set. NOT VALID until claude resolves its 14 disagreeing rows; then VALIDATE.';

insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('handoff-status-pair-disagrees',
  'An agent_handoff row''s status disagrees with its actioned_at / read_at - the register cannot say what is done',
  'key_integrity', 'blocking',
  $d$select (count(*) = 0) as ok from agent_handoff
      where (status in ('actioned','superseded')) <> (actioned_at is not null) or (status = 'unread' and read_at is not null)$d$,
  'Ruling 815, the first 811-style disagreement check (two stores answering one question). Red today on claude''s 14 + 7 rows by design; green once they are resolved, at which point agent_handoff_done_pair / _unread_pair get VALIDATED. A timestamp is never evidence of completion on its own.');

do $$
declare rid bigint; st text; aa timestamptz;
begin
  -- (a) the constraint refuses a disagreeing write on any row, new or old
  begin
    update agent_handoff set actioned_at = null where id = (select id from agent_handoff where to_agent='cc' and status='actioned' limit 1);
    raise exception '169a: CONTROL_FAILED - actioned row lost its timestamp';
  exception when others then
    if sqlerrm like '%CONTROL_FAILED%' then raise; end if;
    if sqlerrm not like '%agent_handoff_done_pair%' then raise exception '169a: unexpected refusal: %', sqlerrm; end if;
  end;
  -- (b) handoff_mark keeps the pair consistent through every transition (rolled back)
  begin
    insert into agent_handoff (from_agent, to_agent, kind, subject, body) values ('cc','cc','note','169a control','control row, rolled back') returning id into rid;
    perform handoff_mark(rid, 'superseded'); select status, actioned_at into st, aa from agent_handoff where id = rid;
    if st <> 'superseded' or aa is null then raise exception '169a: superseded pair wrong'; end if;
    perform handoff_mark(rid, 'read');       select status, actioned_at into st, aa from agent_handoff where id = rid;
    if st <> 'read' or aa is not null then raise exception '169a: read pair wrong'; end if;
    perform handoff_mark(rid, 'actioned');   select status, actioned_at into st, aa from agent_handoff where id = rid;
    if st <> 'actioned' or aa is null then raise exception '169a: actioned pair wrong'; end if;
    raise exception 'ROLLBACK_ME';
  exception when others then
    if sqlerrm <> 'ROLLBACK_ME' then raise; end if;
  end;
  -- (c) the cc side is clean; the detection is red only on claude's rows
  if exists (select 1 from agent_handoff where to_agent='cc' and ((status in ('actioned','superseded')) <> (actioned_at is not null) or (status='unread' and read_at is not null))) then
    raise exception '169a: cc side not clean';
  end if;
  if has_function_privilege('anon','public.handoff_mark(bigint,text)','execute') then raise exception '169a: anon can mark the bus'; end if;
end $$;
