-- 173a - one Volusia parcel -> alt-key resolver for every served function (ruling 830, decision 3).
--
-- Measured 2026-09-30: of 240,264 distinct permit PARIDs, volusia_parcels_govt_source (the served resolver)
-- keys 222,968 (92.8%); parcel_attributes.alt_key keys 236,817 (98.6%); they disagree on 2 of 220,052 overlaps.
-- The same govt_source lookup sat in SEVEN served functions, not one - switching only the permit function would
-- have resolved one house through two different keys inside a single report (the two-stores defect).
--
-- parcel_alt_key(): parcel_attributes first (statewide, UNIQUE (co_no, parcel_id)), govt_source as fallback for the
-- ~2,900 PARIDs only it resolves. Six call sites swap their SELECT for it; get_pir_report keeps its own select
-- (it also reads subnum) and is overridden right after.
--
-- The 154 orphans (permits whose PARID has no properties row), measured BEFORE this: 26 resolve via
-- parcel_attributes, 0 via govt_source, 128 via neither. So this recovers 26; the 128 are the real finding.

create or replace function public.parcel_alt_key(p_co_no numeric, p_parcel_id text) returns text
language sql stable set search_path to 'public' as $$
  select coalesce(
    (select nullif(a.alt_key, '') from public.parcel_attributes a where a.co_no = p_co_no and a.parcel_id = p_parcel_id),
    (select v.altkey::bigint::text from public.volusia_parcels_govt_source v where p_co_no = 74 and v.pid = p_parcel_id limit 1))
$$;
comment on function public.parcel_alt_key(numeric, text) is
  'The one resolver from a DOR parcel id to the county alt key (173a): parcel_attributes.alt_key first (98.6% of Volusia permit PARIDs), volusia_parcels_govt_source as fallback. Every served function uses this - never a second lookup.';

do $$
declare f text; d text; n int;
  fns text[] := array['get_parcel_identity_frame(numeric,text)','get_parcel_permit_facts(numeric,text)','get_parcel_repose_window(numeric,text)',
                      'get_parcel_transaction_facts(numeric,text)','get_parcel_values_facts(numeric,text)','owner_join_key(numeric,text,text)'];
  pat text := 'SELECT\s+altkey::bigint::text\s+INTO\s+(\w+)\s+FROM\s+(public\.)?volusia_parcels_govt_source\s+WHERE\s+pid\s*=\s*p_parcel_id\s+LIMIT\s+1;';
begin
  foreach f in array fns loop
    d := pg_get_functiondef(f::regprocedure);
    n := (select count(*) from regexp_matches(d, pat, 'g'));
    if n <> 1 then raise exception '173a: % has % resolver statements, expected 1', f, n; end if;
    d := regexp_replace(d, pat, '\1 := public.parcel_alt_key(p_co_no, p_parcel_id);');
    execute d;
  end loop;

  d := pg_get_functiondef('public.get_pir_report(numeric,text)'::regprocedure);
  n := (select count(*) from regexp_matches(d, '(FROM\s+volusia_parcels_govt_source\s+WHERE\s+p_co_no\s*=\s*74\s+AND\s+pid\s*=\s*p_parcel_id\s+LIMIT\s+1;)', 'g'));
  if n <> 1 then raise exception '173a: get_pir_report has % anchors, expected 1', n; end if;
  d := regexp_replace(d, '(FROM\s+volusia_parcels_govt_source\s+WHERE\s+p_co_no\s*=\s*74\s+AND\s+pid\s*=\s*p_parcel_id\s+LIMIT\s+1;)',
                  '\1
  v_altkey := coalesce(public.parcel_alt_key(p_co_no, p_parcel_id), v_altkey);  -- 173a: one resolver');
  if position('public.parcel_alt_key(p_co_no, p_parcel_id), v_altkey)' in d) = 0 then raise exception '173a: get_pir_report override not inserted'; end if;
  execute d;
end $$;

-- grants: re-assert exactly what each function held (the secdef ones lose only anon/authenticated on replace)
grant execute on function public.parcel_alt_key(numeric, text) to public;
grant execute on function public.get_pir_report(numeric,text) to service_role, consumer_report_readonly, roz_payload_reader;
grant execute on function public.get_parcel_identity_frame(numeric,text) to service_role;
grant execute on function public.get_parcel_repose_window(numeric,text) to service_role;

do $$
declare b record; bad int := 0;
begin
  -- (a) where both resolvers already agreed, every output is byte-identical to the pre-switch baseline
  for b in select * from public._resolver_switch_baseline loop
    if md5(coalesce(get_parcel_permit_facts(74, b.parcel_id)::text,'')) <> b.permit_h
       or md5(coalesce(get_parcel_transaction_facts(74, b.parcel_id)::text,'')) <> b.txn_h
       or md5(coalesce(get_parcel_values_facts(74, b.parcel_id)::text,'')) <> b.val_h
       or md5(coalesce(get_parcel_identity_frame(74, b.parcel_id)::text,'')) <> b.id_h
       or md5(coalesce(get_parcel_repose_window(74, b.parcel_id)::text,'')) <> b.rep_h then
      bad := bad + 1;
    end if;
  end loop;
  if bad > 0 then raise exception '173a: % of 25 agreeing parcels changed output', bad; end if;
  -- (b) the founding parcel still serves its permits
  if (get_parcel_permit_facts(74, '633001001890')->>'count')::int < 1 then raise exception '173a: founding parcel lost permits'; end if;
  if (get_pir_report(74, '633001001890')) is null then raise exception '173a: get_pir_report broke'; end if;
  -- (c) no served function still does its own govt_source alt-key lookup
  if exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
              and p.proname <> 'parcel_alt_key' and p.prosrc ~ 'SELECT\s+altkey::bigint::text\s+INTO\s+\w+\s+FROM\s+(public\.)?volusia_parcels_govt_source\s+WHERE\s+pid\s*=\s*p_parcel_id\s+LIMIT\s+1;') then
    raise exception '173a: a second resolver survived';
  end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '173a: register grants lost'; end if;
  if not has_function_privilege('roz_payload_reader', 'public.get_pir_report(numeric,text)', 'execute') then raise exception '173a: get_pir_report grant lost'; end if;
end $$;

drop table public._resolver_switch_baseline;
