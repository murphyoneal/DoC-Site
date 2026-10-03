-- 219b - the source sweep, the served payloads 219a did not reach (rulings 991, 994; work order 1002).
--
-- A scan of every public function body for artifact vocabulary after 219a found five more served surfaces:
--   agent_public_page        /a/<slug> renders 'source' ("From the Florida DBPR real estate licence file")
--   agent_claim_submit       the claimant-facing 'note' on an unknown licence number
--   get_parcel_permit_facts  the PIR contractor-licence note ("licence file dated ...")
--   search_contractors       Roz's caveat ("DBPR construction licence file (DBPR_FL)"; also stale: we now hold
--                            the electrical register, it is simply not searched here)
--   registration_check_credential  the self-registration check note, rendered publicly on /c and /r; it also
--                            dated the Oregon check by the source's POSTING date (coalesce(posted, retrieved))
-- KEPT: board and agency names ("holds DBPR licence ..." names the issuing authority, a property of the licence);
-- our retrieval dates; the content of the internal reviewer note in agent_claim_request (never served; its wording is aligned).
-- No stored row carries the old wording: registered_credential.check_note/checked_against and
-- agent_claim_request.check_note hold no 'file|DBPR|CCB' text (measured before writing this).
-- Shape-compatible: no key added, renamed or removed. Grants captured and compared; the anon/authenticated
-- grants of a touched function are re-issued (none of these five is browser-called today).

create temp table _sweep (fn regprocedure, old text, new text, expect int) on commit drop;
insert into _sweep values
  ('public.agent_public_page(text)', $o$'source', 'Florida DBPR real estate licence file')$o$,
                                     $n$'source', 'Our records come from federal, state and local sources, or user-inputted data.')$n$, 1),
  ('public.agent_claim_submit(jsonb)', $o$'That licence number is not in the Florida real estate licence file we hold.'$o$,
                                       $n$'That licence number is not in the Florida real estate licence register we hold.'$n$, 1),
  -- the internal reviewer note keeps its content; only its wording loses the artifact name
  ('public.agent_claim_submit(jsonb)', $o$'Name given vs the licence file: '$o$, $n$'Name given vs the licence register: '$n$, 1),
  ('public.get_parcel_permit_facts(numeric,text)', $o$'listed as current in the Florida construction licence file dated '$o$,
                                                   $n$'listed as current in the Florida construction licence register as we retrieved it on '$n$, 1),
  ('public.get_parcel_permit_facts(numeric,text)', $o$'listed in the Florida construction licence file dated '||to_char(rf.register_file_date,'FMDD Mon YYYY')||' but not in the latest file'$o$,
                                                   $n$'listed in the Florida construction licence register as we retrieved it on '||to_char(rf.register_file_date,'FMDD Mon YYYY')||' but not in the latest records we retrieved'$n$, 1),
  ('public.get_parcel_permit_facts(numeric,text)', $o$'in the Florida construction licence file we hold'$o$, $n$'in the Florida construction licence register we hold'$n$, 1),
  ('public.get_parcel_permit_facts(numeric,text)', $o$No business of that name is in the Florida construction licence file we check permits against. Electrical and alarm contractors are licensed by a separate board whose file we have added but do not yet check permits against. These files list current licensees only$o$,
                                                   $n$No business of that name is in the Florida construction licence register we check permits against. Electrical and alarm contractors are licensed by a separate board whose register we have added but do not yet check permits against. These registers list current licensees only$n$, 1),
  ('public.search_contractors(text,text,numeric,boolean,integer)',
     $o$'DBPR construction licence file (DBPR_FL); the city shown is the business address, NOT service area. Licence status/expiry as recorded - verify current standing at myfloridalicense.com. Electrical contractors are licensed by a separate board whose file we do not hold.$o$,
     $n$'Florida Construction Industry Licensing Board licences, as we retrieved them; the city shown is the business address, NOT service area. Licence status/expiry as recorded - verify current standing at myfloridalicense.com. Electrical contractors are licensed by a separate board (the Electrical Contractors'' Licensing Board) and are not searched here.$n$, 1),
  -- registration_check_credential: our retrieval date, never the posting date; no artifact names
  ('public.registration_check_credential(text,text,text,text)', $o$v_date := to_char(coalesce(v_cov.posted_date, v_cov.retrieved_date), 'FMDD Mon YYYY');$o$,
                                                                $n$v_date := to_char(v_cov.retrieved_date, 'FMDD Mon YYYY');  -- 219b: our retrieval date, not the posting date$n$, 1),
  ('public.registration_check_credential(text,text,text,text)', $o$'checked_against', v_cov.source || ', retrieved '$o$, $n$'checked_against', v_state || ' licence register, retrieved '$n$, 2),
  ('public.registration_check_credential(text,text,text,text)', $o$'checked_against', v_cov.source || ', dated ' || v_date$o$, $n$'checked_against', v_state || ' licence register, retrieved ' || v_date$n$, 2),
  ('public.registration_check_credential(text,text,text,text)', $o$' licence file retrieved '$o$, $n$' licence register retrieved '$n$, 2),
  ('public.registration_check_credential(text,text,text,text)', $o$' (the licence was in an earlier file and is not in the latest one)'$o$, $n$' (the licence was in earlier records and is not in the latest we retrieved)'$n$, 1),
  ('public.registration_check_credential(text,text,text,text)', $o$'Not found in the Oregon CCB active-licence file dated ' || v_date
          || '. That file lists active licences only,$o$,
                                                                $n$'Not found in the Oregon Construction Contractors Board active-licence register, retrieved ' || v_date
          || '. That register lists active licences only,$n$, 1),
  ('public.registration_check_credential(text,text,text,text)', $o$'Matches the Oregon CCB active-licence file dated '$o$, $n$'Matches the Oregon Construction Contractors Board active-licence register, retrieved '$n$, 1),
  ('public.registration_check_credential(text,text,text,text)', $o$'Was in an earlier Oregon CCB active-licence file and is not in the one dated '$o$, $n$'Was in earlier Oregon Construction Contractors Board records and is not in the register retrieved '$n$, 1);

do $$
declare f regprocedure; d text; a1 text; a2 text; r record; n int;
begin
  for f in select distinct fn from _sweep loop
    select coalesce(proacl::text,'') into a1 from pg_proc where oid = f;
    d := pg_get_functiondef(f);
    for r in select * from _sweep where fn = f loop
      n := (length(d) - length(replace(d, r.old, ''))) / greatest(length(r.old), 1);
      if n <> r.expect then raise exception '219b: % - anchor found % times, expected %: %', f, n, r.expect, left(r.old, 80); end if;
      d := replace(d, r.old, r.new);
    end loop;
    execute d;
    if a1 like '%anon=X%' then execute format('grant execute on function %s to anon', f); end if;
    if a1 like '%authenticated=X%' then execute format('grant execute on function %s to authenticated', f); end if;
    select coalesce(proacl::text,'') into a2 from pg_proc where oid = f;
    if a2 is distinct from a1 then raise exception '219b: % grants changed % -> %', f, a1, a2; end if;
  end loop;
end $$;

do $$
declare d text; j jsonb; s text;
begin
  -- no artifact vocabulary left in any swept body
  for d in select pg_get_functiondef(fn) from (select distinct fn from _sweep) x loop
    if d ~* $r$'[^']*(DBPR [a-z ]*file|licence file|CCB active-licence file|DBPR_FL)[^']*'$r$ then
      raise exception '219b: artifact string survived: %', substring(d from $r$.{60}(DBPR [a-z ]*file|licence file|CCB active-licence file|DBPR_FL).{40}$r$);
    end if;
    if d ~ 'posted_date' then raise exception '219b: a posting date is still read'; end if;
  end loop;
  -- CALL the functions (a green migration is not a working function)
  j := public.registration_check_credential('licence', 'US-12', 'construction', (select license_number from public.contractors_public where register_file_state = 'in_latest_file' limit 1));
  if j->>'check_state' <> 'register_held_matched' or j->>'check_note' !~ 'licence register retrieved' then raise exception '219b: FL check broke: %', j; end if;
  j := public.registration_check_credential('licence', 'US-12', 'construction', 'ZZZ0000000');
  if j->>'check_state' <> 'register_held_no_match' then raise exception '219b: FL no-match broke: %', j; end if;
  j := public.registration_check_credential('licence', 'US-41', 'construction', (select license_number from reg_us_or.ccb_active_license limit 1));
  if j->>'check_note' !~ 'Construction Contractors Board' or j::text ~* 'file' then raise exception '219b: OR check broke: %', j; end if;
  s := (public.search_contractors('roofing', null, null, false, 3))::text;
  if s ~* 'DBPR_FL|licence file' or s !~ 'Construction Industry Licensing Board' then raise exception '219b: search_contractors caveat wrong'; end if;
  j := public.agent_public_page((select slug from public.agent_public_profile limit 1));
  if j is not null and j::text ~* 'licence file' then raise exception '219b: agent page still names the file'; end if;
  raise notice '219b: five payloads clean; checks return (FL match, FL miss, OR) without artifact names';
end $$;

select public._log_action('cc', 'source_sweep_remaining_payloads', 'registration_check_credential',
  array['agent_public_page','agent_claim_submit','get_parcel_permit_facts','search_contractors','registration_check_credential'], null,
  jsonb_build_object('stripped', 'licence file wording, DBPR_FL code, posting date in the OR check', 'kept', 'agency/board names, retrieval dates, internal reviewer note'),
  'Ruling 994 / work order 1002: the served payloads 219a did not reach.', null);
