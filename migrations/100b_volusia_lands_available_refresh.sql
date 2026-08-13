-- =============================================================================
-- work order 66 — refresh the Volusia Lands Available register from the Clerk PDF
-- Murphy pulled 2026-08-09 (11 rows; prior snapshot held 10). Upsert on the source
-- natural key (certificate_number), refresh the registry pull date, clear DEF-009.
--
-- Snapshot note: the prior 10 rows are a strict subset of these 11, so an upsert
-- yields exactly the register (no stale rows to retire this cycle). certificate_number
-- is the Clerk's stable id; add the unique constraint invariant 9 requires so a re-run
-- is idempotent rather than duplicating the table.
-- =============================================================================

-- natural key (was PK on surrogate id only)
ALTER TABLE lands_available_for_taxes_volusia
  ADD CONSTRAINT lands_available_for_taxes_volusia_cert_key UNIQUE (certificate_number);

INSERT INTO lands_available_for_taxes_volusia
  (certificate_number, parcel_id, date_original_sale, date_available_public, original_opening_bid, loaded_at)
VALUES
  ('9219-20', '533952000070', DATE '2023-04-18', DATE '2023-08-17', 19493.98, now()),
  ('7582-20', '523903110120', DATE '2024-02-27', DATE '2024-05-31', 31961.00, now()),
  ('3955-16', '802600000130', DATE '2024-04-09', DATE '2024-08-09',  3153.91, now()),
  ('2831-20', '800401420360', DATE '2025-02-11', DATE '2025-06-17',  2710.26, now()),
  ('8028-19', '612901110210', DATE '2025-03-11', DATE '2025-07-11',  1504.56, now()),
  ('889-17',  '502200000935', DATE '2025-03-25', DATE '2025-07-24',  1893.36, now()),
  ('7022-18', '813071000001', DATE '2025-04-01', DATE '2025-07-31', 11913.05, now()),
  ('3733-18', '802301170021', DATE '2025-06-24', DATE '2025-10-24',  1924.93, now()),
  ('3732-18', '802301160121', DATE '2025-07-15', DATE '2025-11-19',  1956.90, now()),
  ('10935-18','533874050071', DATE '2025-07-22', DATE '2025-11-24',  1817.78, now()),
  ('1587-19', '801407000011', DATE '2026-06-09', DATE '2026-10-22',  1834.62, now())
ON CONFLICT (certificate_number) DO UPDATE SET
  parcel_id            = EXCLUDED.parcel_id,
  date_original_sale   = EXCLUDED.date_original_sale,
  date_available_public= EXCLUDED.date_available_public,
  original_opening_bid = EXCLUDED.original_opening_bid,
  loaded_at            = EXCLUDED.loaded_at;

-- clear DEF-009: registry pull date + count for the Volusia tax-deed source
UPDATE data_source_registry
   SET last_successful_pull_date = DATE '2026-08-09', last_count = 11
 WHERE id = 305 AND table_name = 'lands_available_for_taxes_volusia';
