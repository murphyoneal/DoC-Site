-- 209b - the qualifier_business note's "407 rows" is corrected by APPENDING, never by rewriting (ruling 959).
--
-- The note recorded this defect as 407 rows. That number was why nobody re-measured: the labels table was fixed, but
-- doc_category on the data never was. 209a measured 10,408. Rewriting the number would leave a tidy record of a
-- defect found and fixed. Appending leaves the true one: measured, believed closed, found 25 times larger.
-- The wording is claude's (959). The generator reads this column but does not render it, so lib/tradeCategories.ts
-- does not change.

do $$
declare n int;
begin
  update public.trade_display_category
     set note = note || ' | 407 rows (recorded 2026-09-26). CORRECTED 2026-10-03 (209a): the real population was 10,408 - 10,125 general_contractor plus 283 name-inferred trades. The 407 was the rows the LABELS table affected; doc_category itself was never re-measured, so the defect survived its own fix. Guarded now by detection licence-scope-category-without-a-granting-licence and trigger contractors_registration_category.'
   where category = 'qualifier_business' and position('CORRECTED 2026-10-03' in note) = 0
     and note like '%for 407 rows.%';
  get diagnostics n = row_count;
  if n <> 1 then raise exception '209b: expected to append to exactly one note, touched %', n; end if;
end $$;
