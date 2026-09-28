-- 152a — free text bound for a public page is checked for offensive language on save (work order 730
-- item 6). Every claimed profile is a page we host under our name, and Murphy reviews claims, not edits.
--
-- MEASURED BEFORE WIRING, against every real name we hold (114,104 contractors + 496,407 agents):
--   a naive draft flagged D'ACUNTI (surname), KOENIG GARY (matched ACROSS the space), DICK (first name
--   and surname of dozens of real firms) and "THE BEST DAMN REAL ESTATE COMPANY" (a licensed business).
--   So: matching is within a word, never across one; the severe stems match inside a word, except the
--   surname shape d'acunti/acunto; milder words match only as whole words; dick, damn, hell, crap are
--   not listed. Result: 0 of 610,511 real names flagged.
--   Positive controls all caught: "I'm Chieffmuntacunt" (Murphy's test), "f*cking", "sh1t".
--   Negative controls pass: "fire retardant", "stopcock", "Hancock", D'Acunti, "Best Damn Real Estate".
-- A list is never complete; this raises the bar for the obvious and leaves judgement to Murphy.

create or replace function public.offensive_text(p text) returns boolean
language sql immutable set search_path = public as $$
  select exists (
    select 1 from regexp_split_to_table(translate(lower(coalesce(p, '')), '0134$@5', 'oieasas'), '[^a-z0-9''*-]+') tok0,
         lateral (select regexp_replace(tok0, '[^a-z]', '', 'g') tok) t
    where (t.tok ~ '(fuck|fck|phuck|nigger|nigga|faggot|motherf|cunt)' and t.tok !~ '^d?acunt[io]')
       or t.tok ~ '^(asshole|assholes|bitch|bitches|bastard|bastards|pussy|slut|sluts|twat|wanker|whore|whores|shit|shits|shitty|bullshit|retard|retarded|cocksucker|dickhead)$')
$$;

do $f$
declare def text; nd text;
begin
  def := pg_get_functiondef('public.business_profile_save(text,text,jsonb)'::regprocedure);
  nd := replace(def,
    $a$  if jsonb_array_length(coalesce(p->'insurance', '[]')) > 10 then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance'); end if;$a$,
    $a$  if jsonb_array_length(coalesce(p->'insurance', '[]')) > 10 then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance'); end if;
  if offensive_text(p->>'description') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'description', 'reason', 'language'); end if;
  if offensive_text(p->>'other_specialties') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'other_specialties', 'reason', 'language'); end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p->'insurance', '[]')) x where offensive_text(x->>'carrier') or offensive_text(x->>'cover_note')) then
    return jsonb_build_object('allowed', true, 'saved', false, 'field', 'insurance', 'reason', 'language'); end if;$a$);
  if nd = def then raise exception '152a: business_profile_save anchor missing'; end if;
  execute nd;

  def := pg_get_functiondef('public.agent_profile_save(text,text,jsonb)'::regprocedure);
  nd := replace(def,
    $a$  if bad is not null then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'property_classes'); end if;$a$,
    $a$  if bad is not null then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'property_classes'); end if;
  if offensive_text(p->>'bio') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'bio', 'reason', 'language'); end if;
  if offensive_text(p->>'declared_brokerage') then return jsonb_build_object('allowed', true, 'saved', false, 'field', 'declared_brokerage', 'reason', 'language'); end if;$a$);
  if nd = def then raise exception '152a: agent_profile_save anchor missing'; end if;
  execute nd;

  def := pg_get_functiondef('public.self_register(jsonb)'::regprocedure);
  nd := replace(def,
    $a$  if v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return jsonb_build_object('outcome', 'invalid', 'field', 'contact_email'); end if;$a$,
    $a$  if v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return jsonb_build_object('outcome', 'invalid', 'field', 'contact_email'); end if;
  if offensive_text(v_name) then return jsonb_build_object('outcome', 'invalid', 'field', 'business_name', 'reason', 'language'); end if;
  if offensive_text(p->>'other_services') then return jsonb_build_object('outcome', 'invalid', 'field', 'other_services', 'reason', 'language'); end if;
  if exists (select 1 from jsonb_array_elements(coalesce(p->'credentials', '[]')) x where offensive_text(x->>'issuer') or offensive_text(x->>'trade')) then
    return jsonb_build_object('outcome', 'invalid', 'field', 'credentials', 'reason', 'language'); end if;$a$);
  if nd = def then raise exception '152a: self_register anchor missing'; end if;
  execute nd;
end $f$;

revoke all on function public.business_profile_save(text, text, jsonb), public.agent_profile_save(text, text, jsonb), public.self_register(jsonb)
  from public, anon, authenticated;
grant execute on function public.business_profile_save(text, text, jsonb), public.agent_profile_save(text, text, jsonb), public.self_register(jsonb)
  to service_role;

do $a$
begin
  if not public.offensive_text('I''m Chieffmuntacunt') then raise exception '152a: positive control not caught'; end if;
  if public.offensive_text('D''Acunti Builders, fire retardant, stopcock, The Best Damn Real Estate Company, Dick Pittman') then
    raise exception '152a: negative control flagged'; end if;
end $a$;
