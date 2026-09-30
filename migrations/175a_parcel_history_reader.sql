-- 175a - read every claim back FROM THE PARCEL as dated property history (814 step 6, dispatch 854 B2).
--
-- 814: "If the claims are only reachable through a profile, we have built two directories and called it a
-- property record." Until now nothing read attestation_register by parcel except the finding readers, which
-- 174a locked to subject_kind = 'finding'. This adds the parcel-side reader: permits + deeds + claims, one list,
-- date order, each claim carrying its tier, contradiction and audience as READABLE text, not just columns.
--
-- (1) attestation_claim_state excluded is_test rows, so a throwaway acceptance test could never be read back
--     through it. Split into ONE base view carrying is_test (attestation_claim_state_all) and keep
--     attestation_claim_state as its non-test filter - same columns, same order, one tier definition. Measured
--     before: nothing depends on attestation_claim_state (pg_depend + prosrc both empty).
-- (2) get_parcel_history(co_no, parcel_id, include_test default false). Membership is total (839); every item
--     carries its audience and this reader does NOT filter on it - service_role only until a consumer that
--     applies the audience exists. Permits and deeds come from the served functions themselves (never a
--     second read of the tables), so the history cannot disagree with the report.

create or replace view public.attestation_claim_state_all as
 select a.id, a.co_no, a.parcel_id, a.party_kind, a.party_ref, a.subject_kind, a.subject_ref, a.assertion, a.event_date,
    a.attested_at as asserted_at, a.evidence, a.supersedes,
    exists (select 1 from attestation_register s where s.supersedes = a.id) as superseded,
    case
      when a.party_kind = 'county_officer' then 'issued_through_us'
      when exists (select 1 from attestation_corroboration c where c.attestation_id = a.id
                    and c.outcome = any (array['issued_through_our_intake','county_permit_names_this_contractor','owner_confirms','listing_names_this_agent','utility_bill_verified'])) then 'corroborated'
      else 'stated_by_party'
    end as tier,
    exists (select 1 from attestation_corroboration c where c.attestation_id = a.id
             and c.outcome = any (array['county_permit_names_another_contractor','owner_denies','listing_does_not_name_this_agent','utility_bill_not_verified'])) as contradicted,
    a.assertion = any (array['did_not_do_this_work','denies_named_contractor_did_work','not_my_property','did_not_handle_transaction','not_our_product','not_for_sale','withdraws_publication']) as is_negative,
    case
      when a.party_kind = 'searcher' then 'internal_only'
      when a.party_kind = 'owner_occupant' and a.subject_kind = any (array['property','item_approval']) then 'owner_and_operator'
      when exists (select 1 from attestation_corroboration c where c.attestation_id = a.id
                    and c.outcome = any (array['owner_denies','county_permit_names_another_contractor'])) then 'parties_and_operator'
      else 'public_with_tier'
    end as audience,
    a.is_test
   from attestation_register a
  where a.subject_kind <> 'finding';

create or replace view public.attestation_claim_state as
 select id, co_no, parcel_id, party_kind, party_ref, subject_kind, subject_ref, assertion, event_date, asserted_at, evidence,
        supersedes, superseded, tier, contradicted, is_negative, audience
   from public.attestation_claim_state_all
  where is_test = false;

revoke all on public.attestation_claim_state_all from public, anon, authenticated;
grant select on public.attestation_claim_state_all to service_role;

create or replace function public.get_parcel_history(p_co_no numeric, p_parcel_id text, p_include_test boolean default false)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $$
declare v_permits jsonb; v_deeds jsonb; v_claims jsonb; v_items jsonb;
begin
  v_permits := coalesce((get_parcel_permit_facts(p_co_no, p_parcel_id)::jsonb)->'permits', '[]'::jsonb);
  v_deeds   := coalesce((get_parcel_transaction_facts(p_co_no, p_parcel_id)::jsonb)->'conveyances', '[]'::jsonb);

  select coalesce(jsonb_agg(x), '[]'::jsonb) into v_claims from (
    select jsonb_build_object(
      'kind', 'claim',
      'date', coalesce(s.event_date, s.asserted_at::date),
      'date_basis', case when s.event_date is not null then 'date of the event, as stated by the party' else 'date the claim was filed' end,
      'filed_at', s.asserted_at,
      'claim_id', s.id,
      'party_kind', s.party_kind,
      'party', coalesce((select b.display_name from businesses b where s.party_kind = 'contractor' and b.id::text = s.party_ref), s.party_ref),
      'subject_kind', s.subject_kind,
      'subject_ref', s.subject_ref,
      'assertion', s.assertion,
      'is_negative', s.is_negative,
      'tier', s.tier,
      'contradicted', s.contradicted,
      'superseded', s.superseded,
      'audience', s.audience,
      'is_test', s.is_test,
      'statement',
        'The ' || replace(s.party_kind, '_', ' ') || ' '
        || coalesce((select b.display_name from businesses b where s.party_kind = 'contractor' and b.id::text = s.party_ref), s.party_ref)
        || ' states: ' || replace(s.assertion, '_', ' ')
        || coalesce(' (permit ' || (s.subject_ref->>'permit_number') || ')', '') || '.',
      'tier_label',
        case s.tier
          when 'issued_through_us' then 'Issued through our county permit intake.'
          when 'corroborated' then 'Stated by the ' || replace(s.party_kind, '_', ' ') || ' and corroborated by an independent record.'
          else 'Stated by the ' || replace(s.party_kind, '_', ' ') || '. Not corroborated by any record we hold.'
        end
        || case when s.contradicted then ' CONTRADICTED by a record we hold - see corroborations.' else '' end,
      'corroborations', coalesce((select jsonb_agg(jsonb_build_object('outcome', c.outcome, 'basis', c.basis, 'found_by', c.found_by, 'found_at', c.found_at) order by c.found_at)
                                    from attestation_corroboration c where c.attestation_id = s.id), '[]'::jsonb)) x
      from attestation_claim_state_all s
     where s.co_no = p_co_no and s.parcel_id = p_parcel_id and (p_include_test or not s.is_test)) q;

  select coalesce(jsonb_agg(i order by (i->>'date') desc nulls last, i->>'kind'), '[]'::jsonb) into v_items from (
    select jsonb_build_object('kind','permit','date', p->>'date', 'source', p->>'source', 'source_tier', p->>'source_tier',
             'permit_number', p->>'permit_number', 'work_description', p->>'work_description',
             'contractor_as_recorded', p->>'contractor', 'closeout', p->'closeout', 'contractor_licence', p->'contractor_licence') i
      from jsonb_array_elements(v_permits) p
    union all
    select jsonb_build_object('kind','deed','date', d->>'date', 'source', 'volusia_cama_sales', 'source_tier', 'county_assessor_record',
             'instrument_type', d->>'instrument_type', 'book', d->>'book', 'page', d->>'page', 'sale_price', d->'sale_price',
             'nominal', d->'nominal')
      from jsonb_array_elements(v_deeds) d
    union all
    select c from jsonb_array_elements(v_claims) c) u;

  return jsonb_build_object(
    'subject', jsonb_build_object('co_no', p_co_no, 'parcel_id', p_parcel_id),
    'read_from', 'the parcel',
    'counts', jsonb_build_object('permits', jsonb_array_length(v_permits), 'deeds', jsonb_array_length(v_deeds),
                                 'claims', jsonb_array_length(v_claims),
                                 'claims_negative', (select count(*) from jsonb_array_elements(v_claims) c where (c->>'is_negative')::boolean),
                                 'claims_contradicted', (select count(*) from jsonb_array_elements(v_claims) c where (c->>'contradicted')::boolean)),
    'includes_test_claims', p_include_test,
    'audience_note', 'Every item is a member of this parcel''s history; audience says who may see it and is not applied here.',
    'items', v_items);
end $$;
comment on function public.get_parcel_history(numeric, text, boolean) is
  'The parcel-side read-back (814 step 6): permits + deeds (from the served functions) + every claim on the spine with tier, contradiction and audience, one dated list. Operator-level: audience is carried, not applied.';

revoke all on function public.get_parcel_history(numeric, text, boolean) from public, anon, authenticated;
grant execute on function public.get_parcel_history(numeric, text, boolean) to service_role;

select public._log_action('cc', 'build_parcel_history_reader', 'attestation_register', array['get_parcel_history','attestation_claim_state_all'],
  null, jsonb_build_object('reader','get_parcel_history','view','attestation_claim_state_all'),
  'Ruling 814 step 6 / dispatch 854 B2: claims must read back from the parcel as dated history; split claim-state view so test claims are readable.', null);

do $$
declare h jsonb; n_before int; n_after int;
begin
  -- the two views agree on every non-test row (one tier definition)
  select count(*) into n_before from attestation_claim_state;
  select count(*) into n_after from attestation_claim_state_all where not is_test;
  if n_before <> n_after then raise exception '175a: views disagree % vs %', n_before, n_after; end if;
  -- the founding parcel reads back its five permits and two deeds
  h := get_parcel_history(74, '633001001890');
  if (h->'counts'->>'permits')::int <> 5 or (h->'counts'->>'deeds')::int <> 2 then raise exception '175a: founding parcel history wrong: %', h->'counts'; end if;
  -- the register grants are untouched (new SECDEF function DDL fires the scoped trigger on itself only)
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '175a: register grants lost'; end if;
end $$;
