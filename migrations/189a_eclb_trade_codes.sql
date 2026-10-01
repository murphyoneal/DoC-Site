-- 189a - the ten ECLB licence classes and the two missing CE codes enter trade_code_registry (ruling 900).
--
-- reg_us_fl.eclb_licence holds 17,976 licences in 10 classes and 2,127 continuing-education listings in 4 classes, and NONE
-- of the 10 licence classes was in trade_code_registry - so the register was never the blocker, the vocabulary was.
--
-- LABEL SOURCE (ruling 900: never invent a label). The existing rows cite "DBPR code list"; that list is not recorded
-- anywhere in this repo or the database, so it cannot be re-read. The ECLB labels below are therefore taken VERBATIM from
-- the board's own licence-type page, https://www2.myfloridalicense.com/electrical-contractors/ (fetched 2026-10-01), which
-- defines each code in quotation marks - e.g. EC: 'An "electrical contractor" means ...'. Case is kept as the board wrote
-- it (the display layer may capitalise; the stored label is the source string - ruling 903 C3, never enrich).
--   EH and EI: the page says only "No new licenses are issued with EH and EI, however old licenses with these designation(s)
--   can be renewed" and gives NO title. official_label is NULL; the UI shows the raw code. Not inferred from position on
--   the page.
--   EJ (registered residential alarm system contractor) is defined on the page but absent from the file; not added.
-- DISPLAY CATEGORY: EC/ER/ES/ET -> 'electrical' (existing category; ES/ET scope is "a specific segment of electrical or
--   alarm system contracting"). The alarm classes EF/EG/EY/EZ get NO display category yet: an 'alarm' category is new
--   vocabulary in trade_display_category, which the prebuild check regenerates, so it ships with its regenerated
--   lib/tradeCategories.ts in one coordinated change, not here. EH/EI: none (no label to categorise by).
-- CRS2 and CRS3 join CRS1/PVDR as department 'none', is_trade false (continuing education, never a contractor).
-- Nothing reads these rows on a served path until the register search union (phase 2) ships.

-- DEPARTMENT: 'eclb' (ruling 900: electrical classes get their own department). The CHECK allowed only doc, pools, lawns,
-- assurance, property, none, unmapped. Every consumer of department (rebuild_business_register, search_contractors,
-- contractor_finder, contractor_register_search) only tests department = 'none', and nothing under app/ or lib/ reads it,
-- so adding a value hides nothing.
alter table public.trade_code_registry drop constraint trade_code_registry_department_check;
alter table public.trade_code_registry add constraint trade_code_registry_department_check
  check (department = any (array['doc','pools','lawns','assurance','property','none','unmapped','eclb']));

-- LABEL STATE (ruling 900: an unsourced label is NULL with a state saying so, and the UI shows the raw code).
-- official_label was NOT NULL. Its only readers: get_business_licences (coalesce(official_label, c.trade_label) - null-safe)
-- and no view (contractors_public and work_gallery_public join the table but do not read the label); nothing under app/
-- lib/ public/ scripts/ reads it. label_state makes the absence a stated condition, and the CHECK ties the two together so
-- a NULL label can never mean "forgot".
alter table public.trade_code_registry add column if not exists label_state text;
update public.trade_code_registry set label_state = 'sourced' where label_state is null and official_label is not null;
alter table public.trade_code_registry alter column official_label drop not null;

insert into public.trade_code_registry (trade_code, official_label, department, is_trade, authority, note, display_category, label_state) values
 ('EC', 'electrical contractor',                   'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '12,323 licences in reg_us_fl.eclb_licence (2026-09-30 file). Board text: may contract ALL alarm systems and specialty categories.', 'electrical', 'sourced'),
 ('ER', 'registered electrical contractor',        'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '1,656 licences. Registered = competency for the jurisdiction of the registration.', 'electrical', 'sourced'),
 ('ES', 'specialty contractor',                    'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '1,785 licences. Scope limited to a segment of electrical or alarm contracting; the file''s specialty field (ENRG, SIGN, RESD, UTIL, LGHT) names it.', 'electrical', 'sourced'),
 ('ET', 'registered specialty contractor',         'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '112 licences.', 'electrical', 'sourced'),
 ('EF', 'alarm system contractor I',               'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '1,465 licences. Board text: all types of alarm systems for all purposes (fire included). No display category until the alarm category ships with its generated file.', null, 'sourced'),
 ('EY', 'registered alarm system contractor I',    'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '65 licences.', null, 'sourced'),
 ('EG', 'alarm system contractor II',              'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '545 licences. Board text: all types of alarm systems OTHER THAN FIRE.', null, 'sourced'),
 ('EZ', 'registered alarm system contractor II',   'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), quoted verbatim 2026-10-01', '17 licences. Board text: other than fire.', null, 'sourced'),
 ('EH', null,                                      'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), 2026-10-01: no title given', 'LABEL NOT ESTABLISHED. 2 licences. Board text: "No new licenses are issued with EH and EI, however old licenses with these designation can be renewed." The UI shows the raw code.', null, 'not_established'),
 ('EI', null,                                      'eclb', true, 'Electrical Contractors'' Licensing Board licence-type page (myfloridalicense.com/electrical-contractors), 2026-10-01: no title given', 'LABEL NOT ESTABLISHED. 6 licences. Same board text as EH. The UI shows the raw code.', null, 'not_established'),
 ('CRS2', null,                                    'none', false, 'reg_us_fl.eclb_licence record_kind continuing_education_listing (189a)', 'Continuing-education listing in the ECLB file (99 rows). Not a contractor; excluded from every contractor search, like CRS1 and PVDR.', 'education_provider', 'not_established'),
 ('CRS3', null,                                    'none', false, 'reg_us_fl.eclb_licence record_kind continuing_education_listing (189a)', 'Continuing-education listing in the ECLB file (1,725 rows). Not a contractor; excluded from every contractor search.', 'education_provider', 'not_established')
on conflict (trade_code) do nothing;

alter table public.trade_code_registry alter column label_state set not null;
alter table public.trade_code_registry add constraint trade_code_registry_label_state_check
  check ((label_state = 'sourced' and official_label is not null) or (label_state = 'not_established' and official_label is null));
comment on column public.trade_code_registry.label_state is
  'sourced: official_label is quoted from the authority named in authority. not_established: no source gives a label; official_label is NULL and the UI shows the raw trade_code (189a, ruling 900).';

select public._log_action('cc', 'add_eclb_trade_codes', 'trade_code_registry', array['EC','ER','ES','ET','EF','EY','EG','EZ','EH','EI','CRS2','CRS3'], null,
  jsonb_build_object('label_source', 'myfloridalicense.com/electrical-contractors, verbatim', 'labels_not_established', jsonb_build_array('EH','EI')),
  'Ruling 900: 17,976 ECLB licences could not be categorised because none of the 10 classes was in the vocabulary; labels quoted from the board, EH/EI left unlabelled where the board gives no title.', null);

do $$
declare missing int;
begin
  select count(*) into missing from (select distinct class_code from reg_us_fl.eclb_licence) e
   where not exists (select 1 from public.trade_code_registry r where r.trade_code = e.class_code);
  if missing is distinct from 0 then raise exception '189a: % ECLB classes still missing from the registry', missing; end if;
  if exists (select 1 from public.trade_code_registry where trade_code in ('EH','EI') and official_label is not null) then
    raise exception '189a: a label was invented for EH/EI'; end if;
end $$;
