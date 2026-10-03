-- 221b - repose and limitations re-read against current statute text, all 50 states (ruling 1005, priority 2: "a
-- blown deadline is unrecoverable").
--
-- Four research subagents read the CURRENT codified sections on 2026-10-03 (legislature sites first; FindLaw / Cornell
-- / state-published mirrors where blocked) against every stored repose and limitations field. Result: every
-- repose_years value is right. What was wrong or stale:
--  * HAWAII - THE LAW CHANGED. Act 308, SLH 2025 (HB420 CD1), effective on approval 9 July 2025, deleted § 657-8's own
--    two-year clause. Our quote and our limitations note described repealed text for almost three months.
--  * Montana: the 10 -> 6 year cut was a 2025 amendment (Ch. 174, L. 2025, SB 143), not 2023 as our note said.
--  * Oregon: 2025 c.578 (HB 3746) renumbered ORS 12.135 (our provision is now (2)(b)) and added a 7-year period for
--    homeowners/unit-owners associations.
--  * Wrong fraud-exception cites: Ohio (C), not (A)(3); Arkansas (d), not (c). The fraud VALUES were right.
--  * Utah and Indiana cites pinned to the operative subsection; Utah's quote was not the current wording.
--  * Limitations notes that overstated the text: SC (the discovery rule is written for 15-3-530(5) only), VT (§ 512
--    covers personal, not real, property), ID (§ 5-219(4) is personal injury/malpractice, not property), AK (the statute
--    says accrual; discovery is a court rule we did not read).
--  * Quotes that elided text without marking it (AK, MD, TN, AL): the source-check runner correctly could not find them.
--  * Stale or non-primary URLs: SD, TX, NC, OK, AZ, CA, FL, AL, IL, KY, LA.
-- No amendment effective 1 Jul or 1 Oct 2026 or later was found in any of the 50. Where a mirror's currency date
-- predates 2026 and no official text could be read, the provenance row says so (AK, CT, GA, MS, NJ, NM, WY, AL, TN, UT).
-- Narrative fields (rights_you_have, what_to_do_now, homeowner_summary) are still the August pass, so every row stays
-- past recheck until those are re-read - the recheck detection stays red, honestly.

create temp table _f (st text, col text, old text, new text) on commit drop;
insert into _f values
 ('HI','statute_quote', 'No action to recover damages for any injury to property, real or personal, or for bodily injury or wrongful death, arising out of any deficiency or neglect in the planning, design, construction, supervision and administering of construction, and observation of construction relating to an improvement to real property shall be commenced more than two years after the cause of action has accrued, but in any event not more than ten years after the date of completion of the improvement.',
   'No action, whether in contract, tort, statute, or otherwise, to recover damages for any injury to property, real or personal, … shall be commenced more than ten years after the date of completion of the improvement.'),
 ('HI','limitations_cite', 'Haw. Rev. Stat. § 657-8', 'Haw. Rev. Stat. §§ 657-7, 657-1'),
 ('HI','limitations_note', '2-year accrual clause within § 657-8; the 10 years is the outer repose.',
   'Act 308 (2025), effective 9 July 2025, removed § 657-8''s own 2-year clause. The ordinary periods now apply (§ 657-7, 2 years for damage to persons or property; § 657-1, 6 years), all within the 10-year repose.'),
 ('HI','repose_note', '10 years from the date of completion is the outer repose; the action must also be brought within 2 years after the cause of action accrues (Haw. Rev. Stat. § 657-8).',
   '10 years from the date of completion is the outer repose (Haw. Rev. Stat. § 657-8). Since Act 308 (2025), effective 9 July 2025, § 657-8 no longer carries its own 2-year clause; the ordinary limitations periods apply within the repose (§§ 657-7, 657-1).'),
 ('MT','repose_note', 'SHORTENED FROM 10 BY A 2023 AMENDMENT;', 'SHORTENED FROM 10 BY A 2025 AMENDMENT (Ch. 174, L. 2025, SB 143);'),
 ('OH','fraud_exception_cite', 'Ohio Rev. Code § 2305.131(A)(3)', 'Ohio Rev. Code § 2305.131(C)'),
 ('OH','repose_note', 'FRAUD EXCEPTION (A)(3):', 'FRAUD EXCEPTION (C):'),
 ('AR','fraud_exception_cite', 'Ark. Code § 16-56-112(c)', 'Ark. Code § 16-56-112(d)'),
 ('ID','limitations_note', '~8 years for tort (6-yr accrual + 2-yr SOL §§ 5-241, 5-219(4));',
   '~8 years for personal-injury or professional-malpractice claims (6-yr accrual + 2-yr SOL §§ 5-241, 5-219(4)); which period governs a property-damage tort is not settled here;'),
 ('OR','repose_cite', 'O.R.S. § 12.135', 'O.R.S. § 12.135(2)(b)'),
 ('UT','repose_cite', 'Utah Code § 78B-2-225', 'Utah Code § 78B-2-225(4)(c)'),
 ('UT','statute_quote', 'an action ... may not be commenced against a provider more than nine years after completion of the improvement or abandonment of construction.',
   'an action under this Subsection (4) may not be commenced against a provider more than nine years after completion or abandonment of an improvement.'),
 ('IN','repose_cite', 'Ind. Code § 32-30-1-5', 'Ind. Code § 32-30-1-5(d)'),
 ('AL','statute_quote', 'No relief can be granted on any cause of action which accrues or would have accrued more than seven years after the substantial completion of construction of the improvement on or to the real property.',
   'Notwithstanding the foregoing, no relief can be granted on any cause of action which accrues or would have accrued more than seven years after the substantial completion of construction of the improvement on or to the real property.'),
 ('SC','limitations_note', 'Generally 3 years from discovery, capped by the 8-year repose.',
   '3 years (S.C. Code § 15-3-530), capped by the 8-year repose. The statutory discovery rule (§ 15-3-535) is written for § 15-3-530(5) only, so do not assume the clock starts at discovery.'),
 ('VT','limitations_note', '6 years for contract/general civil actions (12 V.S.A. § 511); 3 years for injury to person or property including negligence (12 V.S.A. § 512), with a discovery rule. No outer repose cutoff.',
   '6 years for contract and general civil actions, which by default includes damage to real property (12 V.S.A. § 511); 3 years for personal injury (with a discovery rule) and for damage to personal property (12 V.S.A. § 512). No outer repose cutoff.'),
 ('AK','limitations_note', '2 years from discovery (AS 09.10.070); the 10-year period is the outer repose.',
   '2 years from accrual (AS 09.10.070(a)). Alaska courts apply a discovery rule to accrual; we have not read that case law. The 10-year period is the outer repose.'),
 ('AK','statute_quote', 'or property damage; or (2) the last act', 'or property damage; … or (2) the last act'),
 ('MD','statute_quote', 'a cause of action for damages does not accrue ... against any architect, professional engineer, or contractor ... more than 10 years after the date the entire improvement first became available for its intended use.',
   'a cause of action for damages does not accrue and a person may not seek contribution or indemnity from any architect, professional engineer, or contractor … more than 10 years after the date the entire improvement first became available for its intended use.'),
 ('TN','statute_quote', 'All actions ... to recover damages for any deficiency in the design, planning, supervision, observation of construction, or construction of an improvement to real property ... must be brought against any person performing or furnishing the design, planning, supervision, observation of construction, or construction of the improvement within four (4) years after substantial completion of an improvement.',
   'With the exception of actions brought pursuant to § 28-1-114(a), all actions, arbitrations, or other binding dispute resolution proceedings to recover damages … must be brought … within four (4) years after substantial completion of an improvement.'),
 ('DE','repose_note', '(purchase/acceptance/occupancy or substantial completion)', '(including the contract completion date, payment dates, substantial completion, and acceptance by the owner or occupant)'),
 ('OR','repose_note', 'so fraud_exempts_repose = false.',
   'so fraud_exempts_repose = false. 2025 c.578 (HB 3746) renumbered the section (the residential repose is now (2)(b); subsection numbers above are from the pre-2025 text) and added (4): a homeowners or unit-owners association''s tort action gets 7 years after substantial completion or abandonment, plus 1 year from discovery for a defect found in year 6 to 7, for structures whose declaration is first recorded on or after the Act''s effective date.'),
 -- primary URLs: official text where it serves, a working reproduction where the official site refuses
 ('SD','primary_source_url', null, 'https://sdlegislature.gov/api/Statutes/15-2A-3.html?all=true'),
 ('TX','primary_source_url', null, 'https://statutes.capitol.texas.gov/Docs/CP/htm/CP.16.htm#16.009'),
 ('NC','primary_source_url', null, 'https://www.ncleg.gov/EnactedLegislation/Statutes/HTML/BySection/Chapter_1/GS_1-50.html'),
 ('OK','primary_source_url', null, 'https://www.oscn.net/applications/oscn/DeliverDocument.asp?CiteID=93665'),
 ('AZ','primary_source_url', null, 'https://www.azleg.gov/ars/12/00552.htm'),
 ('CA','primary_source_url', null, 'https://leginfo.legislature.ca.gov/faces/codes_displaySection.xhtml?lawCode=CCP&sectionNum=337.15'),
 ('FL','primary_source_url', null, 'https://www.flsenate.gov/Laws/Statutes/2026/95.11'),
 ('AL','primary_source_url', null, 'https://law.justia.com/codes/alabama/title-6/chapter-5/article-13a/section-6-5-221/'),
 ('IL','primary_source_url', null, 'https://www.ilga.gov/Documents/legislation/ilcs/documents/073500050K13-214.htm'),
 ('KY','primary_source_url', null, 'https://apps.legislature.ky.gov/law/statutes/statute.aspx?id=17869'),
 ('LA','primary_source_url', null, 'https://legis.la.gov/legis/Law.aspx?d=107197');

do $$
declare r record; cur text; n int; total int := 0;
begin
  for r in select * from _f loop
    execute format('select %I::text from public.construction_defect_law where state_code = $1', r.col) into cur using r.st;
    if r.old is null then
      execute format('update public.construction_defect_law set %I = $1 where state_code = $2', r.col) using r.new, r.st;
    else
      n := (length(cur) - length(replace(cur, r.old, ''))) / greatest(length(r.old), 1);
      if n <> 1 then raise exception '221b: % % - anchor found % times: %', r.st, r.col, n, left(r.old, 70); end if;
      execute format('update public.construction_defect_law set %I = replace(%I, $1, $2) where state_code = $3', r.col, r.col) using r.old, r.new, r.st;
    end if;
    total := total + 1;
  end loop;
  raise notice '221b: % field edits', total;
end $$;

-- Provenance: repose, limitations and statute_quote re-read for all 50, recorded with what stayed unverified.
create temp table _u (st text, note text) on commit drop;
insert into _u values
 ('AK','Official site 403; FindLaw current to 1 Jan 2025.'), ('CT','FindLaw current to 1 Jan 2025; official chapter page truncated.'),
 ('GA','No free official code; FindLaw current to 28 Mar 2024. Stored quote is a composite of three passages.'),
 ('MS','FindLaw current to 2024; official code not read.'), ('NJ','FindLaw current to 1 Jan 2024; official site 404.'),
 ('NM','FindLaw current to 1 Jan 2024; no history note.'), ('WY','FindLaw current to 1 Jan 2024; official PDF unparseable.'),
 ('AL','No current text readable (ALISON JS-only, Justia 403); undated mirror read. The exception is knowing nondisclosure, narrower than "fraud".'),
 ('TN','History note unverified (official text not freely fetchable).'), ('UT','2026 session laws not checked.'),
 ('TX','Official site and Justia refuse automated fetch; texas.public.law and FindLaw read. Limitations cite "Ch. 16" is vague; sections not read.'),
 ('AR','Limitations cite (b)(1) is itself a personal-injury repose, not a limitations period; §§ 16-56-105/-111 not read.'),
 ('KY','Limitations cite 413.135(3) is a non-extension clause, not a limitations period.'),
 ('OH','Limitations cite is the repose section; the underlying periods were not read.'),
 ('HI','LAW CHANGED: Act 308 SLH 2025 (HB420 CD1), effective 9 Jul 2025.'),
 ('OR','2025 c.578 (HB 3746) renumbered § 12.135; effective date inferred from the Oregon default, not read.'),
 ('MT','Ch. 174, L. 2025 (SB 143); effective date 1 Oct 2025 inferred, not read.');

insert into public.construction_law_field_check (state_code, field_group, authority_read, method, checked_by, checked_on, migration, note)
select d.state_code, g.fg,
       coalesce(case g.fg when 'repose' then d.repose_cite when 'limitations' then coalesce(d.limitations_cite, '(none stored)') else d.repose_cite end, '(none stored)'),
       'primary_statute_text', 'cc research subagent', date '2026-10-03', '221b',
       coalesce(u.note, 'Current codified text read; no amendment effective 1 Jul or 1 Oct 2026 or later found.')
  from public.construction_defect_law d
 cross join (values ('repose'),('limitations'),('statute_quote')) g(fg)
  left join _u u on u.st = d.state_code;

update public.construction_defect_law d
   set source_note = coalesce(d.source_note, '') || E'\n\n' || 'REPOSE/LIMITATIONS RE-READ 2026-10-03 (221b) against current statute text.'
                     || coalesce(' ' || u.note, '')
  from (select st, note from _u union all select state_code, null from public.construction_defect_law where state_code not in (select st from _u)) u
 where u.st = d.state_code;

-- recompute the clock from the provenance (stalest served field group decides)
update public.construction_defect_law d
   set last_checked = s.stalest, recheck_due = public._legal_next_effective_date(s.stalest), check_method = 'stalest served field: ' || s.how
  from (select distinct on (state_code) state_code, latest as stalest, method as how
          from (select state_code, field_group, max(checked_on) latest, (array_agg(method order by checked_on desc))[1] method
                  from public.construction_law_field_check group by 1, 2) f
         order by state_code, latest asc) s
 where s.state_code = d.state_code;

do $$
declare j jsonb;
begin
  select e into j from jsonb_array_elements(public.get_verified_construction_law()) e where e->>'state_code' = 'HI';
  if j->>'statute_quote' ~ 'two years after the cause of action' or j->>'limitations_cite' !~ '657-7' then raise exception '221b: HI still serves repealed text: %', j->>'statute_quote'; end if;
  select e into j from jsonb_array_elements(public.get_verified_construction_law()) e where e->>'state_code' = 'OH';
  if j->>'fraud_exception_cite' !~ '\(C\)' then raise exception '221b: OH fraud cite'; end if;
  if (select count(*) from public.construction_law_field_check where migration = '221b') <> 150 then raise exception '221b: expected 150 provenance rows'; end if;
  if exists (select 1 from public.construction_defect_law where repose_note ~ '2023 AMENDMENT') then raise exception '221b: MT note'; end if;
  raise notice '221b: served HI/OH corrected; provenance 150 rows; rows still past recheck: %',
    (select count(*) from public.construction_defect_law where recheck_due <= current_date);
end $$;

select public._log_action('cc', 'repose_limitations_reaudit', 'construction_defect_law',
  array['construction_defect_law','construction_law_field_check'], null,
  jsonb_build_object('law_changed', 'HI (Act 308 SLH 2025)', 'wrong_cites', 'OH fraud (C), AR fraud (d)', 'amendment_dates', 'MT 2025, OR 2025 renumbering', 'repose_years_wrong', 0),
  'Ruling 1005 priority 2: repose and limitations re-read against current statute text, 50 states.', null);
