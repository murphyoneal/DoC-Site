-- 143b — review-time checks on a self-registration (work order 706). FOR MURPHY'S REVIEW ONLY: no
-- public function reads this table, and nothing here is ever rendered on /r/ or anywhere else. A
-- finding about a named business on an inference is the line we do not cross.
--
-- TWO CHECKS, one table:
--   sunbiz      - automatic, on insert, Florida registrations only. An exact match on the normalised
--                 name (sunbiz_name_core, identical to the stored column) against the 12,808,196-row
--                 Florida corporate file POSTED 10 JUL 2026. Every match is listed as a CANDIDATE:
--                 name is the only key, and on names without an entity suffix only 19% match exactly
--                 one active entity (measured, 143 report). REPORT, NEVER DECIDE.
--   web_search  - a dated note of what a search found (website, business listing, social page,
--                 nothing), recorded by record_web_search_note(). Tier 4: internet, non-record, never a
--                 corroborator. ABSENCE IS NOT EVIDENCE OF FAKERY - a licensed contractor with no web
--                 presence is who the paid profile is for - so outcomes are stated neutrally.
--
-- No scoring, no automatic rejection, no third-party ratings. Murphy reads every registration.

create table if not exists public.registration_review_check (
  id           uuid primary key default gen_random_uuid(),
  business_id  uuid not null references public.registered_business(id) on delete cascade,
  check_kind   text not null check (check_kind in ('sunbiz', 'web_search')),
  outcome      text not null check (outcome in (
                 'entity_name_found', 'entity_name_found_several', 'entity_name_not_found', 'not_applicable',
                 'web_presence_found', 'no_web_presence_found')),
  finding      text not null,
  source_label text not null,
  source_date  date,
  detail       jsonb,
  performed_by text not null,
  performed_at timestamptz not null default now()
);
create index if not exists registration_review_check_business_idx on public.registration_review_check(business_id);
alter table public.registration_review_check enable row level security;
revoke all on public.registration_review_check from anon, authenticated;
grant select, insert, update, delete on public.registration_review_check to service_role;

create or replace function public._sunbiz_filing_type(p text) returns text
language sql immutable set search_path = public as $$
  select case p when 'FLAL' then 'Florida LLC' when 'DOMP' then 'Florida corporation'
                when 'DOMNP' then 'Florida non-profit corporation' when 'FORL' then 'out-of-state LLC registered in Florida'
                when 'FORP' then 'out-of-state corporation registered in Florida' when 'DOMLP' then 'Florida limited partnership'
                when 'FORLP' then 'out-of-state limited partnership registered in Florida'
                when 'FORNP' then 'out-of-state non-profit registered in Florida'
                else 'filing type ' || coalesce(p, 'not recorded') end
$$;

-- The Sunbiz check for one registration. Writes one row; returns it.
create or replace function public.registration_sunbiz_check(p_business_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare
  b registered_business%rowtype;
  v_key text; v_posted date; v_hits jsonb; v_n int; v_active int;
  v_outcome text; v_finding text; v_src text;
begin
  select * into b from registered_business where id = p_business_id;
  if not found then raise exception 'no registration %', p_business_id; end if;
  select posted_date into v_posted from sunbiz_corporate limit 1;  -- one file, one posted date (10 Jul 2026)
  v_src := 'Florida Division of Corporations corporate file (Sunbiz), posted ' || to_char(v_posted, 'FMDD Mon YYYY');

  if b.state_geo_id <> 'US-12' then
    v_outcome := 'not_applicable';
    v_finding := 'Not checked: the Sunbiz file covers entities registered in Florida, and this business registered in '
                 || (select name from geo_reference where geo_id = b.state_geo_id) || '. We hold no other state''s corporate register.';
  else
    v_key := sunbiz_name_core(b.business_name);
    select jsonb_agg(jsonb_build_object('corporation_number', corporation_number, 'name', corporation_name,
             'status', case status when 'A' then 'active' when 'I' then 'inactive' else status end,
             'type', _sunbiz_filing_type(filing_type), 'filed', file_date, 'city', initcap(city))
             order by (status = 'A') desc, file_date desc)
      into v_hits
      from (select * from sunbiz_corporate where name_core = v_key and v_key <> '' order by (status = 'A') desc, file_date desc limit 10) s;
    select count(*), count(*) filter (where status = 'A') into v_n, v_active
      from sunbiz_corporate where name_core = v_key and v_key <> '';
    if v_n = 0 then
      v_outcome := 'entity_name_not_found';
      v_finding := 'Sunbiz file posted ' || to_char(v_posted, 'FMDD Mon YYYY') || ': no entity with this name. '
        || 'Not a finding about the business: an entity formed after ' || to_char(v_posted, 'FMDD Mon YYYY')
        || ', a trade (fictitious) name, or a sole trader would not appear in this file.';
    elsif v_n = 1 then
      v_outcome := 'entity_name_found';
      v_finding := 'Sunbiz file posted ' || to_char(v_posted, 'FMDD Mon YYYY') || ': one entity with this name - '
        || (v_hits->0->>'name') || ', ' || (v_hits->0->>'status') || ', ' || (v_hits->0->>'type')
        || ', filed ' || to_char((v_hits->0->>'filed')::date, 'FMDD Mon YYYY')
        || coalesce(', ' || nullif(v_hits->0->>'city', ''), '') || '. A name match, not proof it is this business.';
    else
      v_outcome := 'entity_name_found_several';
      v_finding := 'Sunbiz file posted ' || to_char(v_posted, 'FMDD Mon YYYY') || ': ' || v_n || ' entities with this name ('
        || v_active || ' active). Listed for review; none is assumed to be this business.';
    end if;
  end if;

  insert into registration_review_check (business_id, check_kind, outcome, finding, source_label, source_date, detail, performed_by)
  values (p_business_id, 'sunbiz', v_outcome, v_finding, v_src, v_posted,
          case when v_hits is not null then jsonb_build_object('name_key', v_key, 'entities', v_hits, 'total', v_n) end,
          'registration_sunbiz_check');
  return jsonb_build_object('outcome', v_outcome, 'finding', v_finding);
end $$;

-- Runs the Sunbiz check on every new registration. A failure is recorded as a warning and never
-- blocks the registration: losing a review aid is recoverable, losing a registration is not.
create or replace function public._registration_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  begin
    perform registration_sunbiz_check(new.id);
  exception when others then
    raise warning 'registration_sunbiz_check failed for %: %', new.id, sqlerrm;
  end;
  return new;
end $$;
drop trigger if exists registration_sunbiz_check_trg on public.registered_business;
create trigger registration_sunbiz_check_trg after insert on public.registered_business
  for each row execute function public._registration_after_insert();

-- A web-search note, recorded by whoever ran the search (Murphy, or cc at review time). The finding
-- must read as a fact about a search, never a judgement about the business.
create or replace function public.record_web_search_note(p_business_id uuid, p_found boolean, p_urls text[] default null,
                                                         p_note text default null, p_by text default 'murphy')
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare v_finding text;
begin
  if not exists (select 1 from registered_business where id = p_business_id) then raise exception 'no registration %', p_business_id; end if;
  v_finding := 'Web search ' || to_char(now() at time zone 'America/New_York', 'FMDD Mon YYYY') || ': '
    || case when p_found then 'found ' || coalesce(array_to_string(p_urls, ', '), 'a web presence')
            else 'no website or business listing found' end
    || coalesce('. ' || nullif(btrim(p_note), ''), '') || '.';
  insert into registration_review_check (business_id, check_kind, outcome, finding, source_label, source_date, detail, performed_by)
  values (p_business_id, 'web_search', case when p_found then 'web_presence_found' else 'no_web_presence_found' end,
          v_finding, 'Web search (internet, not a record)', (now() at time zone 'America/New_York')::date,
          jsonb_build_object('urls', p_urls), p_by);
  return jsonb_build_object('finding', v_finding);
end $$;

drop view if exists public.registration_review_queue;
create view public.registration_review_queue as
select b.id, b.created_at, b.business_name, s.admin1_abbr as state, co.name as county,
       case b.place_state when 'place' then _place_display(b.place_geo_id) when 'unincorporated' then 'Unincorporated' end as place,
       b.place_state, b.trades,
       b.contact_name, b.contact_email, b.publish_listing, b.florida_duplicate_state, b.florida_duplicate_slugs,
       (select jsonb_agg(jsonb_build_object('kind', rc.kind, 'number', rc.number, 'state', rc.issuing_state_geo_id,
                                            'check', rc.check_state, 'note', rc.check_note))
          from registered_credential rc where rc.business_id = b.id) as credentials,
       (select jsonb_agg(jsonb_build_object('check', k.check_kind, 'outcome', k.outcome, 'finding', k.finding,
                                            'entities', k.detail->'entities') order by k.performed_at)
          from registration_review_check k where k.business_id = b.id) as review_checks
  from registered_business b
  join geo_reference s on s.geo_id = b.state_geo_id
  left join geo_reference co on co.geo_id = b.county_geo_id
 where b.review_state = 'received'
 order by b.created_at;
revoke all on public.registration_review_queue from anon, authenticated;

revoke all on function public.registration_sunbiz_check(uuid), public.record_web_search_note(uuid, boolean, text[], text, text)
  from public, anon, authenticated;
grant execute on function public.registration_sunbiz_check(uuid), public.record_web_search_note(uuid, boolean, text[], text, text)
  to service_role;

-- the registration already waiting (Murphy's test) gets its check too
select public.registration_sunbiz_check(id) from public.registered_business b
 where not exists (select 1 from public.registration_review_check k where k.business_id = b.id and k.check_kind = 'sunbiz');
