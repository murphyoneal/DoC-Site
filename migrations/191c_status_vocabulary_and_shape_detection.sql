-- 191c - the construction register's status columns are checked for vocabulary AND shape (ruling 907 addition).
--
-- 907: "the status detection should check the shape as well as the vocabulary, since a value that's all digits in a
-- status column is a loader defect." Measured 2026-10-01 over contractors (114,105 rows):
--   secondary_status  A 112,223 · I 434 · NULL 1,440 · C 7 · Active 1
--   primary_status    C 114,097 · <all digits> 7 · Current 1
--   license_status    active 95,405 · not_in_latest_file 16,819 · not_stated 1,440 · inactive 434 · unknown 7
-- The 7 all-digit primary_status rows are the column-shifted rows (license_number '74', the serial in primary_status, the
-- class in secondary_status) - question 807, unruled, so they are NOT changed here. 'Current'/'Active' is the ZZ TEST
-- fixture ZZC0000001 (ruling 723), registered in test_fixture and excluded by key, never by name.
--
-- A row fails when, outside test_fixture:
--   SHAPE       primary_status or secondary_status is all digits (a serial in a status column). license_number is NOT a
--               status column and is not shape-tested: a dry run fired on 97 continuing-education listings (CRS1 94,
--               PVDR 3) whose real numbers are 7 digits - the pattern was wrong, not the rows.
--   VOCABULARY  secondary_status not in (A, I, NULL); license_status not in our four derived values
--   DERIVATION  an in-file row whose license_status disagrees with its secondary_status (A->active, I->inactive,
--               NULL->not_stated, per 138a); an absent row reading active (also a CHECK since 191a - belt and braces,
--               because a dropped constraint is silent)
-- Primary_status vocabulary is deliberately NOT enumerated: only 'C' has been observed, and the file's code list is not
-- recorded, so enumerating it would fire on the first legitimate new code. Its shape is checked.
-- RED BY DESIGN at creation: the 7 shifted rows, until 807 is ruled and applied. row_count carries the failing count.

insert into public.data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('contractor-status-vocabulary-and-shape',
  'A construction-register row has a status column of the wrong shape (all digits), a status outside the known vocabulary, or a license_status that disagrees with its file status',
  'entity_confusion', 'blocking',  -- ddr_class_vocab has no 'validity'; a serial in a status column is one kind of value stored as another
  $q$select count(*) = 0 as ok, count(*) as row_count,
            count(*) filter (where c.primary_status ~ '^[0-9]+$' or c.secondary_status ~ '^[0-9]+$') as shape_failures
     from public.contractors c
     where not exists (select 1 from public.test_fixture f where f.register = 'contractors' and f.key = c.license_number)
       and ( c.primary_status ~ '^[0-9]+$' or c.secondary_status ~ '^[0-9]+$'
          or c.secondary_status is not null and c.secondary_status not in ('A','I')
          or c.license_status is null
          or c.license_status not in ('active','inactive','not_stated','not_in_latest_file')
          or (c.register_file_state = 'in_latest_file' and c.license_status is distinct from
                case c.secondary_status when 'A' then 'active' when 'I' then 'inactive' else 'not_stated' end)
          or (c.register_file_state = 'absent_from_latest_file' and c.license_status = 'active') )$q$,
  'Red by design at creation (2026-10-01): the 7 column-shifted rows (license_number 74), held on question 807. The ZZ test fixture is excluded via test_fixture by licence key. primary_status vocabulary is not enumerated (code list unrecorded); its shape is.');

select public._log_action('cc', 'add_status_vocabulary_shape_detection', 'data_defect_registry', array['contractor-status-vocabulary-and-shape'], null,
  jsonb_build_object('red_by_design', 7, 'held_on', 'bus 807'),
  'Ruling 907: a status detection must check shape as well as vocabulary; an all-digit status is a loader defect. Red at creation on the 7 shifted rows awaiting ruling 807.', null);
