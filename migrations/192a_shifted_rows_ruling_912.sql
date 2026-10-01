-- 192a - the 7 column-shifted construction rows, as ruled in 912 (question 807).
--
-- Each row: license_number '74' (the county code), the licence SERIAL in primary_status, the class in secondary_status,
-- a bare surname as business_name. Our parser's output, not a DBPR record. Measured 2026-10-01 before writing: each has
-- exactly one business (same slug) and one business_licences link; 0 claims, photos, redirects, profiles, appeals or
-- other references of any kind.
--
-- R-A, 4 rows that duplicate a correctly loaded licence -> DELETED. Full contractor, business and licence-link rows
-- preserved in moderation_action.before_state; the shifted slug 308s to the correct business.
--   "A record the source withdrew is evidence and is kept. A record the source never published is our own artefact
--    and is removed - preserved in the log, not in the register." (912)
-- R-B, 3 rows with no clean source anywhere -> WITHDRAWN from serving (contractors.active = false, the row-visibility
--   flag every public reader filters on), kept, and recorded as a named gap in build_backlog. All three expired
--   (2000, 2000, 2023), so even repaired they would read not_in_latest_file: the product loss is nil.
--
-- FOUND WHILE MEASURING, fixed here because it is the same artefact: 11 Volusia permits were linked BY NAME to these
-- rows (FORESTA 7, GILLESPIE 2, PAYNE 1, SONTAG 1), so a report could show "licence 74". The name index is now built
-- from served rows only (active IS NOT FALSE), the 11 raw matches are deleted, and the incremental refresh re-matches
-- those permits against the corrected index. Whatever they now match (or don't) is the honest answer.
--
-- The shape detection (191c) is scoped to served rows. A withdrawn row that is re-activated turns it red again.

do $$
declare
  r record; v_c jsonb; v_b jsonb; v_bl jsonb; v_target uuid; v_res jsonb; n int; acl_before text; acl_after text; d text;
begin
  -- RECOUNT INSIDE THE MIGRATION (re-count before destructive DDL): exactly these 7, still shifted, still unreferenced
  create temp table _s (slug text primary key, grp text, target text) on commit drop;
  insert into _s values
    ('michael-new-smyrna-beach-fl',       'A', 'southern-foam-insulation-inc-new-smyrna-beach-fl'),
    ('antonio-manuel-ormond-beach-fl',    'A', 'all-volusia-flagler-heating-air-llc-ormond-beach-fl'),
    ('robert-new-smyrna-beach-fl',        'A', 'paradise-cove-construction-l-l-c-new-smyrna-beach-fl'),
    ('joseph-anthony-oak-hill-fl',        'A', 'foresta-enterprises-inc-oak-hill-fl'),
    ('alan-keith-jr-daytona-beach-fl',    'B', null),
    ('barton-charles-new-smyrna-beach-fl','B', null),
    ('catherine-maire-ormond-beach-fl',   'B', null);

  select count(*) into n from contractors where primary_status ~ '^[0-9]+$';
  if n is distinct from 7 then raise exception '192a: expected 7 shifted rows, found %', n; end if;
  select count(*) into n from _s join contractors c on c.slug = _s.slug
   where c.primary_status ~ '^[0-9]+$' and c.license_number = '74';
  if n is distinct from 7 then raise exception '192a: the 7 named slugs are not the 7 shifted rows (%)', n; end if;
  select count(*) into n from _s join contractors c on c.slug = _s.slug
   where exists (select 1 from claim_requests t where t.contractor_id = c.id)
      or exists (select 1 from work_contribution t where t.contractor_id = c.id)
      or exists (select 1 from permit_claims t where t.contractor_id = c.id)
      or exists (select 1 from permit_filers t where t.contractor_id = c.id)
      or exists (select 1 from permit_submission_contractors t where t.contractor_id = c.id)
      or exists (select 1 from businesses b join business_slug_redirects x on x.business_id = b.id where b.canonical_contractor_id = c.id)
      or exists (select 1 from businesses b join business_profile x on x.business_id = b.id where b.canonical_contractor_id = c.id)
      or exists (select 1 from businesses b join business_appeal x on x.business_id = b.id where b.canonical_contractor_id = c.id)
      or (select count(*) from business_licences t where t.contractor_id = c.id) <> 1;
  if n is distinct from 0 then raise exception '192a: % of the 7 rows gained references since measurement', n; end if;

  -- R-A: delete the 4 duplicates, preserved in the log, 308 to the correct business
  for r in select _s.*, c.id cid from _s join contractors c on c.slug = _s.slug where grp = 'A' loop
    select b.id into v_target from businesses b where b.slug = r.target;
    if v_target is null then raise exception '192a: target business % not found', r.target; end if;
    if not exists (select 1 from businesses b join contractors c2 on c2.id = b.canonical_contractor_id
                    where b.id = v_target and c2.register_file_state = 'in_latest_file') then
      raise exception '192a: target % is not a licence in the latest file', r.target; end if;
    select to_jsonb(c) into v_c from contractors c where c.id = r.cid;
    select to_jsonb(b) into v_b from businesses b where b.canonical_contractor_id = r.cid;
    select jsonb_agg(to_jsonb(bl)) into v_bl from business_licences bl where bl.contractor_id = r.cid;
    perform _log_action('cc', 'delete_parse_artefact', 'contractors', array[r.cid::text, v_b->>'id'],
      jsonb_build_object('contractor', v_c, 'business', v_b, 'business_licences', v_bl),
      jsonb_build_object('redirect', r.slug || ' -> ' || r.target),
      'Ruling 912 R-A (question 807): column-shifted parse artefact (licence 74, surname as business) duplicating a licence already served correctly by ' || r.target || '. A record the source never published is our artefact: removed from the register, preserved here in full.', null);
    delete from business_licences where contractor_id = r.cid;
    delete from businesses where canonical_contractor_id = r.cid;
    delete from contractors where id = r.cid;
    insert into business_slug_redirects (old_slug, business_id) values (r.slug, v_target);
    v_res := resolve_business_slug(r.slug);
    if (v_res->>'slug') is distinct from r.target or (v_res->>'redirect')::boolean is distinct from true then
      raise exception '192a: % does not resolve as a redirect to % (got %)', r.slug, r.target, v_res; end if;
  end loop;

  -- R-B: withdraw the 3 with no clean source, keep them
  for r in select _s.*, c.id cid from _s join contractors c on c.slug = _s.slug where grp = 'B' loop
    select to_jsonb(c) into v_c from contractors c where c.id = r.cid;
    perform _log_action('cc', 'withdraw_from_serving', 'contractors', array[r.cid::text], v_c,
      jsonb_build_object('active', false),
      'Ruling 912 R-B (question 807): column-shifted row with no correctly parsed source anywhere (not in the Sep file, the June frozen copy or the archive under its real number). Withdrawn from serving and kept as the only trace of the mangled record; named gap in build_backlog.', null);
    update contractors set active = false where id = r.cid;
  end loop;

  insert into build_backlog (title, priority, status, spec_ref, evidence)
  values ('Named gap: 3 Florida construction licences held garbled by our parser, unrepairable from any source we hold',
          'low', 'open', 'bus 807, ruling 912 R-B, migration 192a',
          'Column-shifted rows (licence 74, serial in primary_status), withdrawn from serving 2026-10-01 and kept. By trade+serial they are CPC0023577 (exp 06/14/2000), CGC0061296 (exp 09/01/2000), FRO0014795 (exp 11/01/2023). Not in the Sep 2026 file, the June frozen copy or dbpr_construction_snapshot under those numbers. Repair needs a DBPR file carrying them; even repaired they read not_in_latest_file.');

  -- the name index links permits from served rows only
  select coalesce(proacl::text, '') into acl_before from pg_proc where oid = 'public.rebuild_contractor_name_index()'::regprocedure;
  d := pg_get_functiondef('public.rebuild_contractor_name_index()'::regprocedure);
  if (select count(*) from regexp_matches(d, 'from contractors where business_name is not null;', 'g')) <> 1 then
    raise exception '192a: name-index anchor missing or not unique'; end if;
  d := replace(d, 'from contractors where business_name is not null;',
    'from contractors where business_name is not null and active is not false;  -- 192a: withdrawn rows are never linked');
  execute d;
  select coalesce(proacl::text, '') into acl_after from pg_proc where oid = 'public.rebuild_contractor_name_index()'::regprocedure;
  if acl_after is distinct from acl_before then
    if acl_before like '%anon=X%' then grant execute on function public.rebuild_contractor_name_index() to anon; end if;
    if acl_before like '%authenticated=X%' then grant execute on function public.rebuild_contractor_name_index() to authenticated; end if;
    select coalesce(proacl::text, '') into acl_after from pg_proc where oid = 'public.rebuild_contractor_name_index()'::regprocedure;
    if acl_after is distinct from acl_before then raise exception '192a: name-index grants changed % -> %', acl_before, acl_after; end if;
  end if;
  perform rebuild_contractor_name_index();
  if exists (select 1 from contractor_name_index where license_number = '74') then raise exception '192a: licence 74 still in the name index'; end if;

  select count(*) into n from permit_contractor_match where license_number = '74';
  if n is distinct from 11 then raise exception '192a: expected 11 raw matches to licence 74, found %', n; end if;
  perform _log_action('cc', 'delete_parse_artefact_matches', 'permit_contractor_match', array['license_number=74'],
    (select jsonb_agg(to_jsonb(m)) from permit_contractor_match m where m.license_number = '74'), null,
    'Ruling 912: 11 permits linked by name to the shifted rows (licence 74). Derived rows, deleted and re-matched against the corrected name index.', null);
  delete from permit_contractor_match where license_number = '74';
  perform refresh_permit_contractor_match();
  if exists (select 1 from permit_contractor_match_resolved where license_number = '74') then
    raise exception '192a: a permit still resolves to licence 74'; end if;

  -- the shape detection reads served rows
  update data_defect_registry
     set detection_sql = replace(detection_sql, '     where not exists (select 1 from public.test_fixture',
                                                '     where c.active is not false  -- 192a: served rows; a re-activated withdrawn row turns this red
       and not exists (select 1 from public.test_fixture'),
         false_positive_notes = 'Green since 192a (2026-10-01): the 4 duplicate shifted rows deleted, the 3 unrepairable ones withdrawn (active=false, named gap in build_backlog). Scoped to served rows; the ZZ test fixture excluded via test_fixture by licence key. primary_status vocabulary is not enumerated (code list unrecorded); its shape is.'
   where defect_id = 'contractor-status-vocabulary-and-shape';
  if not found then raise exception '192a: shape detection missing'; end if;
  select detection_sql into d from data_defect_registry where defect_id = 'contractor-status-vocabulary-and-shape';
  if position('c.active is not false' in d) = 0 then raise exception '192a: detection scope not applied'; end if;
  execute d into r;
  if r.ok is distinct from true then raise exception '192a: shape detection still red (% rows)', r.row_count; end if;

  if not has_function_privilege('anon', 'public.contractor_register_search(text,integer)', 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then
    raise exception '192a: register grants lost'; end if;
end $$;
