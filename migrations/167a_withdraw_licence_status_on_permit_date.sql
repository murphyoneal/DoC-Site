-- 167a - withdraw every statement of a contractor's licence status ON THE PERMIT DATE (ruling 805, ruling 1).
--
-- get_parcel_permit_facts compared the permit date with the licence's CURRENT period (original_date..expiry_date)
-- from a DBPR file that holds current licences only and no history, and served either:
--   finding       "...licence was not active on the permit date..."          12,170 permits, 591 named licences
--   corroboration "...held an active Florida (DBPR) licence on the permit date" 73,549 permits
-- (measured 2026-09-30 on permit_contractor_match_resolved). A licence held under an earlier period, or lapsed and
-- reinstated, is invisible to that file, so BOTH directions are unsupportable. The negative one accuses a named
-- business of unlicensed contracting. Withdrawn, not softened: the claim is not ours to make in any wording.
--
-- What replaces it is only what the file supports: the licence the NAME matched, the file date that lists it, and
-- the plain statement that the file carries no history. The keys finding / corroboration / active_at_permit_date /
-- checked_as_of are kept and set NULL so the deployed renderer (which shows them only when present) stops showing
-- the claim the moment this applies, with no front-end change needed first. register_note is additive.
--
-- Unserved and NOT changed here (reported for a ruling): match_contractor_license (no callers, no grant) computes
-- status_at_permit incl. 'lapsed_before_permit' the same way.

set local statement_timeout = 0;

do $$
declare d text; d0 text; n_end int;
begin
  d := pg_get_functiondef('public.get_parcel_permit_facts'::regproc);
  d0 := d;
  n_end := (length(d) - length(replace(d, 'END FROM c)', ''))) / length('END FROM c)');

  if d !~ 'CASE WHEN m\.permit_num IS NULL OR m\.match_ambiguous THEN NULL.*?END AS active_at_permit' then
    raise exception '167a: CTE anchor not found - not applied';
  end if;
  d := regexp_replace(d, 'CASE WHEN m\.permit_num IS NULL OR m\.match_ambiguous THEN NULL.*?END AS active_at_permit',
                      'NULL::boolean AS active_at_permit  -- 167a: no status-on-permit-date arithmetic; the file has no history');

  if d !~ 'ELSE jsonb_build_object\(\s*''predicate'',''contractor_licence_at_permit_date''.*?licensed work was authorized\.''\s*ELSE NULL END\)' then
    raise exception '167a: payload anchor not found - not applied';
  end if;
  d := regexp_replace(d,
    'ELSE jsonb_build_object\(\s*''predicate'',''contractor_licence_at_permit_date''.*?licensed work was authorized\.''\s*ELSE NULL END\)',
    $r$ELSE (SELECT jsonb_build_object(
                'predicate','contractor_licence_in_register_file',
                'matched', true, 'license_number', c.license_number, 'business_name', c.business_name,
                'match_basis', 'business name on the permit (the permit carries no licence number)',
                'register_file_date', rf.register_file_date, 'register_file_state', rf.register_file_state,
                'register_note', CASE
                   WHEN rf.register_file_state = 'in_latest_file' THEN
                     'The contractor name on the permit matches DBPR licence '||c.license_number||', which the Florida construction licence file dated '||to_char(rf.register_file_date,'FMDD Mon YYYY')||' lists as current. That file carries no licence history, so we cannot state what the licence status was on the permit date. The match is by business name.'
                   WHEN rf.register_file_state = 'absent_from_latest_file' THEN
                     'The contractor name on the permit matches DBPR licence '||c.license_number||', which was listed in the Florida construction licence file dated '||to_char(rf.register_file_date,'FMDD Mon YYYY')||' but is not in the latest file. The file carries no licence history, so we cannot state the licence status on the permit date. The match is by business name.'
                   ELSE
                     'The contractor name on the permit matches DBPR licence '||c.license_number||'. The licence file carries no history, so we cannot state the licence status on the permit date. The match is by business name.'
                   END,
                'active_at_permit_date', NULL, 'checked_as_of', NULL, 'finding', NULL, 'corroboration', NULL,
                'source','permit_contractor_match_resolved + DBPR contractors','source_tier','analysis_inference')
              FROM (SELECT (SELECT k.register_file_date FROM public.contractors k WHERE k.license_number = c.license_number ORDER BY k.register_file_date DESC NULLS LAST LIMIT 1) AS register_file_date,
                           (SELECT k.register_file_state FROM public.contractors k WHERE k.license_number = c.license_number ORDER BY k.register_file_date DESC NULLS LAST LIMIT 1) AS register_file_state) rf)$r$);

  if position('contractor_licence_at_permit_date' in d) > 0 or position('not active on the permit date' in d) > 0
     or position('on the permit date — an independent second witness' in d) > 0 then
    raise exception '167a: an old claim survived the patch';
  end if;
  if (length(d) - length(replace(d, 'END FROM c)', ''))) / length('END FROM c)') <> n_end then
    raise exception '167a: patch changed the structure (END FROM c) count % -> %)', n_end,
      (length(d) - length(replace(d, 'END FROM c)', ''))) / length('END FROM c)');
  end if;
  execute d;
end $$;

-- The withdrawal is logged in the same transaction (ruling 799 G3 / 805): if the log write fails, the change fails.
insert into public.moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via)
values (now(), 'cc', 'build_agent', 'withdraw_served_statement', 'get_parcel_permit_facts', array['contractor_licence.finding','contractor_licence.corroboration','contractor_licence.active_at_permit_date'],
  jsonb_build_object('predicate','contractor_licence_at_permit_date',
                     'permits_asserting_not_active', 12170, 'distinct_licences_named_not_active', 591,
                     'permits_asserting_active', 73549, 'measured', '2026-09-30 on permit_contractor_match_resolved (191,536 rows)',
                     'served_by', array['get_parcel_permit_facts -> get_pir_report -> PIR page + Roz get_property_record']),
  jsonb_build_object('predicate','contractor_licence_in_register_file','finding',null,'corroboration',null,'active_at_permit_date',null,
                     'replacement','register_note: licence listed as current in the file dated X; no history, so status on the permit date cannot be stated'),
  'Ruling 805 (1): the licence status on a permit date was computed from a DBPR file holding current licences only and no history, so neither "not active" nor "active" on that date is supported by the source. The negative form accused 591 named licences of unlicensed contracting on 12,170 permits. Withdrawn, not reworded.',
  'migration 167a');

do $$
declare f jsonb; lic jsonb; n int;
begin
  -- call the served function on the founding parcel and on a parcel with a matched licence
  f := get_parcel_permit_facts(74, '633001001890');
  if f->>'count' is null or (f->>'count')::int < 1 then raise exception '167a: founding parcel lost its permits: %', f; end if;
  -- the same parcel resolution the function itself uses: volusia_parcels_govt_source.pid -> altkey = PARID
  select e->'contractor_licence' into lic
    from (select m.parid, m.permit_num from permit_contractor_match_resolved m
           where not m.match_ambiguous and nullif(m.original_date,'') is not null and nullif(m.expiry_date,'') is not null
             and not (m.permit_date between m.original_date::date and m.expiry_date::date)   -- a formerly ACCUSED permit
           limit 1) m
    join volusia_parcels_govt_source vp on vp.altkey::bigint::text = m.parid
    cross join lateral jsonb_array_elements(get_parcel_permit_facts(74, vp.pid)->'permits') e
   where e->>'permit_number' = m.permit_num
   limit 1;
  if lic is null then raise exception '167a: could not exercise a matched licence'; end if;
  if lic->>'predicate' <> 'contractor_licence_in_register_file' or lic->'finding' <> 'null'::jsonb
     or lic->'corroboration' <> 'null'::jsonb or coalesce(lic->>'register_note','') not like '%cannot state%' then
    raise exception '167a: served payload not as intended: %', lic;
  end if;
  if not has_function_privilege('anon', 'public.get_parcel_permit_facts(numeric,text)', 'execute') then
    raise exception '167a: get_parcel_permit_facts lost its execute grant';
  end if;
  select count(*) into n from moderation_action where action = 'withdraw_served_statement' and via = 'migration 167a';
  if n <> 1 then raise exception '167a: expected one log row, found %', n; end if;
end $$;
