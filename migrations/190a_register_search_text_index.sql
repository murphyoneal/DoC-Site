-- 190a - an indexable search column for the public register search, which is timing out on the publishable key.
--
-- MEASURED 2026-10-01 over REST with the publishable (anon) key, statement_timeout 3s (ruling 875 probe):
--   contractor_register_search('roofing') -> HTTP 500 / 57014 at 3,135 ms   <- the public register fails on its most
--   contractor_register_search('smith')   -> 200 at 3,520 ms wall            natural query
--   'ele' 2,968 ms, 'air' 2,596 ms, 'abc' 2,575 ms; direct in-database 'smith' 2,507 ms.
-- Every word must appear in business_name, display_name, trading_name, licence number (prefix), city, county or
-- trade_label, tested by ILIKE across 114,105 rows with no usable index - a full scan per word per request.
-- search_text concatenates exactly those fields (with the existing 'dade' -> 'miami-dade' alias), lower-cased, with a
-- separator that no search word can span. It is a NECESSARY condition: any row the exact predicate accepts contains
-- every word in search_text. So the function can prefilter on it through a trigram index and then apply its existing
-- exact predicate unchanged - same results, by construction (asserted by output identity in 190b).
-- Additive; no consumer reads this column. contractors_public lists its columns explicitly, so it is unaffected.

alter table public.contractors add column if not exists search_text text generated always as (
  lower(
    coalesce(business_name, '') || ' | ' || coalesce(display_name, '') || ' | ' || coalesce(trading_name, '') || ' | ' ||
    coalesce(license_number, '') || ' | ' || coalesce(city, '') || ' | ' || replace(coalesce(county_name, ''), '_', ' ') ||
    case when county_name = 'dade' then ' | miami-dade' else '' end || ' | ' || coalesce(trade_label, '')
  )) stored;
comment on column public.contractors.search_text is
  'Generated (190a): the fields contractor_register_search matches on, lower-cased, '' | ''-separated. A NECESSARY-condition prefilter for the trigram index; the search still applies its exact per-field predicate. Never displayed.';
create index if not exists contractors_search_text_trgm on public.contractors using gin (search_text gin_trgm_ops);
analyze public.contractors;

select public._log_action('cc', 'add_register_search_text', 'contractors', array['search_text','contractors_search_text_trgm'],
  jsonb_build_object('roofing_anon', 'HTTP 500 57014 at 3135 ms', 'smith_anon_ms', 3520),
  jsonb_build_object('added', 'generated search_text + gin trigram index'),
  'The public register search times out under the 3 s anon limit on common words (roofing). Additive indexable prefilter column; the function change and its output-identity proof follow in 190b.', null);
