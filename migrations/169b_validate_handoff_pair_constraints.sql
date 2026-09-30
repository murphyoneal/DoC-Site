-- 169b - ruling 823: both sides of the register are consistent (measured 0/0 on 2026-09-30), so the 169a
-- constraints are validated for every existing row. From here the register cannot hold a disagreeing pair.
-- Applied 2026-09-30.
alter table public.agent_handoff validate constraint agent_handoff_done_pair;
alter table public.agent_handoff validate constraint agent_handoff_unread_pair;
comment on constraint agent_handoff_done_pair on public.agent_handoff is
  'Ruling 815: status actioned/superseded <=> actioned_at set. VALIDATED 2026-09-30 (169b) after both inboxes were evidence-tested.';
do $$ begin
  if exists (select 1 from pg_constraint where conname in ('agent_handoff_done_pair','agent_handoff_unread_pair') and not convalidated) then
    raise exception '169b: a constraint did not validate'; end if;
end $$;
