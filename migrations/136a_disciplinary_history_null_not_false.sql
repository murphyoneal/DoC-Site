-- 136a — contractors.disciplinary_history: NULL (never checked), not FALSE (checked and clean).
-- Ruling 2026-09-26 (claude, relayed by Murphy): correct at SOURCE, not hidden at the renderer.
--
-- Measured before this migration: FALSE on all 114,104 rows, NULL on none, TRUE on none. Nothing
-- has ever been checked — no loader writes the column (grepped the repo, every pg_proc body and the
-- WSL scripts); the only writer was the column DEFAULT false. Sentinel-as-value about named
-- people's conduct.
--
-- NOT CURRENTLY SERVED: contractors_public (the anon view) does not carry the column, and no app
-- code or function reads it. (A first draft of this note said the view served it; the migration's
-- own detection failed on "column does not exist", which is how that was caught.) It is corrected
-- here because it is a false assertion waiting for its first reader, not because one exists yet.

alter table public.contractors alter column disciplinary_history drop default;

update public.contractors set disciplinary_history = null where disciplinary_history is not null;

comment on column public.contractors.disciplinary_history is
  'NULL = NOT CHECKED. We hold no DBPR discipline or complaint data. Was FALSE on every row via a column '
  'default until 136a (2026-09-26), a sentinel asserting a clean record nobody checked. Only a sourced '
  'load may write TRUE or FALSE, and FALSE must mean "checked against a named source on a date and none found". '
  'Guarded by detection disciplinary-history-asserted-without-source.';

insert into public.data_defect_registry
  (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_denominator,
   false_positive_notes, status, attribution, expected_state, remediation)
values
('disciplinary-history-asserted-without-source',
 'contractors.disciplinary_history must be NULL on every row, because no discipline source is loaded',
 date '2026-09-26', 'thin-profile measurement (row 664) and ruling 2026-09-26', 'null_as_value', 'blocking',
 $d$select (
    not exists (select 1 from public.contractors where disciplinary_history is not null)
    and (select column_default is null from information_schema.columns
          where table_schema = 'public' and table_name = 'contractors' and column_name = 'disciplinary_history')
  ) as ok$d$,
 'every row of contractors plus the column default',
 'TABLE CHECK, because no served path exists: nothing serves this column today (contractors_public omits it, no '
 'function reads it). If a served path is added, this should move to it. It also asserts the column default stays absent, because a restored DEFAULT false is how the sentinel came back on '
 'every new row. WHEN A REAL DISCIPLINE SOURCE IS LOADED this predicate must be REPLACED, not deleted: the replacement '
 'asserts that every non-null value carries a source and check date.',
 'active', 'ours', 'clean',
 'Set disciplinary_history to NULL where no discipline source backs it, and drop any column default.')
on conflict (defect_id) do nothing;

do $a$
declare n bigint;
begin
  select count(*) into n from public.contractors where disciplinary_history is not null;
  if n <> 0 then raise exception '136a: % rows still assert a disciplinary value', n; end if;
  if (select column_default from information_schema.columns where table_schema='public'
        and table_name='contractors' and column_name='disciplinary_history') is not null then
    raise exception '136a: default still present';
  end if;
end $a$;
