-- 213b - live-false-statement-finding-unactioned matches the tag LITERALLY (audit 971, register data agent).
-- Its predicate was refs ILIKE '%LIVE_FALSE_STATEMENT%'. In LIKE, "_" matches any character, so the pattern also matched
-- "live-false-statement-finding-unactioned" - the detection's own name - which ruling 949 carries in its refs, unactioned.
-- It would have turned red on its own after 2026-10-04 11:03 UTC (24 h after 949) with no live false statement anywhere.
-- Same class as 213a: a pattern character treated as a value.
do $$
declare q text; j jsonb;
begin
  select detection_sql into q from public.data_defect_registry where defect_id = 'live-false-statement-finding-unactioned';
  if position($a$refs ilike '%LIVE_FALSE_STATEMENT%'$a$ in q) = 0 then raise exception '213b: anchor missing: %', q; end if;
  update public.data_defect_registry
     set detection_sql = replace(detection_sql, $a$refs ilike '%LIVE_FALSE_STATEMENT%'$a$, $a$refs ilike '%LIVE\_FALSE\_STATEMENT%'$a$),
         false_positive_notes = coalesce(false_positive_notes, '') || ' | 213b: underscores escaped - "_" matched "-", so the detection''s own name in a ruling''s refs (949) would have tripped it after 2026-10-04 11:03 UTC.'
   where defect_id = 'live-false-statement-finding-unactioned';
  -- control: the hyphenated name no longer matches; the real tag still does
  if 'x live-false-statement-finding-unactioned' ilike '%LIVE\_FALSE\_STATEMENT%' then raise exception '213b: hyphen still matches'; end if;
  if not ('LIVE_FALSE_STATEMENT, 911' ilike '%LIVE\_FALSE\_STATEMENT%') then raise exception '213b: the real tag no longer matches'; end if;
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'live-false-statement-finding-unactioned')) into j;
  if j->>'ok' is null then raise exception '213b: detection does not run: %', j; end if;
  raise notice '213b: %', j;
end $$;
