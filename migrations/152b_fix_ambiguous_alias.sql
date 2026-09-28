-- 152b — 152a applied cleanly and then failed on every call: business_profile_save declares a variable
-- named x, and the inserted check used x as a table alias ("column reference x is ambiguous"). Caught by
-- calling the function straight after the migration, ~2 minutes after 152a; no real save was attempted
-- in the window (business_profile.updated_at unchanged). Alias renamed to lang_x in both functions.
do $f$
declare def text; nd text; fn text;
begin
  foreach fn in array array['public.business_profile_save(text,text,jsonb)', 'public.self_register(jsonb)'] loop
    def := pg_get_functiondef(fn::regprocedure);
    nd := replace(replace(def,
      $a$) x where offensive_text(x->>'carrier') or offensive_text(x->>'cover_note'))$a$,
      $a$) lang_x where offensive_text(lang_x->>'carrier') or offensive_text(lang_x->>'cover_note'))$a$),
      $a$) x where offensive_text(x->>'issuer') or offensive_text(x->>'trade'))$a$,
      $a$) lang_x where offensive_text(lang_x->>'issuer') or offensive_text(lang_x->>'trade'))$a$);
    if nd = def then raise exception '152b: alias anchor missing in %', fn; end if;
    execute nd;
  end loop;
end $f$;
revoke all on function public.business_profile_save(text, text, jsonb), public.self_register(jsonb) from public, anon, authenticated;
grant execute on function public.business_profile_save(text, text, jsonb), public.self_register(jsonb) to service_role;
