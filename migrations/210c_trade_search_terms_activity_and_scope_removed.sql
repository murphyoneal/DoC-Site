-- 210c - remove three search terms that broke Murphy's claimed-vs-recorded rule (ruling 972; claude's session refuses
-- destructive DDL, so cc applies it).
--   security          -> alarm_system: a security business may do guards, cameras or cyber. It names a market, not
--                        another name for the Alarm System Contractor licence.
--   builder, builders -> general_contractor: "builder" spans the General, Building AND Residential classes. Mapping it
--                        to general_contractor steers the visitor to the UNLIMITED scope (s.489.105), the one category
--                        209a stripped from 10,125 pages that did not hold it.
-- Recount inside the migration before deleting (memory recount-before-destructive-ddl); the deleted rows are logged.

do $$
declare n int; before jsonb;
begin
  select jsonb_agg(to_jsonb(t)) into before from public.trade_search_term t where term in ('security','builder','builders');
  select count(*) into n from public.trade_search_term where term in ('security','builder','builders');
  if n is distinct from 3 then raise exception '210c: expected 3 rows to remove, found %', n; end if;
  delete from public.trade_search_term where term in ('security','builder','builders');
  if exists (select 1 from public.trade_search_term where term in ('security','builder','builders')) then raise exception '210c: rows remain'; end if;
  perform public._log_action('cc', 'trade_search_terms_removed', 'trade_search_term', array['security','builder','builders'], before, null,
    'Ruling 972: a term may map to a class only when it is another name for that class; these named a market or guessed a scope.', null);
end $$;
