-- 220a - presuit notice on the /rights state pages: three states, every served claim cited (work order 1002, item 4:
-- "warranty first, fixing presuit_required to three states first").
--
-- WHAT WAS WRONG, read from primary statute text on 2026-10-03:
--  * OHIO SAID "No general statutory pre-suit notice." Ohio Rev. Code 1312.04 requires written notice at least 60 days
--    before suing a residential contractor, and 1312.08(B) dismisses an action filed without it. LIVE FALSE STATEMENT on
--    /rights/ohio; a homeowner who followed it would have their suit dismissed.
--  * MN, VA, NJ said "no requirement"; each has a notice requirement inside its statutory warranty (Minn. Stat. 327A.03,
--    Va. Code 55.1-357(E), N.J.S.A. 46:3B-7(c)). MN's own note said "Notice of claim required" beside presuit_required=false.
--  * MD, MA: the "none" was incomplete (MD condo warranty notice, Real Prop. 11-131(e); MA c.93A 30-day demand).
--  * The ten "not required" rows had NO cite at all. A negative legal claim with no source is an assertion.
--  * Eight states (AK HI IA IN MT NM SD WV) held a cite and a day count beside a NULL boolean, so the page said nothing.
--    Seven are required. IOWA IS NOT, for a homeowner: Iowa Code 686.7 limits the chapter to class actions over new
--    construction. MT's 21 and NM's 60 were the builder's RESPONSE windows, not notice periods; SD's 30 is a wait after
--    notice. Those day counts are corrected.
--  * IL, MI, NC, PA: no statute found, but only by searches that found nothing (MI: one section read). Empty is a sentinel,
--    not a finding - these become not_researched, and the page says we have not confirmed it rather than "none".
-- THREE STATES: presuit_state is generated from presuit_required (true required / false not_required / null
-- not_researched), so the two can never disagree, and get_verified_construction_law serves it as an ADDED key (the page
-- in the companion PR derives the same value until it reads the key). Every required/not_required row now has a cite,
-- and a served-path detection keeps it that way.

alter table public.construction_defect_law
  add column presuit_state text generated always as (
    case when presuit_required then 'required' when not presuit_required then 'not_required' else 'not_researched' end) stored;

create temp table _p (st text, req boolean, days int, cite text, note text) on commit drop;
insert into _p values
 ('OH', true, 60, 'Ohio Rev. Code §§ 1312.04, 1312.08',
  'Ohio requires written notice of the defect to the residential contractor at least 60 days before you sue or start arbitration, and the contractor may offer to inspect and repair. A suit filed without the notice is dismissed without prejudice. The contractor must describe this process in your contract.'),
 ('AK', true, 90, 'AS 09.45.881',
  'Alaska requires written notice of the claim to the construction professional at least 90 days before you file suit or arbitration over a defect in a dwelling. The professional may respond with an offer to repair or settle.'),
 ('HI', true, 90, 'Haw. Rev. Stat. §§ 672E-3, 672E-13',
  'Hawaii requires written notice of the claim to the contractor at least 90 days before you file suit over a dwelling defect. A suit filed without it is dismissed without prejudice, or paused if refiling would be too late.'),
 ('IN', true, 60, 'Ind. Code §§ 32-27-3-2, 32-27-3-6',
  'Indiana requires written notice of the claim to the construction professional at least 60 days before you file a construction defect action over a residence. An action filed first can be dismissed without prejudice.'),
 ('MT', true, null, 'Mont. Code Ann. § 70-19-427',
  'Montana requires written notice of the claim to the construction professional before you sue over a residential defect. The law sets no lead time; the professional has 21 days after the notice to respond. Serving the notice pauses the limitation period.'),
 ('NM', true, null, 'N.M. Stat. Ann. § 42-14-3',
  'New Mexico requires the buyer of a newly built home to give the seller written notice before suing over a defect; the seller has 60 days to respond. Exceptions include an immediate threat to safety and a home that cannot be lived in.'),
 ('SD', true, 30, 'SDCL §§ 21-1-15, 21-1-16',
  'South Dakota requires written notice to the construction professional, and you may not sue until 30 days after serving it, or sooner if the professional refuses to fix the defect. A suit filed early is paused until the notice step is complete.'),
 ('WV', true, 90, 'W. Va. Code §§ 21-11A-7, 21-11A-8',
  'West Virginia requires written notice of the claim at least 90 days before you sue a licensed contractor you hired directly for residential work. It does not apply to claims of $5,000 or less, to unlicensed contractors, or to imminent safety threats. A suit filed without notice is dismissed without prejudice on request.'),
 ('IA', false, null, 'Iowa Code §§ 686.3, 686.7',
  'Iowa''s construction-defect notice law (written notice 120 days before filing) applies only to class actions over defects in new construction, not to an individual homeowner''s suit.'),
 ('MN', false, null, 'Minn. Stat. §§ 327A.02, 327A.03',
  'Minnesota has no general pre-suit notice law, but its statutory home warranty does: report the defect to the builder or home improvement contractor in writing within six months of discovering it, or the warranty claim is lost. The builder may then inspect and offer to repair before you sue.'),
 ('VA', false, null, 'Va. Code § 55.1-357',
  'Virginia has no general pre-suit notice law, but before suing on the implied warranty on a new home, the buyer must first send the seller written notice of the claim by certified mail, overnight delivery or hand delivery with a receipt. The seller then has up to six months to fix it.'),
 ('NJ', false, null, 'N.J.S.A. §§ 46:3B-7, 46:3B-9',
  'New Jersey has no pre-suit notice law for defect lawsuits. A claim against the state new home warranty fund requires notifying the builder first and allowing reasonable time for repair, and choosing that route can bar other remedies.'),
 ('MD', false, null, 'Md. Code, Real Prop. § 11-131',
  'Maryland has no statewide pre-suit notice law for houses. A new condominium''s developer warranty requires notice of the defect within the warranty period.'),
 ('MA', false, null, 'Mass. Gen. Laws c. 93A, § 9(3); c. 142A, § 17',
  'Massachusetts has no construction-specific pre-suit notice law. A consumer-protection (Chapter 93A) claim, including one over a home improvement contractor''s violation, needs a written demand at least 30 days before suit.'),
 ('IL', null, null, null, null), ('MI', null, null, null, null), ('NC', null, null, null, null), ('PA', null, null, null, null);

do $$
declare n int; bad text;
begin
  -- the rows must be what we read before writing this; a moved row aborts rather than overwriting someone else's edit
  select string_agg(d.state_code, ',') into bad from public.construction_defect_law d join _p p on p.st = d.state_code
   where not ((p.st in ('AK','HI','IA','IN','MT','NM','SD','WV') and d.presuit_required is null and d.presuit_days is not null)
           or (p.st in ('OH','MN','VA','NJ','MD','MA','IL','MI','NC','PA') and d.presuit_required = false and d.presuit_cite is null));
  if bad is not null then raise exception '220a: rows changed since they were read: %', bad; end if;

  update public.construction_defect_law d
     set presuit_required = p.req, presuit_days = p.days, presuit_cite = p.cite, presuit_note = p.note,
         source_note = coalesce(d.source_note, '') || E'\n\n' || case
           when p.req is null then 'PRESUIT NOT RESEARCHED (220a, 2026-10-03): the prior "no pre-suit notice" note had no cite, and the only check made was a search that found no statute. Empty is a sentinel, not a finding - not_researched until primary text is read.'
           else 'PRESUIT VERIFIED 2026-10-03 (220a) from primary statute text (' || p.cite || '). ' || case d.state_code
             when 'OH' then 'CORRECTED: the prior note said no pre-suit notice; ORC 1312.04 requires 60 days and 1312.08(B) dismisses without it.'
             when 'IA' then 'CORRECTED: the 120-day notice is real but 686.7 limits the chapter to class actions over new construction.'
             when 'MT' then 'CORRECTED: 21 days is the professional''s response window; the statute sets no lead time.'
             when 'NM' then 'CORRECTED: 60 days is the seller''s response window; the statute sets no lead time.'
             when 'SD' then '30 days is a wait after notice before suit, not a notice lead time.'
             when 'MN' then 'CORRECTED: the prior false flag contradicted its own note; the warranty requires 6-month written notice.'
             when 'VA' then 'CORRECTED: warranty-claim notice under 55.1-357(E).'
             when 'NJ' then 'CORRECTED: warranty-fund notice under 46:3B-7(c); not a precondition to suit (46:3B-9).'
             else '' end end
    from _p p where p.st = d.state_code;
  get diagnostics n = row_count;
  if n <> 18 then raise exception '220a: updated % rows, expected 18', n; end if;
end $$;

-- served payload: add presuit_state (additive; the function has no anon grant - pages read it server-side)
do $$
declare d text; a1 text; a2 text; o text := 'presuit_required, presuit_days, presuit_cite, presuit_note,';
begin
  select coalesce(proacl::text,'') into a1 from pg_proc where oid = 'public.get_verified_construction_law()'::regprocedure;
  d := pg_get_functiondef('public.get_verified_construction_law()'::regprocedure);
  if (length(d) - length(replace(d, o, ''))) / length(o) <> 1 then raise exception '220a: payload anchor not found exactly once'; end if;
  execute replace(d, o, 'presuit_required, presuit_state, presuit_days, presuit_cite, presuit_note,');
  if a1 like '%anon=X%' then execute 'grant execute on function public.get_verified_construction_law() to anon'; end if;
  if a1 like '%authenticated=X%' then execute 'grant execute on function public.get_verified_construction_law() to authenticated'; end if;
  select coalesce(proacl::text,'') into a2 from pg_proc where oid = 'public.get_verified_construction_law()'::regprocedure;
  if a2 is distinct from a1 then raise exception '220a: grants changed % -> %', a1, a2; end if;
end $$;

-- /rights was a served surface with no row here, so nothing on it could declare reachability.
insert into public.served_surface (surface, description, liveness_sql)
values ('rights_state_pages', 'Homeowner rights pages /rights/[state] (construction-defect law per state)',
        'select jsonb_array_length(public.get_verified_construction_law()) > 0');

insert into public.data_defect_registry (defect_id, name, discovered_on, discovered_via, class, severity, detection_sql, expected_state,
  expected_denominator, false_positive_notes, status, attribution, remediation, reachable_on, severity_if_reachable)
values ('presuit-claim-served-without-a-cite',
  'A /rights state page states whether pre-suit notice is required, with no statute cited',
  current_date, 'cc 2026-10-03: Ohio was served "No general statutory pre-suit notice" with no cite; ORC 1312.04 requires 60 days', 'null_as_value', 'blocking',
$q$with s as (select jsonb_array_elements(public.get_verified_construction_law()) e)
select count(*) filter (where e->>'presuit_state' is null
                           or (e->>'presuit_state' in ('required','not_required') and coalesce(e->>'presuit_cite','') = '')
                           or (e->>'presuit_state' = 'not_required' and coalesce(e->>'presuit_note','') = '')
                           or (e->>'presuit_state' = 'not_researched' and e->>'presuit_required' is not null)) = 0 as ok,
       count(*) filter (where e->>'presuit_state' is null
                           or (e->>'presuit_state' in ('required','not_required') and coalesce(e->>'presuit_cite','') = '')
                           or (e->>'presuit_state' = 'not_required' and coalesce(e->>'presuit_note','') = '')
                           or (e->>'presuit_state' = 'not_researched' and e->>'presuit_required' is not null)) as row_count,
       count(*) as population
  from s$q$,
  'clean', 'served /rights state rows (get_verified_construction_law)',
  'Reads the served payload, not the table. A required or not_required claim must carry a statute cite; not_required must also carry the note that says what DOES apply (warranty notice, consumer demand). not_researched renders as "we have not confirmed", never as "none".',
  'active', 'ours', 'Read the primary statute and cite it, or set presuit_required NULL (not_researched).', 'rights_state_pages', 'blocking');

do $$
declare det jsonb; red jsonb; j jsonb;
begin
  execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'presuit-claim-served-without-a-cite')) into det;
  if (det->>'ok')::boolean is distinct from true or coalesce((det->>'population')::int, 0) < 50 then raise exception '220a: detection not clean over 50: %', det; end if;
  -- red run: the founding case, Ohio served a negative with no cite
  begin
    update public.construction_defect_law set presuit_required = false, presuit_cite = null where state_code = 'OH';
    execute format('select to_jsonb(x) from (%s) x', (select detection_sql from public.data_defect_registry where defect_id = 'presuit-claim-served-without-a-cite')) into red;
    if (red->>'ok')::boolean is distinct from false then raise exception '220a: red run stayed green: %', red; end if;
    raise exception 'redrun_done';
  exception when raise_exception then
    if sqlerrm <> 'redrun_done' then raise; end if;
  end;
  -- served values, called
  select e into j from jsonb_array_elements(public.get_verified_construction_law()) e where e->>'state_code' = 'OH';
  if j->>'presuit_state' is distinct from 'required' or (j->>'presuit_days')::int is distinct from 60 or j->>'presuit_cite' !~ '1312' then raise exception '220a: Ohio not served as required: %', j; end if;
  select e into j from jsonb_array_elements(public.get_verified_construction_law()) e where e->>'state_code' = 'IA';
  if j->>'presuit_state' is distinct from 'not_required' or j->>'presuit_note' !~ 'class actions' then raise exception '220a: Iowa wrong: %', j; end if;
  select e into j from jsonb_array_elements(public.get_verified_construction_law()) e where e->>'state_code' = 'PA';
  if j->>'presuit_state' is distinct from 'not_researched' or j->>'presuit_note' is not null then raise exception '220a: PA wrong: %', j; end if;
  raise notice '220a: % ; states %', det, (select jsonb_object_agg(presuit_state, n) from (select presuit_state, count(*) n from public.construction_defect_law group by 1) x);
end $$;

select public._log_action('cc', 'presuit_three_states', 'construction_defect_law',
  array['construction_defect_law','get_verified_construction_law','data_defect_registry'], null,
  jsonb_build_object('corrected', 'OH (live false), MN, VA, NJ, MD, MA, IA, MT, NM, SD', 'set_required', 'AK HI IN MT NM SD WV', 'not_researched', 'IL MI NC PA'),
  'Work order 1002 item 4: presuit to three states, every served claim cited, from primary statute text.', null);
