-- 187a - a derived table checked against its SOURCE, not only the served block against the county table (ruling 896 D3,
-- 898 item 1). Also the register's record of the known degradation 186a introduced.
--
-- permit_surface_count_mismatches compares the served permit block with volusia_cama_permits, so it is honest and reports
-- 0 - and it cannot see a DERIVED table falling behind its source, which is what produced the live roof false statement.
-- Two detections, one per derived table, each keyed on derived_table_asof (186a):
--   derived-permit-history-behind-source  a county permit dated after property_permit_history's as-of is missing from it
--   derived-deed-chain-behind-source      a county sale dated after parcel_deed_chain's as-of exists (the chain cannot
--                                         hold its parties)
-- Both are RED today by design. KNOWN DEGRADATION, stated so nobody reads it as a property of Volusia:
--   cause      property_permit_history built 2026-06-28 (7,524 later permits missing, 6,587 parcels; 186a gates their roof
--              block to not_available); parcel_deed_chain ends 2019-01-09 (every later sale shows "Parties not held").
--   lifting    rebuild each derived table from its source (898 item 2 / D4); the roof gate lifts by itself because its
--              condition stops being true, and these detections go green.
-- Cheap by construction: EXISTS stops at the first missing row; the year filter on the text date keeps the scan to recent
-- rows before cama_date() parses anything.

insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values
('derived-permit-history-behind-source',
 'property_permit_history is missing county permits dated after its recorded as-of (derived_table_asof) - every block reading it is older than the permit list beside it',
 'completeness', 'blocking',
 $q$select not exists (
    select 1 from public.volusia_cama_permits p
     where p."PERMDT" ~ '/\d\d/(2[6-9]) '
       and public.cama_date(p."PERMDT") > (select source_as_of from public.derived_table_asof where table_name = 'property_permit_history')
       and not exists (select 1 from public.property_permit_history h where h.parcel_id = p."PARID" and h.permit_number = p."NUM")) as ok$q$,
 'KNOWN DEGRADATION (187a): RED until property_permit_history is rebuilt (cause: built 2026-06-28; 7,524 later permits missing on 6,587 parcels; 186a gates their roof block). Lifting condition: rebuild from volusia_cama_permits and update derived_table_asof. The year filter assumes the as-of is in 2026 or later; if the as-of is moved earlier than 2026 the filter must widen.'),
('derived-deed-chain-behind-source',
 'parcel_deed_chain cannot carry parties for county sales dated after its recorded as-of (derived_table_asof)',
 'completeness', 'material',
 $q$select not exists (
    select 1 from public.volusia_cama_sales s
     where s."SALEDT" ~ '/\d\d/(19|2\d) '
       and public.cama_date(s."SALEDT") > (select source_as_of from public.derived_table_asof where table_name = 'parcel_deed_chain')
       and public.cama_date(s."SALEDT") <= current_date) as ok$q$,
 'KNOWN DEGRADATION (187a): RED until the deed chain is rebuilt from a party-bearing source (cause: chain ends 2019-01-09; volusia_cama_sales has no party columns; 186b makes the page say "Parties not held"). Lifting condition: a source carrying parties after 2019 is loaded and derived_table_asof updated. Year filter assumes the as-of is 2019 or later.');

select public._log_action('cc', 'register_derived_vs_source_checks', 'data_defect_registry',
  array['derived-permit-history-behind-source','derived-deed-chain-behind-source'], null,
  jsonb_build_object('state_today', 'both red by design (known degradation)'),
  'Ruling 896 D3 / 898: no check compared a derived table with its source; the roof false statement passed every existing check. Two detections, recorded as the known degradation with cause and lifting condition.', null);

-- both directions, in-migration: red now; green when the derived table covers its source (simulated by moving the as-of
-- past the source, inside a sub-block that is rolled back)
do $$
declare p_now boolean; d_now boolean; p_green boolean; d_green boolean;
begin
  execute (select detection_sql from public.data_defect_registry where defect_id = 'derived-permit-history-behind-source') into p_now;
  execute (select detection_sql from public.data_defect_registry where defect_id = 'derived-deed-chain-behind-source') into d_now;
  if p_now is distinct from false or d_now is distinct from false then raise exception '187a: expected both red today, got % / %', p_now, d_now; end if;
  begin
    update public.derived_table_asof set source_as_of = current_date where table_name in ('property_permit_history', 'parcel_deed_chain');
    execute (select detection_sql from public.data_defect_registry where defect_id = 'derived-permit-history-behind-source') into p_green;
    execute (select detection_sql from public.data_defect_registry where defect_id = 'derived-deed-chain-behind-source') into d_green;
    raise exception 'ROLLBACK_GREEN_PROBE';
  exception when others then
    if sqlerrm <> 'ROLLBACK_GREEN_PROBE' then raise; end if;
  end;
  if p_green is distinct from true or d_green is distinct from true then raise exception '187a: detections cannot go green (% / %)', p_green, d_green; end if;
  if (select source_as_of from public.derived_table_asof where table_name = 'property_permit_history') is distinct from date '2026-06-28' then
    raise exception '187a: green probe did not roll back';
  end if;
end $$;
