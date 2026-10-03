-- 221c - statute_quote holds statute text and nothing else (ruling 1005 3d follow-up).
--
-- The source-check runner kept failing nine quotes after 221b. Reading them: four stored "quotes" carried OUR
-- commentary inside the quotation - Ohio's even repeated the wrong fraud cite 221b corrected ('Fraud exception (A)(3):
-- the repose ...'), North Carolina's appended 'Exclusion: does not apply to ...', Georgia's joined three passages with
-- 'Exception:', Delaware's ended in an editorial bracket. Nebraska, Minnesota and Connecticut omitted statute words
-- without an ellipsis. A reader is shown statute_quote as the statute's own words, so each is replaced with the text
-- as it stands on the primary page, elisions marked with an ellipsis. Minnesota and Connecticut were copied from the
-- fetched page on 2026-10-03; the others from the subagents' verbatim readings in 221b's re-audit.
-- Texas: the official statutes site serves a script shell with no statute text, so the URL goes back to a readable
-- reproduction (FindLaw, current to 1 Jan 2026 per the re-audit).

create temp table _q (st text, quote text) on commit drop;
insert into _q values
 ('OH', 'no cause of action … shall accrue against a person who performed services for the improvement to real property or a person who furnished the design, planning, supervision of construction, or construction of the improvement to real property later than ten years from the date of substantial completion of such improvement.'),
 ('NC', 'No action to recover damages based upon or arising out of the defective or unsafe condition of an improvement to real property shall be brought more than six years from the later of the specific last act or omission of the defendant giving rise to the cause of action or substantial completion of the improvement.'),
 ('GA', 'No action to recover damages … shall be brought … more than eight years after substantial completion of such an improvement.'),
 ('DE', 'No action … shall be brought against any person performing or furnishing, or causing the performance or furnishing of, any such construction of such an improvement … after the expiration of 6 years from whichever of the following dates shall be earliest'),
 ('NE', 'In no event may any action be commenced to recover damages for an alleged breach of warranty on improvements to real property or deficiency in the design, planning, supervision, or observation of construction, or construction of an improvement to real property more than ten years beyond the time of the act giving rise to the cause of action.'),
 ('MN', 'Except where fraud is involved, no action by any person in contract, tort, or otherwise to recover damages for any injury to property, real or personal, or for bodily injury or wrongful death, arising out of the defective and unsafe condition of an improvement to real property, shall be brought against any person performing or furnishing the design, planning, supervision, materials, or observation of construction or construction of the improvement to real property or against the owner of the real property more than two years after the cause of action accrues, as specified in paragraph (c), nor in any event shall such a cause of action accrue more than ten years after substantial completion of the construction.'),
 ('CT', 'No action or arbitration, whether in contract, in tort, or otherwise, (1) to recover damages … shall be brought against any architect, professional engineer or land surveyor performing or furnishing the design, planning, supervision, observation of construction or construction of, or land surveying in connection with, such improvement more than seven years after substantial completion of such improvement.');

do $$
declare n int;
begin
  update public.construction_defect_law d set statute_quote = q.quote,
         source_note = coalesce(d.source_note, '') || E'\n\n221c (2026-10-03): statute_quote replaced with the verbatim text; the prior value mixed our commentary or unmarked omissions into the quotation.'
    from _q q where q.st = d.state_code;
  get diagnostics n = row_count;
  if n <> 7 then raise exception '221c: updated % quote rows, expected 7', n; end if;
  update public.construction_defect_law set primary_source_url = 'https://codes.findlaw.com/tx/civil-practice-and-remedies-code/civ-prac-rem-sect-16-009/'
   where state_code = 'TX' and primary_source_url like 'https://statutes.capitol.texas.gov/%';
  get diagnostics n = row_count;
  if n <> 1 then raise exception '221c: TX url not as 221b left it'; end if;
  -- no stored quote may carry our labels
  if exists (select 1 from public.construction_defect_law where statute_quote ~ '(Exception:|Exclusion:|Fraud exception|Late-discovery|\[)') then
    raise exception '221c: a statute_quote still carries editorial text';
  end if;
  raise notice '221c: 7 quotes verbatim; TX url readable';
end $$;

select public._log_action('cc', 'statute_quotes_verbatim', 'construction_defect_law', array['construction_defect_law'], null,
  jsonb_build_object('quotes', 'OH NC GA DE NE MN CT', 'url', 'TX'), 'statute_quote holds statute text only (1005 3d follow-up).', null);
