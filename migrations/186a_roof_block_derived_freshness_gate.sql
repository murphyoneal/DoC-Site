-- 186a - the roof block stops asserting from a permit history older than the permit list beside it (ruling 896 D1/D2).
--
-- LIVE FALSE STATEMENT, measured 2026-10-01 on parcel 74/701710160110:
--   permit block:  "REROOF SHINGLE", permit BD26-2985, 2026-08-20 (county file as of 2026-09-28, loaded today, 185a)
--   roof block:    "A permit history is held for this parcel and was searched; no roofing permit is recorded against it."
-- get_parcel_roof_lifespan (served inside get_parcel_env_findings, and wrapped by get_parcel_roof_lifespan_facts) reads
-- property_permit_history - a DERIVED table whose rows were all created 2026-06-28, before even the 2026-07-20 extract
-- was captured. Across Volusia: 7,524 county permits dated after 2026-06-28 are absent from it, on 6,587 parcels; 1,303 of
-- those parcels have a missing ROOFING permit. On those, the roof block understates roof age or denies a re-roof that the
-- permit block shows - in the direction that favours a seller, on the insurance fact in Florida.
--
-- D2, first instance: derived_table_asof records what each derived table was built from and when, with the evidence.
-- The gate: if the county permit file holds a permit for this parcel dated after property_permit_history's as-of that the
-- derived table does not hold, the roof block is not_available and says why. Parcels whose derived rows are complete are
-- unchanged. The estimate is WITHHELD, never shown stale.
-- Rebuilding property_permit_history (D4) is what removes the gate's effect; it needs the builder recovered first.

create table if not exists public.derived_table_asof (
  table_name     text primary key,
  source_table   text not null,
  source_as_of   date not null,          -- the newest source state the derived rows can reflect
  built_at       timestamptz,
  basis          text not null check (length(basis) >= 20),
  recorded_at    timestamptz not null default now()
);
comment on table public.derived_table_asof is
  'Ruling 896 D2: each derived table declares the source state it was built from. A served block whose derived input is older than its source must not render as current. Evidence in basis; never a guess.';
revoke all on public.derived_table_asof from public, anon, authenticated;
grant select on public.derived_table_asof to service_role;

insert into public.derived_table_asof (table_name, source_table, source_as_of, built_at, basis) values
 ('property_permit_history', 'volusia_cama_permits', date '2026-06-28', timestamptz '2026-06-28 18:31:51+00',
  'Every row has created_at 2026-06-28 17:27-18:31 UTC (measured 2026-10-01); built before the 2026-07-20 CAMA extract was captured (2026-07-23). Builder not recovered (registry: built and untracked).'),
 ('parcel_deed_chain', 'deed parties (not volusia_cama_sales, which carries no party columns)', date '2019-01-09', null,
  'max(sale_date) = 2019-01-09 (measured 2026-10-01). volusia_cama_sales has no grantor/grantee columns, so the registry''s derived_from = volusia_cama_sales is wrong; the true source is not recovered.')
on conflict (table_name) do nothing;

do $$
declare d text; n int;
  anchor text := '  if v_alt is null then return ''[]''::jsonb; end if;';
begin
  d := pg_get_functiondef('public.get_parcel_roof_lifespan(numeric,text)'::regprocedure);
  n := (select count(*) from regexp_matches(d, 'if v_alt is null then return ''\[\]''::jsonb; end if;', 'g'));
  if n <> 1 then raise exception '186a: roof getter anchor matched % times', n; end if;
  d := replace(d, anchor, anchor || $g$
  -- 186a: withhold the estimate when the derived permit history is older than the county permit file for this parcel
  if exists (select 1 from volusia_cama_permits p
              where p."PARID" = v_alt
                and cama_date(p."PERMDT") > (select source_as_of from derived_table_asof where table_name = 'property_permit_history')
                and not exists (select 1 from property_permit_history h where h.parcel_id = v_alt and h.permit_number = p."NUM")) then
    return jsonb_build_array(jsonb_build_object(
      'pass','parcel','pass_num',5,'field','roof_lifespan','category','component_lifespan',
      'field_status','not_available','value', null, 'replacement_urgency','not_evaluated','in_replacement_window', null,
      'derived_as_of', (select source_as_of from derived_table_asof where table_name = 'property_permit_history')::text,
      'resolution_level','parcel','relation', null,
      'reason','Our roof estimate is built from a permit history compiled on 28 June 2026, and the county has recorded permits for this property since then that it does not yet include - possibly a re-roof. We do not give a roof estimate until it does. The current permit list is in the permit section; for the roof''s age, ask the county building department or a licensed roofing contractor.'));
  end if;$g$);
  execute d;

  d := pg_get_functiondef('public.get_parcel_roof_lifespan_facts(numeric,text)'::regprocedure);
  if position('''field_status'', case when jsonb_array_length(items) > 0 then ''present''' in d) = 0 then raise exception '186a: facts status anchor missing'; end if;
  d := replace(d, '''field_status'', case when jsonb_array_length(items) > 0 then ''present''',
                  '''field_status'', case when items->0->>''field_status'' = ''not_available'' then ''not_available'' when jsonb_array_length(items) > 0 then ''present''');
  if position('''coverage_caveat'', case when v_alt is not null' in d) = 0 then raise exception '186a: facts caveat anchor missing'; end if;
  d := replace(d, '''coverage_caveat'', case when v_alt is not null',
                  '''coverage_caveat'', case when items->0->>''field_status'' = ''not_available'' then items->0->>''reason'' when v_alt is not null');
  execute d;
end $$;
grant execute on function public.get_parcel_roof_lifespan(numeric,text) to service_role;
grant execute on function public.get_parcel_roof_lifespan_facts(numeric,text) to service_role;

select public._log_action('cc', 'gate_roof_block_on_derived_freshness', 'get_parcel_roof_lifespan', array['get_parcel_roof_lifespan','get_parcel_roof_lifespan_facts','derived_table_asof'],
  jsonb_build_object('false_statement_example', '74/701710160110: roof block "no roofing permit is recorded" beside REROOF SHINGLE 2026-08-20', 'parcels_affected', 6587, 'parcels_missing_roofing_permit', 1303),
  jsonb_build_object('roof_block', 'not_available with stated reason where the derived permit history lacks a post-2026-06-28 county permit'),
  'Ruling 896 D1: the roof block read a permit history compiled 2026-06-28 while the permit block shows the 2026-09-28 county file; on 6,587 Volusia parcels the two disagreed. Withheld, not shown stale.', null);

do $$
declare r jsonb; f jsonb; ok_parcel jsonb;
begin
  r := get_parcel_roof_lifespan(74, '701710160110');
  if r->0->>'field_status' is distinct from 'not_available' then raise exception '186a: the false-statement parcel is not gated: %', r; end if;
  f := get_parcel_roof_lifespan_facts(74, '701710160110');
  if f->>'field_status' is distinct from 'not_available' or f->>'coverage_caveat' not like 'Our roof estimate is built from%' then
    raise exception '186a: facts did not propagate the gate: %', f; end if;
  if (select count(*) from jsonb_array_elements(get_parcel_env_findings(74, '701710160110')) e
       where e->>'field' = 'roof_lifespan' and e->>'field_status' = 'present') <> 0 then
    raise exception '186a: env findings still serve a present roof estimate on the gated parcel'; end if;
  -- parcels whose derived history is complete are byte-identical to before (baselines taken 2026-10-01 pre-apply)
  if md5(get_parcel_roof_lifespan(74, '483201000050')::text) is distinct from '2b9ba29a626b250e9291ea63526f190c'
     or md5(get_parcel_roof_lifespan(74, '483300000400')::text) is distinct from 'c62ef35b8e40e5f3ae2854453082b425' then
    raise exception '186a: an unaffected parcel''s roof output changed';
  end if;
  ok_parcel := get_parcel_roof_lifespan(74, '633001001890');
  if ok_parcel is null then raise exception '186a: roof getter broke'; end if;
end $$;
