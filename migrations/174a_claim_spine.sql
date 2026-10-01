-- 174a - THE CLAIM SPINE (rulings 810, 830, 833, 837-843, 854 B1; HUB_AND_SPOKES_APPENDIX_A A.2).
--
-- One shape for every party: a party asserts something about a PARCEL; we record who said it, when, on what
-- evidence, what we found independently, and who may see it. attestation_register is EXTENDED (right shape,
-- 0 rows, append-only, wipe-guarded) rather than a fifth claim table beside four.
--
-- It now holds TWO disjoint kinds of row, and its name will lie a little from here (819): subject_kind
-- 'finding' = the original use (an inspector/contractor/owner attesting to one of OUR findings); every other
-- subject_kind = a CLAIM by a party about a parcel. The two are disjoint BY CONSTRUCTION (CHECKs below).
--
-- READER LOCKS, SAME STEP (830 gate). Both existing readers filter subject_kind='finding' explicitly and count
-- only finding rows. Before this, the first claim written anywhere would have flipped the coverage caveat on
-- every parcel in Florida (833). A permanent served-path check proves it stays that way.
--
-- CONSTITUTION (A.0): the record belongs to the property (parcel is the only mandatory key); a party's present
-- state never rewrites a past record (no status filters a claim; a correction is a new row that supersedes);
-- visibility is an audience, derived, never a stored flag. Tiers (833): issued_through_us > corroborated >
-- stated_by_party > not_established. Negative claims are first-class values, counted separately.
-- Parcel explicit as a CONSTRAINT: 60,592 Volusia permit numbers span more than one parcel, so a permit claim
-- must carry (co_no, parcel_id) AND a permit number that exists ON THAT PARCEL - checked by the writer.

set local statement_timeout = 0;

-- 1. The table -------------------------------------------------------------------------------------------------
alter table public.attestation_register
  alter column co_no set not null,
  alter column parcel_id set not null,
  alter column source_class drop not null,
  alter column attested_state drop not null,
  alter column attester_name drop not null,
  alter column subject drop not null,
  add column subject_kind text,
  add column party_kind   text,
  add column party_ref    text,
  add column subject_ref  jsonb,
  add column assertion    text,
  add column event_date   date,
  add column evidence     jsonb,
  add column supersedes   uuid references public.attestation_register(id),
  add column filed_via    text;
update public.attestation_register set subject_kind = 'finding';  -- 0 rows today; states the rule for any that exist
alter table public.attestation_register alter column subject_kind set not null;

alter table public.attestation_register
  add constraint attestation_parcel_fk foreign key (co_no, parcel_id) references public.parcel_attributes (co_no, parcel_id),
  add constraint attestation_subject_kind_check check (subject_kind in
      ('finding','permit','transaction','listing','property','market_status','installed_product','item_approval')),
  add constraint attestation_party_kind_check check (party_kind is null or party_kind in
      ('county_officer','contractor','agent','owner_occupant','searcher','manufacturer')),
  -- disjoint by construction: a finding row uses the finding columns and no party columns; a claim row the reverse
  add constraint attestation_finding_row_shape check (subject_kind <> 'finding' or
      (subject is not null and source_class is not null and attested_state is not null and attester_name is not null
       and party_kind is null and assertion is null and party_ref is null)),
  add constraint attestation_claim_row_shape check (subject_kind = 'finding' or
      (party_kind is not null and party_ref is not null and assertion is not null and subject_ref is not null
       and source_class is null and attested_state is null and finding_state is null
       and disputes_finding = false and disputed_finding_ref is null)),
  -- which party may assert what about which subject; state names name their cause (827); negatives are values
  add constraint attestation_assertion_by_party check (subject_kind = 'finding' or
      (party_kind = 'county_officer' and subject_kind = 'permit'           and assertion in ('issued_permit'))
   or (party_kind = 'contractor'     and subject_kind = 'permit'           and assertion in ('did_this_work','did_not_do_this_work'))
   or (party_kind = 'owner_occupant' and subject_kind = 'property'         and assertion in ('occupies_property'))
   or (party_kind = 'owner_occupant' and subject_kind = 'permit'           and assertion in ('confirms_named_contractor_did_work','denies_named_contractor_did_work','not_my_property'))
   or (party_kind = 'owner_occupant' and subject_kind = 'item_approval'    and assertion in ('approves_publication','withdraws_publication'))
   or (party_kind = 'agent'          and subject_kind in ('transaction','listing') and assertion in ('handled_transaction','did_not_handle_transaction','listed_this_property'))
   or (party_kind = 'searcher'       and subject_kind = 'market_status'    and assertion in ('for_sale','not_for_sale','does_not_know'))
   or (party_kind = 'manufacturer'   and subject_kind = 'installed_product' and assertion in ('installed_our_product','not_our_product'))),
  -- a claim about a permit names the permit; the parcel is already mandatory - never resolved by number alone
  add constraint attestation_permit_claim_names_permit check (subject_kind <> 'permit' or coalesce(subject_ref->>'permit_number','') <> '');

comment on table public.attestation_register is
  'TWO kinds of row (174a): subject_kind=finding - a person attesting to one of OUR findings (the original use, read by get_parcel_attestations); every other subject_kind - a CLAIM by a party (county_officer, contractor, agent, owner_occupant, searcher, manufacturer) about a parcel. Disjoint by CHECK. Append-only: a correction is a NEW row with supersedes. The parcel is the only mandatory key (the record belongs to the property). Tier and audience are DERIVED (attestation_claim_state), never stored. The name predates the claims; read this comment, not the name.';

-- 2. What WE found independently - append-only, one row per finding, cause-named outcomes ------------------------
create table public.attestation_corroboration (
  id             bigint generated always as identity primary key,
  attestation_id uuid not null references public.attestation_register(id),
  outcome        text not null check (outcome in (
                   'issued_through_our_intake',              -- county officer created the record in our workflow
                   'county_permit_names_this_contractor',    -- the county recorded this business's name on the permit
                   'county_permit_names_another_contractor', -- the county recorded a different name
                   'county_permit_names_no_contractor',
                   'owner_confirms', 'owner_denies',         -- the occupant, verified, answered the party's claim
                   'listing_names_this_agent', 'listing_does_not_name_this_agent',
                   'utility_bill_verified', 'utility_bill_not_verified',
                   'not_evaluable')),
  basis          text not null check (length(btrim(basis)) >= 10),
  found_by       text not null,        -- 'system:<function>' or an operator email
  found_at       timestamptz not null default now()
);
comment on table public.attestation_corroboration is
  'What we found independently about a claim (174a). Append-only; a later finding is a new row. Outcome names name their cause (827). Agreeing outcomes raise a claim to corroborated; a contradicting outcome never deletes anything - both stand, dated (837).';
create trigger append_only_attestation_corroboration before update or delete on public.attestation_corroboration
  for each row execute function public.append_only_strict();
create trigger append_only_no_truncate before truncate on public.attestation_corroboration
  for each statement execute function public.append_only_no_truncate();
revoke all on public.attestation_corroboration from anon, authenticated;
alter table public.attestation_corroboration enable row level security;

-- 3. Derived state: tier, contradiction, supersession, audience --------------------------------------------------
create or replace view public.attestation_claim_state as
select a.id, a.co_no, a.parcel_id, a.party_kind, a.party_ref, a.subject_kind, a.subject_ref, a.assertion,
       a.event_date, a.attested_at as asserted_at, a.evidence, a.supersedes,
       exists (select 1 from public.attestation_register s where s.supersedes = a.id) as superseded,
       case when a.party_kind = 'county_officer' then 'issued_through_us'
            when exists (select 1 from public.attestation_corroboration c where c.attestation_id = a.id
                          and c.outcome in ('issued_through_our_intake','county_permit_names_this_contractor','owner_confirms','listing_names_this_agent','utility_bill_verified'))
              then 'corroborated'
            else 'stated_by_party' end as tier,
       exists (select 1 from public.attestation_corroboration c where c.attestation_id = a.id
                and c.outcome in ('county_permit_names_another_contractor','owner_denies','listing_does_not_name_this_agent','utility_bill_not_verified')) as contradicted,
       a.assertion in ('did_not_do_this_work','denies_named_contractor_did_work','not_my_property','did_not_handle_transaction','not_our_product','not_for_sale','withdraws_publication') as is_negative,
       -- audience is derived from origin (13 Aug classes) and state, never stored (839)
       case when a.party_kind = 'searcher' then 'internal_only'                 -- a stranger's answer never renders (813)
            when a.party_kind = 'owner_occupant' and a.subject_kind in ('property','item_approval') then 'owner_and_operator'
            when exists (select 1 from public.attestation_corroboration c where c.attestation_id = a.id
                          and c.outcome in ('owner_denies','county_permit_names_another_contractor')) then 'parties_and_operator'  -- disagreement: both stand, nothing publishes (837)
            else 'public_with_tier' end as audience
  from public.attestation_register a
 where a.subject_kind <> 'finding' and a.is_test = false;
comment on view public.attestation_claim_state is
  'Every non-test CLAIM with its DERIVED tier (issued_through_us > corroborated > stated_by_party), contradiction, negativity, supersession and audience (174a). Nothing here is stored; the log is the state.';
revoke all on public.attestation_claim_state from anon, authenticated;

-- 4. Writers -----------------------------------------------------------------------------------------------------
create or replace function public.record_claim_corroboration(p_attestation_id uuid, p_outcome text, p_basis text, p_found_by text)
returns bigint language plpgsql security definer set search_path to 'public' as $$
declare v bigint;
begin
  insert into attestation_corroboration (attestation_id, outcome, basis, found_by)
  values (p_attestation_id, p_outcome, p_basis, p_found_by) returning id into v;
  return v;
end $$;

create or replace function public.file_parcel_claim(
  p_co_no numeric, p_parcel_id text, p_party_kind text, p_party_ref text, p_subject_kind text, p_subject_ref jsonb,
  p_assertion text, p_event_date date default null, p_evidence jsonb default null, p_supersedes uuid default null,
  p_via text default null, p_is_test boolean default false)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid; v_alt text; v_county_name text; v_party_names text[]; v_target uuid; v_target_party text;
begin
  -- a permit claim must name a permit that exists ON THIS PARCEL (never resolved by permit number alone)
  if p_subject_kind = 'permit' then
    if p_co_no <> 74 then raise exception 'no permit register held for county % - a permit claim cannot be checked', p_co_no; end if;
    v_alt := parcel_alt_key(p_co_no, p_parcel_id);
    select nullif(trim("CONTRACTOR"),'') into v_county_name from volusia_cama_permits
     where "PARID" = v_alt and "NUM" = p_subject_ref->>'permit_number' limit 1;
    if not found then raise exception 'permit % is not on parcel % in the county permit file', p_subject_ref->>'permit_number', p_parcel_id; end if;
  end if;

  insert into attestation_register (co_no, parcel_id, subject_kind, party_kind, party_ref, subject_ref, assertion,
                                    event_date, evidence, supersedes, filed_via, disputes_finding, is_test, attested_at)
  values (p_co_no, p_parcel_id, p_subject_kind, p_party_kind, p_party_ref, p_subject_ref, p_assertion,
          p_event_date, p_evidence, p_supersedes, p_via, false, p_is_test, now())
  returning id into v_id;

  -- automatic, independent corroboration where we hold something to test against
  if p_party_kind = 'county_officer' then
    perform record_claim_corroboration(v_id, 'issued_through_our_intake', 'The permit was created by a county officer through our intake workflow.', 'system:file_parcel_claim');
  elsif p_party_kind = 'contractor' and p_assertion = 'did_this_work' then
    -- party_ref is the business id; compare the county's recorded name with every name the business holds
    select array_agg(distinct normalize_name(n)) into v_party_names from (
      select b.display_name n from businesses b where b.id::text = p_party_ref
      union select c.business_name from business_licences bl join contractors c on c.id = bl.contractor_id where bl.business_id::text = p_party_ref) s
     where n is not null;
    perform record_claim_corroboration(v_id,
      case when v_county_name is null then 'county_permit_names_no_contractor'
           when normalize_name(v_county_name) = any (coalesce(v_party_names, '{}')) then 'county_permit_names_this_contractor'
           else 'county_permit_names_another_contractor' end,
      'County permit file contractor field "' || coalesce(v_county_name, '(blank)') || '" compared by normalised name with the claiming business''s names.',
      'system:file_parcel_claim');
  elsif p_party_kind = 'owner_occupant' and p_subject_kind = 'permit' and p_subject_ref ? 'responds_to' then
    -- the occupant answering a contractor's claim corroborates or contradicts THAT claim (837: opposite incentives)
    v_target := (p_subject_ref->>'responds_to')::uuid;
    select party_kind into v_target_party from attestation_register where id = v_target;
    if v_target_party is distinct from 'contractor' then raise exception 'responds_to must reference a contractor claim'; end if;
    perform record_claim_corroboration(v_target,
      case when p_assertion = 'confirms_named_contractor_did_work' then 'owner_confirms' else 'owner_denies' end,
      'The occupant of the parcel answered this claim (their own claim ' || v_id || ').', 'system:file_parcel_claim');
  end if;
  return v_id;
end $$;

revoke all on function public.file_parcel_claim(numeric,text,text,text,text,jsonb,text,date,jsonb,uuid,text,boolean) from public, anon, authenticated;
revoke all on function public.record_claim_corroboration(uuid,text,text,text) from public, anon, authenticated;
grant execute on function public.file_parcel_claim(numeric,text,text,text,text,jsonb,text,date,jsonb,uuid,text,boolean) to service_role;
grant execute on function public.record_claim_corroboration(uuid,text,text,text) to service_role;

-- 5. READER LOCKS - same step, explicit kind filter, counts over findings only ---------------------------------
do $$ declare d text; begin
  d := pg_get_functiondef('public.get_parcel_attestations(numeric,text)'::regprocedure);
  if position('and disputes_finding = false' in d) = 0 then raise exception '174a: get_parcel_attestations anchor not found'; end if;
  d := replace(d, 'and disputes_finding = false', 'and disputes_finding = false and subject_kind = ''finding''');
  execute d;

  d := pg_get_functiondef('public.get_parcel_attestations_facts(numeric,text)'::regprocedure);
  if position('select count(*) into held from attestation_register;' in d) = 0 then raise exception '174a: facts held anchor not found'; end if;
  if position('and is_test = false and disputes_finding is distinct from false;' in d) = 0 then raise exception '174a: facts withheld anchor not found'; end if;
  d := replace(d, 'select count(*) into held from attestation_register;', 'select count(*) into held from attestation_register where subject_kind = ''finding'';');
  d := replace(d, 'and is_test = false and disputes_finding is distinct from false;', 'and is_test = false and subject_kind = ''finding'' and disputes_finding is distinct from false;');
  execute d;
end $$;
grant execute on function public.get_parcel_attestations(numeric,text) to service_role, roz_payload_reader, consumer_report_readonly;
grant execute on function public.get_parcel_attestations_facts(numeric,text) to service_role, roz_payload_reader, consumer_report_readonly;

-- 6. The PERMANENT isolation check (833): a claim must change no parcel's finding output, including its own ------
create or replace function public.attestation_claim_isolation_ok() returns boolean
language plpgsql security definer set search_path to 'public' as $$
declare a0 text; b0 text; a1 text; b1 text; pa text := '633001001890'; pb text; ok boolean;
begin
  select parcel_id into pb from parcel_attributes where co_no = 74 and parcel_id <> pa order by parcel_id limit 1;
  a0 := get_parcel_attestations_facts(74, pa)::text; b0 := get_parcel_attestations_facts(74, pb)::text;
  begin
    -- a NON-test claim (is_test would be filtered anyway and prove nothing), inside a block that always rolls back
    insert into attestation_register (co_no, parcel_id, subject_kind, party_kind, party_ref, subject_ref, assertion, disputes_finding, is_test, attested_at)
    values (74, pb, 'market_status', 'searcher', 'isolation-probe', '{"probe":true}'::jsonb, 'for_sale', false, false, now());
    a1 := get_parcel_attestations_facts(74, pa)::text; b1 := get_parcel_attestations_facts(74, pb)::text;
    ok := (a0 = a1 and b0 = b1);
    raise exception 'ISOLATION_PROBE_ROLLBACK';
  exception when others then
    if sqlerrm <> 'ISOLATION_PROBE_ROLLBACK' then raise; end if;
  end;
  return ok;
end $$;
revoke all on function public.attestation_claim_isolation_ok() from public, anon, authenticated;
grant execute on function public.attestation_claim_isolation_ok() to service_role;

insert into data_defect_registry (defect_id, name, class, severity, detection_sql, false_positive_notes)
values ('claim-row-leaks-into-finding-readers',
  'A claim row on the spine changes what the finding readers (get_parcel_attestations / _facts) serve for any parcel',
  'access_control', 'blocking',
  $d$select public.attestation_claim_isolation_ok() as ok$d$,
  'Ruling 833: before 174a the first claim anywhere would have flipped the coverage caveat on every parcel (held = count(*) of the whole table). The probe writes a NON-test claim inside a block that always rolls back and asserts both the claimed parcel and another parcel serve byte-identical finding output. Rolled back, so side-effect free. 174a.');

-- 7. The record (799) --------------------------------------------------------------------------------------------
insert into public.moderation_action (occurred_at, actor, actor_kind, action, target_table, target_ids, before_state, after_state, basis, via)
values (now(), 'cc', 'build_agent', 'build_claim_spine', 'attestation_register',
  array['attestation_register','attestation_corroboration','attestation_claim_state','file_parcel_claim','get_parcel_attestations','get_parcel_attestations_facts'],
  jsonb_build_object('attestation_register_rows', 0, 'reader_filter', 'none - any row served; facts counted the whole table'),
  jsonb_build_object('kinds', 'finding | claim, disjoint by CHECK', 'parties', 'county_officer, contractor, agent, owner_occupant, searcher, manufacturer',
                     'tiers', 'issued_through_us > corroborated > stated_by_party (derived)', 'reader_filter', 'subject_kind = finding'),
  'Rulings 810/830/833/854 B1: one claim spine for every party, extending attestation_register, with the finding readers locked to findings in the same step and a permanent isolation check.',
  'migration 174a');

-- 8. Controls ----------------------------------------------------------------------------------------------------
do $$
declare x uuid; f0 text; f1 text;
begin
  f0 := get_parcel_attestations_facts(74, '633001001890')::text;
  -- a claim row carrying finding columns is refused
  begin
    insert into attestation_register (co_no, parcel_id, subject_kind, party_kind, party_ref, subject_ref, assertion, source_class, attested_state, disputes_finding, is_test, attested_at)
    values (74, '633001001890', 'permit', 'contractor', 'x', '{"permit_number":"1"}', 'did_this_work', 'contractor', 'present', false, true, now());
    raise exception '174a: CONTROL_FAILED shape';
  exception when others then if sqlerrm like '%CONTROL_FAILED%' then raise; end if; end;
  -- a party asserting outside its vocabulary is refused
  begin
    insert into attestation_register (co_no, parcel_id, subject_kind, party_kind, party_ref, subject_ref, assertion, disputes_finding, is_test, attested_at)
    values (74, '633001001890', 'permit', 'searcher', 'x', '{"permit_number":"1"}', 'did_this_work', false, true, now());
    raise exception '174a: CONTROL_FAILED vocabulary';
  exception when others then if sqlerrm like '%CONTROL_FAILED%' then raise; end if; end;
  -- a permit claim for a permit that is not on the parcel is refused by the writer
  begin
    perform file_parcel_claim(74, '633001001890', 'contractor', 'x', 'permit', '{"permit_number":"NOT-A-PERMIT"}', 'did_this_work', null, null, null, 'control', true);
    raise exception '174a: CONTROL_FAILED permit';
  exception when others then if sqlerrm like '%CONTROL_FAILED%' then raise; end if; if sqlerrm not like '%not on parcel%' then raise exception '174a: unexpected: %', sqlerrm; end if; end;
  -- a claim on a parcel that does not exist is refused (FK)
  begin
    insert into attestation_register (co_no, parcel_id, subject_kind, party_kind, party_ref, subject_ref, assertion, disputes_finding, is_test, attested_at)
    values (74, 'NO-SUCH-PARCEL', 'market_status', 'searcher', 'x', '{}', 'for_sale', false, true, now());
    raise exception '174a: CONTROL_FAILED fk';
  exception when others then if sqlerrm like '%CONTROL_FAILED%' then raise; end if; end;
  -- the permanent isolation check passes, and the founding parcel's finding output is unchanged
  if public.attestation_claim_isolation_ok() is not true then raise exception '174a: isolation check failed'; end if;
  f1 := get_parcel_attestations_facts(74, '633001001890')::text;
  if f0 is distinct from f1 then raise exception '174a: founding parcel finding output changed'; end if;
  if (select count(*) from attestation_register) <> 0 then raise exception '174a: controls left rows behind'; end if;
  if not has_function_privilege('anon', 'public.contractor_register_search'::regproc, 'execute')
     or not has_function_privilege('anon', 'public.agent_register_search'::regproc, 'execute') then raise exception '174a: register grants lost'; end if;
end $$;
