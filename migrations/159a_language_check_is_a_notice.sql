-- 159a: the language check stops being a gate and becomes a notice (ruling 761, Murphy: "It should be
-- noted but not stopped from production. You can send me a warning").
--
-- 1. NOTHING IS REFUSED. offensive_text() leaves the refusal paths of business_profile_save,
--    agent_profile_save and self_register. A save fails only on the real validations.
-- 2. WIDER MATCHING, because a false positive now costs a glance instead of refusing a real business.
--    language_flags() adds: look-alike letters (Cyrillic/Greek), more substitutions (! | 7 +), spelled-
--    out words ("f u c k", "F.U.C.K."), and stretched words ("fuuuck", "shiiiit" - runs of 3+ only).
--    Returns the rules that matched. MEASURED against the same 610,513 real contractor and agent names
--    as the old rule: 0 flagged. The first draft collapsed double letters and flagged 203 real surnames
--    (Zuniga, Brannigan, Finnigan, Fagot) - for those words the double letter IS the word, so collapsing
--    is limited to runs of 3+ and to the stems where stretching is pure evasion.
--    Known and accepted: substrings still flag "Scunthorpe" (both rules did); as a notice it costs a glance.
-- 3. EVERY FLAG IS A ROW: language_flag (append-only), deduplicated on subject + field + text so a re-save
--    of the same words does not re-notify. Notice delivery is recorded in language_flag_notice, 'failed'
--    with a reason when it does not send - never a silent success.
-- 4. The response is UNPUBLISH, NEVER EDIT; recorded in moderation_action. language_flag_state derives
--    flagged / reviewed_ok / unpublished from those actions.
-- 5. The flag is OURS and never renders publicly: no anon/authenticated grant on any of it.
-- 6. The save-lockout backlog item is retired by this: nothing blocks, so stored text cannot block an
--    unrelated save.

create or replace function public.language_flags(p text) returns text[]
language sql immutable set search_path = public as $f$
  with n as (
    select translate(translate(lower(coalesce(p,'')), 'аеорсхуіјѕԁοαινκυτ', 'aeopcxyijsdoaivkut'), '0134$@5!|7+', 'oieasasiltt') s
  ), j as (
    select s, regexp_replace(s, '(\m[a-z])[^a-z0-9]+(?=[a-z]\M)', '\1', 'g') joined from n
  ), toks as (
    select 'plain' src, regexp_replace(t, '[^a-z]', '', 'g') tok from j, regexp_split_to_table(j.s, '[^a-z0-9''*-]+') t
    union all
    select 'spelled_out', regexp_replace(t, '[^a-z]', '', 'g') from j, regexp_split_to_table(j.joined, '[^a-z0-9''*-]+') t where j.joined <> j.s
  ), m as (
    select src, tok, regexp_replace(tok, '(.)\1{2,}', '\1', 'g') tokc from toks where tok <> ''
  )
  select coalesce(array_agg(distinct r) filter (where r is not null), '{}') from (
    select case
      when (tok ~ '(fuck|fck|phuck|nigger|nigga|faggot|motherf|cunt)' and tok !~ '^d?acunt[io]') then src||':severe'
      when tokc <> tok and (tokc ~ '(fuck|fck|phuck|motherf|cunt)' and tokc !~ '^d?acunt[io]') then src||':severe_stretched'
      when tok ~ '^(asshole|assholes|bitch|bitches|bastard|bastards|pussy|slut|sluts|twat|wanker|whore|whores|shit|shits|shitty|bullshit|retard|retarded|cocksucker|dickhead)$' then src||':word'
      when tokc <> tok and tokc ~ '^(asshole|assholes|bitch|bitches|bastard|bastards|pussy|slut|sluts|twat|wanker|whore|whores|shit|shits|shitty|bullshit|retard|retarded|cocksucker|dickhead)$' then src||':word_stretched'
    end r from m) x
$f$;

create table public.language_flag (
  id             bigserial primary key,
  subject_table  text not null,
  subject_key    text not null,
  field          text not null,
  text_as_saved  text not null,
  text_hash      text not null,
  rules          text[] not null,
  flagged_at     timestamptz not null default now(),
  unique (subject_table, subject_key, field, text_hash)
);
create table public.language_flag_notice (
  id        bigserial primary key,
  flag_id   bigint not null references public.language_flag(id),
  channel   text not null,
  state     text not null check (state in ('sent', 'failed')),
  detail    text,
  at        timestamptz not null default now()
);
alter table public.language_flag enable row level security;
alter table public.language_flag_notice enable row level security;
revoke all on public.language_flag, public.language_flag_notice from anon, authenticated;
create trigger append_only_language_flag before update or delete on public.language_flag
  for each row execute function public.append_only_strict();
create trigger append_only_language_flag_notice before update or delete on public.language_flag_notice
  for each row execute function public.append_only_strict();

create view public.language_flag_state with (security_invoker = true) as
  select f.*, coalesce((
    select a.action from public.moderation_action a
     where a.target_table = 'language_flag' and f.id::text = any(a.target_ids)
       and a.action in ('language_flag_reviewed_ok', 'language_flag_unpublished')
     order by coalesce(a.occurred_at, a.recorded_at) desc limit 1), 'flagged') as state
  from public.language_flag f;
revoke all on public.language_flag_state from anon, authenticated;

-- Records the flags for the fields just saved; returns only NEW flags (the ones to tell Murphy about).
create or replace function public.record_language_flags(p_table text, p_key text, p_fields jsonb) returns jsonb
language plpgsql security definer set search_path = public as $f$
declare k text; v text; fl text[]; new_id bigint; out jsonb := '[]'::jsonb;
begin
  for k, v in select key, value from jsonb_each_text(coalesce(p_fields, '{}'::jsonb)) loop
    if nullif(btrim(coalesce(v, '')), '') is null then continue; end if;
    fl := language_flags(v);
    if cardinality(fl) = 0 then continue; end if;
    insert into language_flag (subject_table, subject_key, field, text_as_saved, text_hash, rules)
    values (p_table, p_key, k, v, md5(v), fl)
    on conflict (subject_table, subject_key, field, text_hash) do nothing
    returning id into new_id;
    if new_id is not null then
      out := out || jsonb_build_object('id', new_id, 'field', k, 'text', v, 'rules', to_jsonb(fl));
    end if;
    new_id := null;
  end loop;
  return out;
end $f$;
revoke all on function public.record_language_flags(text, text, jsonb) from public, anon, authenticated;
grant execute on function public.record_language_flags(text, text, jsonb) to service_role;

create or replace function public.record_language_flag_notice(p_flag_id bigint, p_channel text, p_state text, p_detail text) returns void
language sql security definer set search_path = public as $f$
  insert into language_flag_notice (flag_id, channel, state, detail) values (p_flag_id, p_channel, p_state, left(p_detail, 500));
$f$;
revoke all on function public.record_language_flag_notice(bigint, text, text, text) from public, anon, authenticated;
grant execute on function public.record_language_flag_notice(bigint, text, text, text) to service_role;

-- The three save paths: remove the refusals, record flags after the save, return them.
do $m$
declare d text; n text;
  g_reg_anon boolean := has_function_privilege('anon', 'public.self_register(jsonb)', 'execute');
begin
  -- business_profile_save
  d := pg_get_functiondef('public.business_profile_save(text,text,jsonb)'::regprocedure);
  n := replace(d, $a$declare g jsonb; bid uuid;$a$, $a$declare v_flags jsonb; g jsonb; bid uuid;$a$);
  if n = d then raise exception '159a: bps declare anchor'; end if; d := n;
  n := replace(d, $a$  if offensive_text(p->>'description') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'description', 'reason', 'language'); end if;
  if offensive_text(p->>'other_specialties') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'other_specialties', 'reason', 'language'); end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p->'insurance', '[]')) lang_x where offensive_text(lang_x->>'carrier') or offensive_text(lang_x->>'cover_note')) then
    return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance', 'reason', 'language'); end if;
$a$, '');
  if n = d then raise exception '159a: bps refusal anchor'; end if; d := n;
  n := replace(d, $a$  return jsonb_build_object('allowed', true, 'saved', true, 'business_id', bid);$a$,
    $a$  v_flags := record_language_flags('business_profile', bid::text,
    jsonb_build_object('description', p->>'description', 'other_specialties', p->>'other_specialties')
    || coalesce((select jsonb_object_agg(format('insurance[%s].%s', i - 1, f), x->>f)
                   from jsonb_array_elements(coalesce(p->'insurance', '[]')) with ordinality e(x, i), unnest(array['carrier', 'cover_note']) f), '{}'::jsonb));
  return jsonb_build_object('allowed', true, 'saved', true, 'business_id', bid, 'flags', v_flags);$a$);
  if n = d then raise exception '159a: bps return anchor'; end if;
  execute n;

  -- agent_profile_save
  d := pg_get_functiondef('public.agent_profile_save(text,text,jsonb)'::regprocedure);
  n := replace(d, $a$declare g jsonb; bad text;$a$, $a$declare v_flags jsonb; g jsonb; bad text;$a$);
  if n = d then raise exception '159a: aps declare anchor'; end if; d := n;
  n := replace(d, $a$  if offensive_text(p->>'bio') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'bio', 'reason', 'language'); end if;
  if offensive_text(p->>'declared_brokerage') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'declared_brokerage', 'reason', 'language'); end if;
$a$, '');
  if n = d then raise exception '159a: aps refusal anchor'; end if; d := n;
  n := replace(d, $a$  where slug = p_slug;
  return jsonb_build_object('allowed', true, 'saved', true);$a$, $a$  where slug = p_slug;
  v_flags := record_language_flags('agent_public_profile', p_slug, jsonb_build_object('bio', p->>'bio', 'declared_brokerage', p->>'declared_brokerage'));
  return jsonb_build_object('allowed', true, 'saved', true, 'flags', v_flags);$a$);
  if n = d then raise exception '159a: aps return anchor'; end if;
  execute n;

  -- self_register
  d := pg_get_functiondef('public.self_register(jsonb)'::regprocedure);
  n := replace(d, $a$declare
  v_name   text :=$a$, $a$declare
  v_flags  jsonb;
  v_name   text :=$a$);
  if n = d then raise exception '159a: sr declare anchor'; end if; d := n;
  n := replace(d, $a$  if offensive_text(v_name) then return jsonb_build_object('outcome', 'invalid', 'field', 'business_name', 'reason', 'language'); end if;
  if offensive_text(p->>'other_services') then return jsonb_build_object('outcome', 'invalid', 'field', 'other_services', 'reason', 'language'); end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p->'credentials', '[]')) lang_x where offensive_text(lang_x->>'issuer') or offensive_text(lang_x->>'trade')) then
    return jsonb_build_object('outcome', 'invalid', 'field', 'credentials', 'reason', 'language'); end if;
$a$, '');
  if n = d then raise exception '159a: sr refusal anchor'; end if; d := n;
  n := replace(d, $a$  return jsonb_build_object('outcome', 'received', 'id', v_id, 'slug', v_slug,$a$,
    $a$  v_flags := record_language_flags('registered_business', v_id::text,
    jsonb_build_object('business_name', v_name, 'other_services', p->>'other_services')
    || coalesce((select jsonb_object_agg(format('credentials[%s].%s', i - 1, f), x->>f)
                   from jsonb_array_elements(coalesce(p->'credentials', '[]')) with ordinality e(x, i), unnest(array['issuer', 'trade']) f), '{}'::jsonb));
  return jsonb_build_object('outcome', 'received', 'id', v_id, 'slug', v_slug, 'flags', v_flags,$a$);
  if n = d then raise exception '159a: sr return anchor'; end if;
  execute n;

  if g_reg_anon and not has_function_privilege('anon', 'public.self_register(jsonb)', 'execute') then
    execute 'grant execute on function public.self_register(jsonb) to anon'; end if;
  if exists (select 1 from pg_proc where proname in ('business_profile_save', 'agent_profile_save', 'self_register')
              and pronamespace = 'public'::regnamespace and prosrc ilike '%offensive_text(%') then
    raise exception '159a: a save path still calls offensive_text'; end if;
end $m$;

insert into public.column_writer (table_name, column_name, writer_class, derived_inputs, derived_rule, reason, classified_by)
select 'language_flag', a.attname,
       case when a.attname = 'rules' then 'derived' else 'ours' end,
       case when a.attname = 'rules' then '{text_as_saved}'::text[] end,
       case when a.attname = 'rules' then 'language_flags(): word lists over normalised tokens (look-alikes, substitutions, spelled-out, stretched)' end,
       case when a.attname = 'text_as_saved' then 'our evidence copy of the text as it was saved; never rendered'
            when a.attname = 'rules' then 'our computation about someone''s words; a notice to Murphy, never a public mark'
            else 'language-flag record (159a)' end, 'cc'
  from pg_attribute a where a.attrelid = 'public.language_flag'::regclass and a.attnum > 0 and not a.attisdropped;
insert into public.column_writer (table_name, column_name, writer_class, reason, classified_by)
select 'language_flag_notice', a.attname, 'ours', 'delivery record for a language flag notice (159a)', 'cc'
  from pg_attribute a where a.attrelid = 'public.language_flag_notice'::regclass and a.attnum > 0 and not a.attisdropped;
