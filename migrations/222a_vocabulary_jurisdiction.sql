-- 222a - every trade vocabulary row names the jurisdiction whose law gives it meaning (work order 1009 parts 1a/1c,
-- rulings 988/989).
--
-- 1009: "THE TRADE VOCABULARY IS FLORIDA STATUTE WEARING A NATIONAL LABEL." "General Contractor" means unlimited scope
-- because s.489.105, F.S. says so; another state's class mapped onto that label publishes a scope claim no board made.
-- Measured before this migration: trade_display_category (28), trade_search_term (55), trade_code_registry (41) and the
-- trade_chip_map view carried ZERO columns naming a jurisdiction.
-- ADDITIVE ONLY: a jurisdiction column (ISO-namespaced geo_id, the key register_coverage already uses), backfilled
-- 'US-12' because every row today is Florida vocabulary, NOT NULL with NO default - a future row must say whose law it
-- is, and a default would let a California class silently become Florida's. Primary keys are NOT re-keyed to
-- (jurisdiction, ...) here: that, and the canonical-vs-island licence table, are the 1b proposal awaiting a ruling.
-- Until then a guard refuses any non-Florida vocabulary row, because nothing downstream can keep two jurisdictions'
-- classes apart yet.

alter table public.trade_display_category add column jurisdiction text;
alter table public.trade_search_term      add column jurisdiction text;
alter table public.trade_code_registry    add column jurisdiction text;

update public.trade_display_category set jurisdiction = 'US-12';
update public.trade_search_term      set jurisdiction = 'US-12';
update public.trade_code_registry    set jurisdiction = 'US-12';

alter table public.trade_display_category alter column jurisdiction set not null,
  add constraint trade_display_category_jurisdiction_ck check (jurisdiction = 'US-12');
alter table public.trade_search_term alter column jurisdiction set not null,
  add constraint trade_search_term_jurisdiction_ck check (jurisdiction = 'US-12');
alter table public.trade_code_registry alter column jurisdiction set not null,
  add constraint trade_code_registry_jurisdiction_ck check (jurisdiction = 'US-12');

comment on column public.trade_display_category.jurisdiction is
  'Whose law gives this category its meaning (geo_id). Florida only until the vocabulary is re-keyed (jurisdiction, category) by ruling - the CHECK refuses another state''s row until then (222a, work order 1009 1c).';
comment on column public.trade_search_term.jurisdiction is 'Jurisdiction of the category this term resolves to (geo_id). Florida only until re-keyed (222a).';
comment on column public.trade_code_registry.jurisdiction is
  'Issuing jurisdiction of this licence class (geo_id). A class is meaningful only inside its issuing jurisdiction; Florida only until re-keyed (222a).';

-- the chip view carries the column through (appended, so existing column positions are unchanged)
do $$
declare d text; a text := E'AS min_plottable_share
   FROM trade_display_category d';
begin
  d := pg_get_viewdef('public.trade_chip_map'::regclass, true);
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '222a: view anchor not found exactly once'; end if;
  execute 'create or replace view public.trade_chip_map as '
    || replace(d, a, E'AS min_plottable_share,
    d.jurisdiction
   FROM trade_display_category d');
end $$;

do $$
declare n int;
begin
  select count(*) into n from public.trade_chip_map where jurisdiction is distinct from 'US-12';
  if n <> 0 then raise exception '222a: chip view rows without Florida jurisdiction: %', n; end if;
  if (select count(*) from public.trade_chip_map) <> 28 then raise exception '222a: chip view row count changed'; end if;
  begin
    insert into public.trade_code_registry (trade_code, jurisdiction) values ('ZZTEST', 'US-06');
    raise exception '222a: guard accepted a non-Florida class';
  exception when check_violation or not_null_violation then null;
  end;
  raise notice '222a: jurisdiction on 3 vocabulary tables + chip view; non-Florida rows refused';
end $$;

select public._log_action('cc', 'vocabulary_jurisdiction', 'trade_code_registry',
  array['trade_display_category','trade_search_term','trade_code_registry','trade_chip_map'], null,
  jsonb_build_object('key', 'geo_id', 'backfill', 'US-12', 'default', 'none', 'guard', 'US-12 only until re-keyed by ruling'),
  'Work order 1009 1a/1c: a class is meaningful only inside its issuing jurisdiction.', null);
