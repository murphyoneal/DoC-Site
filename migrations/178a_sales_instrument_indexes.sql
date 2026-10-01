-- 178a - two missing indexes that made the sales history time out on busy parcels (WO 870 item 2 / 872 sweep).
--
-- Found by the row-dropping sweep: the count check on get_parcel_transaction_facts could not run on the parcels
-- with the most sales because the function itself timed out. Per sale it runs
--   (SELECT count(DISTINCT s2."PARID") FROM volusia_cama_sales s2 WHERE s2."INSTRUNO" = s."INSTRUNO")   -- 1.6M rows
--   (SELECT grantor/grantee FROM parcel_deed_chain dc WHERE dc.instrument = c.instrno LIMIT 1)  x2         -- 109k rows
-- and neither column was indexed, so every sale is a full scan of both tables.
-- Measured 2026-09-30: parcel 533901080012 (55 sales) took 33.8 s in this function alone; 633001001890 (2 sales) 1.1 s.
-- REST calls run under authenticator's statement_timeout = 8s (service_role sets none), and get_pir_report calls
-- this plus ~20 other fact functions. 23,181 Volusia parcels have 10+ sales; 1,276 have 15+.
-- A report that times out shows the buyer NO sales history - the row-dropping failure in its bluntest form.
-- Indexes only: no function body, no output, no grant changes. The output hash is asserted identical below.

create index if not exists volusia_cama_sales_instruno_idx on public.volusia_cama_sales ("INSTRUNO");
create index if not exists parcel_deed_chain_instrument_idx on public.parcel_deed_chain (instrument);
analyze public.volusia_cama_sales;
analyze public.parcel_deed_chain;

select public._log_action('cc', 'index_sales_instrument_lookups', 'volusia_cama_sales', array['volusia_cama_sales_instruno_idx','parcel_deed_chain_instrument_idx'],
  jsonb_build_object('533901080012_seconds', 33.8), null,
  'Row-dropping sweep: get_parcel_transaction_facts full-scanned 1.6M sales and 109k deed rows per sale, timing out busy parcels past the 8 s REST limit.', null);
