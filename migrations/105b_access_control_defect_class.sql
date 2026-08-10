-- Ruling 93 §2: ddr_class_vocab had no security/access class, so the anon-callable-secdef guard
-- was filed as completeness. A security regression classified as a completeness defect is a naming
-- defect that misleads whoever reads the board next (and today proved the board gets read under
-- pressure). Add access_control and refile.
ALTER TABLE data_defect_registry DROP CONSTRAINT IF EXISTS ddr_class_vocab;
ALTER TABLE data_defect_registry ADD CONSTRAINT ddr_class_vocab
  CHECK (class = ANY (ARRAY['key_integrity','geometry','completeness','entity_confusion','temporal','null_as_value','fanout','resolution_mislabelling','access_control']));
UPDATE data_defect_registry SET class='access_control' WHERE defect_id='anon-callable-secdef-functions';
