-- 201b - one public search over both Florida contractor registers, and the electrical register-entry reader
-- (ruling 927 items 1 and 3; 905/906 phase 2).
--
-- register_search(q, lim): the construction register (contractor_register_search, unchanged, board 06) plus the
-- Electrical Contractors' Licensing Board register (reg_us_fl.eclb_licence, board 08), each row carrying the register
-- it came from, its class code and label, its status AS PUBLISHED, the file and its date, whether it is in the latest
-- file, the board's own lookup, and the page it links to (href). Results stay grouped by register - one licence record
-- per row, from one board's file, never merged across boards (one register, one table).
-- STATUS AS PUBLISHED (905): the file's codes are printed as codes. C = current and A / I = active / inactive are the
-- meanings this site already states for the construction file (138a, notHeldNote). The electrical file also carries
-- primary codes P (137 rows) and S (17 rows) whose meaning is NOT recorded here: they print as the code, with the board
-- lookup, and are never translated.
-- Additive: contractor_register_search is untouched, so the deployed pages keep working until the new front end ships.
-- register_search is browser-called (the homepage) - SECURITY DEFINER replace revokes anon/authenticated, so this
-- migration grants and asserts. get_eclb_entry is service-role only (the entry page reads with the service key).

create or replace function public.eclb_status_text(p_primary text, p_secondary text)
returns text language sql immutable as $$
  select case
    when p_primary = 'C' and p_secondary = 'A' then 'Current, active'
    when p_primary = 'C' and p_secondary = 'I' then 'Current, inactive'
    else 'Status codes in the file: ' || coalesce(p_primary, '-') || ' / ' || coalesce(p_secondary, '-')
         || ' (the file''s codes, shown as published; check their meaning with the board)'
  end
$$;

create or replace function public.register_search(q text, lim integer default 25)
returns jsonb language plpgsql stable security definer set search_path to 'public', 'pg_temp' as $$
declare
  v_lim int := greatest(1, least(coalesce(lim, 25), 50));
  v_c jsonb; v_terms text[]; v_county text[]; v_e jsonb; v_e_total int := 0; v_cons jsonb;
  v_board_lookup constant text := 'https://www.myfloridalicense.com/wl11.asp?mode=0&SID=&brd=&typ=';
  v_eclb_posted text; v_eclb_url text;
begin
  v_c := public.contractor_register_search(q, v_lim);
  if v_c->>'field_status' = 'not_run' then
    return v_c || jsonb_build_object('registers', '[]'::jsonb);
  end if;
  select coalesce(array_agg(x), '{}') into v_terms from jsonb_array_elements_text(coalesce(v_c->'terms', '[]')) x;
  select coalesce(array_agg(x), '{}') into v_county from jsonb_array_elements_text(coalesce(v_c->'county_filter', '[]')) x;
  select to_char(posted_at, 'YYYY-MM-DD'), source_url into v_eclb_posted, v_eclb_url
    from reg_us_fl.eclb_extract order by extract_id desc limit 1;

  with e as (
    select l.license_number, l.class_code, l.licensee_name, l.dba_name, l.city,
           l.primary_status_code, l.secondary_status_code, l.expiry_date,
           g.name as county_label, public.county_slug(g.name) as county_key,
           r.official_label as class_label, dc.label as category_label
      from reg_us_fl.eclb_licence l
      left join public.geo_reference g on g.admin_level = 2 and g.geo_id like 'US-12%'
             and l.county_code ~ '^[0-9]+$' and g.dor_co_no = l.county_code::int
      left join public.trade_code_registry r on r.trade_code = l.class_code
      left join public.trade_display_category dc on dc.category = r.display_category
     where l.record_kind = 'licence' and l.register_file_state = 'in_latest_file'
  ), hits as (
    select e.*, coalesce(nullif(e.dba_name, ''), e.licensee_name) as nm, count(*) over () as total
      from e
     where (cardinality(v_county) = 0 or e.county_key = any (v_county))
       and not exists (
         select 1 from unnest(v_terms) w
          where not (
                coalesce(e.licensee_name, '') ilike '%' || w || '%'
             or coalesce(e.dba_name, '')      ilike '%' || w || '%'
             or coalesce(e.license_number, '') ilike w || '%'
             or coalesce(e.city, '')           ilike '%' || w || '%'
             or coalesce(e.county_label, '')   ilike '%' || w || '%'
             or coalesce(e.class_label, '')    ilike '%' || w || '%'
             or coalesce(e.category_label, '') ilike '%' || w || '%'))
     order by nm
     limit v_lim
  )
  select coalesce(max(total), 0),
         coalesce(jsonb_agg(jsonb_build_object(
           'register', 'electrical',
           'register_label', 'Electrical Contractors'' Licensing Board',
           'href', '/e/' || license_number,
           'slug', null,
           'name', nm,
           'licensee', case when nullif(dba_name, '') is not null then licensee_name end,
           'license_number', license_number,
           'class_code', class_code,
           'class_label', class_label,
           'trade', coalesce(category_label, class_label),
           'trade_code', class_code,
           'city', initcap(lower(coalesce(city, ''))),
           'county', coalesce(county_label, ''),
           'status_as_published', coalesce(primary_status_code, '') || '/' || coalesce(secondary_status_code, ''),
           'status_text', public.eclb_status_text(primary_status_code, secondary_status_code),
           'expiry_date', expiry_date,
           'file_date', v_eclb_posted,
           'in_latest_file', true,
           'board_lookup_url', v_board_lookup
         ) order by nm), '[]'::jsonb)
    into v_e_total, v_e
    from hits;

  select coalesce(jsonb_agg(r || jsonb_build_object(
           'register', 'construction',
           'register_label', 'Construction Industry Licensing Board',
           'href', '/c/' || (r->>'slug'),
           'class_code', r->>'trade_code',
           'class_label', r->>'trade',
           'file_date', v_c->>'source_posted',
           'board_lookup_url', v_board_lookup)), '[]'::jsonb)
    into v_cons
    from jsonb_array_elements(coalesce(v_c->'results', '[]')) r;

  return jsonb_build_object(
    'query', v_c->'query',
    'terms', v_c->'terms',
    'county_filter', v_c->'county_filter',
    'match_rule', 'Every word must appear in the business or licensee name, licence number, trade or class, city or county.',
    'field_status', case when coalesce((v_c->>'count')::int, 0) + v_e_total = 0 then 'none_found' else 'present' end,
    'count', coalesce((v_c->>'count')::int, 0) + v_e_total,
    'returned', jsonb_array_length(v_cons) + jsonb_array_length(v_e),
    'registers', jsonb_build_array(
      jsonb_build_object('register', 'construction', 'label', 'Construction Industry Licensing Board',
        'file', 'Florida DBPR construction licence file', 'file_date', v_c->>'source_posted',
        'count', coalesce((v_c->>'count')::int, 0), 'returned', jsonb_array_length(v_cons)),
      jsonb_build_object('register', 'electrical', 'label', 'Electrical Contractors'' Licensing Board',
        'file', 'Florida DBPR electrical contractor licence file', 'file_date', v_eclb_posted, 'source_url', v_eclb_url,
        'count', v_e_total, 'returned', jsonb_array_length(v_e))),
    'coverage_note', 'Two state licence files, each reproduced as published on the date shown: construction (Construction Industry Licensing Board) and electrical (Electrical Contractors'' Licensing Board). A licence register shows who is licensed now; we show the file as of its date, so a record may have been renewed or changed since. County is the county recorded on the licence.',
    'results', v_cons || v_e);
end
$$;

create or replace function public.get_eclb_entry(p_licence text)
returns jsonb language sql stable security definer set search_path to 'public', 'pg_temp' as $$
  select coalesce((
    select jsonb_build_object(
      'found', true,
      'register', 'electrical',
      'register_label', 'Electrical Contractors'' Licensing Board',
      'license_number', l.license_number,
      'class_code', l.class_code,
      'class_label', r.official_label,
      'class_label_state', r.label_state,
      'trade', dc.label,
      'licensee_name', l.licensee_name,
      'business_name', nullif(l.dba_name, ''),
      'city', initcap(lower(coalesce(l.city, ''))),
      'county', g.name,
      'primary_status_code', l.primary_status_code,
      'secondary_status_code', l.secondary_status_code,
      'status_text', public.eclb_status_text(l.primary_status_code, l.secondary_status_code),
      'original_date', l.original_date,
      'effective_date', l.effective_date,
      'expiry_date', l.expiry_date,
      'specialty_code', l.specialty_code,
      'in_latest_file', l.register_file_state = 'in_latest_file',
      'file_name', x.file_name,
      'file_source_url', x.source_url,
      'file_date', to_char(x.posted_at, 'YYYY-MM-DD'),
      'board_lookup_url', 'https://www.myfloridalicense.com/wl11.asp?mode=0&SID=&brd=&typ=')
    from reg_us_fl.eclb_licence l
    left join public.trade_code_registry r on r.trade_code = l.class_code
    left join public.trade_display_category dc on dc.category = r.display_category
    left join public.geo_reference g on g.admin_level = 2 and g.geo_id like 'US-12%'
           and l.county_code ~ '^[0-9]+$' and g.dor_co_no = l.county_code::int
    left join reg_us_fl.eclb_extract x on x.extract_id = l.last_seen_extract_id
    where l.record_kind = 'licence' and upper(l.license_number) = upper(btrim(p_licence))
    limit 1), jsonb_build_object('found', false))
$$;

revoke all on function public.register_search(text, integer) from public;
grant execute on function public.register_search(text, integer) to anon, authenticated, service_role;
revoke all on function public.get_eclb_entry(text) from public, anon, authenticated;
grant execute on function public.get_eclb_entry(text) to service_role;

do $$
declare r jsonb; e jsonb;
begin
  if not has_function_privilege('anon', 'public.register_search(text,integer)', 'execute') then raise exception '201b: register_search not anon-executable'; end if;
  if has_function_privilege('anon', 'public.get_eclb_entry(text)', 'execute') then raise exception '201b: get_eclb_entry must be service-only'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '201b: existing register grants lost'; end if;
  r := public.register_search('alarm county:volusia', 10);
  if coalesce((r->'registers'->1->>'count')::int, 0) = 0 then raise exception '201b: no electrical alarm hits in Volusia - %', r->'registers'; end if;
  e := public.get_eclb_entry('EF0000971');
  if (e->>'found')::boolean is distinct from true then raise exception '201b: entry reader found nothing for a real licence'; end if;
  if (public.get_eclb_entry('ZZNOTALICENCE')->>'found')::boolean is distinct from false then raise exception '201b: entry reader invents'; end if;
end $$;

select public._log_action('cc', 'register_search_two_boards', 'register_search', array['register_search','get_eclb_entry','eclb_status_text'], null,
  jsonb_build_object('registers', jsonb_build_array('construction (board 06)', 'electrical (board 08)'), 'grants', 'register_search anon; get_eclb_entry service_role'),
  'Ruling 927 items 1 and 3: one public search over both state registers, each row naming its board, class, status as published and file date; an entry reader for electrical licences.', null);

-- 201c (applied after 201b): measured over anon REST, every query WITHOUT a county failed 400 22023 - contractor_register_search
-- returns "county_filter": null (a JSON null, not SQL NULL), and coalesce(json_null, '[]') keeps the JSON null, so
-- jsonb_array_elements_text raised. 201b's own assert only tried a county query. Guarded by jsonb_typeof, and the
-- assertion now covers a no-county query.
do $$
declare d text; a1 text; a2 text; r jsonb;
begin
  select coalesce(proacl::text, '') into a1 from pg_proc where oid = 'public.register_search(text,integer)'::regprocedure;
  d := pg_get_functiondef('public.register_search(text,integer)'::regprocedure);
  d := replace(d, $x$jsonb_array_elements_text(coalesce(v_c->'terms', '[]')) x$x$,
                  $x$jsonb_array_elements_text(case when jsonb_typeof(v_c->'terms') = 'array' then v_c->'terms' else '[]'::jsonb end) x$x$);
  d := replace(d, $x$jsonb_array_elements_text(coalesce(v_c->'county_filter', '[]')) x$x$,
                  $x$jsonb_array_elements_text(case when jsonb_typeof(v_c->'county_filter') = 'array' then v_c->'county_filter' else '[]'::jsonb end) x$x$);
  if position('jsonb_typeof(v_c->''county_filter'')' in d) = 0 then raise exception '201c: patch did not apply'; end if;
  execute d;
  grant execute on function public.register_search(text, integer) to anon, authenticated, service_role;
  select coalesce(proacl::text, '') into a2 from pg_proc where oid = 'public.register_search(text,integer)'::regprocedure;
  if not has_function_privilege('anon', 'public.register_search(text,integer)', 'execute') then raise exception '201c: anon grant lost'; end if;
  r := public.register_search('smith', 25);
  if r->>'field_status' is distinct from 'present' then raise exception '201c: no-county query failed: %', left(r::text, 300); end if;
  r := public.register_search('alarm', 25);
  if coalesce((r->'registers'->1->>'count')::int, 0) = 0 then raise exception '201c: no electrical hits for alarm'; end if;
end $$;
