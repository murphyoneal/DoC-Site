-- 190b - the public register search prefilters on the indexed search_text (190a) and stops timing out (anon 3 s).
--
-- Change: before the existing exact predicate, a row must satisfy search_text ILIKE '%<longest word>%'. Every row the exact
-- predicate accepts contains every word in search_text (190a), so this is a NECESSARY condition: it removes only rows the
-- exact predicate would reject. When the query has no words (county-only), the prefilter is skipped (v_pat NULL), so that
-- path is unchanged (165 ms before and after).
-- Measured on a temp copy before applying (2026-10-01), output identical on 11 queries incl. multi-word, licence prefix,
-- county alias and empty results; in-database timing old -> new: smith 2,529 -> 20 ms, ele 2,438 -> 28, roofing 2,411 -> 276,
-- abc 2,456 -> 8, roof daytona 2,517 -> 17, llc 2,159 -> 809 (42,866 hits), air 2,372 -> 319.
-- SECURITY DEFINER replace revokes anon/authenticated on this function (CLAUDE.md): the grants it held -
-- postgres, service_role, anon, authenticated - are re-issued here and asserted.

do $$
declare d text; v_q text; same_all boolean := true; bad text := '';
begin
  -- capture the pre-change output for the identity proof, in this transaction
  create temp table _crs_before (qq text primary key, out jsonb) on commit drop;
  foreach v_q in array array['smith','ele','air','roofing','abc','county:volusia','roof daytona','cgc12','miami-dade plumbing','zz test','county:volusia roof'] loop
    insert into _crs_before values (v_q, public.contractor_register_search(v_q, 25) - 'generated_at');
  end loop;

  d := pg_get_functiondef('public.contractor_register_search(text,integer)'::regprocedure);
  if position('  v_total  int;' in d) = 0 or position('WHERE c.active IS NOT FALSE' in d) = 0 or position('  WITH hits AS (' in d) = 0 then
    raise exception '190b: an anchor is missing'; end if;
  if (select count(*) from regexp_matches(d, 'WHERE c\.active IS NOT FALSE', 'g')) <> 1 then raise exception '190b: active anchor not unique'; end if;
  d := replace(d, '  v_total  int;', '  v_total  int;' || E'\n' || '  v_pat    text;  -- 190a/190b: indexed necessary-condition prefilter');
  d := replace(d, '  WITH hits AS (', '  v_pat := ''%'' || (SELECT w FROM unnest(v_terms) w ORDER BY length(w) DESC LIMIT 1) || ''%'';' || E'\n' || '  WITH hits AS (');
  d := replace(d, 'WHERE c.active IS NOT FALSE', 'WHERE (v_pat IS NULL OR c.search_text ILIKE v_pat) AND c.active IS NOT FALSE');
  execute d;

  grant execute on function public.contractor_register_search(text, integer) to service_role, anon, authenticated;

  for v_q in select b.qq from _crs_before b loop
    if (public.contractor_register_search(v_q, 25) - 'generated_at') is distinct from (select b2.out from _crs_before b2 where b2.qq = v_q) then
      same_all := false; bad := bad || v_q || '; ';
    end if;
  end loop;
  if not same_all then raise exception '190b: output changed for: %', bad; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'execute')
     or not has_function_privilege('authenticated', 'public.contractor_register_search(text,integer)', 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then
    raise exception '190b: register grants lost'; end if;
end $$;

select public._log_action('cc', 'register_search_prefilter', 'contractor_register_search', array['contractor_register_search'],
  jsonb_build_object('roofing_anon', 'HTTP 500 57014 at 3135 ms'),
  jsonb_build_object('prefilter', 'search_text ILIKE longest word (indexed); exact predicate unchanged', 'identity', '11 queries identical in-migration'),
  'The public register search timed out under the 3 s anon limit on common words; a necessary-condition prefilter through the trigram index, output identical, anon grants re-issued.', null);
