-- 206d - the resolver's geometry column is measured, not defaulted (ruling 937 section 7). DEF-006 runs again.
--
-- DEF-006 had been errored with `attribute "geom" does not exist`. layer_resolution.geom_column carries the column default
-- 'geom', so every row inserted without a value asserted a geometry column nobody measured. Measured 2026-10-02:
-- 576 resolver-wired public tables name a geometry column, and 5 of them name one that does not exist. All 5 are
-- attribute tables:
--   collier_cama_int_accounts            (cama_tangible)
--   collier_cama_int_values_rp_history   (cama_values_history)
--   lands_available_for_taxes            (tax_deed_escheat)
--   pinellas_cama_rp_structural_elements (cama_structural)
--   property_permit_history              (cama_permits)
-- This is default-as-assertion inside the control plane (column-default-asserts-unasked-fact). No function names any of
-- those five concepts (pg_proc measured), so nulling them changes nothing that is served.
--   1. Drop the default.
--   2. A BEFORE INSERT/UPDATE trigger measures the column from the catalogue:
--      - a given value is kept only if it names a real geometry/geography column on the table;
--      - otherwise the table's single geometry column is used;
--      - otherwise NULL.
--      A table that does not exist here is left as given, because it cannot be measured.
--   3. Null the five, through the trigger.
--   4. New detection resolver-geom-column-not-in-catalogue, two sources (the resolver vs pg_attribute). Population = rows
--      naming a column on a table that exists.
--   5. DEF-006 reads only measured geometry columns and declares its population (tables examined).
-- Not attached to table-inventory-is-a-snapshot-that-drifts, contrary to 937. lands_available_for_taxes appears three
-- times because it is one statewide register holding three counties: co_no 41 has 2 rows, 64 has 36, 74 has 11. Each
-- layer_resolution row_count is that county's count. Correct partitions, not drift.

alter table public.layer_resolution alter column geom_column drop default;

create or replace function public.layer_resolution_measure_geom()
returns trigger language plpgsql set search_path to 'public', 'pg_temp' as $$
declare rel regclass; measured text; n int;
begin
  if NEW.table_name is null then return NEW; end if;
  rel := to_regclass('public.' || quote_ident(NEW.table_name));
  if rel is null then return NEW; end if;  -- cannot be measured here; left as given
  if NEW.geom_column is not null and exists (
       select 1 from pg_attribute a join pg_type t on t.oid = a.atttypid
        where a.attrelid = rel and a.attname = NEW.geom_column and a.attnum > 0 and not a.attisdropped
          and t.typname in ('geometry','geography')) then
    return NEW;
  end if;
  select min(a.attname), count(*) into measured, n
    from pg_attribute a join pg_type t on t.oid = a.atttypid
   where a.attrelid = rel and a.attnum > 0 and not a.attisdropped and t.typname in ('geometry','geography');
  NEW.geom_column := case when n = 1 then measured else null end;
  return NEW;
end $$;
comment on function public.layer_resolution_measure_geom() is
  '206d (ruling 937): layer_resolution.geom_column is measured from the catalogue, never defaulted. A named column is kept only if it is a real geometry/geography column; otherwise the single geometry column; otherwise NULL.';

drop trigger if exists layer_resolution_measure_geom on public.layer_resolution;
create trigger layer_resolution_measure_geom before insert or update of table_name, geom_column on public.layer_resolution
  for each row execute function public.layer_resolution_measure_geom();

do $$
declare n int;
begin
  update public.layer_resolution set geom_column = null
   where table_name in ('collier_cama_int_accounts','collier_cama_int_values_rp_history','lands_available_for_taxes',
                        'pinellas_cama_rp_structural_elements','property_permit_history')
     and geom_column is not null;
  get diagnostics n = row_count;
  if n < 5 then raise exception '206d: expected at least 5 phantom rows, updated %', n; end if;
end $$;

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation)
values ('resolver-geom-column-not-in-catalogue',
  'A layer_resolution row names a geometry column that is not a geometry column on its table - the resolver asserting what the catalogue does not hold',
  current_date, 'ruling 937 section 7 (DEF-006 died on five phantom geom columns written by a column default)', 'geometry', 'material',
$q$with r as (
      select l.table_name, l.geom_column, to_regclass('public.' || quote_ident(l.table_name)) rel
        from public.layer_resolution l where l.geom_column is not null and l.table_name is not null),
    examined as (select * from r where rel is not null),
    bad as (select * from examined e where not exists (
              select 1 from pg_attribute a join pg_type t on t.oid = a.atttypid
               where a.attrelid = e.rel and a.attname = e.geom_column and a.attnum > 0 and not a.attisdropped
                 and t.typname in ('geometry','geography')))
select not exists (select 1 from bad) as ok,
       (select count(*) from bad) as row_count,
       (select string_agg(distinct table_name || ':' || geom_column, ', ') from bad) as phantoms,
       (select count(*) from examined) as population$q$,
  'clean', 'layer_resolution rows naming a geometry column on a table that exists in public (596 rows / 576 tables on 2026-10-02, before 5 phantoms were nulled)',
  'Two sources: the resolver row vs pg_attribute. The measuring trigger (206d) should keep this green; it goes red if the trigger is dropped or bypassed, or if a geometry column is dropped from a wired table.',
  'active', 'ours', 'Measure geom_column from the catalogue (trigger layer_resolution_measure_geom); never default it.');

update public.data_defect_registry set
  detection_sql = $q$with served as (
      select distinct l.table_name, l.geom_column
        from public.layer_resolution l
        join pg_class c on c.relname = l.table_name and c.relkind = 'r'
        join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
        join pg_attribute a on a.attrelid = c.oid and a.attname = l.geom_column and a.attnum > 0 and not a.attisdropped
        join pg_type t on t.oid = a.atttypid and t.typname = 'geometry'
       where l.table_name is not null and l.geom_column is not null),
    bx as (select s.table_name, st_setsrid(st_estimatedextent('public', s.table_name, s.geom_column)::geometry, 4326) as e from served s)
select (count(*) filter (where e is not null) > 0
        and count(*) filter (where e is not null and not st_intersects(st_makeenvelope(-87.7,24.3,-79.8,31.1,4326), e)) = 0) as ok,
       count(*) filter (where e is not null and not st_intersects(st_makeenvelope(-87.7,24.3,-79.8,31.1,4326), e)) as row_count,
       count(*) filter (where e is not null) as population,
       count(*) filter (where e is null) as no_extent_estimate
  from bx$q$,
  expected_denominator = 'resolver-wired public tables with a real geometry column that has an extent estimate (576 named a geometry column on 2026-10-02; 5 were phantoms, nulled in 206d)',
  false_positive_notes = coalesce(false_positive_notes, '') || ' | 206d (ruling 937): was errored on five phantom geom columns (a column default asserting geometry on attribute tables). Now reads only geometry columns that exist; population = tables with an extent estimate; tables with no estimate are counted separately (no_extent_estimate), not hidden.'
 where defect_id = 'DEF-006';

do $$
declare j jsonb; k jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'resolver-geom-column-not-in-catalogue')) into j;
  if (j->>'ok')::boolean is distinct from true or coalesce((j->>'population')::int, 0) <= 0 then raise exception '206d: phantom detection: %', j; end if;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'DEF-006')) into k;
  if k->>'ok' is null or coalesce((k->>'population')::int, 0) <= 0 then raise exception '206d: DEF-006 still cannot run: %', k; end if;
  raise notice '206d: phantom %; DEF-006 %', j, k;
end $$;

select public._log_action('cc', 'resolver_geom_column_measured', 'layer_resolution',
  array['collier_cama_int_accounts','collier_cama_int_values_rp_history','lands_available_for_taxes','pinellas_cama_rp_structural_elements','property_permit_history'],
  jsonb_build_object('geom_column', 'geom (column default)'), jsonb_build_object('geom_column', null, 'default', 'dropped', 'trigger', 'layer_resolution_measure_geom'),
  'Ruling 937 section 7: the resolver wrote geom by default on five attribute tables; measured from the catalogue now.', null);
