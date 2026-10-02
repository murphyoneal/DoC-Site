-- 202a - the public register search prefilters on EVERY word, not only the longest; multi-word queries stop timing out.
--
-- Measured 2026-10-02 over anon REST (3 s statement_timeout): contractor_register_search('General Contractor ZZ TEST')
-- -> HTTP 500, 57014, 3.23 s. It is the LIVE homepage search: a visitor typing "general contractor" and a town gets
-- "the register could not be reached". 190b prefiltered on the single longest word through the trigram index; when that
-- word is common ("contractor"), the index returns most of the register and the exact per-word predicate runs on every
-- row. Each word of the query must appear in search_text (190a: search_text concatenates exactly the fields the exact
-- predicate matches, lower-cased), so EVERY word is a necessary condition - AND-ing one ILIKE per word lets the
-- planner intersect the trigram index (BitmapAnd) without changing which rows match. Words under 3 characters carry
-- no trigram and are left to the exact predicate, as before.
-- The hits query becomes dynamic SQL so each word is a separate, planner-visible predicate; the exact predicate,
-- ordering, limit and payload are unchanged. Output asserted identical before/after on 12 queries, in-migration.
-- SECURITY DEFINER replace revokes anon/authenticated: re-granted and asserted (register_search calls it too).

do $$
declare v_q text; same_all boolean := true; bad text := ''; d text; a1 text;
begin
  create temp table _crs_before (qq text primary key, out jsonb) on commit drop;
  foreach v_q in array array['smith','ele','air','roofing','abc','county:volusia','roof daytona','cgc12','miami-dade plumbing','zz test','county:volusia roof','llc'] loop
    insert into _crs_before values (v_q, public.contractor_register_search(v_q, 25) - 'generated_at');
  end loop;

  execute $fn$
CREATE OR REPLACE FUNCTION public.contractor_register_search(q text, lim integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_q      text := btrim(coalesce(q, ''));
  v_terms  text[] := '{}';
  v_county text[] := '{}';
  t        text;
  v_rows   jsonb;
  v_total  int;
  v_pred   text := '';  -- 202a: one indexed necessary-condition ILIKE per word of 3+ characters
BEGIN
  FOREACH t IN ARRAY regexp_split_to_array(v_q, '\s+') LOOP
    IF t ~* '^county:.+' THEN
      v_county := v_county || lower(substr(t, 8));
    ELSIF length(t) > 0 THEN
      v_terms := v_terms || t;
    END IF;
  END LOOP;

  IF cardinality(v_county) = 0 AND length(array_to_string(v_terms, ' ')) < 3 THEN
    RETURN jsonb_build_object('query', v_q, 'field_status', 'not_run',
      'note', 'Enter at least three characters.', 'results', '[]'::jsonb, 'count', 0);
  END IF;

  FOREACH t IN ARRAY v_terms LOOP
    IF length(t) >= 3 THEN
      v_pred := v_pred || format(' AND c.search_text ILIKE %L', '%' || t || '%');
    END IF;
  END LOOP;

  EXECUTE format($q$
  WITH hits AS (
    SELECT c.id, coalesce(nullif(c.display_name,''), c.business_name) AS nm, count(*) OVER () AS total
      FROM contractors c
     WHERE c.active IS NOT FALSE %s
       AND NOT public.is_test_fixture('contractors', c.license_number)
       AND NOT EXISTS (SELECT 1 FROM public.trade_code_registry tr
                        WHERE tr.trade_code = c.trade_code AND tr.department = 'none')
       AND (cardinality($2) = 0 OR lower(coalesce(c.county_name,'')) = ANY ($2))
       AND NOT EXISTS (
         SELECT 1 FROM unnest($1) w
          WHERE NOT (
                coalesce(c.business_name,'')  ILIKE '%%'||w||'%%'
             OR coalesce(c.display_name,'')   ILIKE '%%'||w||'%%'
             OR coalesce(c.trading_name,'')   ILIKE '%%'||w||'%%'
             OR coalesce(c.license_number,'') ILIKE w||'%%'
             OR coalesce(c.city,'')           ILIKE '%%'||w||'%%'
             OR replace(coalesce(c.county_name,''), '_', ' ') ILIKE '%%'||w||'%%'
             OR (coalesce(c.county_name,'') = 'dade' AND 'miami-dade' ILIKE '%%'||w||'%%')
             OR ( coalesce(c.trade_label,'') ILIKE '%%'||w||'%%'
                  AND EXISTS (SELECT 1 FROM public.trade_code_registry tr
                               WHERE tr.trade_code = c.trade_code AND tr.is_trade) )))
     ORDER BY 2
     LIMIT greatest(1, least(coalesce($3,25), 50)))
  SELECT coalesce(max(h.total), 0),
         coalesce(jsonb_agg(jsonb_build_object(
           'slug',           c.slug,
           'name',           h.nm,
           'license_number', c.license_number,
           'trade',          c.trade_label,
           'trade_code',     c.trade_code,
           'city',           initcap(lower(coalesce(c.city,''))),
           'county',         coalesce(public.county_display(c.county_name),''),
           'license_status', c.license_status,
           'expiry_date',    c.expiry_date,
           'claimed',        public.contractor_is_claimed(c.id),
           'verified',       coalesce(c.verified,false),
           'record_dated',   ( to_date(nullif(c.expiry_date,''),'MM/DD/YYYY') < current_date )
         ) ORDER BY h.nm), '[]'::jsonb)
    FROM hits h JOIN contractors c ON c.id = h.id
  $q$, v_pred) INTO v_total, v_rows USING v_terms, v_county, lim;

  RETURN jsonb_build_object(
    'query', v_q,
    'terms', to_jsonb(v_terms),
    'county_filter', CASE WHEN cardinality(v_county) = 0 THEN NULL ELSE to_jsonb(v_county) END,
    'match_rule', 'Every word must appear in the business name, licence number, trade, city or county.',
    'field_status', CASE WHEN v_total = 0 THEN 'none_found' ELSE 'present' END,
    'count', v_total,
    'returned', jsonb_array_length(v_rows),
    'source', 'Florida DBPR public licence file',
    'source_retrieved', (select to_char(capture_date, 'YYYY-MM-DD') from public.dbpr_snapshot_log where is_register_source limit 1),
    'source_posted', (select to_char(posted_date, 'YYYY-MM-DD') from public.dbpr_snapshot_log where is_register_source limit 1),
    'coverage_note', 'Licence records reproduced from the state register as retrieved on the date shown. A record dated before today may simply have been renewed since; it is not evidence the licence has lapsed. County is the county recorded on the licence, which is not always the county the business address falls in; where they differ we hold both.',
    'results', v_rows);
END
$function$
$fn$;

  grant execute on function public.contractor_register_search(text, integer) to service_role, anon, authenticated;

  for v_q in select b.qq from _crs_before b loop
    if (public.contractor_register_search(v_q, 25) - 'generated_at') is distinct from (select b2.out from _crs_before b2 where b2.qq = v_q) then
      same_all := false; bad := bad || v_q || '; ';
    end if;
  end loop;
  if not same_all then raise exception '202a: output changed for: %', bad; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'execute')
     or not has_function_privilege('anon', 'public.register_search(text,integer)', 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then
    raise exception '202a: register grants lost'; end if;
end $$;

select public._log_action('cc', 'register_search_every_word_prefilter', 'contractor_register_search', array['contractor_register_search'],
  jsonb_build_object('general_contractor_zz_test', 'HTTP 500 57014 at 3.23 s (anon)'),
  jsonb_build_object('prefilter', 'one indexed ILIKE per word of 3+ characters; exact predicate unchanged', 'identity', '12 queries identical in-migration'),
  'The live homepage search timed out on common multi-word queries ("general contractor" + a town); every word is a necessary condition, so each now narrows through the trigram index. Output identical.', null);
