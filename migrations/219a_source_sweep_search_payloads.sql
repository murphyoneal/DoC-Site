-- 219a - the source sweep, search payloads first (rulings 991, 992, 994; work order 1002: "we're keeping traceability
-- on dates.. we're not giving away source").
--
-- 994's test, per sentence: COULD A VISITOR LEARN THIS BY USING THE SITE OR BY READING THE LAW? Yes -> publish; learnable
-- only from our pipeline or inventory -> strip. Payloads go first because JSON is scraped wholesale (994).
--   STRIPPED  "Florida DBPR public licence file" (names our artifact) -> the attribution line; file names; the state's
--             file URL; a source file's POSTING date; "roster pull", "status file" (pipeline vocabulary).
--   KEPT      OUR RETRIEVAL DATE on every record (it dates our claim; a status without it is unsupported - 994, 1002);
--             board names (public law, a property of the licence); the board lookup URL (verification tool, 1002);
--             finder register_coverage naming the boards (955 stands).
-- Shape-compatible on purpose (coupled-deploy rule): keys the pages read keep their names. file_date now carries our
-- retrieval date instead of the file's posting date - the same field, a truthful value - and 'source' carries the
-- attribution line (public/agents.html renders it as "Source: ..."). Keys no page reads are removed. The browser RPCs are
-- re-granted and asserted.

create temp table _sweep (fn regprocedure, old text, new text, expect int) on commit drop;
insert into _sweep values
  -- contractor_register_search
  ('public.contractor_register_search(text,integer)', $o$    'source', 'Florida DBPR public licence file',$o$,
                                                      $n$    'source', 'Our records come from federal, state and local sources, or user-inputted data.',$n$, 1),
  ('public.contractor_register_search(text,integer)', $o$    'source_posted', (select to_char(posted_date, 'YYYY-MM-DD') from public.dbpr_snapshot_log where is_register_source limit 1),
$o$, '', 1),
  -- register_search: retrieval dates, no file labels, no source URL, coverage note without artifacts
  ('public.register_search(text,integer)', $o$  select to_char(posted_at, 'YYYY-MM-DD'), source_url into v_eclb_posted, v_eclb_url$o$,
                                           $n$  select to_char(captured_at, 'YYYY-MM-DD'), null::text into v_eclb_posted, v_eclb_url  -- 219a: our retrieval date, no source URL$n$, 1),
  ('public.register_search(text,integer)', $o$           'file_date', v_c->>'source_posted',$o$, $n$           'file_date', v_c->>'source_retrieved',$n$, 1),
  ('public.register_search(text,integer)', $o$        'file', 'Florida DBPR construction licence file', 'file_date', v_c->>'source_posted',$o$,
                                           $n$        'file_date', v_c->>'source_retrieved',$n$, 1),
  ('public.register_search(text,integer)', $o$        'file', 'Florida DBPR electrical contractor licence file', 'file_date', v_eclb_posted, 'source_url', v_eclb_url,$o$,
                                           $n$        'file_date', v_eclb_posted,$n$, 1),
  ('public.register_search(text,integer)', $o$'Two state licence files, each reproduced as published on the date shown: construction (Construction Industry Licensing Board) and electrical (Electrical Contractors'' Licensing Board). A licence register shows who is licensed now; we show the file as of its date, so a record may have been renewed or changed since. County is the county recorded on the licence.'$o$,
                                           $n$'Florida licenses construction and electrical contractors through two boards: the Construction Industry Licensing Board and the Electrical Contractors'' Licensing Board. Each record is shown as we retrieved it, on the date shown, so it may have been renewed or changed since. County is the county recorded on the licence. Our records come from federal, state and local sources, or user-inputted data.'$n$, 1),
  -- contractor_finder: register_coverage keeps naming the boards (955), loses the file label (both modes)
  ('public.contractor_finder(text,text,text,integer,integer)', $o$          'file', 'Florida DBPR construction licence file',
$o$, '', 2),
  -- get_eclb_entry: no file name, no file URL; file_date is our retrieval date
  ('public.get_eclb_entry(text)', $o$      'file_name', x.file_name,
$o$, '', 1),
  ('public.get_eclb_entry(text)', $o$      'file_source_url', x.source_url,
$o$, '', 1),
  ('public.get_eclb_entry(text)', $o$      'file_date', to_char(x.posted_at, 'YYYY-MM-DD'),$o$, $n$      'file_date', to_char(x.captured_at, 'YYYY-MM-DD'),  -- 219a: our retrieval date$n$, 1),
  -- agent_register_search
  ('public.agent_register_search(text,integer)', $o$  SELECT l.posted_date INTO v_status_as_of$o$, $n$  SELECT l.capture_date INTO v_status_as_of  -- 219a: our retrieval date, not the file's posting date$n$, 1),
  ('public.agent_register_search(text,integer)', $o$    'source',            'Florida DBPR public licence file',$o$,
                                                 $n$    'source',            'Our records come from federal, state and local sources, or user-inputted data.',$n$, 1),
  ('public.agent_register_search(text,integer)', $o$    'Licence records reproduced from the Florida state register. This register is served from two '
    || 'files of two different dates: name, licence type and county come from a roster pull '
    || 'captured no earlier than ' || coalesce(to_char(v_identity_min,'DD Mon YYYY'),'an unrecorded date')
    || ', and licence status and expiry from the state file posted '
    || coalesce(to_char(v_status_as_of,'DD Mon YYYY'),'an unrecorded date') || '. '$o$,
     $n$    'Licence records as the Florida state register showed them on the dates we retrieved them: '
    || 'name, licence type and county as retrieved no earlier than '
    || coalesce(to_char(v_identity_min,'DD Mon YYYY'),'an unrecorded date')
    || ', and licence status and expiry as retrieved on '
    || coalesce(to_char(v_status_as_of,'DD Mon YYYY'),'an unrecorded date') || '. '$n$, 1),
  ('public.agent_register_search(text,integer)', $o$    || 'An entry with no status line appears in the later roster but not in the status file we '
    || 'hold - that is a gap on our side, not a lapsed licence. '$o$,
     $n$    || 'An entry with no status line has no status in the records we hold - that is a gap on our '
    || 'side, not a lapsed licence. '$n$, 1);

do $$
declare f regprocedure; d text; a1 text; a2 text; r record; n int;
begin
  for f in select distinct fn from _sweep loop
    select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
    d := pg_get_functiondef(f);
    for r in select * from _sweep where fn = f loop
      n := (length(d) - length(replace(d, r.old, ''))) / greatest(length(r.old), 1);
      if n <> r.expect then raise exception '219a: % - anchor found % times, expected %: %', f, n, r.expect, left(r.old, 80); end if;
      d := replace(d, r.old, r.new);
    end loop;
    execute d;
    if a1 like '%anon=X%' then execute format('grant execute on function %s to anon', f); end if;
    if a1 like '%authenticated=X%' then execute format('grant execute on function %s to authenticated', f); end if;
    select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
    if a2 is distinct from a1 then raise exception '219a: % grants changed % -> %', f, a1, a2; end if;
  end loop;
end $$;

do $$
declare j text; e jsonb; a jsonb; det jsonb;
begin
  j := (public.register_search('roofing', 5))::text || (public.contractor_register_search('roofing', 5))::text
    || (public.contractor_finder('roofing', null, null, 5, 0))::text || (public.contractor_finder(null, null, null, 1, 0))::text
    || (public.get_eclb_entry((select license_number from reg_us_fl.eclb_licence where record_kind = 'licence' limit 1)))::text
    || (public.agent_register_search('smith', 5))::text;
  if j ~* '(DBPR|licence file|posted|source_url|file_name|file_source_url|\.csv|roster pull|status file)' then
    raise exception '219a: a source string survived: %', substring(j from '(.{60}(DBPR|licence file|posted|source_url|file_name|file_source_url|\.csv|roster pull|status file).{40})');
  end if;
  -- retrieval dates still present on every surface
  if (public.register_search('roofing', 5)->'results'->0->>'file_date') is null then raise exception '219a: register_search rows lost their retrieval date'; end if;
  if (public.contractor_register_search('roofing', 5)->>'source_retrieved') is null then raise exception '219a: contractor search lost its retrieval date'; end if;
  e := public.get_eclb_entry((select license_number from reg_us_fl.eclb_licence where record_kind = 'licence' limit 1));
  if e->>'file_date' is null or e->>'board_lookup_url' is null then raise exception '219a: entry lost its date or verification link: %', e; end if;
  a := public.agent_register_search('smith', 5);
  if a->>'status_as_of' is null or a->>'identity_as_of_min' is null then raise exception '219a: agent search lost its dates'; end if;
  if (public.contractor_finder('roofing', null, null, 5, 0)->'register_coverage'->'not_covered'->0->>'label') is null then raise exception '219a: finder lost its board naming (955)'; end if;
  -- the detections that guard the dates and the caveat still pass
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'licence-status-served-without-date-and-caveat')) into det;
  if (det->>'ok')::boolean is distinct from true then raise exception '219a: licence caveat detection broke: %', det; end if;
  if not has_function_privilege('anon','public.register_search(text,integer)','EXECUTE') or not has_function_privilege('anon','public.agent_register_search(text,integer)','EXECUTE')
     or not has_function_privilege('anon','public.contractor_register_search(text,integer)','EXECUTE') then raise exception '219a: a browser RPC lost anon'; end if;
  raise notice '219a: payloads clean of source strings; retrieval dates present; caveat detection %', det;
end $$;

select public._log_action('cc', 'source_sweep_search_payloads', 'register_search',
  array['register_search','contractor_register_search','contractor_finder','get_eclb_entry','agent_register_search'], null,
  jsonb_build_object('stripped', 'file names, file URL, posting dates, "DBPR ... file", pipeline vocabulary', 'kept', 'retrieval dates, board names, verification link, 955 line'),
  'Rulings 991/992/994, work order 1002: sources go, retrieval dates stay; payloads first.', null);
