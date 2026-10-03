-- 210f - the rate limiter is persisted (ruling 975; audit 971 B7).
--
-- lib/rateLimit.ts kept its counts in a module-scope Map. On Vercel serverless that is PER INSTANCE: instances start
-- and stop constantly and concurrent requests fan out across them, so "5 per 10 minutes" on /api/register limited one
-- warm instance and nothing else. Its own header said "For production, swap the store". 975: "A limiter whose state
-- dies with the process limits nothing that matters."
-- rate_limit_take(key, max, window) counts in the database, under a per-key transaction advisory lock so two
-- concurrent requests cannot both read "under the limit". Old events for the key are pruned as it goes. Service role
-- only - the routes call it with the secret key. Keys are '<route>:<ip>' or '<route>:actor:<email>'.
-- IP is a brake, not a gate (975: Murphy's own test IP is T-Mobile carrier NAT, shared by thousands); per-ACCOUNT keys
-- are added for the claimed-detail writes.

create table if not exists public.rate_limit_event (
  key text not null,
  at timestamptz not null default now()
);
create index if not exists rate_limit_event_key_at on public.rate_limit_event (key, at);
alter table public.rate_limit_event enable row level security;
revoke all on public.rate_limit_event from public, anon, authenticated;
comment on table public.rate_limit_event is '210f: one row per counted request, by key, pruned as the window passes. The persisted store behind lib/rateLimit takeLimit().';

create or replace function public.rate_limit_take(p_key text, p_max int, p_window_seconds int)
returns jsonb language plpgsql set search_path to 'public', 'pg_temp' as $$
declare n int; oldest timestamptz;
begin
  perform pg_advisory_xact_lock(hashtextextended('rate_limit:' || p_key, 0));
  delete from rate_limit_event where key = p_key and at < now() - make_interval(secs => p_window_seconds);
  select count(*), min(at) into n, oldest from rate_limit_event where key = p_key;
  if n >= p_max then
    return jsonb_build_object('allowed', false, 'remaining', 0,
      'reset_at', to_char((oldest + make_interval(secs => p_window_seconds)) at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'));
  end if;
  insert into rate_limit_event (key) values (p_key);
  return jsonb_build_object('allowed', true, 'remaining', p_max - n - 1);
end $$;
comment on function public.rate_limit_take(text, int, int) is '210f: persisted rate limit - counts p_key in the last p_window_seconds under a per-key lock; allowed while under p_max.';
revoke all on function public.rate_limit_take(text, int, int) from public, anon, authenticated;
grant execute on function public.rate_limit_take(text, int, int) to service_role;

do $$
declare j jsonb; i int; allowed int := 0;
begin
  for i in 1..7 loop
    j := public.rate_limit_take('cc-210f-test', 5, 600);
    if (j->>'allowed')::boolean then allowed := allowed + 1; end if;
  end loop;
  if allowed <> 5 then raise exception '210f: 7 takes against a limit of 5 allowed %', allowed; end if;
  if (j->>'allowed')::boolean or j->>'reset_at' is null then raise exception '210f: refusal has no reset time: %', j; end if;
  delete from public.rate_limit_event where key = 'cc-210f-test';
  if has_function_privilege('anon', 'public.rate_limit_take(text,int,int)', 'EXECUTE') then raise exception '210f: anon can take'; end if;
  raise notice '210f: 7 takes, 5 allowed, refusal %', j;
end $$;
