-- 220b - new-home warranty for the 29 states that had none (work order 1002, item 4: "warranty first").
--
-- warranty_regime / warranty_cite / transfers_to_buyer were NULL on 29 of 50 rows. Filled from PRIMARY sources read on
-- 2026-10-03 by three research subagents: codified statute text on legislature sites (FindLaw where blocked), and the
-- opinions themselves (Google Scholar, CourtListener, vLex, FindLaw case law) - never a fifty-state chart or law-firm
-- summary. Where the courts have not decided a point, the row says "Unsettled" rather than guessing: NM and ND have not
-- decided whether a new-home sale carries an implied warranty at all; WI has no published decision; AK and HI have no
-- express appellate adoption. transfers_to_buyer is the point a later buyer needs most, and 9 states say NO.
-- Not rendered on any page today (StateRightsLanding reads none of the three); served by get_verified_construction_law.
-- Read-only through a later opinion's citation, not opened directly (recorded per row in source_note): Cochran (AL),
-- Wawak (AR), Kirk (IA), Bethlahmy (ID), Theis (IN), Norton (NH), Jeanguneat (OK), Padula (RI), Rothberg (VT).

create temp table _w (st text, regime text, cite text, xfer text, unread text) on commit drop;
insert into _w values
 ('AK', 'No Alaska Supreme Court decision adopts an implied warranty of habitability for new-home sales. The court recognises an implied warranty of fitness where a builder holds itself out as specially qualified (Lewis). Unsettled for new-home sales.',
  'Lewis v. Anchorage Asphalt Paving Co., 535 P.2d 1188 (Alaska 1975)', 'Unsettled: no appellate decision found.', 'Lewis read only as cited in Alaska Pac. Assurance Co. v. Collins, 794 P.2d 936 (Alaska 1990).'),
 ('AL', 'Common-law implied warranty of habitability on a builder-vendor''s sale of a new house to the first purchaser. It can be disclaimed in writing (Turner).',
  'Cochran v. Keeton, 252 So. 2d 313 (Ala. 1971); Turner v. Westhampton Court, LLC, 903 So. 2d 82 (Ala. 2004)',
  'NO - later owners have no implied-warranty claim against the builder (Boackle v. Bedwell Constr. Co., 770 So. 2d 1076 (Ala. 2000)).', 'Cochran read only as cited in Turner.'),
 ('AR', 'Common-law implied warranty of habitability, sound workmanship and proper construction on a builder-vendor''s sale of a new home. It can be disclaimed with clear language (O''Mara v. Dykema, 942 S.W.2d 854 (Ark. 1997)).',
  'Wawak v. Stewart, 449 S.W.2d 922 (Ark. 1970); Blagg v. Fred Hunt Co., 612 S.W.2d 321 (Ark. 1981)',
  'YES - for a reasonable time, for latent defects not discoverable on inspection that appear after the purchase (Blagg).', 'Wawak read only as cited in Blagg.'),
 ('CT', 'New Home Warranties Act: implied warranties that a new home is free from faulty materials, built to sound engineering standards and in a workmanlike manner, and fit for habitation, for one year from deed or possession. A completed house''s warranty can be excluded only by a detailed signed instrument.',
  'Conn. Gen. Stat. §§ 47-116 to 47-121',
  'NO under the statute - it protects the original buyer only (§ 47-116), except where a vendor sells through an intermediate buyer to evade it (§ 47-119). The year runs from the first deed or possession.', null),
 ('DE', 'Common-law implied warranty of good quality and workmanship in residential construction. No statutory defect warranty; the New Home Buyers Protection Act covers only an escrow for unfinished work.',
  'Council of Unit Owners of Breakwater House Condo. v. Simpler, 603 A.2d 792 (Del. 1992)', 'Unsettled: no appellate decision found.', null),
 ('HI', 'Hawaii courts have applied an implied warranty of habitability to new homes and condominium units only where the builder conceded it; no appellate court has expressly adopted it. Disclaimers are strictly construed.',
  'AOAO Newtown Meadows v. Venture 15, Inc., 167 P.3d 225 (Haw. 2007)', 'Unsettled: no appellate decision found.', null),
 ('IA', 'Common-law implied warranty of workmanlike construction from a builder-vendor of a home.',
  'Kirk v. Ridgway, 373 N.W.2d 491 (Iowa 1985); Speight v. Walters Dev. Co., 744 N.W.2d 108 (Iowa 2008)',
  'YES - for latent defects not discoverable on reasonable inspection (Speight), within the limitation period and the statute of repose, which runs from completion.', 'Kirk read only as cited in Speight.'),
 ('ID', 'Common-law implied warranty of habitability from a builder-vendor; it is a contract claim. A disclaimer must be clear, unambiguous and specific (Tusch).',
  'Bethlahmy v. Bechtel, 415 P.2d 698 (Idaho 1966); Tusch Enters. v. Coffin, 740 P.2d 1022 (Idaho 1987); Petrus Family Trust v. Kirk, 415 P.3d 358 (Idaho 2018)',
  'YES - for latent defects appearing within a reasonable time (Tusch), but the claim accrues at final completion of construction (Petrus; Idaho Code § 5-241(b)), not at resale.', 'Bethlahmy read only as cited in Tusch.'),
 ('IN', 'Common-law implied warranty of fitness for habitation, plus an optional statutory warranty a builder may give (2 years workmanship and systems, 4 years roof, 10 years major structural). The implied warranty can be disclaimed only under strict statutory conditions, including insurance (§ 32-27-2-9).',
  'Theis v. Heuer, 280 N.E.2d 300 (Ind. 1972); Ind. Code §§ 32-27-2-8, 32-27-2-9',
  'YES - the statutory warranty survives a sale and runs from the original warranty date (§ 32-27-2-8(b)); the implied warranty reaches later buyers for latent defects (Barnes v. Mac Brown & Co., 342 N.E.2d 619 (Ind. 1976)).', 'Theis read only as cited in Barnes.'),
 ('KS', 'Common-law implied warranty that a builder-vendor of a new house built it in a workmanlike manner.',
  'McFeeters v. Renollet, 500 P.2d 47 (Kan. 1972); Scantlin v. Superior Homes, Inc., 627 P.2d 825 (Kan. Ct. App. 1981)', 'Unsettled: no appellate decision found.', null),
 ('KY', 'Common-law implied warranty to the first purchaser that a new house''s major structural features were built in a workmanlike manner.',
  'Crawley v. Terhune, 437 S.W.2d 743 (Ky. 1969)',
  'NO - no implied warranty beyond the initial purchaser (Real Estate Marketing, Inc. v. Franz, 885 S.W.2d 921 (Ky. 1994)); a later buyer may have a building-code claim under KRS 198B.130.', null),
 ('LA', 'New Home Warranty Act: mandatory warranties of 1 year (defects generally), 2 years (plumbing, electrical, heating, cooling, ventilation) and 5 years (major structural). It cannot be waived for an owner-occupied home and is the exclusive remedy between builder and owner. Written notice by registered or certified mail within 1 year of knowing of the defect.',
  'La. R.S. 9:3141-3150',
  'YES - successors in title are owners while the warranties last (§ 3143(6)); the periods run from the first transfer of title or first occupancy, not from resale.', null),
 ('ME', 'Statutory warranty in written home construction contracts over $3,000 (skillful construction, building code, fit for habitation), and a common-law implied warranty of habitability from a builder-vendor to its purchaser.',
  '10 M.R.S. § 1487(7); Banville v. Huckins, 407 A.2d 294 (Me. 1979)', 'Unsettled: no appellate decision found.', null),
 ('MO', 'Common-law implied warranties of merchantable quality and fitness when the first purchaser buys a new home from a builder-vendor. A disclaimer must be conspicuous and fully disclose its consequences (Crowder).',
  'Smith v. Old Warson Dev. Co., 479 S.W.2d 795 (Mo. 1972); Crowder v. Vandendeale, 564 S.W.2d 879 (Mo. 1978)', 'NO - limited to the first purchaser (Crowder).', null),
 ('MS', 'New Home Warranty Act (1 year for building-standard defects, 6 years for major structural defects; notice to the builder within 90 days of knowing; cannot be waived for an owner-occupied home), alongside the common-law implied warranty.',
  'Miss. Code Ann. §§ 83-58-1 to 83-58-17; Keyes v. Guy Bailey Homes, Inc., 439 So. 2d 670 (Miss. 1983)',
  'YES - the statutory warranty transfers automatically to a later owner without extending its term (§ 83-58-13); Keyes abolished privity for later buyers'' implied-warranty claims.', null),
 ('MT', 'Common-law implied warranty that a builder-vendor''s new home is built in a workmanlike manner and suitable for habitation; breach is also a tort.',
  'Chandler v. Madsen, 642 P.2d 1028 (Mont. 1982); Degnan v. Executive Homes, Inc., 696 P.2d 431 (Mont. 1985)', 'Unsettled: no appellate decision found.', null),
 ('ND', 'An implied warranty of fitness applies to construction contracts under conditions (Dobler). Whether a builder''s sale of a finished new home carries one has not been decided.',
  'Dobler v. Malloy, 214 N.W.2d 510 (N.D. 1973); EVI Columbus, LLC v. Lamb, 2012 ND 141', 'Unsettled: no appellate decision found.', null),
 ('NE', 'Contractors impliedly warrant workmanlike performance; Nebraska has not adopted a separate implied warranty of habitability (Moglia).',
  'Moglia v. McNeil Co., 700 N.W.2d 608 (Neb. 2005)',
  'YES - the workmanlike warranty reaches later buyers for latent defects not discoverable on reasonable inspection (Moglia), within Neb. Rev. Stat. § 25-223 (4 years; 10-year repose from the builder''s work).', null),
 ('NH', 'Common-law implied warranty of workmanlike quality.',
  'Norton v. Burleaud, 342 A.2d 629 (N.H. 1975); Lempke v. Dagenais, 547 A.2d 290 (N.H. 1988)',
  'YES - a later buyer may sue the builder for latent defects that appear within a reasonable time after purchase (Lempke).', 'Norton read only as cited in Lempke.'),
 ('NM', 'Unsettled: New Mexico courts have not decided whether an implied warranty comes with the sale of a new house, and a written contract can exclude implied warranties (Newcum).',
  'Newcum v. Lawson, 684 P.2d 534 (N.M. Ct. App. 1984)', 'Unsettled: the warranty itself is not established.', null),
 ('OK', 'Common-law implied warranty that a new home is habitable and built in a workmanlike manner, for a reasonable time.',
  'Jeanguneat v. Jackie Hames Constr. Co., 576 P.2d 761 (Okla. 1978); Elden v. Simmons, 631 P.2d 739 (Okla. 1981)',
  'YES - the warranty does not end on transfer of title (Elden), but the contract claim ends five years after completion of the house, even for a later buyer (Jaworsky v. Frolich, 850 P.2d 1052 (Okla. 1992)).', 'Jeanguneat read only as cited in Elden.'),
 ('RI', 'Common-law implied warranty of workmanlike construction and fitness for habitation from a builder-vendor.',
  'Padula v. J.J. Deb-Cin Homes, Inc., 298 A.2d 529 (R.I. 1973); Nichols v. R.R. Beaufort & Assocs., 727 A.2d 174 (R.I. 1999)',
  'YES - privity is not required for latent defects (Nichols); defects must be discovered within ten years of substantial completion.', 'Padula read only as cited in Nichols.'),
 ('SD', 'Common-law implied warranty of reasonable workmanship and habitability that survives the deed, for a reasonable time.',
  'Waggoner v. Midwestern Dev., Inc., 154 N.W.2d 803 (S.D. 1967)',
  'NO - the warranty extends only to the buyer from the builder-vendor (Brown v. Fowler, 279 N.W.2d 907 (S.D. 1979)); a later buyer may sue in negligence.', null),
 ('TN', 'Common-law implied warranty to the first buyer that a new home is free of major structural defects and built in a workmanlike manner. It applies only where the contract is silent and may be expressly disclaimed (Dixon).',
  'Dixon v. Mountain City Constr. Co., 632 S.W.2d 538 (Tenn. 1982)',
  'NO - only the initial purchaser may sue on the implied warranty (Briggs v. Riversound Ltd. P''ship, 942 S.W.2d 529 (Tenn. Ct. App. 1996)); a later buyer may sue in negligence.', null),
 ('UT', 'Common-law implied warranty that a new residence is built in a workmanlike manner and fit for habitation; it cannot be waived or disclaimed (Davencourt).',
  'Davencourt at Pilgrims Landing HOA v. Davencourt at Pilgrims Landing LC, 2009 UT 65; Utah Code §§ 78B-4-513, 78B-2-225',
  'NO unless assigned - privity is required (§ 78B-4-513(5)), but rights may be assigned to a later owner (§ 78B-4-513(7)); suit within 6 years of completion (§ 78B-2-225(3)(a)).', null),
 ('VT', 'Common-law implied warranty of good workmanship and habitability from a builder-vendor, for latent defects. An exclusion must be conspicuous and unambiguous (Heath v. Palmer, 2006 VT 125).',
  'Rothberg v. Olenik, 262 A.2d 461 (Vt. 1970); Long Trail House Condo. Ass''n v. Engelberth Constr., Inc., 2012 VT 80',
  'PROBABLY NOT - the court requires contractual privity for an implied-warranty claim (Long Trail, a condominium case); a single-family resale is not squarely decided.', 'Rothberg read only as cited in Long Trail.'),
 ('WI', 'Unsettled: no Wisconsin statute and no published appellate decision recognising or rejecting an implied warranty from a home builder.',
  null, 'Unsettled: no appellate decision found.', 'Only an unpublished 1998 Court of Appeals opinion (Stuber v. Frank) addresses it.'),
 ('WV', 'Common-law implied warranty of habitability, fitness and workmanlike construction from a builder.',
  'Gamble v. Main, 300 S.E.2d 110 (W. Va. 1983); Sewell v. Gregory, 371 S.E.2d 82 (W. Va. 1988)',
  'YES - extends to later buyers for a reasonable time after construction, for latent defects (Sewell).', null),
 ('WY', 'Common-law implied warranty that a builder-vendor''s new house is built in a reasonably workmanlike manner and fit for habitation, for a reasonable time.',
  'Tavares v. Horstman, 542 P.2d 1275 (Wyo. 1975); Moxley v. Laramie Builders, Inc., 600 P.2d 733 (Wyo. 1979)',
  'YES - later buyers get the warranty, and it extends to builders who are not sellers (Moxley).', null);

do $$
declare n int; bad text;
begin
  if (select count(*) from _w) <> 29 then raise exception '220b: expected 29 rows'; end if;
  -- only rows still empty; a row someone filled since we read it aborts rather than being overwritten
  select string_agg(d.state_code, ',') into bad from public.construction_defect_law d join _w w on w.st = d.state_code
   where d.warranty_regime is not null or d.warranty_cite is not null or d.transfers_to_buyer is not null;
  if bad is not null then raise exception '220b: rows no longer empty: %', bad; end if;

  update public.construction_defect_law d
     set warranty_regime = w.regime, warranty_cite = w.cite, transfers_to_buyer = w.xfer,
         source_note = coalesce(d.source_note, '') || E'\n\n' || 'WARRANTY VERIFIED 2026-10-03 (220b) from primary sources (statute text; opinions read directly).'
           || coalesce(' NOT OPENED DIRECTLY: ' || w.unread, '')
    from _w w where w.st = d.state_code;
  get diagnostics n = row_count;
  if n <> 29 then raise exception '220b: updated % rows, expected 29', n; end if;

  if exists (select 1 from public.construction_defect_law where warranty_regime is null or transfers_to_buyer is null) then
    raise exception '220b: a state still has no warranty regime or transfer rule';
  end if;
  if (select count(*) from jsonb_array_elements(public.get_verified_construction_law()) e where e->>'warranty_regime' is null) <> 0 then
    raise exception '220b: served payload still has a state with no warranty_regime';
  end if;
  raise notice '220b: 29 filled; transfers YES % / NO % / unsettled %',
    (select count(*) from _w where xfer like 'YES%'), (select count(*) from _w where xfer like 'NO%' or xfer like 'PROBABLY NOT%'),
    (select count(*) from _w where xfer like 'Unsettled%');
end $$;

select public._log_action('cc', 'warranty_29_states', 'construction_defect_law', array['construction_defect_law'], null,
  jsonb_build_object('filled', 29, 'unsettled_regime', 'AK HI ND NM WI'),
  'Work order 1002 item 4: new-home warranty for the 29 states that had none, from primary sources.', null);
