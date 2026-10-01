-- 186b - the sales block carries how far our deed-party coverage reaches, so the page can say which kind of blank it is
-- (ruling 896 D1, second half).
--
-- MEASURED 2026-10-01: parcel_deed_chain's newest sale_date is 2019-01-09, and volusia_cama_sales (the county sales
-- file, loaded today as of 2026-09-28) carries NO party columns. get_parcel_transaction_facts takes grantor/grantee from
-- parcel_deed_chain by instrument, so EVERY Volusia sale after 2019-01-09 returns both null, and the report page renders
-- "Parties not on file" - a statement that reads as being about the county record, where the truth is that we do not hold
-- deed parties for sales after that date (not_available, not none_recorded).
-- Additive: 'deed_parties_as_of' on the Volusia return only (from derived_table_asof, 186a). The page change ships with it.

do $$
declare d text; n int;
begin
  d := pg_get_functiondef('public.get_parcel_transaction_facts(numeric,text)'::regprocedure);
  n := (select count(*) from regexp_matches(d, '''conveyances_total'', v_cnt,', 'g'));
  if n <> 2 then raise exception '186b: expected 2 return anchors (Pinellas, Volusia), found %', n; end if;
  if position('p_co_no = 62' in d) > position('volusia_cama_sales' in d) then raise exception '186b: branch order is not Pinellas-then-Volusia'; end if;
  d := regexp_replace(d, '''conveyances_total'', v_cnt,',
         '''conveyances_total'', v_cnt,' || E'\n' ||
         '    ''deed_parties_as_of'', CASE WHEN p_co_no = 74 THEN (SELECT source_as_of::text FROM public.derived_table_asof WHERE table_name = ''parcel_deed_chain'') END,',
         1, 2);
  execute d;
end $$;

select public._log_action('cc', 'state_deed_party_coverage', 'get_parcel_transaction_facts', array['get_parcel_transaction_facts'], null,
  jsonb_build_object('adds', 'deed_parties_as_of (Volusia)', 'value', '2019-01-09'),
  'Ruling 896 D1: every Volusia sale after 2019-01-09 has no deed parties in anything we hold and rendered "Parties not on file"; the payload now states our coverage date so the page can say which blank it is.', null);

do $$
declare t jsonb;
begin
  t := get_parcel_transaction_facts(74, '633001001890');
  if t->>'deed_parties_as_of' is distinct from '2019-01-09' then raise exception '186b: Volusia return lacks deed_parties_as_of: %', t->>'deed_parties_as_of'; end if;
  if (t->>'conveyances_total')::int is distinct from 2 then raise exception '186b: founding parcel conveyances changed'; end if;
end $$;
