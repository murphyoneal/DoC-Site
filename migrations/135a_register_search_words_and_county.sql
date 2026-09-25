-- 135a — Make the public register search usable (ruling 2026-09-25, walkthrough).
--
-- "roofing" returned 11,864 statewide with no way to narrow, and "roofing volusia" returned ZERO:
-- the whole query was matched as one substring, so the natural refinement emptied the result.
--
--   * EVERY WORD MUST MATCH one of: business / display / trading name, licence number (prefix),
--     trade (licensed trades only), city, or county. "roofing volusia" = roofers in Volusia.
--   * county:<key> is a STRICT county filter (keys as held: volusia, dade, st_johns, palm_beach).
--     The county dropdown adds it; a plain word "orange" can also match "Orange Roofing" in
--     another county, so a picked county must not be a plain word.
--   * The payload states the rule it applied (match_rule, terms, county_filter), additively.
--
-- SAME SIGNATURE (q text, lim integer): the browser caller and the anon-execute detection name it.
-- Replacing a SECURITY DEFINER function revokes its own grants, so they are re-issued here and
-- asserted below — this is the endpoint whose grant loss was a public outage on 2026-09-09.

create or replace function public.contractor_register_search(q text, lim integer default 25)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as
$$
DECLARE
  v_q      text := btrim(coalesce(q, ''));
  v_terms  text[] := '{}';
  v_county text[] := '{}';
  t        text;
  v_rows   jsonb;
  v_total  int;
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

  -- Filter and count first; build the JSON only for the rows returned. Every field is coalesced:
  -- inside NOT EXISTS(... WHERE NOT (a OR b ...)) a NULL field would make the test NULL and let the
  -- row through for EVERY word (found in testing: "red stag" matched 21,308 rows). County words
  -- match the held key with '_' read as a space; county_display() is too slow to run per row.
  WITH hits AS (
    SELECT c.id, coalesce(nullif(c.display_name,''), c.business_name) AS nm, count(*) OVER () AS total
      FROM contractors c
     WHERE c.active IS NOT FALSE
       AND NOT EXISTS (SELECT 1 FROM public.trade_code_registry tr
                        WHERE tr.trade_code = c.trade_code AND tr.department = 'none')
       AND (cardinality(v_county) = 0 OR lower(coalesce(c.county_name,'')) = ANY (v_county))
       AND NOT EXISTS (
         SELECT 1 FROM unnest(v_terms) w
          WHERE NOT (
                coalesce(c.business_name,'')  ILIKE '%'||w||'%'
             OR coalesce(c.display_name,'')   ILIKE '%'||w||'%'
             OR coalesce(c.trading_name,'')   ILIKE '%'||w||'%'
             OR coalesce(c.license_number,'') ILIKE w||'%'
             OR coalesce(c.city,'')           ILIKE '%'||w||'%'
             OR replace(coalesce(c.county_name,''), '_', ' ') ILIKE '%'||w||'%'
             OR (coalesce(c.county_name,'') = 'dade' AND 'miami-dade' ILIKE '%'||w||'%')
             OR ( coalesce(c.trade_label,'') ILIKE '%'||w||'%'
                  AND EXISTS (SELECT 1 FROM public.trade_code_registry tr
                               WHERE tr.trade_code = c.trade_code AND tr.is_trade) )))
     ORDER BY 2
     LIMIT greatest(1, least(coalesce(lim,25), 50)))
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
           'claimed',        coalesce(c.claimed,false),
           'verified',       coalesce(c.verified,false),
           'record_dated',   ( to_date(nullif(c.expiry_date,''),'MM/DD/YYYY') < current_date )
         ) ORDER BY h.nm), '[]'::jsonb)
    INTO v_total, v_rows
    FROM hits h JOIN contractors c ON c.id = h.id;

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
$$;

grant execute on function public.contractor_register_search(text, integer) to anon, authenticated, service_role;

do $a$ begin
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'EXECUTE') then
    raise exception '135a: anon lost EXECUTE on contractor_register_search';
  end if;
end $a$;
