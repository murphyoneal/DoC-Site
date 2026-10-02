-- 201a - the four labelled ECLB alarm classes get a display category (ruling 927 item 2, finding 925).
--
-- EF 1,465 + EG 545 + EY 65 + EZ 17 = 2,092 licences with board-sourced labels (189a) and display_category NULL, so no
-- trade list or facet could show them. The category name comes from the board's own labels, quoted verbatim in 189a from
-- myfloridalicense.com/electrical-contractors: "alarm system contractor I", "alarm system contractor II",
-- "registered alarm system contractor I", "registered alarm system contractor II". Display labels here name the trade
-- ("Electrical", "Roofing"), so the category label is "Alarm System"; its note carries the board's wording.
-- EH and EI stay uncategorised: the board gives them no title (label_state not_established).
-- lib/tradeCategories.ts is generated from this table and checked at prebuild; it is regenerated in the same change.

insert into public.trade_display_category (category, label, grouping, note)
values ('alarm_system', 'Alarm System', 'trade',
  'EF, EG, EY, EZ (Electrical Contractors'' Licensing Board). Board labels, verbatim: alarm system contractor I / II; registered alarm system contractor I / II. EF covers all alarm systems including fire; EG all alarm systems other than fire (board text, 189a).')
on conflict (category) do nothing;

update public.trade_code_registry set display_category = 'alarm_system'
 where trade_code in ('EF','EG','EY','EZ') and department = 'eclb' and label_state = 'sourced' and display_category is null;

do $$
declare n int;
begin
  select count(*) into n from public.trade_code_registry where trade_code in ('EF','EG','EY','EZ') and display_category = 'alarm_system';
  if n is distinct from 4 then raise exception '201a: expected 4 alarm classes categorised, got %', n; end if;
  if exists (select 1 from public.trade_code_registry where trade_code in ('EH','EI') and display_category is not null) then
    raise exception '201a: an unlabelled class was categorised'; end if;
end $$;

select public._log_action('cc', 'add_alarm_system_category', 'trade_display_category', array['alarm_system','EF','EG','EY','EZ'], null,
  jsonb_build_object('licences', 2092, 'label_source', 'board labels quoted in 189a'),
  'Ruling 927 item 2: 2,092 alarm licences had sourced labels and no category to appear under.', null);
