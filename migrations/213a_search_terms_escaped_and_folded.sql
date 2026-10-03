-- 213a - the three public searches escape LIKE metacharacters, fold accents, bound their terms, and refuse an unknown
-- county instead of reporting "nothing matched" (audit 971 C; ruling 976 section 4: "escape at the boundary, once").
--
-- Measured 2026-10-03 as anon:
--   register_search('%%%%')     -> count 131,976  (every record: % is a wildcard)
--   register_search('S%TH')     -> 4,997, incl. SOUTH;  'SMI_H' matches SMITH (_ is a wildcard)
--   agent_register_search('%%%%') -> 500, statement timeout
--   16 one-letter words         -> 500 after ~3.2 s (each '%a%' scans); /c rendered it in 6 s on the service role
--   'José' -> none_found while 'Jose' -> 998;  'county:nowhere' -> none_found ("Nothing ... matched") from an empty query
-- One cause for the first four: unescaped pattern characters reaching ILIKE. The fix lives in ONE helper,
-- search_term_clean(), applied where the LIKE patterns are built:
--   - accents folded (match on the visitor's input, report in the register's spelling);
--   - backslash, %, _ escaped (LIKE's default escape character is backslash);
--   - a term must hold a letter or digit and be at least 2 characters; at most 8 terms are used;
--   - an unknown county: token returns not_run with a note - an invalid input, never a "nothing matched" verdict.
-- The payload still echoes what was typed ('query', 'terms'). register_search, contractor_register_search and
-- agent_register_search are browser RPCs (browser_rpc): replacing each revokes its own grant, so each is re-granted and
-- its ACL asserted unchanged.

create or replace function public.search_term_clean(p text)
returns text language sql immutable parallel safe set search_path to 'pg_catalog' as $$
  select replace(replace(replace(
           translate(lower(coalesce(p, '')),
                     'áàâäãåāéèêëēíìîïīóòôöõøōúùûüūñçýÿ',
                     'aaaaaaaeeeeeiiiiiooooooouuuuuncyy'),
           '\', '\\'), '%', '\%'), '_', '\_')
$$;
comment on function public.search_term_clean(text) is
  '213a: a search term made safe for ILIKE - accents folded, and \ % _ escaped (LIKE''s default escape is backslash). Every public search builds its patterns through this, so a typed % or _ is a character, not a wildcard.';
revoke all on function public.search_term_clean(text) from public, anon, authenticated;

do $$
declare d text; a1 text; a2 text; f regprocedure;
begin
  -- contractor_register_search
  f := 'public.contractor_register_search(text,integer)'::regprocedure;
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
  d := pg_get_functiondef(f);
  if position($a$    ELSIF length(t) > 0 THEN
      v_terms := v_terms || t;$a$ in d) = 0
     or position($a$  IF cardinality(v_county) = 0 AND length(array_to_string(v_terms, ' ')) < 3 THEN$a$ in d) = 0
     or position($a$v_pred := v_pred || format(' AND c.search_text ILIKE %L', '%' || t || '%');$a$ in d) = 0
     or position($a$INTO v_total, v_rows USING v_terms, v_county, lim;$a$ in d) = 0 then
    raise exception '213a: contractor_register_search anchor missing'; end if;
  d := replace(d, $a$    ELSIF length(t) > 0 THEN
      v_terms := v_terms || t;$a$, $a$    ELSIF length(t) >= 2 AND t ~ '[[:alnum:]]' AND cardinality(v_terms) < 8 THEN  -- 213a: bounded, meaningful terms
      v_terms := v_terms || t;$a$);
  d := replace(d, $a$  IF cardinality(v_county) = 0 AND length(array_to_string(v_terms, ' ')) < 3 THEN$a$,
    $a$  -- 213a: an unknown county is an invalid input, never a "nothing matched" verdict
  IF EXISTS (SELECT 1 FROM unnest(v_county) k WHERE NOT EXISTS (SELECT 1 FROM public.contractors c WHERE c.county_name = k)) THEN
    RETURN jsonb_build_object('query', v_q, 'field_status', 'not_run',
      'note', 'That county is not one we recognise. Pick a Florida county from the list.', 'results', '[]'::jsonb, 'count', 0);
  END IF;

  IF cardinality(v_county) = 0 AND length(array_to_string(v_terms, ' ')) < 3 THEN$a$);
  d := replace(d, $a$v_pred := v_pred || format(' AND c.search_text ILIKE %L', '%' || t || '%');$a$,
                  $a$v_pred := v_pred || format(' AND c.search_text ILIKE %L', '%' || public.search_term_clean(t) || '%');$a$);
  d := replace(d, $a$INTO v_total, v_rows USING v_terms, v_county, lim;$a$,
                  $a$INTO v_total, v_rows USING coalesce((SELECT array_agg(public.search_term_clean(x)) FROM unnest(v_terms) x), '{}'::text[]), v_county, lim;$a$);
  execute d;
  grant execute on function public.contractor_register_search(text,integer) to anon, authenticated;
  select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
  if a2 is distinct from a1 then raise exception '213a: contractor_register_search grants % -> %', a1, a2; end if;

  -- register_search: its electrical half filters on the terms contractor_register_search echoes
  f := 'public.register_search(text,integer)'::regprocedure;
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
  d := pg_get_functiondef(f);
  if position($a$select coalesce(array_agg(x), '{}') into v_terms from jsonb_array_elements_text(case when jsonb_typeof(v_c->'terms') = 'array' then v_c->'terms' else '[]'::jsonb end) x;$a$ in d) = 0 then
    raise exception '213a: register_search anchor missing'; end if;
  d := replace(d, $a$select coalesce(array_agg(x), '{}') into v_terms from jsonb_array_elements_text(case when jsonb_typeof(v_c->'terms') = 'array' then v_c->'terms' else '[]'::jsonb end) x;$a$,
                  $a$select coalesce(array_agg(public.search_term_clean(x)), '{}') into v_terms from jsonb_array_elements_text(case when jsonb_typeof(v_c->'terms') = 'array' then v_c->'terms' else '[]'::jsonb end) x;  -- 213a$a$);
  execute d;
  grant execute on function public.register_search(text,integer) to anon, authenticated;
  select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
  if a2 is distinct from a1 then raise exception '213a: register_search grants % -> %', a1, a2; end if;

  -- agent_register_search: one whole-query pattern
  f := 'public.agent_register_search(text,integer)'::regprocedure;
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
  d := pg_get_functiondef(f);
  if position($a$  v_note         text;$a$ in d) = 0 or position($a$  IF length(v_q) < 3 THEN$a$ in d) = 0
     or (length(d) - length(replace(d, $a$'%'||v_q||'%'$a$, ''))) / length($a$'%'||v_q||'%'$a$) <> 2
     or (length(d) - length(replace(d, $a$ILIKE v_q||'%'$a$, ''))) / length($a$ILIKE v_q||'%'$a$) <> 2 then
    raise exception '213a: agent_register_search anchor missing'; end if;
  d := replace(d, $a$  v_note         text;$a$, $a$  v_note         text;
  v_like         text;  -- 213a$a$);
  d := replace(d, $a$  IF length(v_q) < 3 THEN$a$, $a$  v_like := public.search_term_clean(v_q);  -- 213a: escaped, accents folded
  IF length(v_q) < 3 OR v_q !~ '[[:alnum:]]' THEN$a$);
  d := replace(d, $a$'%'||v_q||'%'$a$, $a$'%'||v_like||'%'$a$);
  d := replace(d, $a$ILIKE v_q||'%'$a$, $a$ILIKE v_like||'%'$a$);
  execute d;
  grant execute on function public.agent_register_search(text,integer) to anon, authenticated;
  select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
  if a2 is distinct from a1 then raise exception '213a: agent_register_search grants % -> %', a1, a2; end if;
end $$;

do $$
declare j jsonb; t0 timestamptz;
begin
  if (public.register_search('%%%%', 5)->>'field_status') is distinct from 'not_run' then raise exception '213a: %%%% still runs'; end if;
  if (public.register_search('S%TH', 5)->>'count')::int > 50 then raise exception '213a: S%%TH still a wildcard: %', public.register_search('S%TH', 5)->>'count'; end if;
  if (public.register_search('SMI_H', 5)->>'count')::int > 0 then raise exception '213a: SMI_H still matches'; end if;
  if (public.register_search('José', 5)->>'count')::int < 100 then raise exception '213a: José does not fold'; end if;
  if (public.register_search('county:nowhere', 5)->>'field_status') is distinct from 'not_run' then raise exception '213a: unknown county still a verdict'; end if;
  if (public.register_search('county:volusia', 5)->>'count')::int < 1000 then raise exception '213a: a real county broke'; end if;
  if (public.register_search('roofing', 5)->>'count')::int < 10000 then raise exception '213a: plain search broke: %', public.register_search('roofing', 5)->>'count'; end if;
  if (public.register_search('O''BRIEN', 5)->>'count')::int < 1 then raise exception '213a: apostrophe search broke'; end if;
  if (public.agent_register_search('%%%%', 5)->>'field_status') is distinct from 'not_run' then raise exception '213a: agent %%%% still runs'; end if;
  if (public.agent_register_search('smith', 5)->>'count')::int < 1000 then raise exception '213a: agent search broke'; end if;
  t0 := clock_timestamp();
  j := public.register_search('a b c d e f g h i j k l m n o p', 5);
  if clock_timestamp() - t0 > interval '3 seconds' then raise exception '213a: one-letter words still slow'; end if;
  if not has_function_privilege('anon','public.register_search(text,integer)','EXECUTE')
     or not has_function_privilege('anon','public.contractor_register_search(text,integer)','EXECUTE')
     or not has_function_privilege('anon','public.agent_register_search(text,integer)','EXECUTE') then raise exception '213a: a browser RPC lost anon'; end if;
  raise notice '213a: roofing %, Jose(é) %, S%%TH %, agent smith %', public.register_search('roofing',1)->>'count', public.register_search('José',1)->>'count',
    public.register_search('S%TH',1)->>'count', public.agent_register_search('smith',1)->>'count';
end $$;

select public._log_action('cc', 'search_terms_escaped_and_folded', 'register_search',
  array['search_term_clean','register_search','contractor_register_search','agent_register_search'],
  jsonb_build_object('%%%%', 131976, 'agent %%%%', '500 timeout', 'José', 'none_found', 'county:nowhere', 'none_found'),
  jsonb_build_object('%%%%', 'not_run', 'José', 'folds to Jose', 'county:nowhere', 'not_run'),
  'Audit 971 / ruling 976: LIKE metacharacters reached the pattern; escaped once at the boundary.', null);
