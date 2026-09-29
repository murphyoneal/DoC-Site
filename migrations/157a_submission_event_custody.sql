-- 157a: chain of custody for what people submit (ruling 762, part 2).
--
-- The appeal process turns on telling "the contractor did this" from "someone with their password
-- did this". Until now ip was recorded for assistant queries, scan events and version acceptance,
-- and NOT for uploads, claims, profile saves or self-registration.
--
-- One append-only row per submission: what kind, which subject, whose session or stated email, the
-- IP and user agent the request came from, the outcome, when. An incident record, not analytics:
-- it is never rendered, nothing public reads it, and anon/authenticated hold no grant. Written by the
-- server routes with the service key (RLS on, no policies). Classified 'ours' in column_writer.
-- The privacy notice names it in the same commit.

create table public.submission_event (
  id           bigserial primary key,
  kind         text not null check (kind in ('work_upload', 'logo_upload', 'logo_remove', 'contractor_claim',
                                             'agent_claim', 'profile_save', 'agent_profile_save', 'self_registration')),
  subject_ref  text,
  actor_email  text,
  ip           inet,
  user_agent   text check (user_agent is null or length(user_agent) <= 400),
  outcome      text,
  at           timestamptz not null default now()
);
create index submission_event_subject_idx on public.submission_event (subject_ref, at desc);
alter table public.submission_event enable row level security;
revoke all on public.submission_event from anon, authenticated;
comment on table public.submission_event is
  'Chain of custody (762 part 2): one row per upload, claim, profile save and self-registration - kind, subject, the session or stated email, request IP and user agent, outcome, time. Append-only incident record for appeals; never rendered, no anon/authenticated grant. Privacy notice names it.';

insert into public.column_writer (table_name, column_name, writer_class, reason, classified_by) values
('submission_event','id','ours','key','cc'),
('submission_event','kind','ours','which submission path wrote the row','cc'),
('submission_event','subject_ref','ours','the slug, licence or id the submission was about','cc'),
('submission_event','actor_email','ours','the signed-in session email, or the email given on a signed-out form; recorded by us, never published','cc'),
('submission_event','ip','ours','request IP as the edge reported it; incident record only','cc'),
('submission_event','user_agent','ours','request user agent, truncated to 400; incident record only','cc'),
('submission_event','outcome','ours','what the route returned (saved / refused:<reason> / received ...)','cc'),
('submission_event','at','ours','when','cc');

do $m$ begin
  if has_table_privilege('anon', 'public.submission_event', 'select') or has_table_privilege('authenticated', 'public.submission_event', 'select') then
    raise exception '157a: submission_event is readable by anon/authenticated'; end if;
  if (select count(*) from public.column_writer where table_name = 'submission_event') <>
     (select count(*) from pg_attribute where attrelid = 'public.submission_event'::regclass and attnum > 0 and not attisdropped) then
    raise exception '157a: submission_event not fully classified'; end if;
end $m$;
