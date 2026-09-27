-- 140a — contractor_finder: the data behind the finder page (/map on departmentofconstruction.com).
-- Work order 697: a server-rendered results list beside the map, because text ranks and pins do not.
--
-- ONE ROW PER BUSINESS (businesses + its canonical licence), not per licence: the walkthrough found
-- the register search listing a two-licence business twice. A business matches a trade if ANY of its
-- licences is in that trade (Red Stag is a building contractor AND a roofer).
--
--   q      every word must match the business's name, trading name, a licence number (prefix),
--          its city, its county, or its licensed trade (same rule as contractor_register_search)
--   county a county key as held (volusia, dade, st_johns ...); strict
--   trade  a doc_category key as held (roofing, pool_spa ...); strict
--
-- ORDER: claimed first, then alphabetical. Never evaluative, never a ranking (same line as the
-- related-businesses list). Coordinates are rounded to 2 decimals, as contractors_public serves them.
-- No street address. With no q, county or trade it returns the county list with business counts
-- instead of 98,749 alphabetical rows.
--
-- `trades` counts businesses per trade UNDER THE CURRENT q AND county (ignoring the trade filter), so
-- the page lists only trades that return results for what the visitor has already chosen.
-- Called server-side with the service key; not granted to anon (the browser never calls it).

create or replace function public.contractor_finder(q text default null, county text default null,
                                                    trade text default null, lim integer default 60)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp
set statement_timeout = '8s' as
$$
DECLARE
  v_q      text := btrim(coalesce(q, ''));
  v_county text := nullif(lower(btrim(coalesce(county, ''))), '');
  v_trade  text := nullif(lower(btrim(coalesce(trade, ''))), '');
  v_terms  text[] := '{}';
  t        text;
  v_rows   jsonb;
  v_trades jsonb;
  v_total  int;
BEGIN
  FOREACH t IN ARRAY regexp_split_to_array(v_q, '\s+') LOOP
    IF length(t) > 0 THEN v_terms := v_terms || t; END IF;
  END LOOP;

  -- Nothing chosen yet: the counties, each a link. Real text, and a real way in.
  IF cardinality(v_terms) = 0 AND v_county IS NULL AND v_trade IS NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object('county', k, 'businesses', n) ORDER BY k), '[]'::jsonb)
      INTO v_rows
      FROM (SELECT c.county_name k, count(*) n
              FROM businesses b JOIN contractors c ON c.id = b.canonical_contractor_id
             WHERE c.active IS NOT FALSE AND coalesce(c.county_name,'') <> ''
               AND NOT EXISTS (SELECT 1 FROM trade_code_registry tr WHERE tr.trade_code = c.trade_code AND tr.department = 'none')
             GROUP BY 1) x;
    RETURN jsonb_build_object('mode', 'counties', 'counties', v_rows,
      'source_retrieved', (select to_char(capture_date, 'YYYY-MM-DD') from dbpr_snapshot_log where is_register_source limit 1));
  END IF;

  IF cardinality(v_terms) > 0 AND v_county IS NULL AND v_trade IS NULL AND length(array_to_string(v_terms, ' ')) < 3 THEN
    RETURN jsonb_build_object('mode', 'results', 'field_status', 'not_run', 'note', 'Enter at least three characters.',
                              'results', '[]'::jsonb, 'count', 0, 'trades', '[]'::jsonb);
  END IF;

  WITH biz AS MATERIALIZED (
    SELECT b.id AS bid, b.slug, coalesce(nullif(b.display_name,''), nullif(c.display_name,''), c.business_name) AS nm,
           c.trade_label, c.doc_category, c.city, c.county_name, c.lat, c.lng, coalesce(c.claimed, false) AS claimed,
           c.expiry_date, c.register_file_state,
           -- sort on the name without leading quotes and symbols ("'THE MASTER'S' ..." sorted first)
           regexp_replace(upper(coalesce(nullif(b.display_name,''), nullif(c.display_name,''), c.business_name)), '^[^A-Z0-9]+', '') AS sort_nm
      FROM businesses b JOIN contractors c ON c.id = b.canonical_contractor_id
     WHERE c.active IS NOT FALSE
       AND NOT EXISTS (SELECT 1 FROM trade_code_registry tr WHERE tr.trade_code = c.trade_code AND tr.department = 'none')
       AND (v_county IS NULL OR c.county_name = v_county)
       AND NOT EXISTS (
         SELECT 1 FROM unnest(v_terms) w
          WHERE NOT (
                coalesce(c.business_name,'') ILIKE '%'||w||'%'
             OR coalesce(c.display_name,'')  ILIKE '%'||w||'%'
             OR coalesce(c.trading_name,'')  ILIKE '%'||w||'%'
             OR coalesce(c.city,'')          ILIKE '%'||w||'%'
             OR replace(coalesce(c.county_name,''), '_', ' ') ILIKE '%'||w||'%'
             OR (coalesce(c.county_name,'') = 'dade' AND 'miami-dade' ILIKE '%'||w||'%')
             OR EXISTS (SELECT 1 FROM business_licences bl JOIN contractors c2 ON c2.id = bl.contractor_id
                         WHERE bl.business_id = b.id
                           AND (coalesce(c2.license_number,'') ILIKE w||'%'
                                OR (coalesce(c2.trade_label,'') ILIKE '%'||w||'%'
                                    AND EXISTS (SELECT 1 FROM trade_code_registry tr WHERE tr.trade_code = c2.trade_code AND tr.is_trade))))))
  ),
  lic AS (   -- every trade each matching business holds
    SELECT DISTINCT biz.bid, c2.doc_category
      FROM biz JOIN business_licences bl ON bl.business_id = biz.bid JOIN contractors c2 ON c2.id = bl.contractor_id
     WHERE c2.active IS NOT FALSE AND c2.doc_category IS NOT NULL
       -- not trades: a business registration and a continuing-education provider are not work a visitor hires
       AND c2.doc_category NOT IN ('qualifier_business', 'education_provider')
  ),
  tr AS (
    SELECT coalesce(jsonb_agg(jsonb_build_object('trade', doc_category, 'businesses', n) ORDER BY n DESC, doc_category), '[]'::jsonb) AS j
      FROM (SELECT doc_category, count(*) n FROM lic GROUP BY 1) x
  ),
  hits AS (
    SELECT biz.*, count(*) OVER () AS total
      FROM biz
     WHERE v_trade IS NULL OR EXISTS (SELECT 1 FROM lic WHERE lic.bid = biz.bid AND lic.doc_category = v_trade)
     ORDER BY biz.claimed DESC, biz.sort_nm, biz.nm
     LIMIT greatest(1, least(coalesce(lim, 60), 100))
  )
  SELECT (SELECT j FROM tr),
         coalesce(max(h.total), 0),
         coalesce(jsonb_agg(jsonb_build_object(
           'slug', h.slug, 'name', h.nm, 'trade', h.trade_label, 'trade_key', h.doc_category,
           'city', initcap(lower(coalesce(h.city,''))), 'county', h.county_name,
           'lat', round(h.lat::numeric, 2), 'lng', round(h.lng::numeric, 2),
           'claimed', h.claimed,
           'record_dated', (h.expiry_date ~ '^\d{2}/\d{2}/\d{4}$' AND to_date(h.expiry_date,'MM/DD/YYYY') < current_date),
           'absent_from_latest_file', (h.register_file_state = 'absent_from_latest_file')
         ) ORDER BY h.claimed DESC, h.sort_nm, h.nm), '[]'::jsonb)
    INTO v_trades, v_total, v_rows
    FROM hits h;

  RETURN jsonb_build_object(
    'mode', 'results', 'query', v_q, 'county', v_county, 'trade', v_trade,
    'field_status', CASE WHEN v_total = 0 THEN 'none_found' ELSE 'present' END,
    'count', v_total, 'returned', jsonb_array_length(v_rows),
    'order', 'Claimed businesses first, then alphabetical. Not a ranking or a recommendation.',
    'trades', v_trades,
    'source_retrieved', (select to_char(capture_date, 'YYYY-MM-DD') from dbpr_snapshot_log where is_register_source limit 1),
    'coverage_note', 'Licence records reproduced from the state register as retrieved on the date shown. A record dated before today may simply have been renewed since; it is not evidence the licence has lapsed. County is the county recorded on the licence, which is not always the county the business address falls in. Pins are placed near the licence address, rounded, and are not where the business works.',
    'results', v_rows);
END
$$;

grant execute on function public.contractor_finder(text, text, text, integer) to service_role;

-- 140b (applied as its own migration): each result row also carries `trades`, every doc_category the
-- business holds (from `lic`), because a business's primary licence can be a business registration
-- ("Construction Business Information") that says nothing about the work.
do $f$
declare def text; new_def text;
begin
  def := pg_get_functiondef('public.contractor_finder(text,text,text,integer)'::regprocedure);
  new_def := replace(def,
    $o$'slug', h.slug, 'name', h.nm, 'trade', h.trade_label, 'trade_key', h.doc_category,$o$,
    $n$'slug', h.slug, 'name', h.nm, 'trade', h.trade_label, 'trade_key', h.doc_category,
           -- every trade the business holds (its primary licence can be a business registration)
           'trades', coalesce((SELECT to_jsonb(array_agg(l.doc_category ORDER BY l.doc_category)) FROM lic l WHERE l.bid = h.bid), '[]'::jsonb),$n$);
  if new_def = def then raise exception '140b: anchor not found'; end if;
  execute new_def;
end $f$;
grant execute on function public.contractor_finder(text, text, text, integer) to service_role;
